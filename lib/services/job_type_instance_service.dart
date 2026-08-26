import 'dart:convert';
import '../constants/app_constants.dart';
import '../constants/server_urls.dart';
import 'api_client.dart';
import 'app_logger.dart';
import 'session_storage.dart';

const _kFetchPageSize = 50;
const _kBrokerEmailField = 'Email Id';

Future<({String fieldName, String value})?> resolveBookingsOrdersFilter(
  SessionStorage sessionStorage, {
  required String? businessEmail,
}) async {
  final roleName = (await sessionStorage.readRoleName())?.trim().toLowerCase() ?? '';
  if (roleName.contains('broker')) {
    final email = (await sessionStorage.readSession())?.user.username;
    if (email == null || email.trim().isEmpty) return null;
    return (fieldName: _kBrokerEmailField, value: email.trim());
  }
  if (businessEmail == null || businessEmail.trim().isEmpty) return null;
  return (fieldName: AppConstants.fieldBusinessEmail, value: businessEmail.trim());
}

Future<List<Map<String, dynamic>>> fetchJobTypeInstances(
  ApiClient apiClient, {
  required String typeName,
  required String filterFieldName,
  required String filterValue,
}) async {
  final items = <Map<String, dynamic>>[];
  var pageNumber = 1;
  while (true) {
    try {
      final result = await apiClient.get(
        ServerUrls.jobTypeInstances(typeName),
        query: {
          'pageNumber': '$pageNumber',
          'pageSize': '$_kFetchPageSize',
          'filters': jsonEncode([
            {'fieldName': filterFieldName, 'condition': 'contains', 'value': filterValue},
          ]),
        },
      );
      if (result is! Map<String, dynamic>) break;
      final jobs = (result['jobs'] as List?) ?? const [];
      final pageItems = jobs.whereType<Map>().map((j) => Map<String, dynamic>.from(j)).toList();
      items.addAll(pageItems);
      final total = (result['totalNumRecords'] as num?)?.toInt() ?? items.length;
      AppLogger.i('JobTypeInstances', 'Loaded page $pageNumber of $typeName ($filterFieldName=$filterValue) (${items.length}/$total)');
      if (pageItems.isEmpty || items.length >= total) break;
      pageNumber++;
    } catch (e) {
      AppLogger.w('JobTypeInstances', 'Could not load $typeName page $pageNumber: $e');
      break;
    }
  }
  return items;
}

Future<String?> createJobTypeInstance(
  ApiClient apiClient, {
  required String jobTypeId,
  required Map<String, dynamic> data,
}) async {
  try {
    await apiClient.post(
      ServerUrls.publicInstanceCreate,
      body: {'data': data, 'jobTypeId': jobTypeId},
    );
    return null;
  } on ApiException catch (e) {
    AppLogger.w('JobTypeInstanceService', 'Could not create instance for jobTypeId $jobTypeId: ${e.message}');
    return e.message;
  } catch (e) {
    AppLogger.w('JobTypeInstanceService', 'Could not create instance for jobTypeId $jobTypeId: $e');
    return "Couldn't save your workspace. Please try again.";
  }
}
