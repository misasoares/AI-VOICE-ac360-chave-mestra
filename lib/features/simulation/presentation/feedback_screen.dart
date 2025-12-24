import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';

class FeedbackScreen extends StatelessWidget {
  final String feedbackContent;

  const FeedbackScreen({super.key, required this.feedbackContent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback da Sessão'),
      ),
      body: Markdown(
        data: feedbackContent,
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold),
          h2: const TextStyle(
              color: AppColors.accent,
              fontSize: 20,
              fontWeight: FontWeight.bold),
          p: const TextStyle(fontSize: 16, height: 1.5),
          strong: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
