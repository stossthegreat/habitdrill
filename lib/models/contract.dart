import 'dart:convert';

enum ContractType { quit, build, streak }

enum ContractStatus { active, completed, failed }

class Contract {
  final String id;
  final String title;
  final String emoji;
  final DateTime startDate;
  final int? targetDays;
  final ContractType type;
  ContractStatus status;
  int daysCompleted;
  int daysFailed;
  DateTime? completedAt;
  DateTime? lastCheckedDate;

  Contract({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startDate,
    this.targetDays,
    required this.type,
    this.status = ContractStatus.active,
    this.daysCompleted = 0,
    this.daysFailed = 0,
    this.completedAt,
    this.lastCheckedDate,
  });

  bool get hasTarget => targetDays != null;

  double get progress {
    if (!hasTarget || targetDays == 0) return 0.0;
    return (daysCompleted / targetDays!).clamp(0.0, 1.0);
  }

  int get daysRemaining {
    if (!hasTarget) return 0;
    return (targetDays! - daysCompleted).clamp(0, targetDays!);
  }

  String get progressLabel {
    if (hasTarget) return '$daysCompleted / $targetDays';
    return '$daysCompleted Days';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'startDate': startDate.toIso8601String(),
        'targetDays': targetDays,
        'type': type.name,
        'status': status.name,
        'daysCompleted': daysCompleted,
        'daysFailed': daysFailed,
        'completedAt': completedAt?.toIso8601String(),
        'lastCheckedDate': lastCheckedDate?.toIso8601String(),
      };

  factory Contract.fromJson(Map<String, dynamic> j) => Contract(
        id: j['id'],
        title: j['title'],
        emoji: j['emoji'],
        startDate: DateTime.parse(j['startDate']),
        targetDays: j['targetDays'],
        type: ContractType.values.firstWhere((t) => t.name == j['type'], orElse: () => ContractType.build),
        status: ContractStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => ContractStatus.active),
        daysCompleted: j['daysCompleted'] ?? 0,
        daysFailed: j['daysFailed'] ?? 0,
        completedAt: j['completedAt'] != null ? DateTime.parse(j['completedAt']) : null,
        lastCheckedDate: j['lastCheckedDate'] != null ? DateTime.parse(j['lastCheckedDate']) : null,
      );

  String toRaw() => jsonEncode(toJson());
  factory Contract.fromRaw(String raw) => Contract.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class ContractTemplate {
  final String title;
  final String emoji;
  final int? targetDays;
  final ContractType type;

  const ContractTemplate({
    required this.title,
    required this.emoji,
    required this.targetDays,
    required this.type,
  });

  static const List<ContractTemplate> presets = [
    ContractTemplate(title: 'Quit Vape', emoji: '🚭', targetDays: 90, type: ContractType.quit),
    ContractTemplate(title: '75 Hard', emoji: '🔥', targetDays: 75, type: ContractType.build),
    ContractTemplate(title: 'Monk Mode', emoji: '🧘', targetDays: 30, type: ContractType.build),
    ContractTemplate(title: 'No Sugar', emoji: '🍬', targetDays: 30, type: ContractType.quit),
    ContractTemplate(title: 'Creator Mode', emoji: '🎨', targetDays: 30, type: ContractType.build),
  ];
}
