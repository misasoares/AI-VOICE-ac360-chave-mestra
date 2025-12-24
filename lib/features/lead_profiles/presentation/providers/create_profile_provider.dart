import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/lead_profile.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/services/openai_service.dart';
import '../../../settings/data/settings_provider.dart';
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
    "Para começar: O que você vende? (Produto e Ticket médio)",
    "Qual é a principal transformação ou promessa do seu produto?",
    "Quem é o seu cliente ideal? (Profissão, Idade aproximada, Gênero)",
    "Qual é o nível de consciência desse lead? (Totalmente perdido / Sabe que tem problema / Já está comparando soluções)",
    "Qual é a principal Dor/Problema que tira o sono dele?",
    "Qual é o principal Desejo dele? Onde ele quer chegar?",
    "Liste as TOP 3 Objeções Reais que você ouve. (Ex: 'Tá caro', 'Vou ver com meu sócio').",
    "Qual o estilo de personalidade mais comum? (Ex: Apressado, Desconfiado, Amigável, Tímido)",
    "Qual o contexto dessa chamada? (Cold call, Lead de Inbound, Pós-evento, Indicação?)",
    "O que ele valoriza mais na decisão? (Preço, Rapidez, Confiança, Garantia?)",
    "O que irrita esse lead ou faz ele perder o interesse?",
    "Para a IA calibrar o tom: Escreva 2 frases curtas que esse lead costuma dizer (use gírias ou o jeito dele falar)."
  ];

  final List<String> _keys = [
    "product",
    "transformation",
    "ideal_customer",
    "awareness_level",
    "pain_point",
    "desire",
    "objections",
    "personality_style",
    "call_context",
    "decision_criteria",
    "irritations",
    "speaking_style"
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

    _addSystemMessage(
        "Recebi suas respostas. Aguarde enquanto gero a persona do lead usando Inteligência Artificial...");

    final systemPrompt = await _generatePersona();

    if (systemPrompt == null) {
      _addSystemMessage(
          "Houve um erro ao gerar a persona. Tente novamente mais tarde ou verifique sua chave de API.");
      state = state.copyWith(isTyping: false);
      return;
    }

    _addSystemMessage("Persona gerada com sucesso! Salvando perfil...");

    final profile = LeadProfile(
      id: const Uuid().v4(),
      name: state.answers['product'] != null
          ? 'Lead: ${state.answers['product']!.split(' ').take(3).join(' ')}'
          : 'Novo Lead',
      answers: state.answers,
      systemPrompt: systemPrompt,
      createdAt: DateTime.now(),
    );

    await ref.read(leadProfileRepositoryProvider).saveProfile(profile);
    state = state.copyWith(isTyping: false, isCompleted: true);
  }

  Future<String?> _generatePersona() async {
    try {
      final apiKey = ref.read(apiKeyProvider);
      if (apiKey == null || apiKey.isEmpty) {
        return null; // Handle missing API key
      }

      final openAIService = OpenAIService(apiKey);
      final generatorPromptTemplate = dotenv.env['SYSTEM_PROMPT_GENERATOR'];

      if (generatorPromptTemplate == null) {
        return null;
      }

      // Format user answers for the prompt
      final userAnswersBuffer = StringBuffer();
      for (int i = 0; i < _questions.length; i++) {
        userAnswersBuffer.writeln("Pergunta: ${_questions[i]}");
        userAnswersBuffer.writeln("Resposta: ${state.answers[_keys[i]]}");
        userAnswersBuffer.writeln("---");
      }

      final prompt = generatorPromptTemplate.replaceAll(
          '\${userAnswers}', userAnswersBuffer.toString());

      final systemPrompt = await openAIService.sendMessage([
        {
          'role': 'user',
          'content': prompt
        } // Using user role as we are instructing the model
      ], model: 'gpt-4o-mini');

      return systemPrompt;
    } catch (e) {
      // Log error
      return null;
    }
  }
}

final createProfileProvider = StateNotifierProvider.autoDispose
    .family<CreateProfileNotifier, ChatState, String>((ref, userName) {
  return CreateProfileNotifier(ref, userName: userName);
});
