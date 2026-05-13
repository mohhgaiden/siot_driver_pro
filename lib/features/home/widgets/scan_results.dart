import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:siot_driver_pro/features/alert/pages/alart_screen.dart';
import 'package:siot_driver_pro/features/stats/pages/stats_screen.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/dimens.dart';
import '../../../core/constants/gaps.dart';

// ─── Sensor reading model ─────────────────────────────────────────────────────

class SensorReading {
  const SensorReading({
    required this.temperature,
    this.humidity,
    this.pressure,
    this.voltage,
    this.luminosity,
  });

  final double temperature;
  final double? humidity;
  final double? pressure;
  final double? voltage;
  final double? luminosity;

  factory SensorReading.type1(Uint8List b) {
    final rawTemp = ByteData.sublistView(b, 1, 3).getUint16(0, Endian.big);
    final temperature = _decodeTwosComplement16(rawTemp, scale: 0.005);
    final humidity =
        ByteData.sublistView(b, 3, 5).getUint16(0, Endian.big) / 400;
    final pressure =
        (ByteData.sublistView(b, 5, 7).getUint16(0, Endian.big) + 50000) / 100;
    final rawHH = ByteData.sublistView(
      b,
      13,
      15,
    ).getUint16(0, Endian.big).toRadixString(2).padLeft(16, '0');
    final voltage = (int.parse(rawHH.substring(0, 11), radix: 2) + 1600) / 1000;
    return SensorReading(
      temperature: temperature,
      humidity: humidity,
      pressure: pressure,
      voltage: voltage,
    );
  }

  factory SensorReading.type3(Uint8List b) {
    final rawTemp = ByteData.sublistView(b, 0, 2).getUint16(0, Endian.little);
    return SensorReading(
      temperature: _decodeTwosComplement16(rawTemp, scale: 0.01),
    );
  }

  factory SensorReading.type6(Uint8List b, {required bool includeHumidity}) {
    final rawTemp = ByteData.sublistView(b, 7, 9).getUint16(0, Endian.little);
    final temperature = _decodeTwosComplement16(rawTemp, scale: 0.01);
    final humidity =
        includeHumidity
            ? ByteData.sublistView(b, 9, 11).getUint16(0, Endian.little) * 0.01
            : null;
    final luminosity =
        ByteData.sublistView(b, 11, 13).getUint16(0, Endian.little) * 0.01;
    final voltage =
        ByteData.sublistView(b, 5, 7).getUint16(0, Endian.little) * 0.1;
    return SensorReading(
      temperature: temperature,
      humidity: humidity,
      luminosity: luminosity,
      voltage: voltage,
    );
  }

  factory SensorReading.type10(Uint8List b) {
    final temperature = ((b[14] << 8) | b[15]) / 100.0;
    final humidity = ((b[16] << 8) | b[17]) / 100.0;
    final voltage = ((b[11] << 8) | b[12]) / 1000.0;
    return SensorReading(
      temperature: temperature,
      humidity: humidity,
      voltage: voltage,
    );
  }

  static double _decodeTwosComplement16(int raw, {required double scale}) {
    var bits = raw.toRadixString(2).padLeft(16, '0');
    if (bits.startsWith('1')) {
      bits = bits
          .replaceAll('0', 'X')
          .replaceAll('1', '0')
          .replaceAll('X', '1');
      return (int.parse(bits, radix: 2) + 1) * -1 * scale;
    }
    return int.parse(bits, radix: 2) * scale;
  }
}

// ─── Alert threshold model ────────────────────────────────────────────────────

class _AlertThreshold {
  const _AlertThreshold({
    required this.checked,
    required this.low,
    required this.high,
  });

  final bool checked;
  final double low;
  final double high;

  bool isOutOfRange(double value) => checked && (value < low || value > high);

  static _AlertThreshold from(
    Map<String, dynamic>? data,
    String checkedKey,
    String lowKey,
    String highKey,
  ) {
    if (data == null) {
      return const _AlertThreshold(checked: false, low: 0, high: 0);
    }
    return _AlertThreshold(
      checked: data[checkedKey] == '1',
      low: (data[lowKey] as num).toDouble(),
      high: (data[highKey] as num).toDouble(),
    );
  }
}

// ─── Sensor type enum ─────────────────────────────────────────────────────────

enum SensorType { type1, type3, type6, type10 }

extension SensorTypeX on SensorType {
  /// Recherche tolérante d'une serviceData par UUID court (ex: "2a6e").
  /// flutter_blue_plus peut renvoyer la clé en forme courte ou complète
  /// ("0000-2a6e-..."), majuscule/minuscule, selon la version.
  static List<int>? _findServiceData(AdvertisementData adv, String shortUuid) {
    final target = shortUuid.toLowerCase();
    for (final entry in adv.serviceData.entries) {
      if (entry.key.toString().toLowerCase().contains(target)) {
        return entry.value;
      }
    }
    return null;
  }

