import '../constants/app_constants.dart';
import '../constants/server_urls.dart';
import '../models/job_status_option.dart';
import 'api_client.dart';
import 'app_logger.dart';

Future<List<JobStatusOption>> fetchNextJobStatuses(
  ApiClient apiClient,
  String instanceId,
) async {
  if (instanceId.isEmpty) {
    AppLogger.w('JobStatusService', 'fetchNextJobStatuses called with an empty instanceId');
    return const [];
  }
  final json = await apiClient.get(
    '${ServerUrls.jobInstances}/$instanceId',
    query: const {'limitSubJobs': 'true', 'includeJobWorkflowType': 'true'},
  ) as Map<String, dynamic>;
  final jobs = json['jobs'] as List?;
  final raw = (jobs != null && jobs.isNotEmpty)
      ? (jobs[0] as Map<String, dynamic>)[AppConstants.fieldNextJobStatuses] as List?
      : null;
  if (raw == null) {
    AppLogger.i('JobStatusService', 'No next statuses available for $instanceId');
    return const [];
  }
  final options = raw
      .whereType<Map>()
      .map((e) => JobStatusOption.fromJson(Map<String, dynamic>.from(e)))
      .where((o) => o.secondaryStatus.isNotEmpty)
      .toList();
  AppLogger.i('JobStatusService', 'Loaded ${options.length} next status option(s) for $instanceId');
  return options;
}

Future<void> updateJobStatus(
  ApiClient apiClient, {
  required String instanceId,
  required String status,
}) async {
  await apiClient.post(
    ServerUrls.updateWorkflowStatus,
    body: {'jobInstanceId': instanceId, 'secondaryStatus': status},
  );
  AppLogger.i('JobStatusService', 'Updated $instanceId to status "$status"');
}
