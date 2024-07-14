import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:siot_driver_pro/res/colors.dart';
import 'package:siot_driver_pro/widgets/my_scroll_view.dart';
import '../../res/gaps.dart';
import '../../res/styles.dart';
import '../../widgets/load_image.dart';
import '../../widgets/my_app_bar.dart';
import '../../widgets/my_button.dart';

class AlartScreen extends StatefulWidget {
  const AlartScreen({super.key,required this.name,required this.id,required this.result,required this.type});
  final ScanResult result;
  final String name,id,type;
  @override
  State<AlartScreen> createState() => _AlartScreenState();
}

class _AlartScreenState extends State<AlartScreen> {

  bool onTemp = false;
  double minTemp = -40;
  double maxTemp = 85;
  
  bool onHum = false;
  double minHum = 0;
  double maxHum = 100;

  bool onPress = false;
  double minPress = 300;
  double maxPress = 1100;

  bool onPuis = false;
  double minPuiS = -105;
  double maxPuiS = 0;

  bool onLimen = true;
  double minLimen = 0;
  double maxLimen = 83000;

  late int index;

  intitial() {
    //fetch alert 
    for(int i = 0; i< Hive.box('Alert').length; i++){
      if(Hive.box('Alert').getAt(i)["MacAddrs"] == widget.result.device.remoteId.str){
        setState(() {
          onTemp = Hive.box('Alert').getAt(i)["checkedtemperature"] == "1" ? true : false;
          minTemp = Hive.box('Alert').getAt(i)["lowtemperature"];
          maxTemp = Hive.box('Alert').getAt(i)["hightemperature"];
          onHum = Hive.box('Alert').getAt(i)["checkedhumidity"] == "1" ? true : false;
          minHum = Hive.box('Alert').getAt(i)["lowhumidity"];
          maxHum = Hive.box('Alert').getAt(i)["highhumidity"];
          onPress = Hive.box('Alert').getAt(i)["checkedpresure"] == "1" ? true : false;
          minPress = Hive.box('Alert').getAt(i)["lowpresure"];
          maxPress = Hive.box('Alert').getAt(i)["highpresure"];
          onPuis = Hive.box('Alert').getAt(i)["checkedsignal_strength"] == "1" ? true : false;
          minPuiS = Hive.box('Alert').getAt(i)["lowsignal_strength"];
          maxPuiS = Hive.box('Alert').getAt(i)["highsignal_strength"];
          onLimen = Hive.box('Alert').getAt(i)["checkedluminosite"] == "1" ? true : false;
          minLimen = Hive.box('Alert').getAt(i)["lowluminosite"];
          maxLimen = Hive.box('Alert').getAt(i)["highluminosite"];
          index = i;
        });
      }
    }
  }

