import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';
import '../models/attachment_file.dart';
import 'api_client.dart';
import 'app_logger.dart';

Future<AttachmentFile> uploadAttachment(
  ApiClient apiClient, {
  required String fileName,
  required Uint8List bytes,
  required String parentJobTypeId,
}) async {
  final uri = Uri.parse('${apiClient.baseUrl}${ServerUrls.attachmentsOnlyUpload}');
  AppLogger.i('AttachmentUpload', 'Uploading $fileName to $uri');

  final request = http.MultipartRequest('POST', uri)
    ..fields['parentJobTypeId'] = parentJobTypeId
    ..fields['isPublicAttachment'] = 'false'
    ..files.add(http.MultipartFile.fromBytes('attachments', bytes, filename: fileName));
  request.headers['Accept'] = 'application/json';
  if (apiClient.tenant != null) request.headers['X-Tenant'] = apiClient.tenant!;
  if ((apiClient.accessToken ?? '').isNotEmpty) {
    request.headers['Authorization'] = 'Bearer ${apiClient.accessToken}';
  }

  final streamedResponse = await request.send();
  final bodyBytes = await streamedResponse.stream.toBytes();
  final responseBody = utf8.decode(bodyBytes);
  AppLogger.i('AttachmentUpload', 'Upload response for $fileName: ${streamedResponse.statusCode} '
      'contentLength=${streamedResponse.contentLength} bodyBytes=${bodyBytes.length} '
      'headers=${streamedResponse.headers} '
      'body=${responseBody.length > 500 ? '${responseBody.substring(0, 500)}...(truncated)' : responseBody}');

  if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
    throw Exception('HTTP ${streamedResponse.statusCode} uploading $fileName');
  }

  return attachmentFromUploadResponse(responseBody, fallbackName: fileName);
}

AttachmentFile attachmentFromUploadResponse(String responseBody, {required String fallbackName}) {
  if (responseBody.isEmpty) {
    throw Exception('Empty upload response for $fallbackName (connection may have been interrupted)');
  }
  final decoded = jsonDecode(responseBody);
  final root = decoded is Map ? decoded : null;
  final envelope = root?['data'] is Map ? root!['data'] as Map : root;
  final attachments = envelope?['attachments'];
  if (attachments is! List || attachments.isEmpty || attachments.first is! Map) {
    throw Exception('Unexpected upload response for $fallbackName');
  }
  final first = attachments.first as Map;

  return AttachmentFile(
    name: (first['fileName'] as String?) ?? fallbackName,
    url: (first['url'] ?? first['fileUrl']) as String?,
  );
}
