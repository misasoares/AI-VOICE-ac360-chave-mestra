import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../simulation/data/simulation_repository_provider.dart';
import '../../simulation/domain/entities/simulation_result.dart';

class SimulationHistoryScreen extends ConsumerStatefulWidget {
  const SimulationHistoryScreen({super.key});

  @override
  ConsumerState<SimulationHistoryScreen> createState() =>
      _SimulationHistoryScreenState();
}

class _SimulationHistoryScreenState
    extends ConsumerState<SimulationHistoryScreen> {
  late Future<List<SimulationResult>> _simulationsFuture;

  @override
  void initState() {
    super.initState();
    _loadSimulations();
  }

  void _loadSimulations() {
    _simulationsFuture =
        ref.read(simulationRepositoryProvider).getSimulations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Análise de Simulações'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<SimulationResult>>(
        future: _simulationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar simulações: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final simulations = snapshot.data ?? [];

          if (simulations.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma simulação encontrada.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.builder(
            itemCount: simulations.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final simulation = simulations[index];
              return _buildSimulationCard(simulation);
            },
          );
        },
      ),
    );
  }

  Widget _buildSimulationCard(SimulationResult simulation) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final totalTokens = simulation.inputTokens + simulation.outputTokens;
    final totalReportTokens =
        simulation.reportInputTokens + simulation.reportOutputTokens;

    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          dateFormat.format(simulation.timestamp),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Duração: ${_formatDuration(simulation.durationSeconds)} | Custo estimado: R\$ ${(simulation.totalCost + simulation.reportTotalCost).toStringAsFixed(2).replaceAll('.', ',')}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        iconColor: AppColors.accent,
        collapsedIconColor: Colors.white,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Simulação de Voz'),
                _buildInfoRow('Input Tokens:', '${simulation.inputTokens}'),
                _buildInfoRow('Output Tokens:', '${simulation.outputTokens}'),
                _buildInfoRow('Total Tokens:', '$totalTokens'),
                _buildInfoRow(
                    'Custo:', 'R\$ ${simulation.totalCost.toStringAsFixed(4)}'),
                const Divider(color: Colors.white24),
                _buildSectionTitle('Relatório de Feedback'),
                _buildInfoRow(
                    'Input Tokens:', '${simulation.reportInputTokens}'),
                _buildInfoRow(
                    'Output Tokens:', '${simulation.reportOutputTokens}'),
                _buildInfoRow('Total Tokens:', '$totalReportTokens'),
                _buildInfoRow('Custo:',
                    'R\$ ${simulation.reportTotalCost.toStringAsFixed(4)}'),
                const Divider(color: Colors.white24),
                _buildSectionTitle('Prompt do Sistema'),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    simulation.systemPrompt,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
