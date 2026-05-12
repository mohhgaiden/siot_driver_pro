import 'dart:async';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ble_background_service.dart';

class BleTaskHandler extends TaskHandler {
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    await _initHive();

    FlutterBluePlus.startScan();

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      // 🚀 THIS IS YOUR BACKGROUND LOGIC
      await BleBackgroundService.storeSensorReadings(results);
    });
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    _scanSub?.cancel();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {}

  Future<void> _initHive() async {
    await Hive.initFlutter();

    await Hive.openBox('LOGGED_IN_USER');
    await Hive.openBox('LIST_CAPTEURS');
    await Hive.openBox('SENSOR_READ');
    await Hive.openBox('SENSOR_READ1');
  }
}
