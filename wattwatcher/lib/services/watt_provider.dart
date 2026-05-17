import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/socket_data.dart';
import '../services/mqtt_service.dart';
import '../services/hive_service.dart';

class WattWatcherProvider extends ChangeNotifier {
  final MqttService mqttService;
  final HiveService hiveService;

  // ── Live sensor data ──────────────────────────────────────────────────────
  double voltage = 220.0;
  double current = 0.0;
  double totalWatts = 0.0;
  double kwhToday = 0.0;

  // ── Sockets (1-indexed, list index 0 = socket 1) ─────────────────────────
  List<SocketData> sockets = List.generate(
    4,
    (i) => SocketData(
      socketId: i + 1,
      watts: 0,
      amps: 0,
      isOn: false,
      isOverload: false,
      deviceLabel: _defaultLabel(i + 1),
      timestamp: DateTime.now(),
    ),
  );

  // ── Alerts ────────────────────────────────────────────────────────────────
  final List<String> alerts = [];

  // ── Chart data ────────────────────────────────────────────────────────────
  List<EnergyLog> energyHistory = [];

  StreamSubscription? _mqttSub;

  WattWatcherProvider({
    required this.mqttService,
    required this.hiveService,
  }) {
    _loadFromHive();
    _listenToMqtt();
  }

  // ── Load cached state ─────────────────────────────────────────────────────
  void _loadFromHive() {
    for (int i = 1; i <= 4; i++) {
      final saved = hiveService.getSocketState(i);
      if (saved != null) sockets[i - 1] = saved;
    }
    energyHistory = hiveService.getEnergyLogs();
    kwhToday = hiveService.getTodayKwh();
    notifyListeners();
  }

  // ── MQTT message router ───────────────────────────────────────────────────
  void _listenToMqtt() {
    _mqttSub = mqttService.messageStream.listen((data) {
      final topic = data['_topic'] as String? ?? '';

      if (topic == 'wattwatcher/sensor/power') {
        _handlePowerUpdate(data);
      } else if (topic.startsWith('wattwatcher/socket/') &&
          topic.endsWith('/state')) {
        final parts = topic.split('/');
        final socketId = int.tryParse(parts[2]);
        if (socketId != null) _handleSocketState(socketId, data);
      } else if (topic == 'wattwatcher/alert') {
        _handleAlert(data);
      }
    });
  }

  void _handlePowerUpdate(Map<String, dynamic> data) {
    voltage = (data['voltage'] as num?)?.toDouble() ?? voltage;
    current = (data['current'] as num?)?.toDouble() ?? current;
    totalWatts = (data['watts'] as num?)?.toDouble() ?? totalWatts;
    kwhToday = (data['kwh'] as num?)?.toDouble() ?? kwhToday;

    final log = EnergyLog(
      totalWatts: totalWatts,
      voltage: voltage,
      current: current,
      kwhToday: kwhToday,
      timestamp: DateTime.now(),
    );
    hiveService.logEnergy(log);
    energyHistory = hiveService.getEnergyLogs();
    notifyListeners();
  }

  void _handleSocketState(int socketId, Map<String, dynamic> data) {
    final idx = socketId - 1;
    if (idx < 0 || idx >= 4) return;

    sockets[idx] = SocketData(
      socketId: socketId,
      watts: (data['watts'] as num?)?.toDouble() ?? sockets[idx].watts,
      amps: (data['amps'] as num?)?.toDouble() ?? sockets[idx].amps,
      isOn: data['on'] as bool? ?? sockets[idx].isOn,
      isOverload: data['overload'] as bool? ?? false,
      deviceLabel: sockets[idx].deviceLabel,
      timestamp: DateTime.now(),
    );

    if (sockets[idx].isOverload) {
      _addAlert('Socket $socketId overload! Relay tripped.');
    }

    hiveService.saveSocketState(sockets[idx]);
    notifyListeners();
  }

  void _handleAlert(Map<String, dynamic> data) {
    final msg = data['message'] as String? ?? 'Unknown alert';
    _addAlert(msg);
  }

  void _addAlert(String msg) {
    alerts.insert(0, '[${_timeNow()}] $msg');
    if (alerts.length > 20) alerts.removeLast();
    notifyListeners();
  }

  // ── Commands ──────────────────────────────────────────────────────────────
  void toggleSocket(int socketId, bool on) {
    mqttService.toggleSocket(socketId, on);
    // Optimistic update
    final idx = socketId - 1;
    sockets[idx] = SocketData(
      socketId: socketId,
      watts: sockets[idx].watts,
      amps: sockets[idx].amps,
      isOn: on,
      isOverload: sockets[idx].isOverload,
      deviceLabel: sockets[idx].deviceLabel,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void resetSocket(int socketId) {
    mqttService.resetSocket(socketId);
    final idx = socketId - 1;
    sockets[idx] = SocketData(
      socketId: socketId,
      watts: 0,
      amps: 0,
      isOn: false,
      isOverload: false,
      deviceLabel: sockets[idx].deviceLabel,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void updateDeviceLabel(int socketId, String label) {
    final idx = socketId - 1;
    sockets[idx] = SocketData(
      socketId: socketId,
      watts: sockets[idx].watts,
      amps: sockets[idx].amps,
      isOn: sockets[idx].isOn,
      isOverload: sockets[idx].isOverload,
      deviceLabel: label,
      timestamp: sockets[idx].timestamp,
    );
    hiveService.saveSocketState(sockets[idx]);
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _defaultLabel(int id) {
    const labels = ['Fan', 'Charger', 'TV', 'Lamp'];
    return labels[id - 1];
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }
}
