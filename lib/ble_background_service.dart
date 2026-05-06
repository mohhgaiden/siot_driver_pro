import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BleBackgroundService {
  static Future<void> storeSensorReadings(List<ScanResult> scans) async {
    final sensorReadBox = Hive.box('SENSOR_READ');
    final sensorRead1Box = Hive.box('SENSOR_READ1');
    final capteursBox = Hive.box('LIST_CAPTEURS');
    final userBox = Hive.box('LOGGED_IN_USER');

    final user = userBox.getAt(0);
    final userId = user['uuid_user'];

    const minInterval = 10000;

    for (final result in scans) {
      final mac = result.device.remoteId.str;
      final currentTs = result.timeStamp.millisecondsSinceEpoch;

      for (int j = 0; j < capteursBox.length; j++) {
        final raw = capteursBox.getAt(j);
        if (raw == null) continue;

        if (raw['MacAddrs'] != mac) continue;

        int? lastTimestamp;

        for (final item in sensorReadBox.values) {
          if (item['uuid_user'] == userId && item['MacAddrs'] == mac) {
            final rawTs = item['InfoDate'];
            final ts =
                rawTs is int ? rawTs : int.tryParse(rawTs.toString()) ?? 0;
            if (lastTimestamp == null || ts > lastTimestamp) {
              lastTimestamp = ts;
            }
          }
        }

        final isNew =
            lastTimestamp == null || (currentTs - lastTimestamp) > minInterval;

        if (!isNew) continue;

        // ⚠️ you must parse reading again here (same logic)
        // Simplified example:
        await sensorReadBox.add({
          'uuid_user': userId,
          'MacAddrs': mac,
          'InfoDate': currentTs,
          'lowsignal_strength': result.rssi.toString(),
          'is_synced': false,
        });

        await sensorRead1Box.add({
          'uuid_user': userId,
          'MacAddrs': mac,
          'InfoDate': currentTs,
        });
      }
    }
  }
}
