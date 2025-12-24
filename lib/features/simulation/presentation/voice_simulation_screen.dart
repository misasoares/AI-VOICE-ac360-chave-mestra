import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../simulation/data/voice_provider.dart';
import '../../simulation/domain/prompt_manager.dart';
import '../../simulation/presentation/feedback_screen.dart';
import '../../../core/constants/app_colors.dart';
import 'widgets/simulation_loading_dialog.dart';

class VoiceSimulationScreen extends ConsumerStatefulWidget {
  const VoiceSimulationScreen({super.key});

  @override
  ConsumerState<VoiceSimulationScreen> createState() =>
      _VoiceSimulationScreenState();
}

class _VoiceSimulationScreenState extends ConsumerState<VoiceSimulationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(voiceProvider.notifier).startSession(ScenarioType.coldLead);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            ref.read(voiceProvider.notifier).endSession();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Cost Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black.withValues(alpha: 0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tokens: ${voiceState.inputTokens + voiceState.outputTokens}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Custo: R\$ ${voiceState.totalCost.toStringAsFixed(4)}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Avatar / Visualizer
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLight,
                      border: Border.all(
                        color: voiceState.status == VoiceStatus.speaking
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 4,
                      ),
                      boxShadow: voiceState.status == VoiceStatus.speaking
                          ? [
                              BoxShadow(
                                  color: AppColors.accent.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5)
                            ]
                          : [],
                    ),
                    child:
                        const Icon(Icons.person, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _getStatusText(voiceState.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (voiceState.status == VoiceStatus.error &&
                      voiceState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        voiceState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (voiceState.lastTranscript.isNotEmpty &&
                      voiceState.status != VoiceStatus.error)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        voiceState.lastTranscript,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Interrupt Button (Half-Duplex)
                  if (voiceState.status == VoiceStatus.speaking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(voiceProvider.notifier).interruptAI(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.stop, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Toque para interromper',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Controls
                  Container(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: voiceState.isMicEnabled
                              ? Icons.mic
                              : Icons.mic_off,
                          color: voiceState.isMicEnabled
                              ? Colors.white
                              : Colors.grey,
                          onTap: () =>
                              ref.read(voiceProvider.notifier).toggleMic(),
                        ),
                        _buildControlButton(
                          icon: Icons.call_end,
                          color: AppColors.error,
                          size: 72,
                          onTap: () async {
                            // Show loading FIRST to prevent UI freeze perception
                            // and indicate work is happening.
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) =>
                                  const SimulationLoadingDialog(),
                            );

                            // End session (disconnects, stops audio)
                            // This might throw in debug mode if exceptions happen,
                            // but we are safe.
                            ref.read(voiceProvider.notifier).endSession();

                            try {
                              final feedback = await ref
                                  .read(voiceProvider.notifier)
                                  .generateFeedback();
                              if (context.mounted) {
                                Navigator.pop(context); // Pop loading
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FeedbackScreen(
                                        feedbackContent: feedback),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context); // Pop loading
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Erro ao gerar feedback: $e')),
                                );
                                Navigator.pop(context); // Pop screen
                              }
                            }
                          },
                        ),
                        _buildControlButton(
                          icon:
                              Icons.volume_up, // Placeholder for speaker toggle
                          color: Colors.white,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(VoiceStatus status) {
    switch (status) {
      case VoiceStatus.disconnected:
        return 'Desconectado';
      case VoiceStatus.connecting:
        return 'Conectando...';
      case VoiceStatus.connected:
        return 'Conectado';
      case VoiceStatus.listening:
        return 'Ouvindo...';
      case VoiceStatus.speaking:
        return 'Falando...';
      case VoiceStatus.reconnecting:
        return 'Reconectando...';
      case VoiceStatus.error:
        return 'Erro';
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
