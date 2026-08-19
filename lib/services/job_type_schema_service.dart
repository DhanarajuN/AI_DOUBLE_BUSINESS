import '../constants/server_urls.dart';
import '../models/job_type_schema.dart';
import 'api_client.dart';
import 'app_logger.dart';

Future<JobTypeSchema?> fetchJobTypeSchema(ApiClient apiClient, String jobTypeName, {String? bearerTokenOverride}) async {
  try {
    final result = await apiClient.get(
      ServerUrls.jobTypeCreateInstance(jobTypeName),
      headerOverrides: bearerTokenOverride == null ? null : {'Authorization': 'Bearer $bearerTokenOverride'},
    );
    if (result is! Map<String, dynamic>) return null;
    return JobTypeSchema.fromJson(result);
  } catch (e) {
    AppLogger.w('JobTypeSchemaService', 'Could not load schema for $jobTypeName: $e');
    return null;
  }
}
