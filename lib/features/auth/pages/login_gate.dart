import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as location1;
import 'package:siot_driver_pro/features/home/pages/home_screen.dart';
import 'package:siot_driver_pro/features/auth/pages/login_screen.dart';
import 'package:siot_driver_pro/common/bluetooth_off_screen.dart';
import 'package:siot_driver_pro/common/gps_off_screen.dart';
import '../../../common/notifi_off_screen.dart';
import '../../../main.dart';

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

  // ── NEW: tracks whether we've shown the disclosure this install ──
  bool _disclosureShown = false;

  // ─────────────────────────────────────────────────────────────────
  // Show the prominent disclosure dialog ONCE, then request perms
  // ─────────────────────────────────────────────────────────────────
  Future<void> _showDisclosureIfNeeded() async {
    final box = Hive.box('APP_SETTINGS');
    final alreadyShown = box.get(
      'location_disclosure_shown',
      defaultValue: false,
    );

    if (alreadyShown) {
      setState(() => _disclosureShown = true);
      await _requestPermissions();
      return;
    }

    // Show the dialog and wait for user to tap Continue
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false, // user must tap the button
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Accès à la localisation requis',
                textAlign: TextAlign.center,
              ),
              content: const SingleChildScrollView(
                child: Text(
                  'SiOT Driver a besoin d\'accéder à votre localisation — y compris en arrière-plan — '
                  'pour détecter les appareils Bluetooth installés dans votre véhicule.\n'
                  'Cela est nécessaire pour :\n'
                  '  • Détecter votre véhicule automatiquement\n'
                  '  • Enregistrer les sessions conducteur pendant votre service\n'
                  '  • Synchroniser les données de trajet même lorsque l\'application est réduite\n'
                  'Une notification sera toujours visible pendant que l\'analyse est active. '
                  'Les données de localisation sont uniquement utilisées pour la détection du véhicule '
                  'et ne sont jamais partagées avec des tiers sans votre consentement.',
                  style: TextStyle(height: 1.5),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Je comprends — Continuer'),
                ),
              ],
            ),
      );
    }

    // Mark as shown so it never appears again
    await box.put('location_disclosure_shown', true);
    setState(() => _disclosureShown = true);

    // Now request the actual permissions
    await _requestPermissions();
  }

  // ─────────────────────────────────────────────────────────────────
  // Request all required permissions AFTER disclosure is accepted
  // ─────────────────────────────────────────────────────────────────
  Future<void> _requestPermissions() async {
    // 1. Bluetooth permissions
    await [Permission.bluetoothScan, Permission.bluetoothConnect].request();

    // 2. Fine location (must be granted before background can be asked)
    await Permission.location.request();

    // 3. Background location (Android shows its own system dialog here)
    await Permission.locationAlways.request();

    // 4. Notification + battery (ignoreBatteryOptimizations is Android-only)
    await Permission.notification.request();
    if (Platform.isAndroid) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // 5. AFTER permissions → start foreground service (Android only)
    if (Platform.isAndroid && !(await FlutterForegroundTask.isRunningService)) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'SIOT Driver',
        notificationText: 'Running in background...',
        callback: startCallback,
      );
    }
    // 5. Now read actual statuses
    await checkLocation();
  }

  // ─────────────────────────────────────────────────────────────────
  // Called on every timer tick AFTER disclosure is done
  // ─────────────────────────────────────────────────────────────────
  Future<void> checkLocation() async {
    location1.Location location = location1.Location();
    gpsEnabled = await location.serviceEnabled();
    notify = await Permission.notification.status;
    permission = await Permission.location.status;
    background = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.status
        : PermissionStatus.granted;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // Show disclosure + request permissions on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclosureIfNeeded();
    });

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_disclosureShown) return; // don't poll until disclosure is done
      if (seconds > 0) {
        setState(() => seconds--);
      } else {
        checkLocation();
        setState(() => seconds = 1);
      }
    });

    adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((
      state,
    ) {
      adapterState = state;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    adapterStateStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // While disclosure hasn't been accepted yet, show a blank loading screen
    if (!_disclosureShown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body:
          adapterState != BluetoothAdapterState.on
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
