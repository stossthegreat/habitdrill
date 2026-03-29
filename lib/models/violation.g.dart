// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'violation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ViolationAdapter extends TypeAdapter<Violation> {
  @override
  final int typeId = 1;

  @override
  Violation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Violation(
      id: fields[0] as String,
      habitId: fields[1] as String,
      habitTitle: fields[2] as String,
      violationType: fields[3] as String,
      occurredAt: fields[4] as DateTime,
      scheduledFor: fields[5] as DateTime,
      offenseNumber: fields[6] as int,
      punishmentCompleted: fields[7] as bool,
      clearedAt: fields[8] as DateTime?,
      escalationLevel: fields[9] as int,
      notificationsSent: fields[10] as int,
      exerciseData: fields[11] as String?,
      sergeantMessage: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Violation obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.habitId)
      ..writeByte(2)
      ..write(obj.habitTitle)
      ..writeByte(3)
      ..write(obj.violationType)
      ..writeByte(4)
      ..write(obj.occurredAt)
      ..writeByte(5)
      ..write(obj.scheduledFor)
      ..writeByte(6)
      ..write(obj.offenseNumber)
      ..writeByte(7)
      ..write(obj.punishmentCompleted)
      ..writeByte(8)
      ..write(obj.clearedAt)
      ..writeByte(9)
      ..write(obj.escalationLevel)
      ..writeByte(10)
      ..write(obj.notificationsSent)
      ..writeByte(11)
      ..write(obj.exerciseData)
      ..writeByte(12)
      ..write(obj.sergeantMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViolationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
