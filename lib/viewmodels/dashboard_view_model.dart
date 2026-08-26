import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../constants/server_urls.dart';
import '../models/business_profile.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/job_type_instance_service.dart';
import '../services/session_storage.dart';

class DashboardViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;
  final SessionStorage _sessionStorage;
  final ApiClient _apiClient;

  DashboardViewModel(this._workspace, this._sessionStorage, this._apiClient) {
    _workspace.addListener(notifyListeners);
    _loadBusinessData();
  }

  Map<String, dynamic>? _businessData;
  Map<String, dynamic>? get businessData => _businessData;

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _orders = [];

  List<Map<String, dynamic>> get bookings => _bookings;
  int get bookingsCount => _bookings.length;

  List<Map<String, dynamic>> get orders => _orders;
  int get ordersCount => _orders.length;

  void updateOrderStatus(Map<String, dynamic> order, String status) {
    final id = (order['id'] ?? order['_id'])?.toString();
    final match = [..._bookings, ..._orders].firstWhere(
          (j) => (j['id'] ?? j['_id'])?.toString() == id,
          orElse: () => order,
        );

    match[AppConstants.fieldCurrentJobStatus] = status;

    var data = match['data'];
    if (data is! Map) {
      data = <String, dynamic>{};
      match['data'] = data;
    }
    final key = data.keys.cast<String>().firstWhere(
          (k) => k.toLowerCase() == 'status',
          orElse: () => 'Status',
        );
    data[key] = status;
    notifyListeners();
  }

  static const _kCatalogPageSize = 10;

  final _products = _CatalogPage();
  final _services = _CatalogPage();
  final _providers = _CatalogPage();
  String? _catalogEmail;
  String _providersTypeName = AppConstants.jobTypeProviders;

  List<Map<String, dynamic>> get products => _products.items;
  List<Map<String, dynamic>> get services => _services.items;
  List<Map<String, dynamic>> get providers => _providers.items;

  bool get productsHasMore => _products.hasMore;
  bool get servicesHasMore => _services.hasMore;
  bool get providersHasMore => _providers.hasMore;

  bool get productsLoadingMore => _products.loadingMore;
  bool get servicesLoadingMore => _services.loadingMore;
  bool get providersLoadingMore => _providers.loadingMore;

  Future<void> loadMoreProducts() => _loadMore(_products, AppConstants.jobTypeProducts);
  Future<void> loadMoreServices() => _loadMore(_services, AppConstants.jobTypeServices);
  Future<void> loadMoreProviders() => _loadMore(_providers, _providersTypeName);

  Future<void> _loadBusinessData() async {
    _businessData = await _sessionStorage.readBusinessData();
    notifyListeners();
    await _loadBookingsAndOrders();
    await _loadCatalog();
  }

  Future<void> refresh() async {
    await _loadBookingsAndOrders();
    await _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final data = _businessData;
    final email = data == null
        ? null
        : (data[AppConstants.fieldBusinessEmail] ?? data['Work Email']) as String?;
    if (email == null || email.trim().isEmpty) return;
    _catalogEmail = email;
    _providersTypeName = _providersJobTypeName(data?['Business Category'] as String?);

    await Future.wait([
      _fetchFirstPage(_products, AppConstants.jobTypeProducts),
      _fetchFirstPage(_services, AppConstants.jobTypeServices),
      _fetchFirstPage(_providers, _providersTypeName),
    ]);
    notifyListeners();
  }

  Future<void> _fetchFirstPage(_CatalogPage page, String typeName) async {
    final result = await _fetchJobTypePage(typeName, _catalogEmail!, 1);
    page.items = result.items;
    page.pageNumber = 1;
    page.total = result.total;
  }

  Future<void> _loadMore(_CatalogPage page, String typeName) async {
    if (page.loadingMore || !page.hasMore || _catalogEmail == null) return;
    page.loadingMore = true;
    notifyListeners();
    final nextPage = page.pageNumber + 1;
    final result = await _fetchJobTypePage(typeName, _catalogEmail!, nextPage);
    page.items = [...page.items, ...result.items];
    page.pageNumber = nextPage;
    if (result.total > 0) page.total = result.total;
    page.loadingMore = false;
    notifyListeners();
  }

  String _providersJobTypeName(String? businessCategory) {
    final normalized = (businessCategory ?? '').split('(').first.trim().toLowerCase();
    switch (normalized) {
      case 'home services':
        return 'Home Services Providers';
      case 'medical aesthetics':
        return 'Physiotherapy Providers';
      case 'education':
        return 'Tutors';
      case 'insurance':
        return 'Brokers';
      default:
        return AppConstants.jobTypeProviders;
    }
  }

  Future<({List<Map<String, dynamic>> items, int total})> _fetchJobTypePage(
      String typeName, String email, int pageNumber) async {
    try {
      final result = await _apiClient.get(
        ServerUrls.jobTypeInstances(typeName),
        query: {
          'pageNumber': '$pageNumber',
          'pageSize': '$_kCatalogPageSize',
          'filters': jsonEncode([
            {'fieldName': 'parentJobInstanceId', 'condition': 'is', 'value': ''},
            {'fieldName': AppConstants.fieldBusinessEmail, 'condition': 'contains', 'value': email},
          ]),
        },
      );
      if (result is! Map<String, dynamic>) return (items: <Map<String, dynamic>>[], total: 0);
      final jobs = (result['jobs'] as List?) ?? const [];
      final items = jobs.whereType<Map>().map((j) => Map<String, dynamic>.from(j)).toList();
      final total = (result['totalNumRecords'] as num?)?.toInt() ?? items.length;
      AppLogger.i('DashboardVM', 'Loaded page $pageNumber of $typeName (${items.length}/$total)');
      return (items: items, total: total);
    } catch (e) {
      AppLogger.w('DashboardVM', 'Could not load $typeName page $pageNumber: $e');
      return (items: <Map<String, dynamic>>[], total: 0);
    }
  }

  Future<void> _loadBookingsAndOrders() async {
    final businessEmail = (_businessData?[AppConstants.fieldBusinessEmail] ?? _businessData?['Work Email']) as String?;
    final filter = await resolveBookingsOrdersFilter(_sessionStorage, businessEmail: businessEmail);
    if (filter == null) return;
    final results = await Future.wait([
      fetchJobTypeInstances(_apiClient,
          typeName: AppConstants.jobTypeBookings, filterFieldName: filter.fieldName, filterValue: filter.value),
      fetchJobTypeInstances(_apiClient,
          typeName: AppConstants.jobTypeOrders, filterFieldName: filter.fieldName, filterValue: filter.value),
    ]);
    _bookings = results[0];
    _orders = results[1];
    AppLogger.i('DashboardVM', 'Loaded ${_bookings.length} booking(s) and ${_orders.length} order(s)');
    notifyListeners();
  }

  BusinessProfile? get business => _workspace.business;
  List<DocSource> get docs => _workspace.docs;
  int get usageIn => _workspace.usageIn;
  int get usageOut => _workspace.usageOut;
  int get usageCalls => _workspace.usageCalls;
  List<int> get usageDaily => _workspace.usageDaily;
  String get currency => _workspace.currency;

  @override
  void dispose() {
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}

class _CatalogPage {
  List<Map<String, dynamic>> items = [];
  int pageNumber = 1;
  int total = 0;
  bool loadingMore = false;
  bool get hasMore => items.length < total;
}
