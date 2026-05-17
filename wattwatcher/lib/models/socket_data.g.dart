// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'socket_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SocketDataAdapter extends TypeAdapter<SocketData> {
  @override
  final int typeId = 0;

  @override
  SocketData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SocketData(
      socketId: fields[0] as int,
      watts: fields[1] as double,
      amps: fields[2] as double,
      isOn: fields[3] as bool,
      isOverload: fields[4] as bool,
      deviceLabel: fields[5] as String,
      timestamp: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SocketData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.socketId)
      ..writeByte(1)
      ..write(obj.watts)
      ..writeByte(2)
      ..write(obj.amps)
      ..writeByte(3)
      ..write(obj.isOn)
      ..writeByte(4)
      ..write(obj.isOverload)
      ..writeByte(5)
      ..write(obj.deviceLabel)
      ..writeByte(6)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocketDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EnergyLogAdapter extends TypeAdapter<EnergyLog> {
  @override
  final int typeId = 1;

  @override
  EnergyLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EnergyLog(
      totalWatts: fields[0] as double,
      voltage: fields[1] as double,
      current: fields[2] as double,
      kwhToday: fields[3] as double,
      timestamp: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, EnergyLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.totalWatts)
      ..writeByte(1)
      ..write(obj.voltage)
      ..writeByte(2)
      ..write(obj.current)
      ..writeByte(3)
      ..write(obj.kwhToday)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnergyLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
