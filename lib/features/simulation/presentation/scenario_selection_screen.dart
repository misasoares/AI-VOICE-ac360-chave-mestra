import 'package:flutter/material.dart';
import '../../simulation/domain/prompt_manager.dart';
import '../../simulation/presentation/chat_simulation_screen.dart';
import '../../../core/constants/app_colors.dart';

class ScenarioSelectionScreen extends StatelessWidget {
  const ScenarioSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha o Cenário'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildScenarioCard(
            context,
            title: 'Lead Frio',
            description:
                'Cliente desconhecido, sem interesse inicial. Requer quebra de padrão.',
            type: ScenarioType.coldLead,
            icon: Icons.ac_unit,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildScenarioCard(
            context,
            title: 'Lead Quente',
            description:
                'Cliente interessado, com dúvidas específicas. Requer fechamento.',
            type: ScenarioType.warmLead,
            icon: Icons.local_fire_department,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildScenarioCard(
            context,
            title: 'Cliente Cético',
            description:
                'Cliente desconfiado, exige provas. Requer construção de autoridade.',
            type: ScenarioType.skepticalClient,
            icon: Icons.help_outline,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(
    BuildContext context, {
    required String title,
    required String description,
    required ScenarioType type,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatSimulationScreen(scenarioType: type),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
