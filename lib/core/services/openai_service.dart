import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class OpenAIService {
  final String apiKey;

  OpenAIService(this.apiKey);

  // --- Text Chat (Chat Completions) ---
  Future<ChatResponse> sendMessage(List<Map<String, String>> messages,
      {String model = 'gpt-4o'}) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'];
      final usage = data['usage'];
      return ChatResponse(
        content: content,
        inputTokens: usage['prompt_tokens'],
        outputTokens: usage['completion_tokens'],
      );
    } else {
      throw Exception('Failed to load response: ${response.body}');
    }
  }

  Future<ChatResponse> generateFeedback(
      List<Map<String, String>> history) async {
    final feedbackPrompt = [
      {
        'role': 'system',
        'content': '''
Você é um treinador de vendas especialista no método "Chave Mestra".
Analise a transcrição da conversa abaixo e forneça um feedback detalhado para o vendedor.
Avalie:
1. Abordagem e Quebra de Padrão.
2. Levantamento de Necessidades.
3. Contorno de Objeções.
4. Fechamento.

Dê uma nota de 0 a 10.
Use formatação Markdown.
'''
      },
      ...history,
    ];

    return await sendMessage(feedbackPrompt);
  }

  // --- Voice Chat (Realtime API) ---
  WebSocketChannel? _channel;
  final StreamController<dynamic> _eventController =
      StreamController.broadcast();
  Timer? _reconnectTimer;
  bool _isExpectedDisconnect = false;
  String? _lastSystemPrompt;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  Stream<dynamic> get events => _eventController.stream;

  Future<void> connectRealtime(String systemPrompt) async {
    _lastSystemPrompt = systemPrompt;
    _isExpectedDisconnect = false;
    _reconnectAttempts = 0;
    log('OpenAIService: Connecting to Realtime API...', name: '###');
    await _connect();
  }

  Future<void> _connect() async {
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
    }

    final url = Uri.parse(
        'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview');

    try {
      _channel = WebSocketChannel.connect(
        url,
        protocols: [
          'realtime',
          'openai-insecure-api-key.$apiKey',
          'openai-beta.realtime-v1',
        ],
      );

      // Listen to incoming messages
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          // log('OpenAIService: Received event ${data['type']}', name: '###'); // Verbose, maybe selectively log in VoiceProvider
          _eventController.add(data);
          // Reset reconnect attempts on successful message
          _reconnectAttempts = 0;
        },
        onError: (error) {
          log('OpenAIService: WebSocket Error: $error',
              name: '###', error: error);
          _eventController.addError(error);
          _handleDisconnect();
        },
        onDone: () {
          log('OpenAIService: WebSocket Closed', name: '###');
          _handleDisconnect();
        },
      );

      // Initialize Session
      if (_lastSystemPrompt != null) {
        log('OpenAIService: Sending session.update', name: '###');
        sendEvent({
          'type': 'session.update',
          'session': {
            'modalities': ['text', 'audio'],
            'instructions': _lastSystemPrompt,
            'voice': 'alloy',
            'input_audio_format': 'pcm16',
            'output_audio_format': 'pcm16',
            'turn_detection': {
              'type': 'server_vad',
              'threshold': 0.5,
              'prefix_padding_ms': 300,
              'silence_duration_ms': 1000,
            }
          }
        });
      }
    } catch (e) {
      log('OpenAIService: Connection failed: $e', name: '###', error: e);
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (_isExpectedDisconnect) return;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: 2 * _reconnectAttempts);
      log('OpenAIService: Reconnecting in ${delay.inSeconds}s (Attempt $_reconnectAttempts)',
          name: '###');
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, _connect);
    } else {
      log('OpenAIService: Max reconnect attempts reached', name: '###');
      _eventController.addError(Exception('Connection lost permanently'));
    }
  }

  void sendEvent(Map<String, dynamic> event) {
    if (_channel != null) {
      try {
        final jsonEvent = jsonEncode(event);
        // log('OpenAIService: Sending event: ${event['type']}', name: '###'); // Verbose
        _channel!.sink.add(jsonEvent);
      } catch (e) {
        log('OpenAIService: Failed to send event: $e', name: '###', error: e);
      }
    } else {
      log('OpenAIService: Channel is null, cannot send event ${event['type']}',
          name: '###');
    }
  }

  void sendAudioChunk(Uint8List bytes) {
    // Convert bytes to base64
    final base64Audio = base64Encode(bytes);
    sendEvent({
      'type': 'input_audio_buffer.append',
      'audio': base64Audio,
    });
  }

  void commitAudio() {
    log('OpenAIService: Committing audio buffer', name: '###');
    sendEvent({'type': 'input_audio_buffer.commit'});
    sendEvent({'type': 'response.create'});
  }

  void disconnect() {
    log('OpenAIService: Disconnecting...', name: '###');
    _isExpectedDisconnect = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    // Do not close _eventController here as it might be reused or listened to
    // But usually we want to reset it for a fresh start if the user leaves the screen
    // For now, we keep it open but maybe we should close it if the screen is disposed
  }
}

class ChatResponse {
  final String content;
  final int inputTokens;
  final int outputTokens;

  ChatResponse({
    required this.content,
    required this.inputTokens,
    required this.outputTokens,
  });
}