  @override
  void initState() {
    intitial();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppBar(title: 'Notification'),
      body: MyScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        bottomButton: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16.0,vertical: 16),
          child: MyButton(
            text: 'Enregistrer',
            minHeight: 45,
            onPressed: () async{
              //edit alert
              await Hive.box('Alert').putAt(
                index,{
                  "uuid_user": widget.id,
                  "MacAddrs": widget.result.device.remoteId.str,
                  "checkedtemperature": onTemp ? "1" : "0",
                  "lowtemperature": minTemp,
                  "hightemperature": maxTemp,
                  "checkedhumidity": onHum ? "1" : "0",
                  "lowhumidity": minHum,
                  "highhumidity": maxHum,
                  "checkedpresure": onPress ? "1" : "0",
                  "lowpresure": minPress,
                  "highpresure": maxPress,
                  "checkedsignal_strength": onPuis ? "1" : "0",
                  "lowsignal_strength": minPuiS,
                  "highsignal_strength": maxPuiS,
                  "checkedluminosite": onLimen ? "1" : "0",
                  "lowluminosite": minLimen,
                  "highluminosite": maxLimen,
                }
              );
              Navigator.pop(context);
            },
          ) 
        ),
        children: [
          Gaps.vGap10,
          Row(children: <Widget>[
            ClipOval(child: LoadAssetImage('profile/${widget.type}.jpg', width: 44.0, height: 44.0)),
            Gaps.hGap8,
            Expanded(child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.name),
                  Gaps.vGap5,
                  Text(widget.result.device.remoteId.str,style: TextStyles.textGray12),
                ],
              ),
            )),
          ]),
          Gaps.vGap24,
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('${minTemp.toStringAsFixed(0)} °C',style: TextStyles.textGray12),
                Row(children: [
                  const Text('Temperature'),
                  Transform.scale(
                    scale: 0.6,
                    child: CupertinoSwitch(
                      activeColor: Colours.app_main.withOpacity(0.5),
                      value: onTemp, 
                      onChanged: (value) => setState(() {
                        onTemp = value;
                      }),
                    ),
                  ),
                ]),
                Text('${maxTemp.toStringAsFixed(0)} °C',style: TextStyles.textGray12),
              ]
            ),
            FlutterSlider(
              disabled: !onTemp,
              handlerWidth: 24,
              trackBar: FlutterSliderTrackBar(
                inactiveDisabledTrackBarColor: Colours.bg_gray,
                activeDisabledTrackBarColor: Colors.black12,
                inactiveTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.bg_gray,
                ),
                activeTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.app_main.withOpacity(0.5)
                ),
              ),
              values: [minTemp, maxTemp],
              tooltip: FlutterSliderTooltip(disabled: true),
              rangeSlider: true,
              max: 85,
              min: -40,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                minTemp = lowerValue;
                maxTemp = upperValue;
                setState(() {});
              },
            ),
          ]),
          (widget.type == '1' || widget.type == '6' || widget.type == '10') ?Gaps.line :const SizedBox(),
          (widget.type == '1' || widget.type == '6' || widget.type == '10') ?Gaps.vGap10 :const SizedBox(),
          (widget.type == '1' || widget.type == '6' || widget.type == '10') ?Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('${minHum.toStringAsFixed(0)} %',style: TextStyles.textGray12),
                //const Text('Humidité'),
                Row(children: [
                  const Text('Humidité'),
                  Transform.scale(
                    scale: 0.6,
                    child: CupertinoSwitch(
                      activeColor: Colours.app_main.withOpacity(0.5),
                      value: onHum, 
                      onChanged: (value) => setState(() {
                        onHum = value;
                      }),
                    ),
                  ),
                ]),
                Text('${maxHum.toStringAsFixed(0)} %',style: TextStyles.textGray12),
              ]
            ),
            FlutterSlider(
              disabled: !onHum,
              handlerWidth: 24,
              trackBar: FlutterSliderTrackBar(
                inactiveDisabledTrackBarColor: Colours.bg_gray,
                activeDisabledTrackBarColor: Colors.black12,
                inactiveTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.bg_gray,
                ),
                activeTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.app_main.withOpacity(0.5)
                ),
              ),
              values: [minHum, maxHum],
              tooltip: FlutterSliderTooltip(disabled: true),
              rangeSlider: true,
              max: 100,
              min: 0,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                minHum = lowerValue;
                maxHum = upperValue;
                setState(() {});
              },
            ),
          ]) :const SizedBox(),
          widget.type == '1'?Gaps.line :const SizedBox(),
          widget.type == '1'?Gaps.vGap10 :const SizedBox(),
          widget.type == '1'?Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('${minPress.toStringAsFixed(0)} hPa',style: TextStyles.textGray12),
                //const Text('Pression atmosphérique'),
                Row(children: [
                  const Text('Pression'),
                  Transform.scale(
                    scale: 0.6,
                    child: CupertinoSwitch(
                      activeColor: Colours.app_main.withOpacity(0.5),
                      value: onPress, 
                      onChanged: (value) => setState(() {
                        onPress = value;
                      }),
                    ),
                  ),
                ]),
                Text('${maxPress.toStringAsFixed(0)} hPa',style: TextStyles.textGray12),
              ]
            ),
            FlutterSlider(
              disabled: !onPress,
              handlerWidth: 24,
              trackBar: FlutterSliderTrackBar(
                inactiveDisabledTrackBarColor: Colours.bg_gray,
                activeDisabledTrackBarColor: Colors.black12,
                inactiveTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.bg_gray,
                ),
                activeTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.app_main.withOpacity(0.5)
                ),
              ),
              values: [minPress, maxPress],
              tooltip: FlutterSliderTooltip(disabled: true),
              rangeSlider: true,
              max: 1100,
              min: 300,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                minPress = lowerValue;
                maxPress = upperValue;
                setState(() {});
              },
            ),
          ]):const SizedBox(),
          Gaps.line,
          Gaps.vGap10,
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('${minPuiS.toStringAsFixed(0)} dBm',style: TextStyles.textGray12),
                //const Text('Force de Signal'),
                Row(children: [
                  const Text('Force de Signal'),
                  Transform.scale(
                    scale: 0.6,
                    child: CupertinoSwitch(
                      activeColor: Colours.app_main.withOpacity(0.5),
                      value: onPuis, 
                      onChanged: (value) => setState(() {
                        onPuis = value;
                      }),
                    ),
                  ),
                ]),
                Text('${maxPuiS.toStringAsFixed(0)} dBm',style: TextStyles.textGray12),
              ]
            ),
            FlutterSlider(
              disabled: !onPuis,
              handlerWidth: 24,
              trackBar: FlutterSliderTrackBar(
                inactiveDisabledTrackBarColor: Colours.bg_gray,
                activeDisabledTrackBarColor: Colors.black12,
                inactiveTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.bg_gray,
                ),
                activeTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.app_main.withOpacity(0.5)
                ),
              ),
              values: [minPuiS, maxPuiS],
              tooltip: FlutterSliderTooltip(disabled: true),
              rangeSlider: true,
              max: 0,
              min: -105,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                minPuiS = lowerValue;
                maxPuiS = upperValue;
                setState(() {});
              },
            ),
          ]),
          widget.type == '6'?Gaps.line :const SizedBox(),
          widget.type == '6'?Gaps.vGap10 :const SizedBox(),
          widget.type == '6'?Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('${minLimen.toStringAsFixed(0)} lux',style: TextStyles.textGray12),
                Row(children: [
                  const Text('Luminosité'),
                  Transform.scale(
                    scale: 0.6,
                    child: CupertinoSwitch(
                      activeColor: Colours.app_main.withOpacity(0.5),
                      value: onLimen, 
                      onChanged: (value) => setState(() {
                        onLimen = value;
                      }),
                    ),
                  ),
                ]),
                Text('${maxLimen.toStringAsFixed(0)} lux',style: TextStyles.textGray12),
              ]
            ),
            FlutterSlider(
              disabled: !onLimen,
              handlerWidth: 24,
              trackBar: FlutterSliderTrackBar(
                inactiveDisabledTrackBarColor: Colours.bg_gray,
                activeDisabledTrackBarColor: Colors.black12,
                inactiveTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.bg_gray,
                ),
                activeTrackBar: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colours.app_main.withOpacity(0.5)
                ),
              ),
              values: [minLimen, maxLimen],
              tooltip: FlutterSliderTooltip(disabled: true),
              rangeSlider: true,
              max: 83000,
              min: 0,
              onDragging: (handlerIndex, lowerValue, upperValue) {
                minLimen = lowerValue;
                maxLimen = upperValue;
                setState(() {});
              },
            ),
          ]):const SizedBox(),
        ]
      ),
    );
  }

}