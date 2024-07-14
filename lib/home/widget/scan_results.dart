import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:siot_driver_pro/alert/screen/alart.dart';
import 'package:siot_driver_pro/home/widget/sms_verify_dialog.dart';
import 'package:siot_driver_pro/service/ems_pdf_service.dart';
import 'package:siot_driver_pro/stats/page/stats.dart';
import '../../res/colors.dart';
import '../../res/dimens.dart';
import '../../res/gaps.dart';
import '../../res/styles.dart';

class ScanResults extends StatefulWidget {
  const ScanResults({super.key,required this.name,required this.result,required this.param,required this.print, required this.report, required this.type});
  final ScanResult result;
  final String param, print, report, name, type;
  @override
  ScanResultsState createState() => ScanResultsState();
}

class ScanResultsState extends State<ScanResults>{
  
  final EmsPdfService emsPdfService = EmsPdfService();
  List<Map<String, dynamic>> itemsAlert = [];
  final alert = Hive.box('Alert');
  void refreshAlert() {
    final data = alert.keys.map((key) {
      final item = alert.get(key);
      return {"key":key,
        "uuid_user": item["uuid_user"],
        "MacAddrs": item["MacAddrs"],
        "checkedtemperature": item["checkedtemperature"],
        "lowtemperature": item["lowtemperature"],
        "hightemperature": item["hightemperature"],
        "checkedhumidity": item["checkedhumidity"],
        "lowhumidity": item["lowhumidity"],
        "highhumidity": item["highhumidity"],
        "checkedpresure": item["checkedpresure"],
        "lowpresure": item["lowpresure"],
        "highpresure": item["highpresure"],
        "checkedsignal_strength": item["checkedsignal_strength"],
        "lowsignal_strength": item["lowsignal_strength"],
        "highsignal_strength": item["highsignal_strength"],
        "checkedluminosite": item["checkedluminosite"],
        "lowluminosite": item["lowluminosite"],
        "highluminosite": item["highluminosite"],
      };
    }).toList();
    setState(() {
      itemsAlert = data.reversed.toList();
      index= itemsAlert.indexWhere((item) => item["MacAddrs"] == widget.result.device.remoteId.str);
    });
  }

  late int index = 0;

  @override
  void initState() {
    refreshAlert();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      refreshAlert();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? textTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: Dimens.font_sp12);
    var manufacturerData = Uint8List.fromList(widget.result.advertisementData.manufacturerData[1177]!);
    var temp = (ByteData.sublistView(manufacturerData,1,3).getUint16(0,Endian.big)).toRadixString(2);
    var hum = (ByteData.sublistView(manufacturerData,3,5).getUint16(0,Endian.big)/400).toStringAsFixed(2);
    var press = ((ByteData.sublistView(manufacturerData,5,7).getUint16(0,Endian.big)+50000)/100).toStringAsFixed(2);
    var hh = (ByteData.sublistView(manufacturerData,13,15).getUint16(0,Endian.big).toRadixString(2));
    var vol = ((int.parse(hh.substring(0,11),radix: 2) + 1600)/1000).toStringAsFixed(2);
    if(temp.length < 16) { temp = temp.padLeft(16,'0'); }
    if(temp.startsWith('1')){
      temp = temp.replaceAll("0"," ");
      temp = temp.replaceAll("1","0");
      temp = temp.replaceAll(" ","1");
      int decimalValue = int.parse(temp,radix: 2);
      decimalValue = (decimalValue + 1) * -1;
      temp = (decimalValue*0.005).toStringAsFixed(2);
    }else{
      temp = ((int.parse(temp,radix: 2))*0.005).toStringAsFixed(2);
    }
    
