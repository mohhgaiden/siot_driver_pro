import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:siot_driver_pro/features/auth/pages/login_gate.dart';
import 'package:siot_driver_pro/core/theme/light.dart';
import 'package:siot_driver_pro/core/utils/notification.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'foreground_service.dart'; // where BleTaskHandler is

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BleTaskHandler());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initServices();
  // ✅ INIT FOREGROUND TASK
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'siot_channel',
      channelName: 'SIOT Background Service',
      channelDescription: 'This notification keeps BLE running',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  _configureApp();
  runApp(const MyApp());
}

Future<void> _initServices() async {
  await NotificationService.init();
  await _initHive();
}

Future<void> _initHive() async {
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox('LOGGED_IN_USER'),
    Hive.openBox('LIST_CAPTEURS'),
    Hive.openBox('SENSOR_READ'),
    Hive.openBox('SENSOR_READ1'),
    Hive.openBox('Alert'),
    Hive.openBox('ACTIVITY_START_END'),
    Hive.openBox('USER_PASS'),
    Hive.openBox('APP_SETTINGS'),
  ]);
}

void _configureApp() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Siot Driver Pro',
      debugShowCheckedModeBanner: false,
      theme: LightTheme().light(),
      home: const MainScreen(),
    );
  }
}
