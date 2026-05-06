import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../charts/beziar_chart/bezier_chart_plus.dart';
import '../../../core/constants/colors.dart';
import '../services/pdf_report_service.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    required this.macAddrs,
    required this.uuid,
    required this.name,
    required this.type,
  });

  final String macAddrs, uuid, name, type;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  //List<Map<String, dynamic>> items = [];
  final _statsBox = Hive.box('SENSOR_READ1');

  late DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  late int _refreshInterval;
  bool _isPrinting = false;

  final userBox = Hive.box('LOGGED_IN_USER');

  @override
  void initState() {
    super.initState();
    if (userBox.isNotEmpty) {
      _refreshInterval = int.parse(userBox.getAt(0)['user_clear_interval']);
    } else {
      _refreshInterval = 7;
    }
  }

  List<Map<String, dynamic>> _filterData() {
    final start = _selectedDay.millisecondsSinceEpoch;
    final end = start + 86400000;

    return _statsBox.values
        .where((item) {
          return item != null &&
              item['uuid_user'] == widget.uuid &&
              item['MacAddrs'] == widget.macAddrs &&
              (item['InfoDate'] as num).toInt() > start &&
              (item['InfoDate'] as num).toInt() < end;
        })
        .map((item) {
          return {
            'temperature': (item['temperature'] as num?)?.toDouble(),
            'humidity': (item['humidity'] as num?)?.toDouble(),
            'presure': (item['presure'] as num?)?.toDouble(),
            'InfoDate': (item['InfoDate'] as num).toInt(),
          };
        })
        .toList();
  }

  Future<void> _printReport(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Aucune donnée à imprimer pour ce jour.'),
            ],
          ),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isPrinting = true);
    try {
      await PdfReportService.generateAndOpen(
        sensorName: widget.name,
        macAddress: widget.macAddrs,
        sensorType: widget.type,
        date: _selectedDay,
        readings: items,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ─── Compute min / max / avg ────────────────────────────────────────────────

  _DayStat _stat(String field, List items) {
    final values =
        items
            .where((e) => e[field] != null)
            .map((e) => (e[field] as num).toDouble())
            .toList();
    if (values.isEmpty) return const _DayStat.empty();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.fold(0.0, (a, b) => a + b) / values.length;
    return _DayStat(min: min, max: max, avg: avg);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FF),
      body: ValueListenableBuilder(
        valueListenable: _statsBox.listenable(),
        builder: (context, Box box, _) {
          final items = _filterData();

          final hasHum = widget.type == '1' || widget.type == '6';
          final hasPress = widget.type == '1';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, items),
              SliverToBoxAdapter(child: _buildCalendar()),
              SliverToBoxAdapter(child: _buildDayBadges(items)),

              SliverToBoxAdapter(
                child: _buildMetricCard(
                  context,
                  items: items,
                  title: 'Température',
                  unit: '°C',
                  field: 'temperature',
                  color: Colours.app_main,
                  icon: Icons.thermostat_rounded,
                ),
              ),

              if (hasHum)
                SliverToBoxAdapter(
                  child: _buildMetricCard(
                    context,
                    items: items,
                    title: 'Humidité',
                    unit: '%',
                    field: 'humidity',
                    color: const Color(0xFFFF8C00),
                    icon: Icons.water_drop_rounded,
                  ),
                ),

              if (hasPress)
                SliverToBoxAdapter(
                  child: _buildMetricCard(
                    context,
                    items: items,
                    title: 'Pression',
                    unit: 'hPa',
                    field: 'presure',
                    color: const Color(0xFFEF4444),
                    icon: Icons.compress_rounded,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          );
        },
      ),
    );
  }

  // ─── SliverAppBar ───────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, List items) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 130,
      backgroundColor: Colours.app_main,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Statistiques',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child:
              _isPrinting
                  ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                  : IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    tooltip: 'Exporter PDF',
                    onPressed: () {
                      _printReport(items.cast<Map<String, dynamic>>());
                    },
                  ),
        ),
        /*
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_countdown}s',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),*/
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colours.dark_app_main,
                Colours.app_main,
                Colours.gradient_blue,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.macAddrs,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Calendrier ─────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colours.shadow_blue,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: TableCalendar(
          locale: 'en_US',
          rowHeight: 36,
          daysOfWeekHeight: 32,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1A1A2E),
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left_rounded,
              color: Colours.app_main,
              size: 22,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right_rounded,
              color: Colours.app_main,
              size: 22,
            ),
            headerPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
            weekendStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colours.app_main.withValues(alpha: 0.70),
            ),
          ),
          calendarStyle: CalendarStyle(
            cellMargin: const EdgeInsets.all(3),
            todayDecoration: BoxDecoration(
              color: Colours.app_main.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: Colours.app_main,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            selectedDecoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colours.dark_app_main, Colours.app_main],
              ),
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            defaultTextStyle: const TextStyle(fontSize: 13),
            weekendTextStyle: TextStyle(
              fontSize: 13,
              color: Colours.app_main.withValues(alpha: 0.65),
            ),
            outsideDaysVisible: false,
          ),
          availableGestures: AvailableGestures.all,
          focusedDay: _selectedDay,
          firstDay: DateTime.now().subtract(Duration(days: _refreshInterval)),
          lastDay: DateTime.now(),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = DateTime(
                selectedDay.year,
                selectedDay.month,
                selectedDay.day,
              );
            });
          },
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
        ),
      ),
    );
  }

  // ─── Badges date + compteur ──────────────────────────────────────────────────

  Widget _buildDayBadges(List items) {
    final d = _selectedDay;
    final label =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          _InfoBadge(
            icon: Icons.calendar_today_rounded,
            label: label,
            color: Colours.app_main,
          ),
          const SizedBox(width: 8),
          _InfoBadge(
            icon: Icons.analytics_rounded,
            label: '${items.length} mesure${items.length > 1 ? 's' : ''}',
            color: items.isEmpty ? Colors.grey : Colours.app_main,
          ),
        ],
      ),
    );
  }

  // ─── Metric card ────────────────────────────────────────────────────────────

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String unit,
    required String field,
    required Color color,
    required IconData icon,
    required List<Map<String, dynamic>> items,
  }) {
    final stat = _stat(field, items);

    // rawItems  → real data (used for badge count, empty check, scroll width)
    // chartItems → padded to ≥6 so BezierChart never crashes
    final rawItems = items.where((e) => e[field] != null).toList();
    final chartItems = rawItems;

    final xValues = List<double>.generate(
      chartItems.length,
      (i) => i.toDouble(),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.13),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête gradient ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.82), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    child: Icon(icon, size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$title ($unit)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // Show REAL point count, not padded
                  if (stat.hasData)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${rawItems.length} pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Zone chart ────────────────────────────────────────────────
            SizedBox(
              height: 260,
              child:
                  //rawItems.isEmpty
                  rawItems.length < 2
                      ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.show_chart_rounded,
                              size: 36,
                              color: color.withValues(alpha: 0.25),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aucune donnée pour ce jour',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                      : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            // math.max avoids clamp crash when few points
                            width: math.max(
                              MediaQuery.of(context).size.width - 32,
                              rawItems.length * 60.0,
                            ),
                            height: 256,
                            child: BezierChart(
                              bezierChartScale: BezierChartScale.custom,
                              xAxisCustomValues: xValues,
                              footerValueBuilder: (double val) {
                                final idx = val.toInt().clamp(
                                  0,
                                  chartItems.length - 1,
                                );
                                final dt = DateTime.fromMillisecondsSinceEpoch(
                                  chartItems[idx]['InfoDate'] as int,
                                );
                                return '${dt.hour.toString().padLeft(2, '0')}:'
                                    '${dt.minute.toString().padLeft(2, '0')}';
                              },
                              bubbleLabelValueBuilder: (double val) {
                                final idx = val.toInt().clamp(
                                  0,
                                  chartItems.length - 1,
                                );
                                final dt = DateTime.fromMillisecondsSinceEpoch(
                                  chartItems[idx]['InfoDate'] as int,
                                );
                                return '${dt.day.toString().padLeft(2, '0')}/'
                                    '${dt.month.toString().padLeft(2, '0')} '
                                    '${dt.hour.toString().padLeft(2, '0')}:'
                                    '${dt.minute.toString().padLeft(2, '0')}:'
                                    '${dt.second.toString().padLeft(2, '0')} \n';
                              },
                              series: [
                                BezierLine(
                                  lineColor: color.withValues(alpha: 0.7),
                                  dataPointStrokeColor: color,
                                  dataPointFillColor: color,
                                  lineStrokeWidth: 2.5,
                                  label: unit,
                                  data:
                                      List.generate(
                                        chartItems.length,
                                        (i) {
                                          final value = chartItems[i][field];
                                          if (value == null) return null;
                                          return DataPoint<double>(
                                            value: (value as num).toDouble(),
                                            xAxis: xValues[i],
                                          );
                                        },
                                      ).whereType<DataPoint<double>>().toList(),
                                ),
                              ],
                              config: BezierChartConfig(
                                verticalIndicatorFixedPosition: false,
                                verticalIndicatorColor: color.withValues(
                                  alpha: 0.80,
                                ),
                                verticalIndicatorStrokeWidth: 2.0,
                                showVerticalIndicator: true,
                                snap: true,
                                showDataPoints: true,
                                footerHeight: 28,
                                displayYAxis: false,
                                startYAxisFromNonZeroValue: true,
                                yAxisTextStyle: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                ),
                                xAxisTextStyle: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade500,
                                ),
                                bubbleIndicatorColor: color,
                                bubbleIndicatorValueStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                                bubbleIndicatorLabelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                ),
                                bubbleIndicatorTitleStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
            ),

            // ── Bande Min / Moy / Max ─────────────────────────────────────
            if (stat.hasData) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: color.withValues(alpha: 0.10),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        label: 'Min',
                        value: stat.min.toStringAsFixed(1),
                        unit: unit,
                        color: const Color(0xFF22C55E),
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        label: 'Moyenne',
                        value: stat.avg.toStringAsFixed(1),
                        unit: unit,
                        color: color,
                        icon: Icons.horizontal_rule_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        label: 'Max',
                        value: stat.max.toStringAsFixed(1),
                        unit: unit,
                        color: const Color(0xFFEF4444),
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _DayStat {
  const _DayStat({required this.min, required this.max, required this.avg})
    : hasData = true;
  const _DayStat.empty() : min = 0, max = 0, avg = 0, hasData = false;

  final double min, max, avg;
  final bool hasData;
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  final String label, value, unit;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 10, color: color.withValues(alpha: 0.80)),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
