import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/openai_service.dart';
import '../../../core/services/audio_service.dart';
import '../../settings/data/settings_provider.dart';
import '../../lead_profiles/domain/entities/lead_profile.dart';
import '../domain/prompt_manager.dart';

import 'package:uuid/uuid.dart';
import '../domain/entities/simulation_result.dart';
import '../domain/repositories/simulation_repository.dart';
import 'simulation_repository_provider.dart';

final voiceProvider =
    StateNotifierProvider.autoDispose<VoiceNotifier, VoiceState>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey == null) {
    log('VoiceProvider: API Key not found', name: '###');
    throw Exception('API Key not found');
  }
  final simulationRepository = ref.watch(simulationRepositoryProvider);
  return VoiceNotifier(
      OpenAIService(apiKey), AudioService(), simulationRepository);
});

enum VoiceStatus {
  disconnected,
  connecting,
  connected,
  listening,
  speaking,
  reconnecting,
  error
}

class VoiceState {
  final VoiceStatus status;
  final String lastTranscript;
  final bool isMicEnabled;
  final List<Map<String, String>> history;
  final String? errorMessage;
  final int inputTokens;
  final int outputTokens;
  final double totalCost;
  final DateTime? startTime;
  final String? systemPrompt;

  VoiceState({
    this.status = VoiceStatus.disconnected,
    this.lastTranscript = '',
    this.isMicEnabled = false,
    this.history = const [],
    this.errorMessage,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalCost = 0.0,
    this.startTime,
    this.systemPrompt,
  });

