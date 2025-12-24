import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/lead_profile.dart';
import 'lead_profile_repository_provider.dart';

enum MessageSender { system, user }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;
  final int currentStep;
  final Map<String, String> answers;
  final bool isCompleted;

  ChatState({
    required this.messages,
    required this.isTyping,
    required this.currentStep,
    required this.answers,
    this.isCompleted = false,
  });

  factory ChatState.initial() {
    return ChatState(
      messages: [],
      isTyping: false,
      currentStep: 0,
      answers: {},
    );
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    int? currentStep,
    Map<String, String>? answers,
    bool? isCompleted,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      currentStep: currentStep ?? this.currentStep,
      answers: answers ?? this.answers,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class CreateProfileNotifier extends StateNotifier<ChatState> {
  final Ref ref;
  final String userName;

  CreateProfileNotifier(this.ref, {required this.userName})
      : super(ChatState.initial()) {
    _initChat();
  }

  final List<String> _questions = [
    "Qual o nome do lead?",
    "Qual o cargo ocupa?",
    "Qual o setor da empresa?",
    "Quais são as principais dores ou problemas que ele enfrenta?",
  ];

  final List<String> _keys = [
    "name",
    "role",
    "sector",
    "pain_points",
  ];

  Future<void> _initChat() async {
    _addSystemMessage(
        "Olá $userName, vamos criar um novo perfil de Lead para você treinar. Responda as perguntas listadas abaixo para criarmos um perfil de lead.");
    await Future.delayed(const Duration(seconds: 1));
    _askNextQuestion();
  }

  Future<void> _askNextQuestion() async {
    if (state.currentStep < _questions.length) {
      state = state.copyWith(isTyping: true);
      await Future.delayed(const Duration(seconds: 1)); // Simulate typing
      _addSystemMessage(_questions[state.currentStep]);
      state = state.copyWith(isTyping: false);
    } else {
      _finishCreation();
    }
  }

  void addUserMessage(String text) {
    if (state.isTyping || state.isCompleted) return;

    final message = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final currentKey = _keys[state.currentStep];
    final newAnswers = Map<String, String>.from(state.answers);
    newAnswers[currentKey] = text;

    state = state.copyWith(
      messages: [...state.messages, message],
      answers: newAnswers,
      currentStep: state.currentStep + 1,
    );

    _askNextQuestion();
  }

  void _addSystemMessage(String text) {
    final message = ChatMessage(
      id: const Uuid().v4(),
      text: text,
      sender: MessageSender.system,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, message],
    );
  }

  Future<void> _finishCreation() async {
    state = state.copyWith(isTyping: true);
    await Future.delayed(const Duration(seconds: 1));
    _addSystemMessage("Perfeito! Perfil de lead criado com sucesso.");

    final profile = LeadProfile(
      id: const Uuid().v4(),
      name: state.answers['name'] ?? 'Sem Nome',
      answers: state.answers,
      createdAt: DateTime.now(),
    );

    await ref.read(leadProfileRepositoryProvider).saveProfile(profile);
    state = state.copyWith(isTyping: false, isCompleted: true);
  }
}

final createProfileProvider = StateNotifierProvider.autoDispose
    .family<CreateProfileNotifier, ChatState, String>((ref, userName) {
  return CreateProfileNotifier(ref, userName: userName);
});
