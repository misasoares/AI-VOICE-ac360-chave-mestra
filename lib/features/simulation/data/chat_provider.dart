import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/openai_service.dart';
import '../../settings/data/settings_provider.dart';
import '../domain/prompt_manager.dart';

final chatProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, List<Map<String, String>>>(
        (ref) {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey == null) throw Exception('API Key not found');
  return ChatNotifier(OpenAIService(apiKey));
});

class ChatNotifier extends StateNotifier<List<Map<String, String>>> {
  final OpenAIService _openAIService;

  ChatNotifier(this._openAIService) : super([]);

  void initialize(ScenarioType type) {
    state = [
      {'role': 'system', 'content': PromptManager.getSystemPrompt(type)},
    ];
  }

  Future<void> sendMessage(String content) async {
    // Add user message
    state = [
      ...state,
      {'role': 'user', 'content': content}
    ];

    try {
      print('ChatProvider: Sending message: $content');
      final response = await _openAIService.sendMessage(state);
      print('ChatProvider: Received response: $response');
      // Add assistant response
      state = [
        ...state,
        {'role': 'assistant', 'content': response}
      ];
    } catch (e) {
      // Handle error (maybe add an error message to state)
      state = [
        ...state,
        {'role': 'system', 'content': 'Erro: $e'}
      ];
    }
  }

  Future<String> generateFeedback() async {
    return await _openAIService.generateFeedback(state);
  }
}
