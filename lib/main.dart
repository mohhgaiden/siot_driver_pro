import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  // 🚀 BUILD MARKER — si vous voyez cette ligne, vous tournez avec la nouvelle
  // version du code (storage 1 min + CapteurSync). Sinon, c'est l'ancienne app.
  debugPrint(
    '🚀 SIOT Driver — build du ${DateTime.now()} — '
    'avec stockage régulier + CapteurSync',
  );
  // Localisation des dates en français (calendrier, DateFormat)
  await initializeDateFormatting('fr_FR', null);
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
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnMyPackageReplaced: true,
      //interval: 5000,
      //isOnceEvent: false,
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
    Hive.openBox('IOS_UUID_MAC'),
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
      // Localisations : français en premier, fallback anglais
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
      home: const MainScreen(),
    );
  }
}
