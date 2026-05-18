import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// ─── MQTT Topic Map (matches ESP32 firmware) ─────────────────────────────────
// wattwatcher/sensor/power     → { voltage, current, watts, kwh }
// wattwatcher/socket/1/state   → { on: bool, watts, amps, overload }
// wattwatcher/socket/2/state   → ...
// wattwatcher/socket/3/state   → ...
// wattwatcher/socket/4/state   → ...
// wattwatcher/socket/1/set     ← publish { on: true/false }  (command)
// wattwatcher/alert            → { type: "overload", socket: 3, message: "..." }
// ─────────────────────────────────────────────────────────────────────────────

class MqttService extends ChangeNotifier {
  // ── Read everything from .env — no hardcoded secrets anywhere ────────────
  static String get _defaultHost =>
      dotenv.env['MQTT_HOST'] ?? 'localhost';
  static int get _defaultPort =>
      int.tryParse(dotenv.env['MQTT_PORT'] ?? '8883') ?? 8883;
  static String get _defaultUsername =>
      dotenv.env['MQTT_USERNAME'] ?? '';
  static String get _defaultPassword =>
      dotenv.env['MQTT_PASSWORD'] ?? '';

  // Unique client ID per device so two phones don't kick each other off
  static final String _clientId =
      'wattwatcher_flutter_${DateTime.now().millisecondsSinceEpoch}';

  MqttServerClient? _client;

  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;

  // ── Connect ───────────────────────────────────────────────────────────────
  Future<bool> connect({
    String? host,
    int? port,
    String? username,
    String? password,
  }) async {
    // Caller can override (e.g. from a settings screen); otherwise use .env
    final resolvedHost     = host     ?? _defaultHost;
    final resolvedPort     = port     ?? _defaultPort;
    final resolvedUsername = username ?? _defaultUsername;
    final resolvedPassword = password ?? _defaultPassword;

    _setStatus('Connecting…');

    _client = MqttServerClient.withPort(resolvedHost, _clientId, resolvedPort);
    _client!.securityContext = SecurityContext.defaultContext;
    _client!.secure = true;
    _client!.logging(on: kDebugMode);
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnect = () => _setStatus('Reconnecting…');

    // HiveMQ always requires credentials — chain so nothing is discarded
    final connMsg = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .authenticateAs(resolvedUsername, resolvedPassword);

    _client!.connectionMessage = connMsg;

    try {
      await _client!.connect();
      return _isConnected;
    } catch (e) {
      _setStatus('Error: $e');
      _client?.disconnect();
      return false;
    }
  }

  void _onConnected() {
    _isConnected = true;
    _setStatus('Connected');
    _subscribeToTopics();
    _listenToMessages();
  }

  void _onDisconnected() {
    _isConnected = false;
    _setStatus('Disconnected');
  }

  void _setStatus(String status) {
    _connectionStatus = status;
    notifyListeners();
  }

  // ── Subscribe ─────────────────────────────────────────────────────────────
  void _subscribeToTopics() {
    final topics = [
      'wattwatcher/sensor/power',
      'wattwatcher/socket/1/state',
      'wattwatcher/socket/2/state',
      'wattwatcher/socket/3/state',
      'wattwatcher/socket/4/state',
      'wattwatcher/alert',
    ];
    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void _listenToMessages() {
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final recMsg = msg.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          recMsg.payload.message,
        );
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          data['_topic'] = msg.topic;
          _messageController.add(data);
        } catch (_) {}
      }
    });
  }

  // ── Publish ───────────────────────────────────────────────────────────────
  void toggleSocket(int socketId, bool on) {
    if (!_isConnected) return;
    final topic = 'wattwatcher/socket/$socketId/set';
    final payload = jsonEncode({'on': on});
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void resetSocket(int socketId) {
    if (!_isConnected) return;
    final topic = 'wattwatcher/socket/$socketId/set';
    final payload = jsonEncode({'reset': true});
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
    _setStatus('Disconnected');
    notifyListeners();
  }

  @override
  void dispose() {
    _messageController.close();
    disconnect();
    super.dispose();
  }
}