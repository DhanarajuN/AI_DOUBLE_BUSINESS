import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';

class LlmException implements Exception {
  final String message;
  final int? statusCode;
  const LlmException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class LlmResult {
  final String text;
  final int inputTokens;
  final int outputTokens;
  const LlmResult({required this.text, required this.inputTokens, required this.outputTokens});
}

const kProviders = {
  'openai': (name: 'OpenAI', model: 'gpt-4o-mini', keyHint: 'sk-…'),
  'anthropic': (name: 'Anthropic', model: 'claude-3-5-haiku-latest', keyHint: 'sk-ant-…'),
  'gemini': (name: 'Google Gemini', model: 'gemini-1.5-flash', keyHint: 'AIza…'),
};

class LlmService {
  static Future<LlmResult> call({
    required String provider,
    required String apiKey,
    required String model,
    required String system,
    required List<Map<String, String>> messages,
  }) async {
    switch (provider) {
      case 'anthropic':
        return _callAnthropic(apiKey, model, system, messages);
      case 'gemini':
        return _callGemini(apiKey, model, system, messages);
      case 'openai':
      default:
        return _callOpenAI(apiKey, model, system, messages);
    }
  }

  static Future<LlmException> _err(http.Response res) async {
    String detail = '';
    try {
      final j = jsonDecode(res.body);
      detail = (j is Map ? (j['error']?['message'] ?? j['message']) : null)?.toString() ?? res.body;
    } catch (_) {
      detail = res.body;
    }
    return LlmException(detail.isEmpty ? 'HTTP ${res.statusCode}' : detail, res.statusCode);
  }

  static Future<LlmResult> _callOpenAI(String key, String model, String system, List<Map<String, String>> messages) async {
    final res = await http.post(
      Uri.parse(ServerUrls.openAiChatCompletions),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${key.trim()}'},
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          ...messages,
        ],
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final text = j['choices']?[0]?['message']?['content'] as String? ?? '';
    final usage = j['usage'] as Map<String, dynamic>?;
    return LlmResult(text: text, inputTokens: usage?['prompt_tokens'] ?? 0, outputTokens: usage?['completion_tokens'] ?? 0);
  }

  static Future<LlmResult> _callAnthropic(String key, String model, String system, List<Map<String, String>> messages) async {
    final res = await http.post(
      Uri.parse(ServerUrls.anthropicMessages),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': key.trim(),
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 1024,
        'system': system,
        'messages': messages,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final content = j['content'] as List?;
    final text = (content ?? const []).map((c) => c['text'] ?? '').join();
    final usage = j['usage'] as Map<String, dynamic>?;
    return LlmResult(text: text, inputTokens: usage?['input_tokens'] ?? 0, outputTokens: usage?['output_tokens'] ?? 0);
  }

  static Future<LlmResult> _callGemini(String key, String model, String system, List<Map<String, String>> messages) async {
    final url = Uri.parse(
        '${ServerUrls.geminiModels}/$model:generateContent?key=${key.trim()}');
    final contents = messages.map((m) => {'role': m['role'] == 'assistant' ? 'model' : 'user', 'parts': [{'text': m['content']}]}).toList();
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {'parts': [{'text': system}]},
        'contents': contents,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) throw await _err(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final parts = j['candidates']?[0]?['content']?['parts'] as List?;
    final text = (parts ?? const []).map((p) => p['text'] ?? '').join();
    final usage = j['usageMetadata'] as Map<String, dynamic>?;
    return LlmResult(text: text, inputTokens: usage?['promptTokenCount'] ?? 0, outputTokens: usage?['candidatesTokenCount'] ?? 0);
  }

  static String friendlyError(Object err) {
    if (err is LlmException) {
      if (err.statusCode == 401) return 'The key was rejected (401). Check it under Account.';
      if (err.statusCode == 429) return 'Rate limit or quota reached (429). Try again shortly.';
      if (err.statusCode == 404) return 'Model not found (404). Check the model name under Account.';
      return err.message;
    }
    return err.toString();
  }
}
