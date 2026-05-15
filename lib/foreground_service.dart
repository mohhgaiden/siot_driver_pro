/*
import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ble_background_service.dart';

class BleTaskHandler extends TaskHandler {
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _initHive();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 0));

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      await BleBackgroundService.storeSensorReadings(results);
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _scanSub?.cancel();

    await FlutterBluePlus.stopScan();
  }

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationDismissed() {}

  Future<void> _initHive() async {
    await Hive.initFlutter();

    await Hive.openBox('LOGGED_IN_USER');
    await Hive.openBox('LIST_CAPTEURS');
    await Hive.openBox('SENSOR_READ');
    await Hive.openBox('SENSOR_READ1');
  }
}
*/

import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ble_background_service.dart';

class BleTaskHandler extends TaskHandler {
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _initHive();

    // ==========================================
    // START BLE SCAN
    // ==========================================

    await FlutterBluePlus.startScan(timeout: const Duration(minutes: 30));

    // ==========================================
    // LISTENER
    // ==========================================

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        print('==========================');
        print('DEVICE: ${r.device.platformName}');
        print('RSSI: ${r.rssi}');
        print('ADV NAME: ${r.advertisementData.advName}');
        print('SERVICE DATA: ${r.advertisementData.serviceData}');
        print('MANUFACTURER DATA: ${r.advertisementData.manufacturerData}');
        print('SERVICE UUIDS: ${r.advertisementData.serviceUuids}');
        print('==========================');
      }

      await BleBackgroundService.storeSensorReadings(results);
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _scanSub?.cancel();

    await FlutterBluePlus.stopScan();
  }

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationDismissed() {}

  Future<void> _initHive() async {
    await Hive.initFlutter();

    await Hive.openBox('LOGGED_IN_USER');
    await Hive.openBox('LIST_CAPTEURS');
    await Hive.openBox('SENSOR_READ');
    await Hive.openBox('SENSOR_READ1');
  }
}
