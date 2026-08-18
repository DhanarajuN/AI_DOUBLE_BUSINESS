import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
import '../models/business_profile.dart';
import '../models/channel.dart';
import '../models/doc_source.dart';
import '../models/industry.dart';
import '../theme/app_theme.dart';

const _kFirsts = ['Aarav', 'Priya', 'Rohan', 'Anjali', 'Vikram', 'Sneha', 'Karthik', 'Neha', 'Arjun', 'Divya', 'Rahul', 'Meera', 'Aditya', 'Pooja', 'Siddharth', 'Kavya', 'Ishaan', 'Riya', 'Aman', 'Tara'];
const _kLasts = ['Sharma', 'Iyer', 'Nair', 'Reddy', 'Patel', 'Gupta', 'Menon', 'Rao', 'Khan', 'Desai', 'Kapoor', 'Mehta', 'Bose', 'Pillai', 'Singh'];

class WorkspaceRepository extends ChangeNotifier {
  final _rand = Random();
  SharedPreferences? _prefs;

  BusinessProfile? business;
  List<Booking> bookings = [];
  List<DocSource> docs = [];
  List<Map<String, String>> chatMessages = [];
  int usageIn = 0;
  int usageOut = 0;
  int usageCalls = 0;
  List<int> usageDaily = List.filled(14, 0);

  String provider = 'openai';
  String apiKey = '';
  String model = '';
  String brand = 'AI Double';
  String accent = '#1D4ED8';
  AppThemeMode themeMode = AppThemeMode.system;
  String lang = 'en';
  bool autoSpeak = true;
  String currency = 'in';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    final bizJson = p.getString('biz');
    if (bizJson != null) business = BusinessProfile.fromJson(jsonDecode(bizJson) as Map<String, dynamic>);
    bookings = (p.getStringList('bookings') ?? [])
        .map((s) => Booking.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    docs = (p.getStringList('docs') ?? []).map((s) => DocSource.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
    chatMessages = (p.getStringList('chatMessages') ?? [])
        .map((s) => Map<String, String>.from(jsonDecode(s) as Map))
        .toList();
    usageIn = p.getInt('usageIn') ?? 0;
    usageOut = p.getInt('usageOut') ?? 0;
    usageCalls = p.getInt('usageCalls') ?? 0;
    final daily = p.getStringList('usageDaily');
    if (daily != null && daily.length == 14) usageDaily = daily.map(int.parse).toList();
    provider = p.getString('provider') ?? 'openai';
    apiKey = p.getString('apiKey') ?? '';
    model = p.getString('model') ?? '';
    brand = p.getString('brand') ?? 'AI Double';
    accent = p.getString('accent') ?? '#1D4ED8';
    themeMode = AppThemeMode.values.firstWhere(
      (m) => m.name == p.getString('themeMode'),
      orElse: () => AppThemeMode.system,
    );
    lang = p.getString('lang') ?? 'en';
    autoSpeak = p.getBool('autoSpeak') ?? true;
    currency = p.getString('currency') ?? 'in';
    notifyListeners();
  }

  Future<void> _saveBookings() async {
    await _prefs?.setStringList('bookings', bookings.map((b) => jsonEncode(b.toJson())).toList());
  }

  Future<void> _saveDocs() async {
    await _prefs?.setStringList('docs', docs.map((d) => jsonEncode(d.toJson())).toList());
  }

  Future<void> _saveUsage() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('usageIn', usageIn);
    await p.setInt('usageOut', usageOut);
    await p.setInt('usageCalls', usageCalls);
    await p.setStringList('usageDaily', usageDaily.map((e) => e.toString()).toList());
  }

  T _pick<T>(List<T> list) => list[_rand.nextInt(list.length)];
  String _randName() => '${_pick(_kFirsts)} ${_pick(_kLasts)}';

  BookingStatus _weightedStatus(int daysAgo) {
    final r = _rand.nextDouble();
    if (daysAgo <= 1) {
      if (r < 0.6) return BookingStatus.confirmed;
      if (r < 0.85) return BookingStatus.pending;
      return BookingStatus.completed;
    }
    if (r < 0.72) return BookingStatus.completed;
    if (r < 0.9) return BookingStatus.confirmed;
    return BookingStatus.noshow;
  }