  VoiceState copyWith({
    VoiceStatus? status,
    String? lastTranscript,
    bool? isMicEnabled,
    List<Map<String, String>>? history,
    String? errorMessage,
    int? inputTokens,
    int? outputTokens,
    double? totalCost,
    DateTime? startTime,
    String? systemPrompt,
  }) {
    return VoiceState(
      status: status ?? this.status,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      isMicEnabled: isMicEnabled ?? this.isMicEnabled,
      history: history ?? this.history,
      errorMessage: errorMessage,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      totalCost: totalCost ?? this.totalCost,
      startTime: startTime ?? this.startTime,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}

class VoiceNotifier extends StateNotifier<VoiceState> {
  final OpenAIService _openAIService;
  final AudioService _audioService;
  final ISimulationRepository _simulationRepository;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _eventSubscription;

  VoiceNotifier(
      this._openAIService, this._audioService, this._simulationRepository)
      : super(VoiceState());

  Future<void> startSession(
      ScenarioType scenarioType, LeadProfile leadProfile) async {
    try {
      log('VoiceNotifier: Starting session...', name: '###');
      state = state.copyWith(status: VoiceStatus.connecting);

      final systemPrompt =
          PromptManager.getSystemPrompt(scenarioType, leadProfile);

      state = state.copyWith(
        startTime: DateTime.now(),
        systemPrompt: systemPrompt,
      );

      // Connect to OpenAI
      await _openAIService.connectRealtime(systemPrompt);
      if (!mounted) return;

      // Listen to events
      _eventSubscription?.cancel();
      _eventSubscription = _openAIService.events.listen(
        (event) {
          if (!mounted) return;
          _handleEvent(event);
        },
        onError: (error) {
          log('VoiceNotifier: Stream error: $error', name: '###', error: error);
          if (mounted) {
            state = state.copyWith(
              status: VoiceStatus.error,
              errorMessage: 'Erro de conexão: $error',
            );
          }
        },
      );

      // Start Recording
      final stream = await _audioService.startRecordingStream();
      if (!mounted) return;

      _audioSubscription = stream.listen(
        (bytes) {
          if (!mounted) return;

          if (state.isMicEnabled) {
            // Half-Duplex Mode:
            // If AI is speaking, we effectively "mute" the mic by ignoring input.
            // The user must press the "Interrupt" button to stop the AI.
            if (state.status == VoiceStatus.speaking) {
              return;
            }

            // No local VAD check. Just stream to server.
            _openAIService.sendAudioChunk(bytes);
          }
        },
        onDone: () {
          log('VoiceNotifier: Audio stream closed (Done)', name: '###');
        },
        onError: (e) {
          log('VoiceNotifier: Audio stream error: $e', name: '###', error: e);
        },
        cancelOnError: false,
      );

      state = state.copyWith(status: VoiceStatus.connected, isMicEnabled: true);
      log('VoiceNotifier: Session started and connected. Mic enabled.',
          name: '###');
    } catch (e) {
      log('VoiceNotifier: Error starting session: $e', name: '###', error: e);
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Falha ao iniciar: $e',
      );
    }
  }

  bool _ignoreAudio = false;

  void interruptAI() {
    log('VoiceNotifier: Manually interrupting AI.', name: '###');
    _ignoreAudio = true;
    _openAIService.sendEvent({'type': 'response.cancel'});
    _audioService.clearQueue();
    // Reset status to connected/listening so mic opens again
    state = state.copyWith(status: VoiceStatus.connected);
  }

  void _handleEvent(dynamic event) {
    final type = event['type'];
    log('VoiceNotifier: Received event type: $type', name: '###');

    if (type == 'response.created') {
      _ignoreAudio = false;
      log('VoiceNotifier: New response created: $event', name: '###');
    } else if (type == 'response.audio.delta') {
      if (_ignoreAudio) return;
      final base64Audio = event['delta'];
      final bytes = base64Decode(base64Audio);
      _audioService.playAudioChunk(bytes);
      // Don't log every chunk play to avoid spam, but logging start is good
      if (state.status != VoiceStatus.speaking) {
        log('VoiceNotifier: Playing audio response...', name: '###');
      }
      state = state.copyWith(status: VoiceStatus.speaking);
    } else if (type == 'response.audio_transcript.done') {
      final transcript = event['transcript'];
      log('VoiceNotifier: Transcript done: $transcript', name: '###');
      state = state.copyWith(
        lastTranscript: transcript,
        history: [
          ...state.history,
          {'role': 'assistant', 'content': transcript}
        ],
      );
    } else if (type == 'input_audio_buffer.speech_started') {
      log('VoiceNotifier: User started speaking. Interrupting AI.',
          name: '###');
      _ignoreAudio = true;
      _openAIService.sendEvent({'type': 'response.cancel'});
      _audioService.clearQueue();
      state = state.copyWith(status: VoiceStatus.listening);
    } else if (type == 'input_audio_buffer.speech_stopped') {
      log('VoiceNotifier: Speech stopped (VAD detected silence).', name: '###');
    } else if (type == 'input_audio_buffer.committed') {
      log('VoiceNotifier: Audio committed to context.', name: '###');
    } else if (type == 'response.done') {
      log('VoiceNotifier: Response generation done: $event', name: '###');

      // Calculate Usage & Cost
      if (event.containsKey('response') &&
          event['response'].containsKey('usage')) {
        final usage = event['response']['usage'];
        final int input = usage['input_token_details']?['audio_tokens'] ?? 0;
        final int output = usage['output_token_details']?['audio_tokens'] ?? 0;

        // Pricing (USD per 1M tokens)
        const double priceInput = 32.0;
        const double priceOutput = 64.0;
        const double exchangeRate = 5.54; // USD to BRL

        final double costUSD =
            (input * priceInput / 1000000) + (output * priceOutput / 1000000);
        final double costBRL = costUSD * exchangeRate;

        state = state.copyWith(
          status: VoiceStatus.connected,
          inputTokens: state.inputTokens + input,
          outputTokens: state.outputTokens + output,
          totalCost: state.totalCost + costBRL,
        );
        log('VoiceNotifier: Cost Updated. +${input}in/${output}out. Total: R\$ ${state.totalCost.toStringAsFixed(4)}',
            name: '###');
      } else {
        state = state.copyWith(status: VoiceStatus.connected);
      }
    } else if (type ==
        'conversation.item.input_audio_transcription.completed') {
      final transcript = event['transcript'];
      log('VoiceNotifier: User transcript: $transcript', name: '###');
      state = state.copyWith(
        history: [
          ...state.history,
          {'role': 'user', 'content': transcript}
        ],
      );
    } else if (type == 'error') {
      final error = event['error'];
      log('VoiceNotifier: OpenAI Error: ${error['message']}',
          name: '###', error: error);
      // Don't necessarily stop session, just log or show toast
    }
  }

  Future<ChatResponse> generateFeedback() async {
    log('VoiceNotifier: Generating feedback...', name: '###');
    final response = await _openAIService.generateFeedback(state.history);

    // Calculate report cost
    const double priceInput = 2.50; // gpt-4o input cost/1M
    const double priceOutput = 10.00; // gpt-4o output cost/1M
    const double exchangeRate = 5.54;

    final double reportCostUSD = (response.inputTokens * priceInput / 1000000) +
        (response.outputTokens * priceOutput / 1000000);
    final double reportCostBRL = reportCostUSD * exchangeRate;

    // Save simulation result
    if (state.startTime != null) {
      final duration = DateTime.now().difference(state.startTime!).inSeconds;
      final result = SimulationResult(
        id: const Uuid().v4(),
        timestamp: state.startTime!,
        durationSeconds: duration,
        inputTokens: state.inputTokens,
        outputTokens: state.outputTokens,
        totalCost: state.totalCost,
        systemPrompt: state.systemPrompt ?? '',
        feedbackReport: response.content,
        reportInputTokens: response.inputTokens,
        reportOutputTokens: response.outputTokens,
        reportTotalCost: reportCostBRL,
      );

      try {
        await _simulationRepository.saveSimulation(result);
        log('VoiceNotifier: Simulation saved successfully', name: '###');
      } catch (e) {
        log('VoiceNotifier: Error saving simulation: $e', name: '###');
      }
    }

    return response;
  }

  void toggleMic() {
    final newStatus = !state.isMicEnabled;
    log('VoiceNotifier: Toggling mic to $newStatus', name: '###');
    state = state.copyWith(isMicEnabled: newStatus);
  }

  void endSession() {
    if (state.status == VoiceStatus.disconnected) {
      log('VoiceNotifier: Already disconnected, skipping endSession',
          name: '###');
      return;
    }
    log('VoiceNotifier: Ending session', name: '###');
    state = state.copyWith(status: VoiceStatus.disconnected);

    try {
      _openAIService.disconnect();
    } catch (e) {
      log('VoiceNotifier: Error disconnecting OpenAI: $e', name: '###');
    }

    try {
      _audioService.stopRecording();
      _audioService.clearQueue();
    } catch (e) {
      log('VoiceNotifier: Error stopping audio: $e', name: '###');
    }

    _audioSubscription?.cancel();
    _eventSubscription?.cancel();
    _audioSubscription = null;
    _eventSubscription = null;
  }

  @override
  void dispose() {
    log('VoiceNotifier: Disposing', name: '###');
    endSession(); // Now safe to call because of the check
    _audioService.dispose();
    super.dispose();
  }
}
