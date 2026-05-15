import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../common/load_image.dart';
import '../../../common/popup_window.dart';
import '../../../core/constants/dimens.dart';
import '../../../core/constants/gaps.dart';
import '../../../core/constants/styles.dart';
import '../../../core/services/capteur_sync.dart';
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

// ─── Tri d'affichage des capteurs ─────────────────────────────────────────────

/// Modes de tri proposés à l'utilisateur dans la liste "Mes Capteurs".
enum _SensorSort {
  nameAsc('Nom (A → Z)', Icons.arrow_downward_rounded),
  nameDesc('Nom (Z → A)', Icons.arrow_upward_rounded),
  proximity('Proximité', Icons.signal_cellular_alt_rounded),
  lastSeen('Dernière lecture', Icons.access_time_rounded);

  const _SensorSort(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Tuple temporaire utilisé pour trier la liste des capteurs avant rendu.
class _SensorEntry {
  _SensorEntry({
    required this.result,
    required this.name,
    required this.type,
    required this.sensorType,
  });
  final ScanResult result;
  final String name;
  final String type;
  final SensorType sensorType;
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
  // Dernier timestamp d'écriture par MAC (clé en lower-case),
  // pour respecter interval_stockage entre deux écritures.
  final Map<String, int> _lastWriteMs = {};

  // ─── State ───────────────────────────────────────────────────────────────────
  final GlobalKey _settingsKey = GlobalKey();
  List<ScanResult> _scanResults = [];
  List<Map<String, dynamic>> _alertCache = [];
  bool _missionStarted = false;
  // Tri d'affichage des capteurs (persisté dans `_userBox` sous `sort_mode`).
  _SensorSort _sortMode = _SensorSort.nameAsc;

  // ─── iOS UUID → MAC mapping (Type 3 sensors have no MAC in adv data) ────────
  final Map<String, String> _iosUuidToMacCache = {};

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
    if (Platform.isIOS) _loadIosUuidMap();
    startBleService();
    _user = _userBox.getAt(0) as Map;
    _userId = _user['uuid_user'] as String;
    // Charge le tri d'affichage sauvegardé (ex. "nameDesc"). Si la valeur
    // n'existe pas ou est invalide, on garde le défaut (nameAsc).
    final savedSort = _user['sort_mode']?.toString();
    if (savedSort != null) {
      _sortMode = _SensorSort.values.firstWhere(
        (s) => s.name == savedSort,
        orElse: () => _SensorSort.nameAsc,
      );
    }
    _checkPendingMission();
    _startBluetooth();
    _refreshData();
    _updateLocation();

    // ✅ Re-sync de la liste des capteurs à chaque ouverture de l'app
    // (cas auto-login : on saute LoginPage donc _listCapteur n'est pas appelé)
    _syncCapteurs();

    _connectTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );

    _applyIntervalTimers();
    _userBox.listenable().addListener(
      _onUserBoxChanged,
    ); // reacts to profile changes
  }

  Future<void> _syncCapteurs() async {
    await CapteurSync.sync(_userId);
    // Après la sync, on rafraîchit l'UI avec les nouvelles alertes
    if (mounted) _refreshData();
  }

