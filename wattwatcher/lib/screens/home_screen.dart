import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/watt_provider.dart';
import '../services/mqtt_service.dart';
import '../theme.dart';
import '../widgets/socket_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/power_chart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WattWatcherProvider>();
    final mqtt = context.watch<MqttService>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Watt',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(
                text: 'Watcher',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          _ConnectionDot(status: mqtt.connectionStatus),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: provider.alerts.isNotEmpty ? AppTheme.amber : AppTheme.textMuted,
            onPressed: () => _showAlerts(context, provider.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: AppTheme.textMuted,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Total power card ──────────────────────────────────────────────
          _PowerCard(provider: provider),
          const SizedBox(height: 12),

          // ── Stats grid ────────────────────────────────────────────────────
          _SectionLabel('Live Readings'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(
                icon: Icons.electrical_services,
                iconColor: AppTheme.accent,
                iconBg: AppTheme.bg,
                value: '${provider.voltage.toStringAsFixed(0)} V',
                label: 'Voltage',
              ),
              StatCard(
                icon: Icons.bolt,
                iconColor: AppTheme.green,
                iconBg: AppTheme.bg,
                value: '${provider.current.toStringAsFixed(2)} A',
                label: 'Current',
              ),
              StatCard(
                icon: Icons.wb_sunny_outlined,
                iconColor: AppTheme.amber,
                iconBg: AppTheme.bg,
                value: '${provider.totalWatts.toStringAsFixed(0)} W',
                label: 'Active Power',
              ),
              StatCard(
                icon: Icons.battery_charging_full,
                iconColor: AppTheme.red,
                iconBg: AppTheme.bg,
                value: '${provider.kwhToday.toStringAsFixed(2)} kWh',
                label: 'Today',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Overload alert ────────────────────────────────────────────────
          if (provider.sockets.any((s) => s.isOverload)) ...[
            _OverloadAlert(
              sockets: provider.sockets
                  .where((s) => s.isOverload)
                  .map((s) => s.socketId)
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          // ── Socket controls ───────────────────────────────────────────────
          _SectionLabel('Socket Control'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: provider.sockets.map((socket) {
              return SocketCard(
                socket: socket,
                onToggle: () =>
                    provider.toggleSocket(socket.socketId, !socket.isOn),
                onReset: () => provider.resetSocket(socket.socketId),
                onLabelEdit: () => _editLabel(context, provider, socket.socketId,
                    socket.deviceLabel),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAlerts(BuildContext context, List<String> alerts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Text(
                        'No alerts',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView(
                      children: alerts
                          .map((a) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Color(0xFFFF9800), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a,
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _editLabel(
      BuildContext context, WattWatcherProvider provider, int socketId, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Socket $socketId device',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Device name',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              provider.updateDeviceLabel(socketId, ctrl.text.trim());
              Navigator.pop(context);
            },
            child: Text('Save',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  final String status;
  const _ConnectionDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConnected = status == 'Connected';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.green : AppTheme.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isConnected ? 'MQTT' : 'Offline',
            style: TextStyle(
              color: isConnected ? AppTheme.green : AppTheme.red,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerCard extends StatelessWidget {
  final WattWatcherProvider provider;
  const _PowerCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color:AppTheme.textPrimary, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${provider.totalWatts.toStringAsFixed(0)} W',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${provider.voltage.toStringAsFixed(0)}V · ${provider.current.toStringAsFixed(2)}A total',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(
                    label: provider.sockets.any((s) => s.isOverload)
                        ? 'Overload!'
                        : 'Normal',
                    isGood: !provider.sockets.any((s) => s.isOverload),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Today: ${provider.kwhToday.toStringAsFixed(2)} kWh',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          PowerChart(logs: provider.energyHistory),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isGood;
  const _StatusBadge({required this.label, required this.isGood});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isGood ? AppTheme.bg : AppTheme.redDim,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isGood ? AppTheme.green : AppTheme.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isGood ? AppTheme.green : AppTheme.red,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverloadAlert extends StatelessWidget {
  final List<int> sockets;
  const _OverloadAlert({required this.sockets});

  @override
  Widget build(BuildContext context) {
    final socketList = sockets.map((s) => 'Socket $s').join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.amberDim,
        border: Border.all(color: const Color(0xFF6A3010), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$socketList tripped due to overload. Relay disconnected. Long-press socket card to reset after unplugging device.',
              style: const TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
