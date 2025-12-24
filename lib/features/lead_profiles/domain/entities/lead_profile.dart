class LeadProfile {
  final String id;
  final String name;
  final Map<String, String> answers;
  final DateTime createdAt;

  LeadProfile({
    required this.id,
    required this.name,
    required this.answers,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'answers': answers,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LeadProfile.fromJson(Map<String, dynamic> json) {
    return LeadProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      answers: Map<String, String>.from(json['answers'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
