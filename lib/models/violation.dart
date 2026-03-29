import 'package:hive/hive.dart';

part 'violation.g.dart';

@HiveType(typeId: 1)
class Violation extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String habitId;

  @HiveField(2)
  String habitTitle;

  @HiveField(3)
  String violationType; // 'missed' or 'indulged'

  @HiveField(4)
  DateTime occurredAt;

  @HiveField(5)
  DateTime scheduledFor;

  @HiveField(6)
  int offenseNumber; // cumulative per-habit

  @HiveField(7)
  bool punishmentCompleted;

  @HiveField(8)
  DateTime? clearedAt;

  @HiveField(9)
  int escalationLevel; // 1, 2, or 3

  @HiveField(10)
  int notificationsSent;

  // Reserve fields for future
  @HiveField(11)
  String? exerciseData; // JSON string of completed exercises

  @HiveField(12)
  String? sergeantMessage; // AI-generated message

  Violation({
    required this.id,
    required this.habitId,
    required this.habitTitle,
    required this.violationType,
    required this.occurredAt,
    required this.scheduledFor,
    required this.offenseNumber,
    this.punishmentCompleted = false,
    this.clearedAt,
    required this.escalationLevel,
    this.notificationsSent = 0,
    this.exerciseData,
    this.sergeantMessage,
  });

  static int getEscalationLevel(int offenseNumber) {
    if (offenseNumber <= 1) return 1;
    if (offenseNumber == 2) return 2;
    return 3;
  }
}
