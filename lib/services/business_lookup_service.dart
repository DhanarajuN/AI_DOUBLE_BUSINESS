import 'dart:convert';
import '../constants/server_urls.dart';
import 'api_client.dart';
import 'app_logger.dart';
import 'push_notification_service.dart';
import 'session_storage.dart';

Future<void> resolveBusinessForEmail(
  SessionStorage sessionStorage,
  ApiClient apiClient,
  String? email,
) async {
  final wanted = email?.trim().toLowerCase();
  if (wanted == null || wanted.isEmpty) {
    AppLogger.w('BusinessLookup', 'No signed-in email, skipping business lookup');
    return;
  }

  final roleName = (await sessionStorage.readRoleName())?.trim().toLowerCase() ?? '';
  AppLogger.i('BusinessLookup', 'resolveBusinessForEmail called for $wanted, roleName="$roleName"');
  if (roleName.contains('broker')) {
    AppLogger.i('BusinessLookup', 'Routing to broker instances API');
    await _resolveViaBrokersApi(sessionStorage, apiClient, wanted);
  } else {
    AppLogger.i('BusinessLookup', 'Routing to business instances API');
    await _resolveViaBusinessApi(sessionStorage, apiClient, wanted);
  }
}

Future<void> _resolveViaBusinessApi(
  SessionStorage sessionStorage,
  ApiClient apiClient,
  String wanted,
) async {
  AppLogger.i('BusinessLookup', 'Looking up business for $wanted');
  try {
    final result = await apiClient.get(
      ServerUrls.businessInstances,
      query: {
        'pageNumber': '1',
        'pageSize': '10',
        'filters': jsonEncode([
          {'fieldName': 'parentJobInstanceId', 'condition': 'is', 'value': ''},
          {'fieldName': 'Work Email', 'condition': 'contains', 'value': wanted},
        ]),
      },
    );
    if (result is! Map<String, dynamic>) {
      AppLogger.w('BusinessLookup', 'Unexpected business lookup response: $result');
      return;
    }
    final jobs = result['jobs'] as List?;
    if (jobs == null || jobs.isEmpty) {
      AppLogger.w('BusinessLookup', 'No business found for $wanted');
      return;
    }
    final job = jobs.first;
    if (job is! Map<String, dynamic>) {
      AppLogger.w('BusinessLookup', 'Unexpected business record shape: $job');
      return;
    }
    await _saveResolvedBusiness(sessionStorage, job);
  } catch (e) {
    AppLogger.w('BusinessLookup', 'Could not resolve businessId: $e');
  }
}

Future<void> _resolveViaBrokersApi(
  SessionStorage sessionStorage,
  ApiClient apiClient,
  String wanted,
) async {
  AppLogger.i('BusinessLookup', 'Looking up broker record for $wanted');
  try {
    final query = {
      'pageNumber': '1',
      'pageSize': '10',
      'filters': jsonEncode([
        {'fieldName': 'Email', 'condition': 'contains', 'value': wanted},
      ]),
    };
    AppLogger.i('BusinessLookup', 'Broker lookup request: ${ServerUrls.jobTypeInstances('Broker')} query=$query');
    final result = await apiClient.get(
      ServerUrls.jobTypeInstances('Broker'),
      query: query,
    );
    AppLogger.i('BusinessLookup', 'Broker lookup raw response: ${jsonEncode(result)}');
    if (result is! Map<String, dynamic>) {
      AppLogger.w('BusinessLookup', 'Unexpected broker lookup response: $result');
      return;
    }
    final jobs = result['jobs'] as List?;
    AppLogger.i('BusinessLookup',
        'Broker lookup jobs count: ${jobs?.length ?? 'null'}, totalNumRecords: ${result['totalNumRecords']}');
    if (jobs == null || jobs.isEmpty) {
      AppLogger.w('BusinessLookup', 'No broker record found for $wanted');
      return;
    }
    final broker = jobs.first;
    if (broker is! Map<String, dynamic>) {
      AppLogger.w('BusinessLookup', 'Unexpected broker record shape: $broker');
      return;
    }
    AppLogger.i('BusinessLookup', 'Broker record top-level keys: ${broker.keys.toList()}');
    final brokerData = broker['data'];
    if (brokerData is Map) {
      AppLogger.i('BusinessLookup', 'Broker record data keys: ${brokerData.keys.toList()}');
    }
    await _saveResolvedBusiness(sessionStorage, broker);
  } catch (e, st) {
    AppLogger.e('BusinessLookup', 'Could not resolve business for broker $wanted', e, st);
  }
}

Future<void> _saveResolvedBusiness(SessionStorage sessionStorage, Map<String, dynamic> job) async {
  final id = job['id'] as String?;
  if (id != null && id.isNotEmpty) {
    await sessionStorage.saveBusinessId(id);
    AppLogger.i('BusinessLookup', 'Resolved businessId: $id');
    // Re-registers the FCM token now carrying businessId — the earlier
    // registration right after login (auth_repository.dart) ran before
    // this resolved, so it went up without one. Same token, upsert by
    // token server-side, so this just fills in what was missing.
    await PushNotificationService().registerForCurrentUser();
  } else {
    AppLogger.w('BusinessLookup', 'Business record had no id: $job');
  }
  final data = job['data'];
  if (data is Map<String, dynamic> && data.isNotEmpty) {
    await sessionStorage.saveBusinessData(data);
    AppLogger.i('BusinessLookup', 'Captured business data fields: ${data.keys.toList()}');
  } else {
    AppLogger.w('BusinessLookup', 'Business record had no data captured');
  }
}
