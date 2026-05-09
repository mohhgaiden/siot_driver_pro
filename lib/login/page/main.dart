import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as location1;
import 'package:siot_driver_pro/home/page/homo.dart';
import 'package:siot_driver_pro/login/page/login.dart';
import 'package:siot_driver_pro/widgets/bluetooth_off_screen.dart';
import 'package:siot_driver_pro/widgets/gps_off_screen.dart';
import '../../widgets/notifi_off_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Timer timer;
  int seconds = 1;
  bool gpsEnabled = true;
  PermissionStatus permission = PermissionStatus.granted;
  PermissionStatus notify = PermissionStatus.granted;
  PermissionStatus background = PermissionStatus.granted;
  BluetoothAdapterState adapterState = BluetoothAdapterState.on;
  late StreamSubscription<BluetoothAdapterState> adapterStateStateSubscription;

  Future<void> checkLocation() async {
    location1.Location location = location1.Location();
    gpsEnabled = await location.serviceEnabled();
    notify = await Permission.notification.status;
    permission = await Permission.location.status;
    if (Platform.isAndroid) {
      background = await Permission.ignoreBatteryOptimizations.status;
    }
    setState(() {});
  }

  @override
  void initState() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (seconds > 0) {
        setState(() {
          seconds--;
        });
      } else {
        checkLocation();
        setState(() {
          seconds = 1;
        });
      }
    });
    adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((
      state,
    ) {
      adapterState = state;
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          adapterState == BluetoothAdapterState.off
              ? BluetoothOffScreen(adapterState: adapterState)
              : (!gpsEnabled || permission == PermissionStatus.denied)
              ? GpsOffScreen(gpsEnabled: gpsEnabled, permission: permission)
              : (notify == PermissionStatus.denied ||
                  background == PermissionStatus.denied)
              ? NotifiOffScreen(notify: notify, background: background)
              : Hive.box('LOGGED_IN_USER').length == 0
              ? LoginPage()
              : HomePage(),
    );
  }
}