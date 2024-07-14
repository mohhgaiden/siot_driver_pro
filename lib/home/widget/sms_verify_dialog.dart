import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:siot_driver_pro/service/ems_pdf_service.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../res/colors.dart';
import '../../res/gaps.dart';
import '../../res/styles.dart';
import '../../widgets/load_image.dart';
import '../../widgets/my_button.dart';
import '../pdf/model/invoice.dart';

class SMSVerifyDialog extends StatefulWidget {

  const SMSVerifyDialog({super.key,required this.macAddrs,required this.uuid,required this.name,required this.type});
  final String macAddrs, uuid, name, type;

  @override
  _SMSVerifyDialogState createState() => _SMSVerifyDialogState();
}

class _SMSVerifyDialogState extends State<SMSVerifyDialog> {

  List<Map<String, dynamic>> items = [];
  final stats = Hive.box('SENSOR_READ1');
  EmsPdfService emsPdfService = EmsPdfService();

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
    const Color textColor = Colours.app_main;
    
    final Widget child = Column(
      children: <Widget>[
        Stack(
          children: <Widget>[
            Container(
              width: double.infinity,
              height: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 0.0),
              child: const Text(
                'Impression',
                style: TextStyles.textBold16,
              ),
            ),
            Positioned(
              top: 0.0,
              right: 0.0,
              child: Semantics(
                label: '关闭',
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: LoadAssetImage('goods/icon_dialog_close.png', width: 16.0),
                  ),
                ),
              ),
            )
          ],
        ),
        Gaps.line,
        Column(children: [
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
        ]),
        Gaps.line,
        MyButton(
          text: 'Imprimer',
          textColor: textColor,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          onPressed: () async{
            final invoice = Invoice(
              items: [
                for(int i = 0;i<items.length;i++) 
                  InvoiceItem(
                    id: i+1,
                    date: DateTime.fromMillisecondsSinceEpoch(items.elementAt(i)["InfoDate"]).toString().substring(0,19), 
                    temperature: items.elementAt(i)["temperature"], 
                    humidity: widget.type =='1' ?items.elementAt(i)["humidity"] : 0, 
                    pression: widget.type =='1' ?items.elementAt(i)["presure"] : 0
                  )
              ],
            );
            final data = await emsPdfService.generateEMSPDF(invoice,widget.name,widget.macAddrs,widget.type);
            if(invoice.items.isNotEmpty){emsPdfService.savePdfFile("emsPdf", data);}
            if(invoice.items.isEmpty){
              showDialog(
                context: context, 
                builder: (context) => AlertDialog(
                  content: const Text("Aucune information pour le jour sélectionné"),
                  actions: [
                    TextButton(onPressed: (){Navigator.pop(context);}, child: Text("ok"))
                  ]
                )
              );
            }
          },
        ),
      ],
    );

    Widget body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      width: 290,
      height: 380,
      child: child,
    );
    body = AnimatedContainer(
        alignment: Alignment.center,
        height: MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInCubic,
        child: body,
      );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: body,
    );
  }

}
