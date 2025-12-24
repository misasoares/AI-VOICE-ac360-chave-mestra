class LeadProfile {
  final String id;
  final String name;
  final Map<String, String> answers;
  final String? systemPrompt;
  final DateTime createdAt;

  LeadProfile({
    required this.id,
    required this.name,
    required this.answers,
    this.systemPrompt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'answers': answers,
      'systemPrompt': systemPrompt,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LeadProfile.fromJson(Map<String, dynamic> json) {
    return LeadProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      answers: Map<String, String>.from(json['answers'] as Map),
      systemPrompt: json['systemPrompt'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