  Future<void> ensureBusinessBelongsTo(String identity) async {
    if (business != null && business!.email != identity) {
      business = null;
      await _prefs?.remove('biz');
      notifyListeners();
    }
  }

  Future<void> ensureDefaultBusiness({required String name, required String owner, required String email}) async {
    if (business != null) return;
    await completeSignup(
      name: name,
      owner: owner,
      email: email,
      industryId: kIndustries.first.id,
      size: kTeamSizes.first,
      planId: 'growth',
      region: 'in',
    );
  }

  Future<void> completeSignup({
    required String name,
    required String owner,
    required String email,
    required String industryId,
    required String size,
    required String planId,
    required String region,
  }) async {
    business = BusinessProfile(
      name: name,
      owner: owner,
      email: email,
      industryId: industryId,
      size: size,
      planId: planId,
      region: region,
      createdAt: DateTime.now(),
    );
    currency = region;
    brand = name;
    await _prefs?.setString('biz', jsonEncode(business!.toJson()));
    await _prefs?.setString('currency', currency);
    await _prefs?.setString('brand', brand);
    await _seedBusinessData();
    notifyListeners();
  }

  Future<void> updateBusiness({String? name, String? owner, String? industryId, String? size}) async {
    if (business == null) return;
    business = business!.copyWith(name: name, owner: owner, industryId: industryId, size: size);
    if (name != null) {
      brand = name;
      await _prefs?.setString('brand', brand);
    }
    await _prefs?.setString('biz', jsonEncode(business!.toJson()));
    notifyListeners();
  }

  Future<void> setPlan(String planId) async {
    if (business == null) return;
    business = business!.copyWith(planId: planId);
    await _prefs?.setString('biz', jsonEncode(business!.toJson()));
    notifyListeners();
  }

  Future<void> _seedBusinessData() async {
    final ind = industryById(business?.industryId);
    final n = 9 + _rand.nextInt(8);
    final now = DateTime.now();
    final generated = <Booking>[];
    for (var i = 0; i < n; i++) {
      final daysAgo = _rand.nextInt(14);
      final time = now.subtract(Duration(days: daysAgo, minutes: _rand.nextInt(1440)));
      generated.add(Booking(
        id: 'bk${time.millisecondsSinceEpoch}_$i',
        customerName: _randName(),
        service: _pick(ind.services),
        channelId: _pick(kChannels).id,
        time: time,
        status: _weightedStatus(daysAgo),
      ));
    }
    generated.sort((a, b) => b.time.compareTo(a.time));
    bookings = generated;
    await _saveBookings();

    final daily = List<int>.filled(14, 0);
    for (final b in bookings) {
      final diffDays = now.difference(b.time).inDays;
      final d = 13 - (diffDays > 13 ? 13 : diffDays);
      final t = 900 + _rand.nextInt(2400);
      if (d >= 0 && d < 14) daily[d] += t;
    }
    usageDaily = daily;
    final total = daily.fold<int>(0, (a, b) => a + b);
    usageIn = (total * 0.58).round();
    usageOut = (total * 0.42).round();
    usageCalls = bookings.length;
    await _saveUsage();
  }

  Future<void> recordUsage(int inTok, int outTok) async {
    usageIn += inTok;
    usageOut += outTok;
    usageCalls += 1;
    if (usageDaily.length != 14) usageDaily = List.filled(14, 0);
    usageDaily[13] += inTok + outTok;
    await _saveUsage();
    notifyListeners();
  }

  Future<Booking> addBookingOn(DateTime day) async {
    final ind = industryById(business?.industryId);
    final hour = 9 + _rand.nextInt(9);
    final minute = [0, 15, 30, 45][_rand.nextInt(4)];
    final time = DateTime(day.year, day.month, day.day, hour, minute);
    final bk = Booking(
      id: 'bk${DateTime.now().millisecondsSinceEpoch}',
      customerName: _randName(),
      service: _pick(ind.services),
      channelId: _pick(kChannels).id,
      time: time,
      status: time.isAfter(DateTime.now()) ? BookingStatus.confirmed : BookingStatus.completed,
    );
    bookings.add(bk);
    bookings.sort((a, b) => b.time.compareTo(a.time));
    await _saveBookings();
    final t = 900 + _rand.nextInt(1600);
    await recordUsage((t * 0.58).round(), (t * 0.42).round());
    notifyListeners();
    return bk;
  }

