import 'package:hive/hive.dart';

part 'socket_data.g.dart';

@HiveType(typeId: 0)
class SocketData extends HiveObject {
  @HiveField(0)
  int socketId;

  @HiveField(1)
  double watts;

  @HiveField(2)
  double amps;

  @HiveField(3)
  bool isOn;

  @HiveField(4)
  bool isOverload;

  @HiveField(5)
  String deviceLabel;

  @HiveField(6)
  DateTime timestamp;

  SocketData({
    required this.socketId,
    required this.watts,
    required this.amps,
    required this.isOn,
    required this.isOverload,
    required this.deviceLabel,
    required this.timestamp,
  });
}

@HiveType(typeId: 1)
class EnergyLog extends HiveObject {
  @HiveField(0)
  double totalWatts;

  @HiveField(1)
  double voltage;

  @HiveField(2)
  double current;

  @HiveField(3)
  double kwhToday;

  @HiveField(4)
  DateTime timestamp;

  EnergyLog({
    required this.totalWatts,
    required this.voltage,
    required this.current,
    required this.kwhToday,
    required this.timestamp,
  });
}
