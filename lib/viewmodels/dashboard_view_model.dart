import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants/server_urls.dart';
import '../models/business_profile.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
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

  List<dynamic> _subJobs = [];
  List<dynamic> get subJobs => _subJobs;

  List<Map<String, dynamic>> _subJobsOfType(String jobTypeName) => _subJobs
      .whereType<Map>()
      .where((j) {
        final type = j['jobTypeName'];
        return type is String && type.toLowerCase() == jobTypeName.toLowerCase();
      })
      .map((j) => Map<String, dynamic>.from(j))
      .toList();

  List<Map<String, dynamic>> get bookings => _subJobsOfType('Bookings');
  int get bookingsCount => bookings.length;

  static final List<Map<String, dynamic>> _dummyOrders = [
    {
      'id': 'dummy-order-1',
      'jobTypeName': 'Orders',
      'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'data': {'Customer Name': 'Aarav Sharma', 'Product Name': 'Premium Plan Setup', 'Amount': '₹4,999', 'Status': 'Accepted'},
    },
    {
      'id': 'dummy-order-2',
      'jobTypeName': 'Orders',
      'createdAt': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toIso8601String(),
      'data': {'Customer Name': 'Priya Nair', 'Product Name': 'Website Chat Widget', 'Amount': '₹1,499', 'Status': 'Delivered'},
    },
    {
      'id': 'dummy-order-3',
      'jobTypeName': 'Orders',
      'createdAt': DateTime.now().subtract(const Duration(days: 2, hours: 5)).toIso8601String(),
      'data': {'Customer Name': 'Rohan Gupta', 'Product Name': 'WhatsApp Integration', 'Amount': '₹2,999', 'Status': 'In Transit'},
    },
    {
      'id': 'dummy-order-4',
      'jobTypeName': 'Orders',
      'createdAt': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(),
      'data': {'Customer Name': 'Neha Iyer', 'Product Name': 'Calendar Booking Setup', 'Amount': '₹1,999', 'Status': 'Placed'},
    },
    {
      'id': 'dummy-order-5',
      'jobTypeName': 'Orders',
      'createdAt': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      'data': {'Customer Name': 'Karthik Rao', 'Product Name': 'Knowledge Base Import', 'Amount': '₹3,499', 'Status': 'Delivered'},
    },
    {
      'id': 'dummy-order-6',
      'jobTypeName': 'Orders',
      'createdAt': DateTime.now().subtract(const Duration(days: 40)).toIso8601String(),
      'data': {'Customer Name': 'Divya Menon', 'Product Name': 'Premium Plan Setup', 'Amount': '₹4,999', 'Status': 'Cancelled'},
    },
  ];

  List<Map<String, dynamic>> get orders {
    final real = _subJobsOfType('Orders');
    return real.isNotEmpty ? real : _dummyOrders;
  }

  int get ordersCount => orders.length;

  void updateOrderStatus(Map<String, dynamic> order, String status) {
    order['Current_Job_Status'] = status;

    var data = order['data'];
    if (data is! Map) {
      data = <String, dynamic>{};
      order['data'] = data;
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
  String _providersTypeName = 'Providers';

  List<Map<String, dynamic>> get products => _products.items;
  List<Map<String, dynamic>> get services => _services.items;
  List<Map<String, dynamic>> get providers => _providers.items;

  bool get productsHasMore => _products.hasMore;
  bool get servicesHasMore => _services.hasMore;
  bool get providersHasMore => _providers.hasMore;

  bool get productsLoadingMore => _products.loadingMore;
  bool get servicesLoadingMore => _services.loadingMore;
  bool get providersLoadingMore => _providers.loadingMore;

  Future<void> loadMoreProducts() => _loadMore(_products, 'Products');
  Future<void> loadMoreServices() => _loadMore(_services, 'Services');
  Future<void> loadMoreProviders() => _loadMore(_providers, _providersTypeName);

  Future<void> _loadBusinessData() async {
    _businessData = await _sessionStorage.readBusinessData();
    notifyListeners();
    await _loadSubJobs();
    await _loadCatalog();
  }

  Future<void> refresh() async {
    await _loadSubJobs();
    await _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final data = _businessData;
    final email = data == null
        ? null
        : (data['Business Email'] ?? data['Work Email']) as String?;
    if (email == null || email.trim().isEmpty) return;
    _catalogEmail = email;
    _providersTypeName = _providersJobTypeName(data?['Business Category'] as String?);

    await Future.wait([
      _fetchFirstPage(_products, 'Products'),
      _fetchFirstPage(_services, 'Services'),
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
        return 'Providers';
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
            {'fieldName': 'Business Email', 'condition': 'contains', 'value': email},
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

  // Sub jobs of the resolved Business record — GET /api/v1/job-instances/:businessId
  // returns {jobs: [{...business fields..., CreatedSubJobs: [{jobTypeName, data, ...}]}]}.
  Future<void> _loadSubJobs() async {
    final businessId = await _sessionStorage.readBusinessId();
    if (businessId == null || businessId.isEmpty) return;
    try {
      final result =
          await _apiClient.get('${ServerUrls.jobInstances}/$businessId');
      if (result is! Map<String, dynamic>) return;
      final jobs = result['jobs'] as List?;
      if (jobs == null || jobs.isEmpty) return;
      final job = jobs.first;
      if (job is! Map<String, dynamic>) return;
      final subJobs = job['CreatedSubJobs'];
      if (subJobs is List) {
        _subJobs = subJobs;
        AppLogger.i('DashboardVM', 'Loaded ${subJobs.length} sub jobs');
        notifyListeners();
      }
    } catch (e) {
      AppLogger.w('DashboardVM', 'Could not load sub jobs: $e');
    }
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
