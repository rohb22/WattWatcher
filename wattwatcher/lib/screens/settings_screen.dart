import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/hive_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _thresholdCtrl;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    final hive = context.read<HiveService>();
    final settings = hive.getBrokerSettings();
    _hostCtrl = TextEditingController(text: settings['host']);
    _portCtrl = TextEditingController(text: settings['port'].toString());
    _userCtrl = TextEditingController(text: settings['username']);
    _passCtrl = TextEditingController(text: settings['password']);
    _thresholdCtrl = TextEditingController(
        text: hive.getOverloadThreshold().toStringAsFixed(1));
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttService>();
    final hive = context.read<HiveService>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Connection status ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bg,
           ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: mqtt.isConnected ? AppTheme.green : AppTheme.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  mqtt.connectionStatus,
                  style: TextStyle(
                    color: mqtt.isConnected ? AppTheme.green : AppTheme.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (mqtt.isConnected)
                  TextButton(
                    onPressed: mqtt.disconnect,
                    child: Text('Disconnect',
                        style: TextStyle(color: AppTheme.red, fontSize: 13)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionLabel('MQTT BROKER'),
          const SizedBox(height: 10),

          _Field(label: 'Host', controller: _hostCtrl, hint: 'broker.hivemq.com'),
          const SizedBox(height: 10),
          _Field(
              label: 'Port',
              controller: _portCtrl,
              hint: '8000',
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),

          _SectionLabel('PROTECTION'),
          const SizedBox(height: 10),
          _Field(
            label: 'Overload threshold (A)',
            controller: _thresholdCtrl,
            hint: '10.0',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          // ── Connect button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final host = _hostCtrl.text.trim();
                final port = int.tryParse(_portCtrl.text.trim()) ?? 1883;
                final user = _userCtrl.text.trim();
                final pass = _passCtrl.text.trim();
                final threshold =
                    double.tryParse(_thresholdCtrl.text.trim()) ?? 10.0;

                hive.saveBrokerSettings(
                    host: host, port: port, username: user, password: pass);
                hive.saveOverloadThreshold(threshold);

                if (mqtt.isConnected) mqtt.disconnect();
                final ok = await mqtt.connect(
                    host: host, port: port, username: user, password: pass);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Connected to $host' : 'Connection failed'),
                    backgroundColor:
                        ok ? const Color(0xFF1A6640) : AppTheme.redDim,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.accent, width: 0.5),
                ),
              ),
              child: const Text('Connect to Broker',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppTheme.accent, width: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}
