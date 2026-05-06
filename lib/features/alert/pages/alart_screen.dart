import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:siot_driver_pro/core/constants/colors.dart';
import 'package:siot_driver_pro/common/my_scroll_view.dart';
import '../../../core/constants/gaps.dart';
import '../../../core/constants/styles.dart';
import '../../../common/load_image.dart';
import '../../../common/my_button.dart';

class AlartScreen extends StatefulWidget {
  const AlartScreen({
    super.key,
    required this.name,
    required this.id,
    required this.result,
    required this.type,
  });

  final ScanResult result;
  final String name, id, type;

  @override
  State<AlartScreen> createState() => _AlartScreenState();
}

class _AlartScreenState extends State<AlartScreen> {
  bool onTemp = false;
  double minTemp = -40, maxTemp = 85;

  bool onHum = false;
  double minHum = 0, maxHum = 100;

  bool onPress = false;
  double minPress = 300, maxPress = 1100;

  bool onSignal = false;
  double minSignal = -105, maxSignal = 0;

  bool onLight = false;
  double minLight = 0, maxLight = 83000;

  late int _index;

  @override
  void initState() {
    super.initState();
    _loadAlertData();
  }

  void _loadAlertData() {
    final box = Hive.box('Alert');
    final mac = widget.result.device.remoteId.str;
    for (int i = 0; i < box.length; i++) {
      final item = box.getAt(i);
      if (item == null || item['MacAddrs'] != mac) continue;
      setState(() {
        onTemp = item['checkedtemperature'] == '1';
        minTemp = (item['lowtemperature'] as num).toDouble();
        maxTemp = (item['hightemperature'] as num).toDouble();
        onHum = item['checkedhumidity'] == '1';
        minHum = (item['lowhumidity'] as num).toDouble();
        maxHum = (item['highhumidity'] as num).toDouble();
        onPress = item['checkedpresure'] == '1';
        minPress = (item['lowpresure'] as num).toDouble();
        maxPress = (item['highpresure'] as num).toDouble();
        onSignal = item['checkedsignal_strength'] == '1';
        minSignal = (item['lowsignal_strength'] as num).toDouble();
        maxSignal = (item['highsignal_strength'] as num).toDouble();
        onLight = item['checkedluminosite'] == '1';
        minLight = (item['lowluminosite'] as num).toDouble();
        maxLight = (item['highluminosite'] as num).toDouble();
        _index = i;
      });
      break;
    }
  }

