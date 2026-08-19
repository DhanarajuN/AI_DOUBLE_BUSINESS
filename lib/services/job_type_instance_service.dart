import '../constants/server_urls.dart';
import 'api_client.dart';
import 'app_logger.dart';

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
