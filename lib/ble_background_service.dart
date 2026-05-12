import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/home/widgets/scan_results.dart';

/// Logique de stockage des lectures BLE — appelée depuis :
///   1. Le foreground service (à chaque batch de scanResults reçu en arrière-plan)
///   2. Le timer UI dans home_screen.dart (tick périodique au premier plan)
///
/// Garantit qu'un capteur n'est enregistré qu'une fois par
/// `interval_stockage` (configuré dans le profil utilisateur, en minutes).
class BleBackgroundService {
  // ── Mapping Type backend → SensorType (dupliqué de home_screen pour
  //    éviter le couplage). À garder synchronisé avec _sensorTypeMap.
  static const _sensorTypeMap = {
    '1': SensorType.type1,
    '3': SensorType.type3,
    '5': SensorType.type6,
    '6': SensorType.type6,
    '10': SensorType.type10,
  };

  /// Cache en mémoire des derniers timestamps écrits par MAC, pour éviter
  /// de re-scanner toute la box `SENSOR_READ` à chaque appel (perf).
  /// Note : chaque isolate (UI / foreground) a son propre cache ; la
  /// cohérence finale est assurée par Hive (qui est partagé).
  static final Map<String, int> _lastWriteMs = {};

  static Future<void> storeSensorReadings(List<ScanResult> scans) async {
    if (scans.isEmpty) return;

    final sensorReadBox = Hive.box('SENSOR_READ');
    final sensorRead1Box = Hive.box('SENSOR_READ1');
    final capteursBox = Hive.box('LIST_CAPTEURS');
    final userBox = Hive.box('LOGGED_IN_USER');

    if (userBox.isEmpty) return;
    final user = userBox.getAt(0);
    if (user == null) return;
    final userId = user['uuid_user'];
    if (userId == null) return;

    // ✅ Intervalle utilisateur, en millisecondes. Default : 1 minute.
    final intervalMin =
        int.tryParse(user['interval_stockage']?.toString() ?? '1') ?? 1;
    final minIntervalMs = intervalMin * 60 * 1000;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final result in scans) {
      final mac = result.device.remoteId.str;

      // 1) Le capteur est-il enregistré pour cet utilisateur ?
      Map? matchedCapteur;
      for (int j = 0; j < capteursBox.length; j++) {
        final raw = capteursBox.getAt(j);
        if (raw == null) continue;
        final capteurMac = (raw['MacAddrs']?.toString() ?? '').trim();
        if (capteurMac.toLowerCase() == mac.toLowerCase()) {
          matchedCapteur = raw as Map;
          break;
        }
      }
      if (matchedCapteur == null) continue;

      final typeStr = matchedCapteur['Type']?.toString() ?? '';
      final sensorType = _sensorTypeMap[typeStr];
      if (sensorType == null) continue;

      // 2) Le delta depuis la dernière écriture est-il assez grand ?
      final lastMs = _lastWriteMs[mac.toLowerCase()] ??
          _lastTimestampFromHive(sensorReadBox, userId, mac);
      if (lastMs != null && (nowMs - lastMs) < minIntervalMs) continue;

      // 3) Parser les valeurs (température, etc.)
      final reading = sensorType.tryParse(
        result.advertisementData,
        deviceType: typeStr,
      );
      if (reading == null) continue;

      // 4) Écrire les deux boxes
      await sensorReadBox.add({
        'uuid_user': userId,
        'MacAddrs': mac,
        'temperature': reading.temperature.toStringAsFixed(2),
        'humidity': reading.humidity?.toStringAsFixed(2) ?? '',
        'luminosite': reading.luminosity?.toStringAsFixed(2) ?? '',
        'presure': reading.pressure?.toStringAsFixed(2) ?? '',
        'lowsignal_strength': result.rssi.toString(),
        'InfoDate': nowMs.toString(),
        'battery_level': reading.voltage?.toStringAsFixed(2) ?? '',
      });

      await sensorRead1Box.add({
        'uuid_user': userId,
        'MacAddrs': mac,
        'temperature': reading.temperature,
        'humidity': reading.humidity,
        'presure': reading.pressure,
        'InfoDate': nowMs,
      });

      _lastWriteMs[mac.toLowerCase()] = nowMs;
      debugPrint(
        '💾 BleBgService: ${matchedCapteur['Name']} ($mac) '
        'temp=${reading.temperature.toStringAsFixed(2)}°C',
      );
    }
  }

  /// Cherche le dernier `InfoDate` enregistré pour cette MAC dans Hive.
  /// Utilisé uniquement la première fois (puis le cache mémoire prend le relais).
  static int? _lastTimestampFromHive(
    Box sensorReadBox,
    dynamic userId,
    String mac,
  ) {
    int? last;
    for (final item in sensorReadBox.values) {
      if (item['uuid_user'] != userId) continue;
      if (item['MacAddrs'] != mac) continue;
      final raw = item['InfoDate'];
      final ts = raw is int ? raw : int.tryParse(raw?.toString() ?? '0') ?? 0;
      if (last == null || ts > last) last = ts;
    }
    if (last != null) _lastWriteMs[mac.toLowerCase()] = last;
    return last;
  }
}
