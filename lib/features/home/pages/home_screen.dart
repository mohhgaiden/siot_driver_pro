import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../../../common/load_image.dart';
import '../../../common/popup_window.dart';
import '../../../core/constants/dimens.dart';
import '../../../core/constants/gaps.dart';
import '../../../core/constants/styles.dart';
import '../../../core/utils/notification.dart';
import '../../../main.dart';
import '../widgets/goods_add_menu.dart';
import '../widgets/scan_results.dart';

abstract class _HiveBox {
  static const user = 'LOGGED_IN_USER';
  static const capteurs = 'LIST_CAPTEURS';
  static const sensorRead = 'SENSOR_READ';
  static const sensorRead1 = 'SENSOR_READ1';
  static const alert = 'Alert';
  static const activity = 'ACTIVITY_START_END';
}

const _sensorTypeMap = {
  '1': SensorType.type1,
  '3': SensorType.type3,
  '5': SensorType.type6,
  '6': SensorType.type6,
  '10': SensorType.type10,
};

abstract class _Api {
  static const sensorRead =
      'https://sirius-iot.app/Admin/Mobile/API/SiotDriver2022/Android/sensor_read_all.php';
  //'https://sirius-iot.app/Admin/Mobile/API/SiotDriver2022/Android/sensor_read.php';

  static const activity =
      'https://sirius-iot.app/Admin/Mobile/API/SiotDriver2022/Android/sensor_activity_start_end.php';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ─── Hive boxes ─────────────────────────────────────────────────────────────
  final _userBox = Hive.box(_HiveBox.user);
  final _capteursBox = Hive.box(_HiveBox.capteurs);
  final _sensorReadBox = Hive.box(_HiveBox.sensorRead);
  final _sensorRead1Box = Hive.box(_HiveBox.sensorRead1);
  final _alertBox = Hive.box(_HiveBox.alert);
  final _activityBox = Hive.box(_HiveBox.activity);

  // ─── Cached user data ────────────────────────────────────────────────────────
  Map _user = {};
  String _userId = '';
  final Set<String> _dedupCache = {};

  // ─── State ───────────────────────────────────────────────────────────────────
  final GlobalKey _settingsKey = GlobalKey();
  List<ScanResult> _scanResults = [];
  List<Map<String, dynamic>> _alertCache = [];
  bool _missionStarted = false;

  // ─── Per-device alert tracking ───────────────────────────────────────────────
  final Map<String, DateTime> _lastNotificationPerDevice = {};
  static const _notificationCooldown = Duration(minutes: 1);

  // ─── GPS ─────────────────────────────────────────────────────────────────────
  String _lat = '0', _long = '0', _time = '0', _speed = '0', _dir = '0';

  // ─── Subscriptions & timers ──────────────────────────────────────────────────
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _connectTimer;
  Timer? _refreshTimer;
  Timer? _storeTimer;

  // ─── Sync control ────────────────────────────────────────────────────────────
  DateTime? _lastSyncAttempt;
  //Duration _syncCooldown = Duration(minutes: 30);
  bool _isSyncing = false;

  // ─── Init ────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    startBleService();
    _user = _userBox.getAt(0) as Map;
    _userId = _user['uuid_user'] as String;
    _checkPendingMission();
    _startBluetooth();
    _refreshData();
    _updateLocation();