  Future<void> startBleService() async {
    if (!Platform.isAndroid) return;
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

  /// Décode `interval_affichage` (clé Hive) en `Duration`.
  ///
  /// Nouveau format : valeur stockée en **secondes** (ex. "60", "300").
  /// Ancien format (legacy) : valeur stockée en **minutes** (ex. "5").
  /// Pour rester compatible, toute valeur `< 30` est traitée comme du legacy
  /// (multiplication par 60). 30 est le minimum proposé dans le picker.
  /// Défaut : 60 s (= 1 minute).
  static Duration _decodeAffichage(String? raw) {
    final n = int.tryParse(raw ?? '') ?? 60;
    return n < 30 ? Duration(minutes: n) : Duration(seconds: n);
  }

  void _applyIntervalTimers() {
    _refreshTimer?.cancel();
    _storeTimer?.cancel();

    final refresh = _decodeAffichage(_user['interval_affichage']?.toString());
    final storeInterval =
        int.tryParse(_user['interval_stockage']?.toString() ?? '5') ??
        5; // ← fixed key

    _refreshTimer = Timer.periodic(refresh, (_) {
      _updateLocation();
      _refreshData();
    });
    // ✅ Tick toutes les 30 s — la décision d'écrire ou non se fait
    // dans _storeSensorReadings selon interval_stockage (cache _lastWriteMs).
    _storeTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _storeSensorReadings(_scanResults),
    );
    debugPrint('⏱ Store timer = 30 s tick, '
        'interval_stockage utilisateur = $storeInterval min');

    debugPrint(
      '⏱ Timers set — refresh: ${refresh.inSeconds}s | store: ${storeInterval}min',
    );
  }

  @override
  void dispose() {
    _userBox.listenable().removeListener(_onUserBoxChanged);
    _scanSub?.cancel();
    _connectTimer?.cancel();
    _refreshTimer?.cancel();
    _storeTimer?.cancel();
    _scanWatchdog?.cancel();
    _scanRestartTimer?.cancel();
    super.dispose();
  }

  // ─── iOS MAC resolution ──────────────────────────────────────────────────────

  // On iOS, CoreBluetooth exposes a UUID instead of the Bluetooth MAC address.
  // We try multiple strategies to recover the real MAC so sensor matching
  // against LIST_CAPTEURS (which stores MACs) still works.

