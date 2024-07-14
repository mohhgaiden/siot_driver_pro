import 'dart:async';
import 'package:bezier_chart_plus/bezier_chart_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:siot_driver_pro/widgets/my_app_bar.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../res/colors.dart';
import '../../res/gaps.dart';
import '../../res/styles.dart';
import '../../widgets/my_card.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key,required this.macAddrs,required this.uuid,required this.name,required this.type});
  final String macAddrs, uuid, name, type;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {

  List<Map<String, dynamic>> items = [];
  final stats = Hive.box('SENSOR_READ1');

  void refresh() {
    final data = stats.keys
    .where((element) => stats.get(element)["uuid_user"]==widget.uuid && stats.get(element)["MacAddrs"]==widget.macAddrs && stats.get(element)["InfoDate"]>initialDay.millisecondsSinceEpoch && stats.get(element)["InfoDate"] < (initialDay.millisecondsSinceEpoch + 86400000))
    .map((key) {
      final item = stats.get(key);
      return {"key":key,
        "uuid_user": item["uuid_user"],
        "MacAddrs": item["MacAddrs"],
        "temperature": item["temperature"],
        "humidity": item["humidity"],
        "presure": item["presure"],
        "InfoDate": item["InfoDate"]
      };
    }).toList();
    items = data.toList();
    setState(() {});
  }

  int index = 0;

  int selectedIndex = 2;
  late DateTime initialDay = DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day);
  late Timer timer2; int seconds2 = 60;
  late int seconds = 60;

  @override
  void initState() {
    seconds = int.parse(Hive.box('LOGGED_IN_USER').getAt(0)["user_clear_interval"]);
    refresh();
    timer2 = Timer.periodic(const Duration(seconds: 1), (timer) { 
      if(seconds2>0){
        setState(() {seconds2--;});
      }else{
        refresh();
        setState(() {seconds2 = 60;});
      }
    });
    initialDay = DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(title: 'Statistics'),
      body: SingleChildScrollView(child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TableCalendar(
              locale: "en_US",
              rowHeight: 34,
              headerStyle: const HeaderStyle(formatButtonVisible: false,titleCentered: true,leftChevronVisible: false,rightChevronVisible: false),
              availableGestures: AvailableGestures.none,
              sixWeekMonthsEnforced: false,
              daysOfWeekHeight: 34,
              focusedDay: initialDay, 
              firstDay: DateTime.now().subtract(Duration(days: seconds)), 
              lastDay: DateTime.now(),
              onDaySelected: (selectedDay, focusedDay) { setState(() {initialDay = DateTime(selectedDay.year,selectedDay.month,selectedDay.day);}); refresh();},
              selectedDayPredicate: (day) => isSameDay(day, initialDay),
            ),
            Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.name, style: TextStyles.textBold18),
                    Gaps.hGap16,
                    Gaps.vGap16,
                    AspectRatio(
                      aspectRatio: 2.5,
                      child: MyCard(
                        color: Colours.app_main,
                        shadowColor: Colours.shadow_blue,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/stats/chart_fg.png'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          child: Column(children: <Widget>[
                            Gaps.vGap16,
                            const Row(children: <Widget>[
                              Gaps.hGap16,
                              Text('Temperature (°C)', style: TextStyle(color: Colors.white)),
                              Spacer(),
                              Text('-40° 85°', style: TextStyle(color: Colors.white)),
                              Gaps.hGap16,
                            ]),
                            Gaps.vGap4,
                            Expanded(child: items.isEmpty?const SizedBox() :BezierChart(
                              bezierChartScale: BezierChartScale.custom,
                              xAxisCustomValues: List.generate(items.length, (index) => index.toDouble()),
                              footerValueBuilder: (double value) => '',
                              bubbleLabelValueBuilder: (double value) => '${DateTime.fromMillisecondsSinceEpoch(items.elementAt(value.toInt())["InfoDate"]).toString().substring(0,19)}\n',
                              series: [
                                BezierLine(
                                  dataPointStrokeColor: Colours.app_main,
                                  label: '°C',
                                  data: List.generate(items.length, (index) => DataPoint<DateTime>(value: items.elementAt(index)["temperature"], xAxis: DateTime.fromMillisecondsSinceEpoch(items.elementAt(index)["InfoDate"]))),
                                ),
                              ],
                              config: BezierChartConfig(
                                verticalIndicatorFixedPosition: false,
                                contentWidth: items.length<5 ?null :MediaQuery.of(context).size.width * (items.length/10),
                                footerHeight: 16,
                                showVerticalIndicator: false,
                                backgroundColor: Colours.app_main,
                              ),
                            )),
                          ]),
                        ),
                      ),
                    ),
                    (widget.type == '1' || widget.type == '6') ?Gaps.vGap16 : const SizedBox(),
                    (widget.type == '1' || widget.type == '6') ?AspectRatio(
                      aspectRatio: 2.5,
                      child: MyCard(
                        color: const Color(0xFFFFAA33),
                        shadowColor: const Color(0x80FFAA33),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/stats/chart_fg.png'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          child: Column(children: <Widget>[
                            Gaps.vGap16,
                            const Row(children: <Widget>[
                              Gaps.hGap16,
                              Text('Humidité (%)', style: TextStyle(color: Colors.white)),
                              Spacer(),
                              Text('0-100%', style: TextStyle(color: Colors.white)),
                              Gaps.hGap16,
                            ]),
                            Gaps.vGap4,
                            Expanded(child: items.isEmpty?const SizedBox() :BezierChart(
                              bezierChartScale: BezierChartScale.custom,
                              xAxisCustomValues: List.generate(items.length, (index) => index.toDouble()),
                              footerValueBuilder: (double value) => '',
                              bubbleLabelValueBuilder: (double value) => '${DateTime.fromMillisecondsSinceEpoch(items.elementAt(value.toInt())["InfoDate"]).toString().substring(0,19)}\n',
                              series: [
                                BezierLine(
                                  dataPointStrokeColor: const Color(0xFFFFAA33),
                                  label: '%',
                                  data: List.generate(items.length, (index) => DataPoint<DateTime>(value: items.elementAt(index)["humidity"], xAxis: DateTime.fromMillisecondsSinceEpoch(items.elementAt(index)["InfoDate"]))),
                                ),
                              ],
                              config: BezierChartConfig(
                                verticalIndicatorFixedPosition: false,
                                contentWidth: items.length<5 ?null :MediaQuery.of(context).size.width * (items.length/10),
                                footerHeight: 16,
                                showVerticalIndicator: false,
                                backgroundColor: const Color(0xFFFFAA33),
                              ),
                            )),
                          ]),
                        ),
                      ),
                    ): const SizedBox(),
                    widget.type == '1' ?Gaps.vGap16 :const SizedBox(),
                    widget.type == '1' ?AspectRatio(
                      aspectRatio: 2.5,
                      child: MyCard(
                        color: Theme.of(context).colorScheme.error,
                        shadowColor: const Color(0x80FF4759),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/stats/chart_fg.png'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          child: Column(children: <Widget>[
                            Gaps.vGap16,
                            const Row(children: <Widget>[
                              Gaps.hGap16,
                              Text('Pressure (hPa)', style: TextStyle(color: Colors.white)),
                              Spacer(),
                              Text('300-1100', style: TextStyle(color: Colors.white)),
                              Gaps.hGap16,
                            ]),
                            Gaps.vGap4,
                            Expanded(child: items.isEmpty?const SizedBox() :BezierChart(
                              bezierChartScale: BezierChartScale.custom,
                              xAxisCustomValues: List.generate(items.length, (index) => index.toDouble()),
                              footerValueBuilder: (double value) => '',
                              bubbleLabelValueBuilder: (double value) => '${DateTime.fromMillisecondsSinceEpoch(items.elementAt(value.toInt())["InfoDate"]).toString().substring(0,19)}\n',
                              series: [
                                BezierLine(
                                  dataPointStrokeColor: Theme.of(context).colorScheme.error,
                                  label: 'hPa',
                                  data: List.generate(items.length, (index) => DataPoint<DateTime>(value: items.elementAt(index)["presure"], xAxis: DateTime.fromMillisecondsSinceEpoch(items.elementAt(index)["InfoDate"]))),
                                ),
                              ],
                              config: BezierChartConfig(
                                verticalIndicatorFixedPosition: false,
                                contentWidth: items.length<5 ?null :MediaQuery.of(context).size.width * (items.length/10),
                                footerHeight: 16,
                                showVerticalIndicator: false,
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            )),
                          ]),
                        ),
                      ),
                    ): const SizedBox(),
                    Gaps.vGap16,
                  ],
                ),
              ),
          ],
        )
      )),
    );
  }
  
}