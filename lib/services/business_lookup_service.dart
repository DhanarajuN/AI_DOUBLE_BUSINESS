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
  } catch (e) {
    AppLogger.w('BusinessLookup', 'Could not resolve businessId: $e');
  }
}
