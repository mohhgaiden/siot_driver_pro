import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_background_service.dart';

class BleTaskHandler extends TaskHandler {
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  Future<void> onStart(
    DateTime timestamp,
    SendPort? sendPort,
  ) async {
    // ✅ NEVER RUN ON IOS
    if (!Platform.isAndroid) return;

    try {
      // Start BLE scanning
      await FlutterBluePlus.startScan();

      _scanSub = FlutterBluePlus.scanResults.listen(
        (results) async {
          try {
            await BleBackgroundService.storeSensorReadings(results);
          } catch (e) {
            print('BLE STORE ERROR: $e');
          }
        },
      );
    } catch (e) {
      print('BLE SCAN ERROR: $e');
    }
  }

  @override
  Future<void> onDestroy(
    DateTime timestamp,
    SendPort? sendPort,
  ) async {
    await _scanSub?.cancel();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  @override
  void onRepeatEvent(
    DateTime timestamp,
    SendPort? sendPort,
  ) {}
}