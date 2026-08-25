import '../constants/server_urls.dart';
import 'api_client.dart';
import 'app_logger.dart';

Future<void> saveJobInstance(
  ApiClient apiClient, {
  required String instanceId,
  required String jobTypeId,
  required Map<String, dynamic> data,
}) async {
  if (instanceId.isEmpty) {
    AppLogger.i('JobInstanceUpdate', 'Creating instance for jobTypeId $jobTypeId');
    await apiClient.post(ServerUrls.jobInstances, body: {'data': data, 'jobTypeId': jobTypeId});
    return;
  }
  AppLogger.i('JobInstanceUpdate', 'Updating instance $instanceId');
  await apiClient.put('${ServerUrls.jobInstances}/$instanceId', body: {'data': data});
}
