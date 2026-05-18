import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/socket_data.dart';

class HiveService {
  static const String _socketBox   = 'socket_states';
  static const String _energyBox   = 'energy_logs';
  static const String _settingsBox = 'settings';

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SocketDataAdapter());
    Hive.registerAdapter(EnergyLogAdapter());
    await Hive.openBox<SocketData>(_socketBox);
    await Hive.openBox<EnergyLog>(_energyBox);
    await Hive.openBox(_settingsBox);
  }

  // ── Socket state persistence ──────────────────────────────────────────────
  Box<SocketData> get _sockets => Hive.box<SocketData>(_socketBox);

  void saveSocketState(SocketData data) =>
      _sockets.put('socket_${data.socketId}', data);

  SocketData? getSocketState(int socketId) =>
      _sockets.get('socket_$socketId');

  List<SocketData> getAllSockets() => _sockets.values.toList();

  // ── Energy logs ───────────────────────────────────────────────────────────
  Box<EnergyLog> get _energy => Hive.box<EnergyLog>(_energyBox);

  void logEnergy(EnergyLog log) {
    _energy.add(log);
    // Keep only last 288 entries (24 h at 5-min intervals)
    if (_energy.length > 288) _energy.deleteAt(0);
  }

  List<EnergyLog> getEnergyLogs({int limit = 48}) {
    final all = _energy.values.toList();
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
  }

  double getTodayKwh() {
    final now = DateTime.now();
    final todayLogs = _energy.values.where((log) =>
        log.timestamp.day   == now.day   &&
        log.timestamp.month == now.month &&
        log.timestamp.year  == now.year).toList();
    return todayLogs.isEmpty ? 0.0 : todayLogs.last.kwhToday;
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  Box get _settings => Hive.box(_settingsBox);

  void saveBrokerSettings({
    required String host,
    required int port,
    required String username,
    required String password,
  }) {
    _settings.put('broker_host', host);
    _settings.put('broker_port', port);
    _settings.put('broker_user', username);
    _settings.put('broker_pass', password);
  }

  /// Returns broker settings saved by the user, falling back to .env values,
  /// which in turn fall back to safe empty strings.
  Map<String, dynamic> getBrokerSettings() {
    return {
      'host':     _settings.get('broker_host',
                    defaultValue: dotenv.env['MQTT_HOST'] ?? ''),
      'port':     _settings.get('broker_port',
                    defaultValue: int.tryParse(
                        dotenv.env['MQTT_PORT'] ?? '8883') ?? 8883),
      'username': _settings.get('broker_user',
                    defaultValue: dotenv.env['MQTT_USERNAME'] ?? ''),
      'password': _settings.get('broker_pass',
                    defaultValue: dotenv.env['MQTT_PASSWORD'] ?? ''),
    };
  }

  void saveOverloadThreshold(double amps) =>
      _settings.put('overload_threshold', amps);

  double getOverloadThreshold() {
    final envVal = double.tryParse(
        dotenv.env['OVERLOAD_THRESHOLD'] ?? '10.0') ?? 10.0;
    return _settings.get('overload_threshold', defaultValue: envVal);
  }
}