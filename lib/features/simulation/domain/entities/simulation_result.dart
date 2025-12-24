import 'dart:convert';

class SimulationResult {
  final String id;
  final DateTime timestamp;
  final int durationSeconds;
  final int inputTokens;
  final int outputTokens;
  final double totalCost;
  final String systemPrompt;
  final String? feedbackReport;
  final int reportInputTokens;
  final int reportOutputTokens;
  final double reportTotalCost;

  SimulationResult({
    required this.id,
    required this.timestamp,
    required this.durationSeconds,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalCost,
    required this.systemPrompt,
    this.feedbackReport,
    this.reportInputTokens = 0,
    this.reportOutputTokens = 0,
    this.reportTotalCost = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'totalCost': totalCost,
      'systemPrompt': systemPrompt,
      'feedbackReport': feedbackReport,
      'reportInputTokens': reportInputTokens,
      'reportOutputTokens': reportOutputTokens,
      'reportTotalCost': reportTotalCost,
    };
  }

  factory SimulationResult.fromMap(Map<String, dynamic> map) {
    return SimulationResult(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      durationSeconds: map['durationSeconds']?.toInt() ?? 0,
      inputTokens: map['inputTokens']?.toInt() ?? 0,
      outputTokens: map['outputTokens']?.toInt() ?? 0,
      totalCost: map['totalCost']?.toDouble() ?? 0.0,
      systemPrompt: map['systemPrompt'] ?? '',
      feedbackReport: map['feedbackReport'],
      reportInputTokens: map['reportInputTokens']?.toInt() ?? 0,
      reportOutputTokens: map['reportOutputTokens']?.toInt() ?? 0,
      reportTotalCost: map['reportTotalCost']?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory SimulationResult.fromJson(String source) =>
      SimulationResult.fromMap(json.decode(source));
}