    //var txp = (int.parse(hh.substring(11,16),radix: 2)*2) -40;
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: const <BoxShadow> [
          BoxShadow(color: Color(0x80DCE7FA), offset: Offset(0.0, 2.0), blurRadius: 8.0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name),
                  Text(
                    widget.result.device.remoteId.str,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            Row(children: [
              widget.param == '1' ?OrderItemButton(
                text: 'assets/images/home/message.png',
                textColor: Colours.text,
                bgColor:  Colours.bg_gray,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder:(context){return AlartScreen(name: widget.name,id: Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],result: widget.result,type: widget.type);}));
                },
              ): const SizedBox(),
              widget.print == '1' ?Gaps.hGap4 :const SizedBox(),
              widget.print == '1' ?OrderItemButton(
                text: 'assets/images/home/print.png',
                textColor: Colors.black,
                bgColor: Colours.bg_gray,
                onTap: () async{
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => SMSVerifyDialog(uuid: Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],macAddrs: widget.result.device.remoteId.str,name: widget.name, type: widget.type)
                  );
                }
              ): const SizedBox(),
              widget.report == '1' ?Gaps.hGap4 : const SizedBox(),
              widget.report == '1' ?OrderItemButton(
                text: 'assets/images/home/statistic-48.png',
                textColor: null,
                bgColor: Colours.bg_gray,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder:(context){return StatsPage( uuid: Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],macAddrs: widget.result.device.remoteId.str,name: widget.name, type: widget.type,);}));
                },
              ):const SizedBox()
            ])
          ]),
          Gaps.vGap8,
          Gaps.line,
          Gaps.vGap8,
          Row(crossAxisAlignment: CrossAxisAlignment.start,children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
                RichText(text: TextSpan(
                  style: textTextStyle,
                  children: <TextSpan>[
                    const TextSpan(text: 'Humidité: '),
                    TextSpan(
                      text: '$hum %', 
                      style: TextStyle(
                        fontSize: Dimens.font_sp12,
                        color: (itemsAlert.elementAt(index)["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(index)["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(index)["highhumidity"]))?Colors.red :Colours.text_gray,
                        fontWeight: FontWeight.normal
                      )
                    ),
                  ]
                )),
                Gaps.vGap8,
                RichText(text: TextSpan(
                  style: textTextStyle,
                  children: <TextSpan>[
                    const TextSpan(text: 'Pression: '),
                    TextSpan(
                      text: '$press hPa', 
                      style: TextStyle(
                        fontSize: Dimens.font_sp12,
                        color: (itemsAlert.elementAt(index)["checkedpresure"] == '1' && (double.parse(press) < itemsAlert.elementAt(index)["lowpresure"] || double.parse(press) > itemsAlert.elementAt(index)["highpresure"]))?Colors.red :Colours.text_gray,
                        fontWeight: FontWeight.normal
                      )
                    ),
                  ],
                )),
                Gaps.vGap8,
                RichText(text: TextSpan(
                  style: textTextStyle,
                  children: <TextSpan>[
                    const TextSpan(text: 'Force du signal: '),
                    TextSpan(
                      text: '${widget.result.rssi} dBm', 
                      style: TextStyle(
                        fontSize: Dimens.font_sp12,
                        color: (itemsAlert.elementAt(index)["checkedsignal_strength"] == '1' && (widget.result.rssi < itemsAlert.elementAt(index)["lowsignal_strength"] || widget.result.rssi > itemsAlert.elementAt(index)["highsignal_strength"]))?Colors.red :Colours.text_gray,
                        fontWeight: FontWeight.normal
                      )
                    ),
                  ],
                )),
              ]),
            ),
            Row(children: [
              Image.asset('assets/images/home/ic_temperature.png',width: 30, height: 30,color: (itemsAlert.elementAt(index)["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(index)["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(index)["hightemperature"]))?Colors.red :null),
              Text(
                '$temp°C',
                style: TextStyle(
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  color: (itemsAlert.elementAt(index)["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(index)["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(index)["hightemperature"]))?Colors.red :null
                )
              ),
            ])
          ]),
          Gaps.vGap8,
          Row(children: <Widget>[
            Expanded(child: RichText(text: TextSpan(
              style: textTextStyle,
              children: <TextSpan>[
                const TextSpan(text: 'Voltage: '),
                TextSpan(text: '$vol V', style: Theme.of(context).textTheme.titleSmall),
              ])
            )),
            Row(children: [
              Image.asset('assets/images/home/icon_calendar.png', width: 14.0, height: 14.0),
              Gaps.hGap4,
              Text(
                widget.result.timeStamp.toString().substring(0,19),
                // widget.result.timeStamp.millisecondsSinceEpoch.toString()
                style: TextStyles.textSize12,
              ),
            ]),
          ])
        ],
      ),
    );
  }
  
}

class OrderItemButton extends StatelessWidget {
  
  const OrderItemButton({
    super.key,
    this.bgColor,
    this.textColor,
    required this.text,
    this.onTap
  });
  
  final Color? bgColor;
  final Color? textColor;
  final GestureTapCallback? onTap;
  final String text;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4.0),
        ),
        constraints: const BoxConstraints(
          minWidth: 30.0,
          //maxHeight: 30.0,
          minHeight: 30.0,
        ),
        child: //IconButton(onPressed: (){}, icon: Image.asset(text,color: textColor,height: 24,width: 24), tooltip: 'Notification')
        Image.asset(text,color: textColor,height: 20,width: 20,)
      ),
    );
  }

}