  static String _bytesToMac(List<int> b) =>
      b.map((v) => v.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');

  static bool _looksLikeMac(String s) =>
      RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(s);

  static String? _extractMacFromAdv(AdvertisementData adv) {
    // Type 1 – Ruuvi RAWv2 v5 (company 0x0499 = 1177)
    final d1 = adv.manufacturerData[1177];
    if (d1 != null && d1.length >= 24) {
      return _bytesToMac(d1.sublist(18, 24));
    }
    // Type 10 (company 0x0CCE = 3278)
    final d10 = adv.manufacturerData[3278];
    if (d10 != null && d10.length >= 6) {
      return _bytesToMac(d10.sublist(0, 6));
    }
    // Type 6 (company 0xFFFF = 65535)
    final d6 = adv.manufacturerData[65535];
    if (d6 != null && d6.length >= 6) {
      return _bytesToMac(d6.sublist(0, 6));
    }
    return null;
  }

  // ─── iOS UUID → MAC helpers ──────────────────────────────────────────────────

  void _loadIosUuidMap() {
    final box = Hive.box('IOS_UUID_MAC');
    for (final key in box.keys) {
      final mac = box.get(key)?.toString();
      if (mac != null) _iosUuidToMacCache[key.toString()] = mac;
    }
    debugPrint('🍎 iOS UUID map loaded: ${_iosUuidToMacCache.length} entries');
  }

  void _saveIosUuidMapping(String uuid, String mac) {
    _iosUuidToMacCache[uuid] = mac;
    Hive.box('IOS_UUID_MAC').put(uuid, mac);
    debugPrint('🍎 iOS UUID→MAC saved: $uuid → $mac');
  }

  /// Returns the set of all MACs registered in LIST_CAPTEURS (lowercase, trimmed).
  Set<String> _knownMacsLower() {
    final macs = <String>{};
    for (int j = 0; j < _capteursBox.length; j++) {
      final raw = _capteursBox.getAt(j);
      if (raw == null) continue;
      final mac = (raw['MacAddrs']?.toString() ?? '').trim().toLowerCase();
      if (_looksLikeMac(mac)) macs.add(mac);
    }
    return macs;
  }

  /// For Type 3 (service UUID 2a6e) when no MAC is in manufacturer data:
  /// if exactly one Type 3 capteur is registered and not yet mapped,
  /// auto-map the CoreBluetooth UUID to it.
  String? _tryAutoMapByServiceUuid(String uuid, AdvertisementData adv) {
    // Accept match from serviceData keys OR serviceUuids list
    final has2a6e =
        adv.serviceData.keys
            .any((k) => k.toString().toLowerCase().contains('2a6e')) ||
        adv.serviceUuids
            .any((u) => u.toString().toLowerCase().contains('2a6e'));
    if (!has2a6e) return null;

    final mappedMacs = _iosUuidToMacCache.values.toSet();
    final candidates = <String>[];
    for (int j = 0; j < _capteursBox.length; j++) {
      final raw = _capteursBox.getAt(j);
      if (raw == null) continue;
      if ((raw['Type']?.toString() ?? '') != '3') continue;
      final mac = (raw['MacAddrs']?.toString() ?? '').trim();
      if (mac.isEmpty || mappedMacs.contains(mac)) continue;
      candidates.add(mac);
    }

    if (candidates.length != 1) return null;
    _saveIosUuidMapping(uuid, candidates.first);
    return candidates.first;
  }

  // Returns the effective MAC to use for LIST_CAPTEURS matching.
  String _resolveDeviceMac(ScanResult result) {
    if (!Platform.isIOS) return result.device.remoteId.str;

    final uuid = result.device.remoteId.str;

    // 1. Persistent mapping (fastest path after first resolution)
    if (_iosUuidToMacCache.containsKey(uuid)) {
      return _iosUuidToMacCache[uuid]!;
    }

    // 2. Known manufacturer data layouts (Type 1 / 6 / 10)
    final extracted = _extractMacFromAdv(result.advertisementData);
    if (extracted != null) {
      debugPrint('🍎 iOS known-layout MAC: $extracted (UUID: $uuid)');
      _saveIosUuidMapping(uuid, extracted);
      return extracted;
    }

    // 3. Generic scan: slide a 6-byte window over every manufacturer data
    //    entry and check if any window matches a registered capteur MAC.
    final knownMacs = _knownMacsLower();
    for (final entry in result.advertisementData.manufacturerData.entries) {
      final bytes = entry.value;
      for (int offset = 0; offset + 6 <= bytes.length; offset++) {
        final candidate =
            _bytesToMac(bytes.sublist(offset, offset + 6)).toLowerCase();
        if (knownMacs.contains(candidate)) {
          final mac = candidate.toUpperCase();
          debugPrint(
            '🍎 iOS generic MAC at mfgId=${entry.key} offset=$offset: $mac',
          );
          _saveIosUuidMapping(uuid, mac);
          return mac;
        }
      }
    }

    // 4. Service-UUID auto-map for Type 3 (no MAC in advertisement at all)
    final autoMapped = _tryAutoMapByServiceUuid(uuid, result.advertisementData);
    if (autoMapped != null) return autoMapped;

    // Nothing worked — log everything so we can diagnose the sensor format
    debugPrint(
      '🍎 iOS UNRESOLVED UUID: $uuid\n'
      '   name="${result.advertisementData.advName}"\n'
      '   mfg=${result.advertisementData.manufacturerData.entries.map((e) => 'id=${e.key}(0x${e.key.toRadixString(16)}) '
              'hex=${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}').join(' | ')}\n'
      '   svcData=${result.advertisementData.serviceData.keys.toList()}\n'
      '   svcUuids=${result.advertisementData.serviceUuids}',
    );
    return uuid;
  }

  // ─── Bluetooth ───────────────────────────────────────────────────────────────

  // Watchdog & restart périodique du scan BLE
  Timer? _scanWatchdog;
  Timer? _scanRestartTimer;
  DateTime _lastScanRestart = DateTime.now();

  Future<void> _restartScanSafely() async {
    try {
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 200));
      await FlutterBluePlus.startScan();
      _lastScanRestart = DateTime.now();
      debugPrint('🔄 BLE scan restarted at $_lastScanRestart');
    } catch (e) {
      debugPrint('⚠️ Failed to restart BLE scan: $e');
    }
  }

  void _startBluetooth() {
    // ⚠️ `null` au démarrage → le premier scan déclenche systématiquement
    // un `setState` (sinon l'utilisateur attendrait `interval_affichage`
    // avant de voir la moindre valeur).
    DateTime? lastUiUpdate;
    // ⚠️ Set des MAC déjà affichés dans la liste : si un nouveau capteur
    // apparaît à l'intérieur d'une fenêtre de throttle, on bypass le
    // throttle pour qu'il s'affiche immédiatement (sinon il faudrait
    // attendre la fin du cycle pour le voir).
    final knownMacs = <String>{};

    FlutterBluePlus.startScan();
    _lastScanRestart = DateTime.now();

    // 🔁 Watchdog : vérifie toutes les 30 s que le scan tourne, relance sinon
    _scanWatchdog?.cancel();
    _scanWatchdog = Timer.periodic(const Duration(seconds: 30), (_) async {
      final isScanning = FlutterBluePlus.isScanningNow;
      if (!isScanning) {
        debugPrint('⚠️ BLE scan était arrêté, relance');
        await _restartScanSafely();
      }
    });

    // 🔁 Force un redémarrage complet toutes les 5 min — évite la dégradation
    // BLE Android sur scans longs sans filtre.
    _scanRestartTimer?.cancel();
    _scanRestartTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _restartScanSafely(),
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final now = DateTime.now();

      // 🔥 Throttle l'affichage des valeurs capteurs selon l'intervalle
      // défini dans Profil → "Affichage rafraîchissement écran"
      // (clé Hive `interval_affichage`).
      //
      // ⚠️ On lit la valeur dynamiquement à chaque tick : si l'utilisateur
      // modifie le réglage dans le profil, la nouvelle cadence est prise
      // en compte immédiatement (pas besoin de redémarrer l'app).
      //
      // Les alertes (`_checkAlertsRealTime`) sont volontairement appelées
      // hors du throttle pour rester réactives à tout dépassement de seuil.
      var throttle = _decodeAffichage(_user['interval_affichage']?.toString());
      // Plancher de sécurité : minimum 1 seconde, pour éviter de spammer
      // le setState si la valeur n'est pas correctement renseignée.
      if (throttle.inSeconds <= 0) {
        throttle = const Duration(seconds: 1);
      }

      // Détection de nouveaux capteurs (MAC jamais vu dans cette session BLE).
      // Tant qu'un nouveau capteur apparaît, on contourne le throttle pour
      // l'afficher immédiatement.
      final currentMacs = results
          .map((r) => r.device.remoteId.str.toLowerCase())
          .toSet();
      final hasNewDevice =
          currentMacs.any((m) => !knownMacs.contains(m));

      // Premier scan, throttle écoulé, OU nouveau capteur → on rafraîchit.
      // Sinon on garde les anciennes valeurs et on ne traite que les alertes.
      if (lastUiUpdate != null &&
          !hasNewDevice &&
          now.difference(lastUiUpdate!) < throttle) {
        _checkAlertsRealTime(results); // alertes toujours temps réel
        return;
      }

      knownMacs.addAll(currentMacs);
      lastUiUpdate = now;

      // 🔍 DIAGNOSTIC — actif uniquement en mode debug.
      // Imprime tout ce que les capteurs BLE diffusent pour repérer
      // les nouveaux modèles (ex. ELA T-probe).
      // ⚠️ La compilation tree-shake ce bloc en release grâce à `kDebugMode`.
      if (kDebugMode) {
        for (final r in results) {
          final adv = r.advertisementData;
          final name = adv.advName.isNotEmpty
              ? adv.advName
              : r.device.platformName;
          final mfg = adv.manufacturerData.entries
              .map((e) =>
                  'id=${e.key} (0x${e.key.toRadixString(16)}) '
                  'data=${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}')
              .join(' | ');
          final svc = adv.serviceData.entries
              .map((e) =>
                  'uuid=${e.key} '
                  'data=${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}')
              .join(' | ');
          debugPrint(
            '🔎 BLE name="$name" mac=${r.device.remoteId.str} rssi=${r.rssi} '
            'mfg=[$mfg] svc=[$svc]',
          );
        }
      }

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
      final mac = _resolveDeviceMac(result);

      for (int j = 0; j < _capteursBox.length; j++) {
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;

        final capteurMac = (raw['MacAddrs']?.toString() ?? '').trim();
        if (capteurMac.toLowerCase() != mac.toLowerCase()) continue;

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
    if (scans.isEmpty) return;

    // Intervalle utilisateur (en minutes) → ms. Default : 1 min.
    final intervalMin =
        int.tryParse(_user['interval_stockage']?.toString() ?? '1') ?? 1;
    final minIntervalMs = intervalMin * 60 * 1000;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final result in scans) {
      final mac = _resolveDeviceMac(result);
      final macKey = mac.toLowerCase();

      // ✅ Filtre par intervalle utilisateur (clé MAC lowercase)
      final lastMs = _lastWriteMs[macKey];
      if (lastMs != null && (nowMs - lastMs) < minIntervalMs) continue;

      for (int j = 0; j < _capteursBox.length; j++) {
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;

        final capteurMac = (raw['MacAddrs']?.toString() ?? '').trim();
        if (capteurMac.toLowerCase() != macKey) continue;

        final typeStr = raw['Type']?.toString() ?? '';
        final sensorType = _sensorTypeMap[typeStr];
        if (sensorType == null) continue;

        final reading = sensorType.tryParse(
          result.advertisementData,
          deviceType: typeStr,
        );
        if (reading == null) continue;

        await _sensorReadBox.add({
          'uuid_user': _userId,
          'MacAddrs': mac,
          'temperature': reading.temperature.toStringAsFixed(2),
          'humidity': reading.humidity?.toStringAsFixed(2) ?? '',
          'luminosite': reading.luminosity?.toStringAsFixed(2) ?? '',
          'presure': reading.pressure?.toStringAsFixed(2) ?? '',
          'lowsignal_strength': result.rssi.toString(),
          'InfoDate': nowMs.toString(),
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
          'InfoDate': nowMs,
        });

        _lastWriteMs[macKey] = nowMs;
        debugPrint(
          '💾 _storeSensorReadings: ${raw['Name']} ($mac) '
          'temp=${reading.temperature.toStringAsFixed(2)}°C '
          '(intervalle ${intervalMin} min)',
        );
        break; // un capteur correspond, pas besoin de continuer la boucle
      }
    }
  }

  // ─── Connectivity & API sync ──────────────────────────────────────────────────

  Future<bool> _hasInternetAccess() async {
    try {
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkConnectivity() async {
    final intervalSync =
        int.tryParse(_user['interval_sync']?.toString() ?? '30') ?? 30;

    var syncCooldown = Duration(minutes: intervalSync);
    if (_isSyncing) return;
    if (_lastSyncAttempt != null &&
        DateTime.now().difference(_lastSyncAttempt!) < syncCooldown) {
      return;
    }

    final hasInternet = await _hasInternetAccess();
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
          // ⚠️ On itère sur un snapshot des clés pour éviter le décalage
          // d'index quand un item est supprimé en cours de boucle.
          final keys = _activityBox.keys.toList();
          for (final key in keys) {
            await _syncActivityByKey(key);
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

  Future<bool> _syncActivityByKey(dynamic key) async {
    try {
      final item = _activityBox.get(key);
      if (item == null) return false;

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

      debugPrint('📤 Sending activity (key=$key): $body');

      final response = await http
          .post(Uri.parse(_Api.activity), body: body)
          .timeout(const Duration(seconds: 30)); // ✅ 30s for slow PHP

      debugPrint('📥 activity status: ${response.statusCode}');
      debugPrint('📥 activity body: ${response.body}');

      if (response.statusCode != 200) return false;

      dynamic result;
      try {
        final rawBody = response.body;
        final jsonStart = rawBody.indexOf('{');
        if (jsonStart == -1) {
          debugPrint('❌ No JSON found in response: $rawBody');
          return false;
        }
        result = jsonDecode(rawBody.substring(jsonStart));
      } catch (_) {
        debugPrint('❌ activity: invalid JSON — ${response.body}');
        return false;
      }

      if (result['ACTIVITY_START_END']?['error'] == 'false') {
        await _activityBox.delete(key);
        debugPrint('✅ Activity synced and deleted (key=$key)');
        return true;
      }

      debugPrint(
        '⚠️ activity backend error: ${result['ACTIVITY_START_END']}',
      );
      return false;
    } on TimeoutException {
      debugPrint('⏱ activity timeout — will retry later');
      return false;
    } catch (e) {
      debugPrint('❌ activity error: $e');
      return false;
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
    // 1) Toujours sauvegarder localement d'abord (single source of truth).
    final key = await _activityBox.add({
      'uuid_user': _userId,
      'activity_type': type,
      'activity_date_heur': DateTime.now().toString().substring(0, 19),
      ..._gpsPayload,
    });

    // 2) Tentative d'envoi immédiat (best-effort, ne bloque pas l'UI).
    bool sent = false;
    try {
      final hasInternet = await _hasInternetAccess();
      if (hasInternet) {
        sent = await _syncActivityByKey(key);
      } else {
        debugPrint('📴 Pas de connexion — activité mise en file d\'attente');
      }
    } catch (e) {
      debugPrint('⚠️ Envoi immédiat impossible: $e — sera retenté');
    }

    // 3) Feedback utilisateur.
    if (!mounted) return;
    final isStart = type == '1';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor:
              sent ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(
                sent ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sent
                      ? (isStart
                          ? 'Mission démarrée — envoyée au serveur'
                          : 'Mission terminée — envoyée au serveur')
                      : (isStart
                          ? 'Mission démarrée — sera synchronisée dès la connexion'
                          : 'Mission terminée — sera synchronisée dès la connexion'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
  // 🔥 Remove duplicates by MAC / UUID
  final uniqueDevices = <String, ScanResult>{};

  for (final result in _scanResults) {
    final id = Platform.isIOS
        ? result.device.remoteId.str
        : _resolveDeviceMac(result);

    if (!uniqueDevices.containsKey(id)) {
      uniqueDevices[id] = result;
    }
  }

  // 🔥 Convert map to list
  final devices = uniqueDevices.values.toList();

  // 🔥 Sort by nearest signal
  devices.sort((a, b) => b.rssi.compareTo(a.rssi));

  return Column(
    children: [
      // ─────────────────────────────
      // Mission panel
      // ─────────────────────────────
      _buildMissionPanel(),

      // ─────────────────────────────
      // Header
      // ─────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0F5FF),
                border: Border.all(
                  color: const Color(0xFFDDE6FF),
                ),
              ),
              child: Text(
                '${devices.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007FFF),
                ),
              ),
            ),

            const SizedBox(width: 8),

            const Text(
              'Scanned BLE Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            IconButton(
              onPressed: _restartBluetooth,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),

      // ─────────────────────────────
      // Devices list
      // ─────────────────────────────
      Expanded(
        child: RefreshIndicator(
          onRefresh: _onPullToRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final result = devices[index];

              final mac = Platform.isIOS
                  ? result.device.remoteId.str
                  : _resolveDeviceMac(result);

              final advName =
                  result.advertisementData.advName;

              final platformName =
                  result.device.platformName;

              final name = advName.isNotEmpty
                  ? advName
                  : platformName.isNotEmpty
                      ? platformName
                      : 'Unknown Device';

              final serviceUuids = result
                  .advertisementData.serviceUuids;

              final manufacturerData = result
                  .advertisementData.manufacturerData;

              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),

                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF007FFF),
                    child: const Icon(
                      Icons.bluetooth,
                      color: Colors.white,
                    ),
                  ),

                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAC / UUID: $mac',
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          'RSSI: ${result.rssi}',
                          style: TextStyle(
                            fontSize: 12,
                            color: result.rssi > -70
                                ? Colors.green
                                : result.rssi > -90
                                    ? Colors.orange
                                    : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        14,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Divider(),

                          const Text(
                            'Advertisement Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            advName.isEmpty
                                ? 'N/A'
                                : advName,
                          ),

                          const SizedBox(height: 14),

                          const Text(
                            'Platform Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            platformName.isEmpty
                                ? 'N/A'
                                : platformName,
                          ),

                          const SizedBox(height: 14),

                          const Text(
                            'Service UUIDs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            serviceUuids.isEmpty
                                ? 'No services'
                                : serviceUuids.join(', '),
                          ),

                          const SizedBox(height: 14),

                          const Text(
                            'Manufacturer Data',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            manufacturerData.isEmpty
                                ? 'No manufacturer data'
                                : manufacturerData.entries
                                    .map(
                                      (e) =>
                                          'ID ${e.key}: ${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
                                    )
                                    .join('\n'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

  /*Widget _buildBody() {
    final showAlert = _user['user_can_param'] == '1';
    final showPrint = _user['user_can_print'] == '1';
    final showReport = _user['user_can_report'] == '1';

    // 🔍 DIAGNOSTIC — actif uniquement en mode debug.
    // Permet de comprendre pourquoi un capteur ne s'affiche pas (mismatch
    // MAC / Type Hive vs scan BLE). Tree-shaké en release grâce à `kDebugMode`.
    if (kDebugMode) {
      debugPrint('───── _buildBody: ${_scanResults.length} BLE scannés, '
          '${_capteursBox.length} capteurs enregistrés ─────');
      for (int j = 0; j < _capteursBox.length; j++) {
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;
        debugPrint(
          '  📋 Capteur Hive #$j  '
          'MAC="${raw['MacAddrs']}"  '
          'Type="${raw['Type']}"  '
          'Name="${raw['Name']}"',
        );
      }
      for (final result in _scanResults) {
        debugPrint(
          '  📡 Scan vu  MAC="${result.device.remoteId.str}"  '
          'name="${result.advertisementData.advName}"',
        );
      }
    }

    final entries = <_SensorEntry>[];
    final seenKeys = <String>{};
    for (final result in _scanResults) {
      final mac = _resolveDeviceMac(result);
      for (int j = 0; j < _capteursBox.length; j++) {
        // ✅ Safe Hive access — no more 'as Map' cast crash
        final raw = _capteursBox.getAt(j);
        if (raw == null) continue;

        final capteurMac = (raw['MacAddrs']?.toString() ?? '').trim();
        if (capteurMac.toLowerCase() != mac.toLowerCase()) continue;

        final typeStr = raw['Type']?.toString() ?? '';
        final sensorName = raw['Name']?.toString() ?? '';
        final sensorType = _sensorTypeMap[typeStr];
        if (sensorType == null) {
          debugPrint('  ⚠️ MAC $mac matchée mais Type="$typeStr" inconnu — '
              'ajouter dans _sensorTypeMap');
          continue;
        }

        // Clé unique d'affichage : on ne garde qu'une carte par (MAC, Type).
        final dedupKey = '${mac.toLowerCase()}|$typeStr';
        if (!seenKeys.add(dedupKey)) continue; // déjà ajoutée → on saute

        entries.add(_SensorEntry(
          result: result,
          name: sensorName,
          type: typeStr,
          sensorType: sensorType,
        ));
      }
    }

    switch (_sortMode) {
      case _SensorSort.nameAsc:
        entries.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case _SensorSort.nameDesc:
        entries.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case _SensorSort.proximity:
        entries.sort((a, b) => b.result.rssi.compareTo(a.result.rssi));
        break;
      case _SensorSort.lastSeen:
        entries.sort(
          (a, b) => b.result.timeStamp.compareTo(a.result.timeStamp),
        );
        break;
    }

    // 3) Génération des widgets dans l'ordre trié.
    final cards = entries.map((e) {
      final mac = _resolveDeviceMac(e.result);
      return Padding(
        key: ValueKey('card_${mac}_${e.type}'),
        padding: const EdgeInsets.only(bottom: 10),
        child: ScanResultCard(
          key: ValueKey('scan_${mac}_${e.type}'),
          result: e.result,
          name: e.name,
          type: e.type,
          mac: mac,
          sensorType: e.sensorType,
          showAlert: showAlert,
          showPrint: showPrint,
          showReport: showReport,
        ),
      );
    }).toList();

    return Column(
      children: [
        // ─── Mission control panel
        _buildMissionPanel(),
        // ─── Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pastille circulaire avec le nombre de capteurs (remplace
              // l'ancien logo + l'ancien badge "X capteurs" à droite).
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F5FF),
                  border: Border.all(color: const Color(0xFFDDE6FF)),
                ),
                child: Text(
                  '${_capteursBox.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007FFF),
                  ),
                ),
              ),
              Gaps.hGap8,
              const Text('Mes Capteurs', style: TextStyles.textBold18),
              const Spacer(),
              // Chip de tri (cliquable → bottom sheet)
              _SortChip(
                mode: _sortMode,
                onTap: _showSortPicker,
              ),
            ],
          ),
        ),
        // ─── Sensor cards list (avec pull-to-refresh)
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onPullToRefresh,
            color: const Color(0xFF007FFF),
            child: ListView(
              key: ValueKey(_scanResults.length),
              padding: const EdgeInsets.only(top: 2),
              // ⚠️ AlwaysScrollableScrollPhysics est nécessaire pour que le
              // RefreshIndicator se déclenche même quand la liste est trop
              // courte pour scroller.
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: cards,
            ),
          ),
        ),
      ],
    );
  }*/

  Future<void> _onPullToRefresh() async {
    debugPrint('🔄 Pull-to-refresh déclenché');
    _restartBluetooth();
    await Future.wait<void>([
      _updateLocation(),
      Future(() => _refreshData()),
    ]);
    await Future.delayed(const Duration(milliseconds: 600));
    unawaited(_checkConnectivity());
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

  // ─── Tri des capteurs ────────────────────────────────────────────────────────
  void _saveSortMode(_SensorSort mode) {
    setState(() => _sortMode = mode);
    if (_userBox.isEmpty) return;
    final key = _userBox.keys.first;
    final item = _userBox.get(key);
    if (item == null) return;
    final updated = Map<dynamic, dynamic>.from(item as Map);
    updated['sort_mode'] = mode.name;
    _userBox.put(key, updated);
  }

  Future<void> _showSortPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SortPickerSheet(
        current: _sortMode,
        onSelected: (mode) {
          _saveSortMode(mode);
          Navigator.pop(ctx);
        },
      ),
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

// ─── Sort chip + bottom-sheet picker ─────────────────────────────────────────

/// Petite pastille cliquable affichée dans l'en-tête "Mes Capteurs".
/// Affiche le mode de tri courant et ouvre le sélecteur au tap.
class _SortChip extends StatelessWidget {
  const _SortChip({required this.mode, required this.onTap});

  final _SensorSort mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF007FFF);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 13, color: accent),
            const SizedBox(width: 5),
            Text(
              mode.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 14, color: accent),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listant les 4 modes de tri disponibles.
class _SortPickerSheet extends StatelessWidget {
  const _SortPickerSheet({
    required this.current,
    required this.onSelected,
  });

  final _SensorSort current;
  final ValueChanged<_SensorSort> onSelected;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF007FFF);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Trier les capteurs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          // Options
          ..._SensorSort.values.map((s) {
            final selected = s == current;
            return InkWell(
              onTap: () => onSelected(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                color: selected
                    ? accent.withValues(alpha: 0.05)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        s.icon,
                        size: 18,
                        color: selected ? accent : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? accent : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      )
                    else
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