  Future<void> _save() async {
    await Hive.box('Alert').putAt(_index, {
      'uuid_user': widget.id,
      'MacAddrs': widget.result.device.remoteId.str,
      'checkedtemperature': onTemp ? '1' : '0',
      'lowtemperature': minTemp,
      'hightemperature': maxTemp,
      'checkedhumidity': onHum ? '1' : '0',
      'lowhumidity': minHum,
      'highhumidity': maxHum,
      'checkedpresure': onPress ? '1' : '0',
      'lowpresure': minPress,
      'highpresure': maxPress,
      'checkedsignal_strength': onSignal ? '1' : '0',
      'lowsignal_strength': minSignal,
      'highsignal_strength': maxSignal,
      'checkedluminosite': onLight ? '1' : '0',
      'lowluminosite': minLight,
      'highluminosite': maxLight,
    });
    if (mounted) Navigator.pop(context);
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool hasHum =
        widget.type == '1' || widget.type == '6' || widget.type == '10';
    final bool hasPress = widget.type == '1';
    final bool hasLight = widget.type == '6';

    return Scaffold(
      appBar: _buildAppBar(context),
      body: MyScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        bottomButton: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colours.shadow_blue,
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: MyButton(
            text: 'Enregistrer',
            radius: 10,
            minHeight: 48,
            onPressed: _save,
          ),
        ),
        children: [
          // ─── Device info card
          _buildDeviceCard(),
          Gaps.vGap16,

          // ─── Température (tous types)
          _buildAlertSection(
            icon: Icons.thermostat_outlined,
            title: 'Température',
            unit: '°C',
            enabled: onTemp,
            min: minTemp,
            max: maxTemp,
            sliderMin: -40,
            sliderMax: 85,
            onToggle: (v) => setState(() => onTemp = v),
            onDragging: (_, lower, upper) =>
                setState(() { minTemp = lower; maxTemp = upper; }),
          ),

          // ─── Humidité (types 1, 6, 10)
          if (hasHum)
            _buildAlertSection(
              icon: Icons.water_drop_outlined,
              title: 'Humidité',
              unit: '%',
              enabled: onHum,
              min: minHum,
              max: maxHum,
              sliderMin: 0,
              sliderMax: 100,
              onToggle: (v) => setState(() => onHum = v),
              onDragging: (_, lower, upper) =>
                  setState(() { minHum = lower; maxHum = upper; }),
            ),

          // ─── Pression (type 1)
          if (hasPress)
            _buildAlertSection(
              icon: Icons.compress_outlined,
              title: 'Pression atmosphérique',
              unit: 'hPa',
              enabled: onPress,
              min: minPress,
              max: maxPress,
              sliderMin: 300,
              sliderMax: 1100,
              onToggle: (v) => setState(() => onPress = v),
              onDragging: (_, lower, upper) =>
                  setState(() { minPress = lower; maxPress = upper; }),
            ),

          // ─── Signal (tous types)
          _buildAlertSection(
            icon: Icons.signal_cellular_alt_outlined,
            title: 'Force du signal',
            unit: 'dBm',
            enabled: onSignal,
            min: minSignal,
            max: maxSignal,
            sliderMin: -105,
            sliderMax: 0,
            onToggle: (v) => setState(() => onSignal = v),
            onDragging: (_, lower, upper) =>
                setState(() { minSignal = lower; maxSignal = upper; }),
          ),

          // ─── Luminosité (type 6)
          if (hasLight)
            _buildAlertSection(
              icon: Icons.light_mode_outlined,
              title: 'Luminosité',
              unit: 'lux',
              enabled: onLight,
              min: minLight,
              max: maxLight,
              sliderMin: 0,
              sliderMax: 83000,
              onToggle: (v) => setState(() => onLight = v),
              onDragging: (_, lower, upper) =>
                  setState(() { minLight = lower; maxLight = upper; }),
            ),

          Gaps.vGap16,
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colours.app_main,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuration Alertes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ─── Device info card ─────────────────────────────────────────────────────────

  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colours.line),
        boxShadow: const [
          BoxShadow(
            color: Colours.shadow_blue,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LoadAssetImage(
              'profile/${widget.type}.jpg',
              width: 48.0,
              height: 48.0,
            ),
          ),
          Gaps.hGap12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Gaps.vGap4,
                Text(
                  widget.result.device.remoteId.str,
                  style: TextStyles.textGray12,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colours.app_main.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colours.app_main.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Type ${widget.type}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colours.app_main,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Alert section card ───────────────────────────────────────────────────────

  Widget _buildAlertSection({
    required IconData icon,
    required String title,
    required String unit,
    required bool enabled,
    required double min,
    required double max,
    required double sliderMin,
    required double sliderMax,
    required ValueChanged<bool> onToggle,
    required Function(int, dynamic, dynamic) onDragging,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? Colours.app_main.withValues(alpha: 0.35)
                : Colours.line,
          ),
          boxShadow: [
            BoxShadow(
              color: enabled
                  ? Colours.shadow_blue
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─ Header row with icon + title + switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: enabled
                    ? Colours.app_main.withValues(alpha: 0.07)
                    : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: enabled ? Colours.app_main : Colours.text_gray,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled ? Colours.text : Colours.text_gray,
                      ),
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: onToggle,
                    activeColor: Colours.app_main,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            // ─ Min/Max chips + slider
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RangeChip(
                        label: 'Min',
                        value: '${min.toStringAsFixed(0)} $unit',
                        active: enabled,
                      ),
                      _RangeChip(
                        label: 'Max',
                        value: '${max.toStringAsFixed(0)} $unit',
                        active: enabled,
                        isMax: true,
                      ),
                    ],
                  ),
                  FlutterSlider(
                    disabled: !enabled,
                    handlerWidth: 22,
                    trackBar: FlutterSliderTrackBar(
                      inactiveDisabledTrackBarColor: Colours.line,
                      activeDisabledTrackBarColor:
                          Colours.app_main.withValues(alpha: 0.2),
                      inactiveTrackBar: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colours.bg_gray,
                      ),
                      activeTrackBar: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: enabled
                            ? Colours.app_main
                            : Colours.app_main.withValues(alpha: 0.3),
                      ),
                    ),
                    values: [min, max],
                    tooltip: FlutterSliderTooltip(disabled: true),
                    rangeSlider: true,
                    max: sliderMax,
                    min: sliderMin,
                    onDragging: onDragging,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Range chip ───────────────────────────────────────────────────────────────

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.value,
    required this.active,
    this.isMax = false,
  });

  final String label;
  final String value;
  final bool active;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colours.app_main.withValues(alpha: 0.08) : Colours.bg_gray,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? Colours.app_main.withValues(alpha: 0.3)
              : Colours.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: TextStyle(
              fontSize: 11,
              color: active ? Colours.app_main.withValues(alpha: 0.7) : Colours.text_gray,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colours.app_main : Colours.text_gray,
            ),
          ),
        ],
      ),
    );
  }
}