  Future<void> _saveChat() async {
    await _prefs?.setStringList('chatMessages', chatMessages.map((m) => jsonEncode(m)).toList());
  }

  Future<void> addChatMessage(String role, String content) async {
    chatMessages.add({'role': role, 'content': content});
    await _saveChat();
    notifyListeners();
  }

  Future<void> clearChat() async {
    chatMessages = [];
    await _saveChat();
    notifyListeners();
  }

  Future<void> addTextDoc(String name, String text, {String category = kDocCategoryGeneral}) async {
    docs.add(DocSource(
      id: 'd${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      text: text.length > 20000 ? text.substring(0, 20000) : text,
      meta: '${(text.length / 1000).toStringAsFixed(1)}k chars',
      category: category,
    ));
    await _saveDocs();
    notifyListeners();
  }

  Future<void> addFileDoc(String name, String text, String meta, {String category = kDocCategoryGeneral}) async {
    docs.add(DocSource(
      id: 'd${DateTime.now().millisecondsSinceEpoch}${_rand.nextInt(9999)}',
      name: name,
      text: text.length > 20000 ? text.substring(0, 20000) : text,
      meta: meta,
      isFile: true,
      category: category,
    ));
    await _saveDocs();
    notifyListeners();
  }

  Future<void> removeDoc(String id) async {
    docs.removeWhere((d) => d.id == id);
    await _saveDocs();
    notifyListeners();
  }

  Future<void> clearDocs() async {
    docs = [];
    await _saveDocs();
    notifyListeners();
  }

  Future<void> setProvider(String v) async {
    provider = v;
    await _prefs?.setString('provider', v);
    notifyListeners();
  }

  Future<void> setApiKey(String v) async {
    apiKey = v;
    await _prefs?.setString('apiKey', v);
    notifyListeners();
  }

  Future<void> setModel(String v) async {
    model = v;
    await _prefs?.setString('model', v);
  }

  Future<void> setBrand(String v) async {
    brand = v.isEmpty ? 'AI Double' : v;
    await _prefs?.setString('brand', brand);
    notifyListeners();
  }

  Future<void> setAccent(String v) async {
    accent = v;
    await _prefs?.setString('accent', v);
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode v) async {
    themeMode = v;
    await _prefs?.setString('themeMode', v.name);
    notifyListeners();
  }

  Future<void> setLang(String v) async {
    lang = v;
    await _prefs?.setString('lang', v);
    notifyListeners();
  }

  Future<void> setAutoSpeak(bool v) async {
    autoSpeak = v;
    await _prefs?.setBool('autoSpeak', v);
    notifyListeners();
  }

  Future<void> setCurrency(String v) async {
    currency = v;
    await _prefs?.setString('currency', v);
    notifyListeners();
  }

  bool get keyReady => apiKey.trim().isNotEmpty;

  Future<void> resetAll() async {
    final p = _prefs;
    if (p != null) {
      for (final k in ['biz', 'bookings', 'docs', 'chatMessages', 'usageIn', 'usageOut', 'usageCalls', 'usageDaily', 'provider', 'apiKey', 'model', 'brand', 'accent', 'themeMode', 'lang', 'autoSpeak', 'currency']) {
        await p.remove(k);
      }
    }
    business = null;
    bookings = [];
    docs = [];
    chatMessages = [];
    usageIn = 0;
    usageOut = 0;
    usageCalls = 0;
    usageDaily = List.filled(14, 0);
    provider = 'openai';
    apiKey = '';
    model = '';
    brand = 'AI Double';
    accent = '#1D4ED8';
    themeMode = AppThemeMode.system;
    lang = 'en';
    autoSpeak = true;
    currency = 'in';
    notifyListeners();
  }
}