  // ✅ Returns null instead of crashing when data is missing
  SensorReading? tryParse(AdvertisementData adv, {String deviceType = ''}) {
    try {
      switch (this) {
        case SensorType.type1:
          final data = adv.manufacturerData[1177];
          if (data == null || data.isEmpty) return null;
          return SensorReading.type1(Uint8List.fromList(data));

        case SensorType.type3:
          // 🔍 DIAGNOSTIC TEMPORAIRE — à retirer ensuite
          if (adv.serviceData.isEmpty) {
            debugPrint('⚠️ type3: serviceData VIDE — '
                'name="${adv.advName}" '
                'mfgKeys=${adv.manufacturerData.keys.toList()}');
          } else {
            debugPrint('🔍 type3: serviceData keys=${adv.serviceData.keys
                    .map((k) => k.toString())
                    .toList()} '
                'name="${adv.advName}"');
          }
          final data = _findServiceData(adv, '2a6e');
          if (data == null || data.isEmpty) return null;
          return SensorReading.type3(Uint8List.fromList(data));

        case SensorType.type6:
          final data = adv.manufacturerData[65535];
          if (data == null || data.isEmpty) return null;
          return SensorReading.type6(
            Uint8List.fromList(data),
            includeHumidity: deviceType == '6',
          );

        case SensorType.type10:
          final data = adv.manufacturerData[3278];
          if (data == null || data.isEmpty) return null;
          return SensorReading.type10(Uint8List.fromList(data));
      }
    } catch (e) {
      debugPrint('SensorReading parse error [$name]: $e');
      return null;
    }
  }
}

// ─── Main unified widget ──────────────────────────────────────────────────────

class ScanResultCard extends StatefulWidget {
  const ScanResultCard({
    super.key,
    required this.name,
    required this.result,
    required this.sensorType,
    required this.type,
    required this.mac,
    this.showAlert = false,
    this.showPrint = false,
    this.showReport = false,
  });

  final ScanResult result;
  final String name;
  final String type;
  final String mac;
  final SensorType sensorType;
  final bool showAlert;
  final bool showPrint;
  final bool showReport;

  @override
  State<ScanResultCard> createState() => _ScanResultCardState();
}

class _ScanResultCardState extends State<ScanResultCard> {
  final _alertBox = Hive.box('Alert');
  final _userBox = Hive.box('LOGGED_IN_USER');
  Timer? _timer;
  Map<String, dynamic>? _alertData;

  String get _mac => widget.mac;
  String get _userId => _userBox.getAt(0)['uuid_user'];

