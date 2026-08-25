import '../constants/server_urls.dart';
import '../models/field_rule.dart';
import 'api_client.dart';

Future<FieldRule?> fetchFieldRule(ApiClient apiClient, String ruleName) async {
  final json = await apiClient.get(
    ServerUrls.jobTypeInstances('rules'),
    query: const {'pageNumber': '1', 'pageSize': '200'},
  ) as Map<String, dynamic>;
  final jobs = (json['jobs'] as List?) ?? const [];
  for (final job in jobs) {
    if (job is! Map) continue;
    final data = job['data'];
    if (data is! Map) continue;
    if (data['Name']?.toString() == ruleName) {
      return FieldRule.fromJson(Map<String, dynamic>.from(data));
    }
  }
  return null;
}
