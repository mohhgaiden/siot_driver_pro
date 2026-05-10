import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_background_service.dart';import 'package:flutter/foundation.dart';

class BleTaskHandler extends TaskHandler {
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  Future<void> onStart(
    DateTime timestamp,
    SendPort? sendPort,
  ) async {
    // Hard guard — this handler must never run on iOS
    if (!Platform.isAndroid) return;

    try {
      await FlutterBluePlus.startScan();
      _scanSub = FlutterBluePlus.scanResults.listen(
        (results) async {
          try {
            await BleBackgroundService.storeSensorReadings(results);
          } catch (e) {
            debugPrint('BLE STORE ERROR: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('BLE SCAN ERROR: $e');
    }
  }

  @override
  Future<void> onDestroy(
    DateTime timestamp,
    SendPort? sendPort,
  ) async {
    if (!Platform.isAndroid) return;
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