    _connectTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );

    _applyIntervalTimers();
    _userBox.listenable().addListener(
      _onUserBoxChanged,
    ); // reacts to profile changes
  }

  Future<void> startBleService() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      notificationTitle: 'SIOT Driver',
      notificationText: 'Scanning BLE devices...',
      callback: startCallback,
    );
  }

  void _onUserBoxChanged() {
    if (_userBox.isEmpty) return;
    final updated = _userBox.getAt(0) as Map;

    final oldAffichage = _user['interval_affichage']?.toString();
    final oldStockage = _user['interval_stockage']?.toString();

    final newAffichage = updated['interval_affichage']?.toString();
    final newStockage = updated['interval_stockage']?.toString();

    _user = updated;
    // always keep _user fresh (sync interval is read dynamically)

    if (oldAffichage != newAffichage || oldStockage != newStockage) {
      debugPrint('⚙️ Intervals changed — restarting timers');
      _applyIntervalTimers();
    }
  }

  void _applyIntervalTimers() {
    _refreshTimer?.cancel();
    _storeTimer?.cancel();

    final refreshInterval =
        int.tryParse(_user['interval_affichage']?.toString() ?? '5') ?? 5;
    final storeInterval =
        int.tryParse(_user['interval_stockage']?.toString() ?? '5') ??
        5; // ← fixed key

    _refreshTimer = Timer.periodic(Duration(minutes: refreshInterval), (_) {
      _updateLocation();
      _refreshData();
    });
    _storeTimer = Timer.periodic(
      Duration(minutes: storeInterval),
      (_) => _storeSensorReadings(_scanResults),
    );

    debugPrint(
      '⏱ Timers set — refresh: ${refreshInterval}min | store: ${storeInterval}min',
    );
  }

  @override
  void dispose() {
    _userBox.listenable().removeListener(_onUserBoxChanged);
    _scanSub?.cancel();
    _connectTimer?.cancel();
    _refreshTimer?.cancel();
    _storeTimer?.cancel();
    super.dispose();
  }

  // ─── Bluetooth ───────────────────────────────────────────────────────────────

  void _startBluetooth() {
    DateTime lastUiUpdate = DateTime.now();

    FlutterBluePlus.startScan();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final now = DateTime.now();

      // 🔥 Only update UI every 1 second
      if (now.difference(lastUiUpdate).inMilliseconds < 1000) {
        _checkAlertsRealTime(results); // keep alerts realtime
        return;
      }

      lastUiUpdate = now;

      if (mounted) {
        setState(() => _scanResults = results);
      }

      _checkAlertsRealTime(results);
    });
    /*
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() => _scanResults = results);
        _checkAlertsRealTime(results);
      }
    });*/
  }

  void _restartBluetooth() {
    _scanSub?.cancel();
    _startBluetooth();
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _updateLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _lat = pos.latitude.toString();
          _long = pos.longitude.toString();
          _time = pos.timestamp.millisecondsSinceEpoch.toString();
          _speed = pos.speed.toString();
          _dir = pos.heading.toString();
        });
      }
    } catch (_) {}
  }

  // ─── Data refresh ─────────────────────────────────────────────────────────────

  void _refreshData() {
    // ✅ Safe Hive map reading — no .cast()
    final sensorData = <Map<String, dynamic>>[];
    for (final key in _sensorRead1Box.keys) {
      final item = _sensorRead1Box.get(key);
      if (item == null) continue;
      sensorData.add({
        'key': key,
        'uuid_user': item['uuid_user'],
        'MacAddrs': item['MacAddrs'],
        'temperature': item['temperature'],
        'humidity': item['humidity'],
        'presure': item['presure'],
        'InfoDate': item['InfoDate'],
      });
    }

    final alertData = <Map<String, dynamic>>[];
    for (final key in _alertBox.keys) {
      final item = _alertBox.get(key);
      if (item == null) continue;
      alertData.add({
        'key': key,
        'uuid_user': item['uuid_user'],
        'MacAddrs': item['MacAddrs'],
        'checkedtemperature': item['checkedtemperature'],
        'lowtemperature': item['lowtemperature'],
        'hightemperature': item['hightemperature'],
        'checkedhumidity': item['checkedhumidity'],
        'lowhumidity': item['lowhumidity'],
        'highhumidity': item['highhumidity'],
        'checkedpresure': item['checkedpresure'],
        'lowpresure': item['lowpresure'],
        'highpresure': item['highpresure'],
        'checkedsignal_strength': item['checkedsignal_strength'],
        'lowsignal_strength': item['lowsignal_strength'],
        'highsignal_strength': item['highsignal_strength'],
        'checkedluminosite': item['checkedluminosite'],
        'lowluminosite': item['lowluminosite'],
        'highluminosite': item['highluminosite'],
      });
    }

    if (mounted) {
      setState(() {
        _alertCache = alertData;
      });
    }
  }

  // ─── Real-time alert checking ─────────────────────────────────────────────────

  Future<void> _checkAlertsRealTime(List<ScanResult> scans) async {
    final now = DateTime.now();

    for (final result in scans) {
      final mac = result.device.remoteId.str;

      for (int j = 0; j < _capteursBox.length; j++) {
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;

        final capteurMac = raw['MacAddrs']?.toString() ?? '';
        if (capteurMac != mac) continue;

        final typeStr = raw['Type']?.toString() ?? '';
        final sensorName = raw['Name']?.toString() ?? '';
        final sensorType = _sensorTypeMap[typeStr];
        if (sensorType == null) continue;

        final reading = sensorType.tryParse(
          result.advertisementData,
          deviceType: typeStr,
        );
        if (reading == null) continue;

        final triggered = _isAnyAlertTriggered(mac, reading, result.rssi);

        // ✅ Only care about triggered — ignore cleared state
        if (!triggered) continue;

        final lastNotif = _lastNotificationPerDevice[mac];
        final cooldownPassed =
            lastNotif == null ||
            now.difference(lastNotif) >= _notificationCooldown;

        if (cooldownPassed) {
          NotificationService.showSimpleNotification(
            int.tryParse(typeStr) ?? 1,
            'SIOT Driver',
            "Problèmes dans le capteur '$sensorName'.",
          );
          _lastNotificationPerDevice[mac] = now;
          debugPrint('🔔 Alert sent for $sensorName ($mac) at $now');
        }
      }
    }
  }

  // ─── Alert checking ───────────────────────────────────────────────────────────

  bool _isAnyAlertTriggered(String mac, SensorReading reading, int rssi) {
    final alertData =
        _alertCache.where((a) => a['MacAddrs'] == mac).firstOrNull;
    if (alertData == null) return false;

    bool check(String checkedKey, String lowKey, String highKey, double value) {
      if (alertData[checkedKey] != '1') return false;
      final low = (alertData[lowKey] as num).toDouble();
      final high = (alertData[highKey] as num).toDouble();
      return value < low || value > high;
    }

    final tempTriggered = check(
      'checkedtemperature',
      'lowtemperature',
      'hightemperature',
      reading.temperature,
    );
    final humTriggered =
        reading.humidity != null &&
        check(
          'checkedhumidity',
          'lowhumidity',
          'highhumidity',
          reading.humidity!,
        );
    final pressTriggered =
        reading.pressure != null &&
        check('checkedpresure', 'lowpresure', 'highpresure', reading.pressure!);
    final lightTriggered =
        reading.luminosity != null &&
        check(
          'checkedluminosite',
          'lowluminosite',
          'highluminosite',
          reading.luminosity!,
        );
    final signalTriggered = check(
      'checkedsignal_strength',
      'lowsignal_strength',
      'highsignal_strength',
      rssi.toDouble(),
    );

    return tempTriggered ||
        humTriggered ||
        pressTriggered ||
        lightTriggered ||
        signalTriggered;
  }

  // ─── Sensor data storage ──────────────────────────────────────────────────────

  Future<void> _storeSensorReadings(List<ScanResult> scans) async {
    for (final result in scans) {
      final mac = result.device.remoteId.str;
      final timestamp = result.timeStamp.millisecondsSinceEpoch;

      // 🔥 UNIQUE KEY
      final uniqueKey = '$mac-$timestamp';

      // ❌ Skip duplicate
      if (_dedupCache.contains(uniqueKey)) continue;

      for (int j = 0; j < _capteursBox.length; j++) {
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;

        final capteurMac = raw['MacAddrs']?.toString() ?? '';
        if (capteurMac != mac) continue;

        final typeStr = raw['Type']?.toString() ?? '';
        final sensorType = _sensorTypeMap[typeStr];
        if (sensorType == null) continue;

        final reading = sensorType.tryParse(
          result.advertisementData,
          deviceType: typeStr,
        );
        if (reading == null) continue;

        // ✅ ADD TO CACHE FIRST
        _dedupCache.add(uniqueKey);

        // 🔥 OPTIONAL: prevent duplicates after app restart
        final exists = _sensorRead1Box.values.any(
          (e) => e['MacAddrs'] == mac && e['InfoDate'] == timestamp,
        );

        if (exists) continue;

        await _sensorReadBox.add({
          'uuid_user': _userId,
          'MacAddrs': mac,
          'temperature': reading.temperature.toStringAsFixed(2),
          'humidity': reading.humidity?.toStringAsFixed(2) ?? '',
          'luminosite': reading.luminosity?.toStringAsFixed(2) ?? '',
          'presure': reading.pressure?.toStringAsFixed(2) ?? '',
          'lowsignal_strength': result.rssi.toString(),
          'InfoDate': timestamp.toString(),
          'gps_lat': _lat,
          'gps_long': _long,
          'gps_time': _time,
          'gps_speed': _speed,
          'gps_direction': _dir,
          'battery_level': reading.voltage?.toStringAsFixed(2) ?? '',
        });

        await _sensorRead1Box.add({
          'uuid_user': _userId,
          'MacAddrs': mac,
          'temperature': reading.temperature,
          'humidity': reading.humidity,
          'presure': reading.pressure,
          'InfoDate': timestamp,
        });
      }
    }

    // 🔥 Prevent memory leak
    if (_dedupCache.length > 5000) {
      _dedupCache.clear();
    }
  }
  /*Future<void> _storeSensorReadings(List<ScanResult> scans) async {
    for (final result in scans) {
      final mac = result.device.remoteId.str;
      final timestamp = result.timeStamp.millisecondsSinceEpoch;

      final uniqueKey = '$mac-$timestamp';
      if (_dedupCache.contains(uniqueKey)) continue;

      for (int j = 0; j < _capteursBox.length; j++) {
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;

        final capteurMac = raw['MacAddrs']?.toString() ?? '';
        if (capteurMac != mac) continue;

        final typeStr = raw['Type']?.toString() ?? '';
        final sensorType = _sensorTypeMap[typeStr];
        if (sensorType == null) continue;

        final existingForDevice =
            _sensorReadCache
                .where((e) => e['uuid_user'] == _userId && e['MacAddrs'] == mac)
                .toList();

        bool isNew;
        if (existingForDevice.isEmpty) {
          isNew = true;
        } else {
          final lastDate = existingForDevice.last['InfoDate'] as int;
          isNew = lastDate < result.timeStamp.millisecondsSinceEpoch;
        }
        if (!isNew) continue;

        final reading = sensorType.tryParse(
          result.advertisementData,
          deviceType: typeStr,
        );
        if (reading == null) continue;

        _dedupCache.add(uniqueKey);

        await _sensorReadBox.add({
          'uuid_user': _userId,
          'MacAddrs': mac,
          'temperature': reading.temperature.toStringAsFixed(2),
          'humidity': reading.humidity?.toStringAsFixed(2) ?? '',
          'luminosite': reading.luminosity?.toStringAsFixed(2) ?? '',
          'presure': reading.pressure?.toStringAsFixed(2) ?? '',
          'lowsignal_strength': result.rssi.toString(),
          'InfoDate': result.timeStamp.millisecondsSinceEpoch.toString(),
          'gps_lat': _lat,
          'gps_long': _long,
          'gps_time': _time,
          'gps_speed': _speed,
          'gps_direction': _dir,
          'battery_level': reading.voltage?.toStringAsFixed(2) ?? '',
        });

        await _sensorRead1Box.add({
          'uuid_user': _userId,
          'MacAddrs': mac,
          'temperature': reading.temperature,
          'humidity': reading.humidity,
          'presure': reading.pressure,
          'InfoDate': result.timeStamp.millisecondsSinceEpoch,
        });
      }
    }
  }*/

  // ─── Connectivity & API sync ──────────────────────────────────────────────────

  Future<void> _checkConnectivity() async {
    final intervalSync =
        int.tryParse(_user['interval_sync']?.toString() ?? '30') ?? 30;

    var syncCooldown = Duration(minutes: intervalSync);
    if (_isSyncing) return;
    if (_lastSyncAttempt != null &&
        DateTime.now().difference(_lastSyncAttempt!) < syncCooldown) {
      return;
    }

    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) return;

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();

    // ✅ Run sync in background — never blocks BLE alerts
    Future(() async {
      try {
        /*if (_sensorReadBox.isNotEmpty) {
          for (int i = 0; i < _sensorReadBox.length; i++) {
            await _syncSensorRead(i);
          }
        }*/
        syncAllSensorReads();
        if (_activityBox.isNotEmpty) {
          for (int i = 0; i < _activityBox.length; i++) {
            await _syncActivity(i);
          }
        }
      } finally {
        _isSyncing = false;
      }
    });
  }

  Future<void> syncAllSensorReads() async {
    try {
      final items = _sensorReadBox.values.toList();
      if (items.isEmpty) return;

      final first = items.first;

      final uuidUser = first['uuid_user']?.toString() ?? '';

      // 🔥 Build records
      final dataList =
          items.map((item) {
            return {
              "MacAddrs": item['MacAddrs']?.toString() ?? '',
              "temperature": item['temperature']?.toString() ?? '',
              "humidity": item['humidity']?.toString() ?? '',
              "luminosite": item['luminosite']?.toString() ?? '',
              "presure": item['presure']?.toString() ?? '',
              "lowsignal_strength":
                  item['lowsignal_strength']?.toString() ?? '',
              "InfoDate": item['InfoDate']?.toString() ?? '',
              "battery_level": item['battery_level']?.toString() ?? '',
            };
          }).toList();

      final body = {
        "uuid_user": uuidUser,
        'gps_lat': _lat.toString(),
        'gps_long': _long.toString(),
        'gps_time': _time.toString(),
        'gps_speed': _speed.toString(),
        'gps_direction': _dir.toString(),

        // 🔥 SAME PATTERN AS PRODUCT API
        'recording_list_json': jsonEncode({"recording_list": dataList}),
      };

      debugPrint('📤 Sending ${dataList.length} records');
      debugPrint('📤 Body: $body'); // ⚠️ NOT jsonEncode

      final response = await http
          .post(
            Uri.parse(_Api.sensorRead),
            body: body, // ✅ IMPORTANT
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        dynamic result;
        try {
          final rawBody = response.body;
          final jsonStart = rawBody.indexOf('{');
          if (jsonStart == -1) {
            debugPrint('❌ No JSON found');
            return;
          }
          result = jsonDecode(rawBody.substring(jsonStart));
        } catch (_) {
          debugPrint('❌ Invalid JSON');
          return;
        }

        if (result['INFOS_REGISTRATION']?['error'] == 'false') {
          await _sensorReadBox.clear();
          debugPrint('✅ All sensor data synced & cleared');
        } else {
          debugPrint('⚠️ Backend error: ${result['INFOS_REGISTRATION']}');
        }
      }
    } on TimeoutException {
      debugPrint('⏱ Timeout — retry later');
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  Future<void> _syncActivity(int i) async {
    try {
      final item = _activityBox.getAt(i);
      if (item == null) return;

      final body = {
        'uuid_user': item['uuid_user']?.toString() ?? '',
        'activity_type': item['activity_type']?.toString() ?? '',
        'activity_date_heur': item['activity_date_heur']?.toString() ?? '',
        'gps_lat': item['gps_lat']?.toString() ?? '',
        'gps_long': item['gps_long']?.toString() ?? '',
        'gps_time': item['gps_time']?.toString() ?? '',
        'gps_speed': item['gps_speed']?.toString() ?? '',
        'gps_direction': item['gps_direction']?.toString() ?? '',
      };

      debugPrint('📤 Sending activity: $body');

      final response = await http
          .post(Uri.parse(_Api.activity), body: body)
          .timeout(const Duration(seconds: 30)); // ✅ 30s for slow PHP

      debugPrint('📥 activity status: ${response.statusCode}');
      debugPrint('📥 activity body: ${response.body}');

      if (response.statusCode == 200) {
        dynamic result;
        try {
          final rawBody = response.body;
          final jsonStart = rawBody.indexOf('{');
          if (jsonStart == -1) {
            debugPrint('❌ No JSON found in response: $rawBody');
            return;
          }
          result = jsonDecode(rawBody.substring(jsonStart));
        } catch (_) {
          debugPrint('❌ activity: invalid JSON — ${response.body}');
          return;
        }

        if (result['ACTIVITY_START_END']?['error'] == 'false') {
          await _activityBox.deleteAt(i);
          debugPrint('✅ Activity synced and deleted at index $i');
        } else {
          debugPrint(
            '⚠️ activity backend error: ${result['ACTIVITY_START_END']}',
          );
        }
      }
    } on TimeoutException {
      debugPrint('⏱ activity timeout — will retry later');
    } catch (e) {
      debugPrint('❌ activity error: $e');
    }
  }

  // ─── Mission helpers ──────────────────────────────────────────────────────────

  Map<String, String> get _gpsPayload => {
    'gps_lat': _lat,
    'gps_long': _long,
    'gps_time': _time,
    'gps_speed': _speed,
    'gps_direction': _dir,
  };

  Future<void> _recordActivity(String type) async {
    await _activityBox.add({
      'uuid_user': _userId,
      'activity_type': type,
      'activity_date_heur': DateTime.now().toString().substring(0, 19),
      ..._gpsPayload,
    });
  }

  void _checkPendingMission() {
    if (_activityBox.isEmpty) return;
    final last = _activityBox.values.last as Map;
    if (last['activity_type'] != '1') return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              content: const Text(
                'Vous avez déjà commencé une mission. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _missionStarted = true);
                    Navigator.pop(context);
                  },
                  child: const Text('Oui'),
                ),
                TextButton(
                  onPressed: () async {
                    await _recordActivity('2');
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Non'),
                ),
              ],
            ),
      );
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: _buildAppBar(),
        body:
            _scanResults.isEmpty
                ? Column(
                  children: [
                    _buildMissionPanel(),
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                )
                : _buildBody(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Color.fromRGBO(62, 127, 214, 1),
      // const Color(0xFF007FFF),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leadingWidth: 160,
      leading: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            width: 36,
            child: Image.asset('assets/images/login/logo_dark.png'),
          ),
          const SizedBox(width: 6),
          const Text(
            'SIOT Driver',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: Dimens.font_sp16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Paramètres',
          key: _settingsKey,
          onPressed: _showSettingsMenu,
          icon: const LoadAssetImage(
            'home/setting.png',
            key: Key('settings'),
            width: 22.0,
            height: 22.0,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ─── Mission control panel ────────────────────────────────────────────────────

  Widget _buildMissionPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A007FFF),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ─ Status indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _missionStarted
                      ? const Color(0xFF22C55E)
                      : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Align(
                key: ValueKey(_missionStarted),
                alignment: Alignment.centerLeft,
                child: Text(
                  _missionStarted ? 'Mission en cours' : 'Aucune mission',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        _missionStarted
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ),
          // ─ Refresh button
          _CircleAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser BLE',
            color: const Color(0xFF007FFF),
            onTap: _restartBluetooth,
          ),
          const SizedBox(width: 8),
          // ─ Start / Stop pill button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder:
                (child, anim) => ScaleTransition(scale: anim, child: child),
            child:
                _missionStarted
                    ? _PillAction(
                      key: const ValueKey('stop'),
                      label: 'Terminer',
                      icon: Icons.stop_rounded,
                      color: const Color(0xFFEF4444),
                      onTap: () async {
                        await _recordActivity('2');
                        setState(() => _missionStarted = false);
                      },
                    )
                    : _PillAction(
                      key: const ValueKey('start'),
                      label: 'Démarrer',
                      icon: Icons.play_arrow_rounded,
                      color: const Color(0xFF007FFF),
                      onTap: () async {
                        await _recordActivity('1');
                        setState(() => _missionStarted = true);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final showAlert = _user['user_can_param'] == '1';
    final showPrint = _user['user_can_print'] == '1';
    final showReport = _user['user_can_report'] == '1';

    final cards = <Widget>[];
    for (final result in _scanResults) {
      final mac = result.device.remoteId.str;
      for (int j = 0; j < _capteursBox.length; j++) {
        // ✅ Safe Hive access — no more 'as Map' cast crash
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;

        final capteurMac = raw['MacAddrs']?.toString() ?? '';
        if (capteurMac != mac) continue;

        final typeStr = raw['Type']?.toString() ?? '';
        final sensorName = raw['Name']?.toString() ?? '';
        final sensorType = _sensorTypeMap[typeStr];
        if (sensorType == null) continue;

        cards.add(
          Padding(
            key: ValueKey('card_${mac}_$typeStr'),
            padding: const EdgeInsets.only(bottom: 10),
            child: ScanResultCard(
              key: ValueKey('scan_${mac}_$typeStr'),
              result: result,
              name: sensorName,
              type: typeStr,
              sensorType: sensorType,
              showAlert: showAlert,
              showPrint: showPrint,
              showReport: showReport,
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        // ─── Mission control panel
        _buildMissionPanel(),
        // ─── Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/home/xdd_n.png',
                    width: 20.0,
                    height: 20.0,
                  ),
                  Gaps.hGap5,
                  const Text('Mes Capteurs', style: TextStyles.textBold18),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDE6FF)),
                ),
                child: Text(
                  '${_capteursBox.length} capteurs',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007FFF),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ─── Sensor cards list
        Expanded(
          child: ListView(
            key: ValueKey(_scanResults.length),
            padding: const EdgeInsets.only(top: 2),
            physics: const BouncingScrollPhysics(),
            children: cards,
          ),
        ),
      ],
    );
  }

  void _showSettingsMenu() {
    final button =
        _settingsKey.currentContext!.findRenderObject()! as RenderBox;
    showPopupWindow<void>(
      context: context,
      isShowBg: true,
      offset: Offset(button.size.width - 8.0, -12.0),
      anchor: button,
      child: const GoodsAddMenu(),
    );
  }
}

// ─── Circular icon button ─────────────────────────────────────────────────────

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ─── Pill action button ───────────────────────────────────────────────────────

class _PillAction extends StatelessWidget {
  const _PillAction({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
