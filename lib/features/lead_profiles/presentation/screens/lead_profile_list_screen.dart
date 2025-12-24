import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lead_profile_list_provider.dart';
import '../providers/lead_profile_repository_provider.dart';
import '../../domain/entities/lead_profile.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/openai_service.dart';
import 'create_lead_profile_screen.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../../../settings/data/settings_provider.dart';

class LeadProfileListScreen extends ConsumerStatefulWidget {
  const LeadProfileListScreen({super.key});

  @override
  ConsumerState<LeadProfileListScreen> createState() =>
      _LeadProfileListScreenState();
}

class _LeadProfileListScreenState extends ConsumerState<LeadProfileListScreen> {
  bool _isGenerating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKey();
    });
  }

  void _checkApiKey() {
    final apiKey = ref.read(apiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) {
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => const SettingsScreen(isForced: true),
        ),
      )
          .then((_) {
        // Double check if key was set after returning
        final key = ref.read(apiKeyProvider);
        if (key == null || key.isEmpty) {
          // If still no key (shouldn't happen with forced mode, but safety first), pop back
          Navigator.of(context).pop();
        }
      });
    }
  }

  Future<void> _generateAutoProfile() async {
    setState(() => _isGenerating = true);

    // Hardcoded answers
    final answers = {
      "product": "Software de Gestão para Clínicas (SaaS) - R\$ 497/mês",
      "transformation":
          "Organizar a agenda e reduzir faltas de pacientes em 30%",
      "ideal_customer": "Dono de clínica médica ou odontológica, 35-55 anos",
      "awareness_level": "Sabe que tem problema (agenda bagunçada)",
      "pain_point":
          "Perder dinheiro com faltas e desorganização da recepcionista",
      "desire": "Ter a clínica rodando no automático e sobrar tempo",
      "objections": "Acha caro, Time não vai se adaptar, Já usa planilha",
      "personality_style": "Apressado e Prático",
      "call_context": "Lead de Inbound (baixou ebook)",
      "decision_criteria": "Facilidade de uso e Suporte",
      "irritations": "Vendedor prolixo/que enrola muito",
      "speaking_style":
          "Fala rápido, direto ao ponto. Usa termos como 'ROI', 'Otimizar'."
    };

    // Questions for prompt construction
    final questions = [
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

    final keys = [
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

    try {
      final apiKey = ref.read(apiKeyProvider);
      if (apiKey == null || apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configure sua API Key primeiro.')),
          );
          _checkApiKey(); // Force redirect
        }
        return;
      }

      final openAIService = OpenAIService(apiKey);
      final generatorPromptTemplate = dotenv.env['SYSTEM_PROMPT_GENERATOR'];

      if (generatorPromptTemplate == null) {
        throw Exception("Template de prompt não encontrado no .env");
      }

      final userAnswersBuffer = StringBuffer();
      for (int i = 0; i < questions.length; i++) {
        userAnswersBuffer.writeln("Pergunta: ${questions[i]}");
        userAnswersBuffer.writeln("Resposta: ${answers[keys[i]]}");
        userAnswersBuffer.writeln("---");
      }

      final prompt = generatorPromptTemplate.replaceAll(
          '\${userAnswers}', userAnswersBuffer.toString());

      final systemPromptRes = await openAIService.sendMessage([
        {'role': 'user', 'content': prompt}
      ], model: 'gpt-4o-mini');

      final systemPrompt = systemPromptRes.content;

      final profile = LeadProfile(
        id: const Uuid().v4(),
        name: 'Lead: Clínica (Auto)',
        answers: answers,
        systemPrompt: systemPrompt,
        createdAt: DateTime.now(),
      );

      await ref.read(leadProfileRepositoryProvider).saveProfile(profile);
      // ignore: unused_result
      ref.refresh(leadProfileListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Perfil gerado automaticamente com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        // Safe check for context mounting
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar perfil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(leadProfileListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfis de Leads'),
        actions: [
          IconButton(
            icon: _isGenerating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            onPressed: _isGenerating ? null : _generateAutoProfile,
            tooltip: 'Gerar Perfil Automaticamente',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => const CreateLeadProfileScreen(),
                ),
              )
                  .then((_) {
                // Refresh list when coming back
                // ignore: unused_local_variable
                final result = ref.refresh(leadProfileListProvider);
              });
            },
            tooltip: 'Criar Perfil de Lead',
          ),
        ],
      ),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Nenhum perfil criado ainda.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                          builder: (context) => const CreateLeadProfileScreen(),
                        ),
                      )
                          .then((_) {
                        // ignore: unused_local_variable
                        final result = ref.refresh(leadProfileListProvider);
                      });
                    },
                    child: const Text('Criar Perfil de Lead'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(profile.name),
                  subtitle:
                      Text(profile.answers['role'] ?? 'Sem cargo definido'),
                  onTap: () => _showProfileDetails(context, profile),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () =>
                        _showDeleteConfirmation(context, ref, profile),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Erro ao carregar perfis: $err')),
      ),
    );
  }

  void _showProfileDetails(BuildContext context, LeadProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(profile.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...profile.answers.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: '${e.key}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: e.value),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    LeadProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Perfil'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tem certeza que deseja excluir este perfil?'),
                const SizedBox(height: 16),
                Text(
                  'Nome: ${profile.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Características:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...profile.answers.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child: Text('${e.key}: ${e.value}'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(leadProfileRepositoryProvider).deleteProfile(profile.id);
      // Refresh the list to remove the deleted item
      // ignore: unused_result
      ref.refresh(leadProfileListProvider);
    }
  }
}