  @override
  void initState() {
    super.initState();
    _loadAlertData();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadAlertData(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ✅ Fix: manually build Map<String, dynamic> — no .cast() on Hive maps
  void _loadAlertData() {
    Map<String, dynamic>? match;

    for (final key in _alertBox.keys) {
      final item = _alertBox.get(key);
      if (item == null) continue;
      if (item['MacAddrs'] == _mac) {
        match = {
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
        };
        break;
      }
    }

    if (mounted && match != _alertData) {
      setState(() => _alertData = match);
    }
  }

  _AlertThreshold _threshold(
    String checkedKey,
    String lowKey,
    String highKey,
  ) => _AlertThreshold.from(_alertData, checkedKey, lowKey, highKey);

  @override
  Widget build(BuildContext context) {
    // ✅ Safe parse — show placeholder if BLE data not ready yet
    final reading = widget.sensorType.tryParse(
      widget.result.advertisementData,
      deviceType: widget.type,
    );

    if (reading == null) return _buildPlaceholder(context);

    final tempAlert = _threshold(
      'checkedtemperature',
      'lowtemperature',
      'hightemperature',
    ).isOutOfRange(reading.temperature);

    final humAlert =
        reading.humidity != null
            ? _threshold(
              'checkedhumidity',
              'lowhumidity',
              'highhumidity',
            ).isOutOfRange(reading.humidity!)
            : false;

    final pressAlert =
        reading.pressure != null
            ? _threshold(
              'checkedpresure',
              'lowpresure',
              'highpresure',
            ).isOutOfRange(reading.pressure!)
            : false;

    final lightAlert =
        reading.luminosity != null
            ? _threshold(
              'checkedluminosite',
              'lowluminosite',
              'highluminosite',
            ).isOutOfRange(reading.luminosity!)
            : false;

    final signalAlert = _threshold(
      'checkedsignal_strength',
      'lowsignal_strength',
      'highsignal_strength',
    ).isOutOfRange(widget.result.rssi.toDouble());

    final labelStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontSize: Dimens.font_sp12);

    return _buildCard(
      context,
      reading: reading,
      labelStyle: labelStyle,
      tempAlert: tempAlert,
      humAlert: humAlert,
      pressAlert: pressAlert,
      lightAlert: lightAlert,
      signalAlert: signalAlert,
    );
  }

  // ─── Placeholder shown while BLE data is not yet available ─────────────────

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: const [
          BoxShadow(
            color: Colours.shadow_blue,
            offset: Offset(0.0, 2.0),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: Colours.app_main.withValues(alpha: 0.4),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _mac,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colours.app_main.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Full card ──────────────────────────────────────────────────────────────

  Widget _buildCard(
    BuildContext context, {
    required SensorReading reading,
    required TextStyle? labelStyle,
    required bool tempAlert,
    required bool humAlert,
    required bool pressAlert,
    required bool lightAlert,
    required bool signalAlert,
  }) {
    final anyAlert =
        tempAlert || humAlert || pressAlert || lightAlert || signalAlert;
    final accentColor = anyAlert ? Colors.red : Colours.app_main;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color:
                anyAlert
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colours.shadow_blue,
            offset: const Offset(0.0, 2.0),
            blurRadius: 10.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, anyAlert: anyAlert),
                      Gaps.vGap8,
                      Divider(height: 1, thickness: 1, color: Colours.line),
                      Gaps.vGap8,
                      _buildBody(
                        reading: reading,
                        labelStyle: labelStyle,
                        tempAlert: tempAlert,
                        humAlert: humAlert,
                        pressAlert: pressAlert,
                        lightAlert: lightAlert,
                      ),
                      Gaps.vGap8,
                      _buildFooter(
                        context,
                        reading: reading,
                        labelStyle: labelStyle,
                        signalAlert: signalAlert,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, {bool anyAlert = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (anyAlert) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Alerte',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(_mac, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Row(
          children: [
            if (widget.showAlert) ...[
              _ActionButton(
                iconPath: 'assets/images/home/message.png',
                iconColor: Colours.app_main,
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => AlartScreen(
                              name: widget.name,
                              id: _userId,
                              result: widget.result,
                              type: widget.type,
                              mac: widget.mac,
                            ),
                      ),
                    ),
              ),
            ],
            /*
            if (widget.showPrint) ...[
              Gaps.hGap8,
              _ActionButton(
                iconPath: 'assets/images/home/print.png',
                iconColor: Colours.app_main,
                onTap: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => SMSVerifyDialog(
                    uuid: _userId,
                    macAddrs: _mac,
                    name: widget.name,
                    type: widget.type,
                  ),
                ),
              ),
            ],
            */
            if (widget.showReport) ...[
              Gaps.hGap8,
              _ActionButton(
                iconPath: 'assets/images/home/statistic-48.png',
                iconColor: Colours.app_main,
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => StatsPage(
                              uuid: _userId,
                              macAddrs: _mac,
                              name: widget.name,
                              type: widget.type,
                            ),
                      ),
                    ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody({
    required SensorReading reading,
    required TextStyle? labelStyle,
    required bool tempAlert,
    required bool humAlert,
    required bool pressAlert,
    required bool lightAlert,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reading.humidity != null) ...[
                _SensorLabel(
                  label: 'Humidité',
                  value: '${reading.humidity!.toStringAsFixed(2)} %',
                  isAlert: humAlert,
                  style: labelStyle,
                ),
                Gaps.vGap8,
              ],
              if (reading.pressure != null) ...[
                _SensorLabel(
                  label: 'Pression',
                  value: '${reading.pressure!.toStringAsFixed(2)} hPa',
                  isAlert: pressAlert,
                  style: labelStyle,
                ),
                Gaps.vGap8,
              ],
              if (reading.luminosity != null) ...[
                _SensorLabel(
                  label: 'Luminosité',
                  value: '${reading.luminosity!.toStringAsFixed(2)} lux',
                  isAlert: lightAlert,
                  style: labelStyle,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _TemperatureDisplay(
          temperature: reading.temperature,
          isAlert: tempAlert,
        ),
      ],
    );
  }

  // ─── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(
    BuildContext context, {
    required SensorReading reading,
    required TextStyle? labelStyle,
    required bool signalAlert,
  }) {
    return Row(
      children: [
        // ─ Signal (gauche)
        _FooterChip(
          icon: Icons.signal_cellular_alt_rounded,
          label: '${widget.result.rssi} dBm',
          isAlert: signalAlert,
        ),
        const SizedBox(width: 6),
        // ─ Date + Heure (gauche) — affichage agrandi
        _FooterChip(
          icon: Icons.access_time_rounded,
          // Format : JJ/MM HH:MM:SS  (ex. "08/05 14:32:07")
          label: () {
            final ts = widget.result.timeStamp.toString(); // 2026-05-08 14:32:07.xxx
            final date = ts.substring(0, 10); // 2026-05-08
            final time = ts.substring(11, 19); // 14:32:07
            final dmy = '${date.substring(8, 10)}/${date.substring(5, 7)}';
            return '$dmy  $time';
          }(),
          large: true,
        ),
        const SizedBox(width: 4),
        // ─ Sablier de fraîcheur — indique visuellement si l'info est récente.
        //   • vert  : < 30 s     (sablier plein en haut)
        //   • orange: 30 s – 2 min (sablier en cours)
        //   • rouge : > 2 min     (sablier épuisé)
        _FreshnessIndicator(timestamp: widget.result.timeStamp),
        const Spacer(),
        // ─ Voltage (droite)
        if (reading.voltage != null)
          _FooterChip(
            icon: Icons.battery_charging_full_rounded,
            label: '${reading.voltage!.toStringAsFixed(2)} V',
          ),
      ],
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SensorLabel extends StatelessWidget {
  const _SensorLabel({
    required this.label,
    required this.value,
    required this.isAlert,
    this.style,
  });

  final String label;
  final String value;
  final bool isAlert;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: Dimens.font_sp12,
            color: Colours.text_gray,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:
                isAlert ? Colors.red.withValues(alpha: 0.10) : Colours.bg_gray,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color:
                  isAlert ? Colors.red.withValues(alpha: 0.35) : Colours.line,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: Dimens.font_sp12,
              color: isAlert ? Colors.red : Colours.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TemperatureDisplay extends StatelessWidget {
  const _TemperatureDisplay({required this.temperature, required this.isAlert});

  final double temperature;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final color = isAlert ? Colors.red : Colours.app_main;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/home/ic_temperature.png',
            width: 20,
            height: 20,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            '${temperature.toStringAsFixed(1)}°',
            style: TextStyle(
              fontSize: 36.0,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          Text(
            '°C',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer chip ──────────────────────────────────────────────────────────────

class _FooterChip extends StatelessWidget {
  const _FooterChip({
    required this.icon,
    required this.label,
    this.isAlert = false,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final bool isAlert;

  /// Si `true`, le chip est légèrement agrandi (utilisé pour l'horodatage
  /// dans le footer afin que la date + heure restent lisibles).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = isAlert ? Colors.red : Colours.text_gray;

    final iconSize = large ? 13.0 : 11.0;
    final fontSize = large ? 12.5 : 11.0;
    final hPad = large ? 9.0 : 7.0;
    final vPad = large ? 5.0 : 3.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.withValues(alpha: 0.08) : Colours.bg_gray,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isAlert ? Colors.red.withValues(alpha: 0.30) : Colours.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: large ? 5 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: isAlert
                  ? FontWeight.w700
                  : (large ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur visuel de fraîcheur d'une lecture capteur.
///
/// Affiche un petit sablier dont la couleur et l'orientation reflètent l'âge
/// de la mesure :
/// • **Vert + sablier plein en haut** → < 30 s (donnée fraîche)
/// • **Orange + sablier en cours**     → 30 s – 2 min
/// • **Rouge + sablier épuisé**         → > 2 min (donnée potentiellement obsolète)
///
/// Le widget est volontairement *stateless* : la carte parente
/// (`_ScanResultCardState`) déclenche déjà un `setState` toutes les secondes
/// via son propre `_timer`, donc l'âge se met à jour automatiquement.
class _FreshnessIndicator extends StatelessWidget {
  const _FreshnessIndicator({required this.timestamp});

  final DateTime timestamp;

  static const _freshThreshold = Duration(seconds: 30);
  static const _staleThreshold = Duration(minutes: 2);

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(timestamp);

    final IconData icon;
    final Color color;
    if (age < _freshThreshold) {
      icon = Icons.hourglass_top_rounded;
      color = const Color(0xFF22C55E); // vert
    } else if (age < _staleThreshold) {
      icon = Icons.hourglass_bottom_rounded;
      color = const Color(0xFFF59E0B); // orange
    } else {
      icon = Icons.hourglass_disabled_rounded;
      color = const Color(0xFFEF4444); // rouge
    }

    return Tooltip(
      message: 'Reçu il y a ${_humanAge(age)}',
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  static String _humanAge(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    return '${d.inHours} h';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.iconPath, this.iconColor, this.onTap});

  final String iconPath;
  final Color? iconColor;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colours.app_main;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Image.asset(iconPath, color: color, height: 18, width: 18),
      ),
    );
  }
}
