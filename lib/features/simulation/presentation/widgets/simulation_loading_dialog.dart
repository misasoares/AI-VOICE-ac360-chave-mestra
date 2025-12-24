import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';

class SimulationLoadingDialog extends StatefulWidget {
  const SimulationLoadingDialog({super.key});

  @override
  State<SimulationLoadingDialog> createState() =>
      _SimulationLoadingDialogState();
}

class _SimulationLoadingDialogState extends State<SimulationLoadingDialog> {
  double _progress = 0.0;
  String _message = 'Iniciando análise...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() {
    // Simulate progress: 0 -> 95% over ~6 seconds
    // The last 5% waits for the actual API response
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      setState(() {
        if (_progress < 0.4) {
          _progress += 0.02; // Fast start
          _message = 'Analisando transcrição da conversa...';
        } else if (_progress < 0.7) {
          _progress += 0.01; // Slow down
          _message = 'Avaliando técnicas de venda...';
        } else if (_progress < 0.90) {
          _progress += 0.005; // Very slow near end
          _message = 'Compilando relatório final...';
        } else if (_progress < 0.95) {
          _progress += 0.001; // Creep
        }
        // Cap at 0.95 until dismissed
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gerando Feedback',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
