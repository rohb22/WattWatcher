import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/mqtt_service.dart';
import 'services/hive_service.dart';
import 'services/watt_provider.dart';
import 'screens/main_shell.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  runApp(const WattWatcherApp());
}

class WattWatcherApp extends StatelessWidget {
  const WattWatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hive = HiveService();
    final mqtt = MqttService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MqttService>.value(value: mqtt),
        Provider<HiveService>.value(value: hive),
        ChangeNotifierProvider(
          create: (_) => WattWatcherProvider(
            mqttService: mqtt,
            hiveService: hive,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'WattWatcher',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const MainShell(),
        routes: {
          '/settings': (_) => const MainShell(),
        },
      ),
    );
  }
}
