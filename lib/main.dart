import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:siot_driver_pro/core/theme/light.dart';
import 'package:siot_driver_pro/core/utils/notification.dart';
import 'package:siot_driver_pro/features/auth/pages/login_gate.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'foreground_service.dart';

@pragma('vm:entry-point')
void startCallback() {
  // ✅ FOREGROUND TASK ONLY ON ANDROID
  if (Platform.isAndroid) {
    FlutterForegroundTask.setTaskHandler(BleTaskHandler());
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeApp();

  runApp(const MyApp());
}

Future<void> _initializeApp() async {
  try {
    await _initServices();

    // ✅ ANDROID ONLY
    if (Platform.isAndroid) {
      await _initForegroundTask();
    }

    _configureApp();
  } catch (e) {
    debugPrint('INIT ERROR: $e');
  }
}

Future<void> _initForegroundTask() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'siot_channel',
      channelName: 'SIOT Background Service',
      channelDescription: 'Keeps BLE scanning active',
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
  ]);

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ],
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S-IOT Driver',
      debugShowCheckedModeBanner: false,
      theme: LightTheme().light(),
      home: const MainScreen(),
    );
  }
}