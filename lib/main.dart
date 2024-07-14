import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:siot_driver_pro/login/page/main.dart';
import 'package:siot_driver_pro/theme/light.dart';
import 'package:siot_driver_pro/util/notification.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await Hive.initFlutter();
  await Hive.openBox('LOGGED_IN_USER');
  await Hive.openBox('LIST_CAPTEURS');
  await Hive.openBox('SENSOR_READ');
  await Hive.openBox('SENSOR_READ1');
  await Hive.openBox('Alert');
  await Hive.openBox('ACTIVITY_START_END');
  await Hive.openBox('USER_PASS');
  appConfig();
  runApp(const MyApp());
}

appConfig(){
  WidgetsFlutterBinding.ensureInitialized();                 
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.white
  ));
                
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [
      SystemUiOverlay.bottom,
      SystemUiOverlay.top,
    ]
  );
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Siot Driver Pro',
      debugShowCheckedModeBanner: false,
      theme: LightTheme().light(),
      home: const MainScreen()
    );
  }
}