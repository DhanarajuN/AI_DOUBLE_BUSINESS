import 'package:flutter/foundation.dart';
import '../constants/server_urls.dart';
import '../models/booking.dart';
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

  int get bookingsCount => _subJobsOfType('Bookings').length;

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

  static final List<Map<String, dynamic>> _dummyProducts = [
    {
      'id': 'dummy-product-1',
      'jobTypeName': 'Products',
      'data': {
        'Name': 'Hydrating Facial Kit',
        'Price': '₹1,299',
        'Category': 'Skincare',
        'Description': 'At-home hydrating facial kit with serum, sheet mask and moisturizer.',
      },
    },
    {
      'id': 'dummy-product-2',
      'jobTypeName': 'Products',
      'data': {
        'Name': 'Laser Hair Removal Package (5 sessions)',
        'Price': '₹14,999',
        'Category': 'Laser Treatment',
        'Description': 'Prepaid package of 5 full-body laser hair removal sessions, valid for 6 months.',
      },
    },
    {
      'id': 'dummy-product-3',
      'jobTypeName': 'Products',
      'data': {
        'Name': 'Anti-Aging Serum',
        'Price': '₹2,499',
        'Category': 'Skincare',
        'Description': 'Retinol-based serum for fine lines, sold at the front desk.',
      },
    },
    {
      'id': 'dummy-product-4',
      'jobTypeName': 'Products',
      'data': {
        'Name': 'Gift Voucher – ₹5,000',
        'Price': '₹5,000',
        'Category': 'Voucher',
        'Description': 'Redeemable against any service or product at Cynosure Beauty Care.',
      },
    },
  ];

  static final List<Map<String, dynamic>> _dummyServices = [
    {
      'id': 'dummy-service-1',
      'jobTypeName': 'Services',
      'data': {
        'Name': 'Classic Facial',
        'Duration': '60 mins',
        'Price': '₹1,499',
        'Description': 'Deep-cleansing facial with steam, extraction and a soothing mask.',
      },
    },
    {
      'id': 'dummy-service-2',
      'jobTypeName': 'Services',
      'data': {
        'Name': 'Laser Hair Removal – Full Body',
        'Duration': '90 mins',
        'Price': '₹3,999',
        'Description': 'Single-session full-body laser hair removal treatment.',
      },
    },
    {
      'id': 'dummy-service-3',
      'jobTypeName': 'Services',
      'data': {
        'Name': 'Bridal Makeup',
        'Duration': '2 hrs',
        'Price': '₹12,999',
        'Description': 'Complete bridal makeup with a trial session included.',
      },
    },
    {
      'id': 'dummy-service-4',
      'jobTypeName': 'Services',
      'data': {
        'Name': 'Hair Spa & Treatment',
        'Duration': '45 mins',
        'Price': '₹999',
        'Description': 'Nourishing hair spa with scalp massage and deep conditioning.',
      },
    },
  ];

  static final List<Map<String, dynamic>> _dummyProviders = [
    {
      'id': 'dummy-provider-1',
      'jobTypeName': 'Providers',
      'data': {
        'Name': 'Ananya Reddy',
        'Role': 'Senior Aesthetician',
        'Phone': '+91 98765 11220',
        'Availability': 'Tue–Sun, 10am–7pm',
      },
    },
    {
      'id': 'dummy-provider-2',
      'jobTypeName': 'Providers',
      'data': {
        'Name': 'Meera Kapoor',
        'Role': 'Laser Treatment Specialist',
        'Phone': '+91 98765 11221',
        'Availability': 'Mon–Sat, 11am–8pm',
      },
    },
    {
      'id': 'dummy-provider-3',
      'jobTypeName': 'Providers',
      'data': {
        'Name': 'Kavya Iyer',
        'Role': 'Bridal Makeup Artist',
        'Phone': '+91 98765 11222',
        'Availability': 'By appointment',
      },
    },
  ];

  List<Map<String, dynamic>> get products {
    final real = _subJobsOfType('Products');
    return real.isNotEmpty ? real : _dummyProducts;
  }

  List<Map<String, dynamic>> get services {
    final real = _subJobsOfType('Services');
    return real.isNotEmpty ? real : _dummyServices;
  }

  List<Map<String, dynamic>> get providers {
    final real = _subJobsOfType('Providers');
    return real.isNotEmpty ? real : _dummyProviders;
  }

  Future<void> _loadBusinessData() async {
    _businessData = await _sessionStorage.readBusinessData();
    notifyListeners();
    await _loadSubJobs();
  }

  Future<void> refresh() => _loadSubJobs();

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
  List<Booking> get bookings => _workspace.bookings;
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
