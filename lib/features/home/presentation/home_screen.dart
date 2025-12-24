import 'package:flutter/material.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/constants/app_colors.dart';
// Placeholder imports for simulation screens
import '../../simulation/presentation/voice_simulation_screen.dart';
import '../../simulation/presentation/scenario_selection_screen.dart';

import '../../lead_profiles/presentation/screens/lead_profile_list_screen.dart';
import '../../simulation/presentation/simulation_history_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lead_profiles/presentation/providers/lead_profile_list_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chave Mestra RP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escolha o modo de treino',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildSimulationCard(
              context,
              title: 'Simulação por Texto',
              icon: Icons.chat_bubble_outline,
              color: AppColors.primary,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ScenarioSelectionScreen()));
              },
            ),
            const SizedBox(height: 16),
            _buildSimulationCard(
              context,
              title: 'Simulação por Voz',
              icon: Icons.mic_none,
              color: AppColors.accent,
              onTap: () async {
                try {
                  // Show loading indicator in a dialog if fetching takes time?
                  // Or just await. Since it's a future provider, it might be cached or quick.
                  final profiles =
                      await ref.read(leadProfileListProvider.future);

                  if (!context.mounted) return;

                  if (profiles.isEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Perfil Necessário'),
                        content: const Text(
                            'Você precisa criar um perfil de lead antes de iniciar a simulação por voz.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LeadProfileListScreen(),
                                ),
                              );
                            },
                            child: const Text('Criar Perfil'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Show selection dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Selecione um Perfil'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: profiles.length,
                            itemBuilder: (context, index) {
                              final profile = profiles[index];
                              return ListTile(
                                title: Text(profile.name),
                                leading: const Icon(Icons.person),
                                onTap: () {
                                  Navigator.pop(context); // Close dialog
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          VoiceSimulationScreen(
                                        leadProfile: profile,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao carregar perfis: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            _buildSimulationCard(
              context,
              title: 'Perfis de Leads',
              icon: Icons.people,
              color: Colors.blueGrey,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LeadProfileListScreen()));
              },
            ),
            const SizedBox(height: 16),
            _buildSimulationCard(
              context,
              title: 'Análise de Simulações',
              icon: Icons.analytics_outlined,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SimulationHistoryScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
