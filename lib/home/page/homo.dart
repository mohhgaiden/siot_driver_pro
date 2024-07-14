import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../../res/dimens.dart';
import '../../res/gaps.dart';
import '../../res/styles.dart';
import '../../util/notification.dart';
import '../../widgets/load_image.dart';
import '../../widgets/popup_window.dart';
import '../widget/goods_add_menu.dart';
import 'package:http/http.dart' as http;
import '../widget/scan_results.dart';
import '../widget/scan_results10.dart';
import '../widget/scan_results3.dart';
import '../widget/scan_results6.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {

  final GlobalKey _addKey = GlobalKey();
  late Timer timer,timer2,timer3;
  late String lat,long,time,speed,direction;
  bool isStart = false;
  bool hide = false;

  Future<bool> onWillPop() async{
    return false;
  }

  void getCurrentLocation() async{
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      lat = position.latitude.toString();
      long = position.longitude.toString();
      time = position.timestamp.millisecondsSinceEpoch.toString();
      speed = position.speed.toString();
      direction = position.heading.toString();
    });
  }
  
  void addSensorRead(int i) async {
    var response = await http.post(
      Uri.parse("https://admin.sirius-iot.eu/Mobile/API/SiotDriver2022/Android/sensor_read.php"),
      body: {
        "uuid_user":Hive.box('SENSOR_READ').getAt(i)["uuid_user"],
        "MacAddrs": Hive.box('SENSOR_READ').getAt(i)["MacAddrs"],
        "temperature": Hive.box('SENSOR_READ').getAt(i)["temperature"],
        "humidity": Hive.box('SENSOR_READ').getAt(i)["humidity"],
        "luminosite": Hive.box('SENSOR_READ').getAt(i)["luminosite"],
        "presure": Hive.box('SENSOR_READ').getAt(i)["presure"],
        "lowsignal_strength": Hive.box('SENSOR_READ').getAt(i)["lowsignal_strength"],
        "InfoDate": Hive.box('SENSOR_READ').getAt(i)["InfoDate"],
        "gps_lat": Hive.box('SENSOR_READ').getAt(i)["gps_lat"],
        "gps_long": Hive.box('SENSOR_READ').getAt(i)["gps_long"],
        "gps_time": Hive.box('SENSOR_READ').getAt(i)["gps_time"],
        "gps_speed": Hive.box('SENSOR_READ').getAt(i)["gps_speed"],
        "gps_direction": Hive.box('SENSOR_READ').getAt(i)["gps_direction"],
        "battery_level": Hive.box('SENSOR_READ').getAt(i)["battery_level"],
      },
    ); 
    var result = jsonDecode(response.body);
    print(Hive.box('SENSOR_READ').length);
    if(result['INFOS_REGISTRATION']['error'] == "false") {
      await Hive.box('SENSOR_READ').deleteAt(i);
    }
  }

  void addEnd(int i) async {
    var response = await http.post(
      Uri.parse("https://admin.sirius-iot.eu/Mobile/API/SiotDriver2022/Android/sensor_activity_start_end.php"),
      body: {
        "uuid_user":Hive.box('ACTIVITY_START_END').getAt(i)["uuid_user"],
        "activity_type": Hive.box('ACTIVITY_START_END').getAt(i)["activity_type"],
        "activity_date_heur": Hive.box('ACTIVITY_START_END').getAt(i)["activity_date_heur"],
        "gps_lat": Hive.box('ACTIVITY_START_END').getAt(i)["gps_lat"],
        "gps_long": Hive.box('ACTIVITY_START_END').getAt(i)["gps_long"],
        "gps_time": Hive.box('ACTIVITY_START_END').getAt(i)["gps_time"],
        "gps_speed": Hive.box('ACTIVITY_START_END').getAt(i)["gps_speed"],
        "gps_direction": Hive.box('ACTIVITY_START_END').getAt(i)["gps_direction"]
      },
    ); 
    var result = jsonDecode(response.body);
    print(result);
    if(result['ACTIVITY_START_END']['error'] == "false") {
      await Hive.box('ACTIVITY_START_END').deleteAt(i);
    }
  }

  List<ScanResult> scanResults = [];
  late StreamSubscription<List<ScanResult>> scanResultsSubscription;

  Type3SensorRead(ScanResult result) async{
    for(int i=0;i<Hive.box('LIST_CAPTEURS').length;i++){
      if(result.device.remoteId.str == Hive.box('LIST_CAPTEURS').getAt(i)['MacAddrs'] && Hive.box('LIST_CAPTEURS').getAt(i)['Type'] == '3'){
        var manufacturerData = Uint8List.fromList(result.advertisementData.serviceData[Guid("2a6e")]!);
        var temp = ByteData.sublistView(manufacturerData,0,2).getUint16(0,Endian.little).toRadixString(2);
        if(temp.length < 16) { temp = temp.padLeft(16,'0'); }
        if(temp.startsWith('1')){
          temp = temp.replaceAll("0"," ");
          temp = temp.replaceAll("1","0");
          temp = temp.replaceAll(" ","1");
          int decimalValue = int.parse(temp,radix: 2);
          decimalValue = (decimalValue + 1) * -1;
          temp = (decimalValue*0.01).toStringAsFixed(2);
        }else{
          temp = ((int.parse(temp,radix: 2))*0.01).toStringAsFixed(2);
        }
        if(items.where(
          (element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).isEmpty || 
          items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).last["InfoDate"] < result.timeStamp.millisecondsSinceEpoch) {
          await Hive.box('SENSOR_READ').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": temp,
            "humidity": "",
            "luminosite": "",
            "presure": "",
            "lowsignal_strength": result.rssi.toString(),
            "InfoDate": result.timeStamp.millisecondsSinceEpoch.toString(),
            "gps_lat": lat,
            "gps_long": long,
            "gps_time": time,
            "gps_speed": speed,
            "gps_direction": direction,
            "battery_level": ""
          });
          await Hive.box('SENSOR_READ1').add({
          "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
          "MacAddrs": result.device.remoteId.str,
          "temperature": double.parse(temp),
          "humidity": null,
          "presure": null,
          "InfoDate": result.timeStamp.millisecondsSinceEpoch
          });
          if( (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          ){NotificationService.showSimpleNotification(3,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=false;});}
        } 
        if(!hide && ((itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          )){NotificationService.showSimpleNotification(3,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=true;});}
      }
    }
  }
  Type1SensorRead(ScanResult result) async{
    for(int i=0;i<Hive.box('LIST_CAPTEURS').length;i++){
      if(result.device.remoteId.str == Hive.box('LIST_CAPTEURS').getAt(i)['MacAddrs'] && Hive.box('LIST_CAPTEURS').getAt(i)['Type'] == '1'){
        var manufacturerData = Uint8List.fromList(result.advertisementData.manufacturerData[1177]!);
        var temp = ByteData.sublistView(manufacturerData,1,3).getUint16(0,Endian.big).toRadixString(2);
        var hum = (ByteData.sublistView(manufacturerData,3,5).getUint16(0,Endian.big)/400).toStringAsFixed(2);
        var press = ((ByteData.sublistView(manufacturerData,5,7).getUint16(0,Endian.big)+50000)/100).toStringAsFixed(2);
        var hh = (ByteData.sublistView(manufacturerData,13,15).getUint16(0,Endian.big).toRadixString(2));
        var vol = int.parse(hh.substring(0,11),radix: 2) + 1600;
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
        if(
          items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).isEmpty || items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).last["InfoDate"] < result.timeStamp.millisecondsSinceEpoch) {
          await Hive.box('SENSOR_READ').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": temp,
            "humidity": hum,
            "luminosite": "",
            "presure": press,
            "lowsignal_strength": result.rssi.toString(),
            "InfoDate": result.timeStamp.millisecondsSinceEpoch.toString(),
            "gps_lat": lat,
            "gps_long": long,
            "gps_time": time,
            "gps_speed": speed,
            "gps_direction": direction,
            "battery_level": vol.toString()
          });
          await Hive.box('SENSOR_READ1').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": double.parse(temp),
            "humidity": double.parse(hum),
            "presure": double.parse(press),
            "InfoDate": result.timeStamp.millisecondsSinceEpoch
          });
          if( (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedpresure"] == '1' && (double.parse(press) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowpresure"] || double.parse(press) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highpresure"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          ){NotificationService.showSimpleNotification(1,"SIOT Driver",/*"Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'."*/"${result.timeStamp}");setState(() {hide=false;});}
        } 
        if(!hide && ((itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedpresure"] == '1' && (double.parse(press) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowpresure"] || double.parse(press) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highpresure"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          )){NotificationService.showSimpleNotification(1,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=true;});}
        
      }
    }
  }
  Type5SensorRead(ScanResult result) async{
    for(int i=0;i<Hive.box('LIST_CAPTEURS').length;i++){
      if(result.device.remoteId.str == Hive.box('LIST_CAPTEURS').getAt(i)['MacAddrs'] && Hive.box('LIST_CAPTEURS').getAt(i)['Type'] == '5' ){
        var manufacturerData = Uint8List.fromList(result.advertisementData.manufacturerData[65535]!);
        var temp = (ByteData.sublistView(manufacturerData,7,9).getUint16(0,Endian.little)).toRadixString(2);
        var light = ((ByteData.sublistView(manufacturerData,11,13).getUint16(0,Endian.little))*0.01).toStringAsFixed(2);
        var hum = ((ByteData.sublistView(manufacturerData,9,11).getUint16(0,Endian.little))*0.01).toStringAsFixed(2);
        var vol = ((ByteData.sublistView(manufacturerData,5,null).getUint16(0,Endian.little))*100).toStringAsFixed(0);
        if(temp.length < 16) { temp = temp.padLeft(16,'0'); }
        if(temp.startsWith('1')){
          temp = temp.replaceAll("0"," ");
          temp = temp.replaceAll("1","0");
          temp = temp.replaceAll(" ","1");
          int decimalValue = int.parse(temp,radix: 2);
          decimalValue = (decimalValue + 1) * -1;
          temp = (decimalValue*0.01).toStringAsFixed(2);
        }else{
          temp = ((int.parse(temp,radix: 2))*0.01).toStringAsFixed(2);
        }
        if(items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).isEmpty || items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).last["InfoDate"] < result.timeStamp.millisecondsSinceEpoch) {
          await Hive.box('SENSOR_READ').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": temp,
            "humidity": hum,
            "luminosite": light,
            "presure": "",
            "lowsignal_strength": result.rssi.toString(),
            "InfoDate": result.timeStamp.millisecondsSinceEpoch.toString(),
            "gps_lat": lat,
            "gps_long": long,
            "gps_time": time,
            "gps_speed": speed,
            "gps_direction": direction,
            "battery_level": vol
          });
          await Hive.box('SENSOR_READ1').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": double.parse(temp),
            "humidity": double.parse(hum),
            "presure": null,
            "InfoDate": result.timeStamp.millisecondsSinceEpoch
          });
          if( (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedluminosite"] == '1' && (double.parse(light) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowluminosite"] || double.parse(light) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highluminosite"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          ){NotificationService.showSimpleNotification(6,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=false;});}
        }
        if(!hide && ((itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedluminosite"] == '1' && (double.parse(light) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowluminosite"] || double.parse(light) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highluminosite"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          )){NotificationService.showSimpleNotification(6,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=true;});}
      }
    }
  }
  
  Type6SensorRead(ScanResult result) async{
    for(int i=0;i<Hive.box('LIST_CAPTEURS').length;i++){
      if(result.device.remoteId.str == Hive.box('LIST_CAPTEURS').getAt(i)['MacAddrs'] && Hive.box('LIST_CAPTEURS').getAt(i)['Type'] == '6' ){
        var manufacturerData = Uint8List.fromList(result.advertisementData.manufacturerData[65535]!);
        var temp = (ByteData.sublistView(manufacturerData,7,9).getUint16(0,Endian.little)).toRadixString(2);
        var light = ((ByteData.sublistView(manufacturerData,11,13).getUint16(0,Endian.little))*0.01).toStringAsFixed(2);
        var hum = ((ByteData.sublistView(manufacturerData,9,11).getUint16(0,Endian.little))*0.01).toStringAsFixed(2);
        var vol = ((ByteData.sublistView(manufacturerData,5,null).getUint16(0,Endian.little))*100).toStringAsFixed(0);
        if(temp.length < 16) { temp = temp.padLeft(16,'0'); }
        if(temp.startsWith('1')){
          temp = temp.replaceAll("0"," ");
          temp = temp.replaceAll("1","0");
          temp = temp.replaceAll(" ","1");
          int decimalValue = int.parse(temp,radix: 2);
          decimalValue = (decimalValue + 1) * -1;
          temp = (decimalValue*0.01).toStringAsFixed(2);
        }else{
          temp = ((int.parse(temp,radix: 2))*0.01).toStringAsFixed(2);
        }
        if(items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).isEmpty || items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).last["InfoDate"] < result.timeStamp.millisecondsSinceEpoch) {
          await Hive.box('SENSOR_READ').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": temp,
            "humidity": hum,
            "luminosite": light,
            "presure": "",
            "lowsignal_strength": result.rssi.toString(),
            "InfoDate": result.timeStamp.millisecondsSinceEpoch.toString(),
            "gps_lat": lat,
            "gps_long": long,
            "gps_time": time,
            "gps_speed": speed,
            "gps_direction": direction,
            "battery_level": vol
          });
          await Hive.box('SENSOR_READ1').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": double.parse(temp),
            "humidity": double.parse(hum),
            "presure": null,
            "InfoDate": result.timeStamp.millisecondsSinceEpoch
          });
          if( (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedluminosite"] == '1' && (double.parse(light) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowluminosite"] || double.parse(light) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highluminosite"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          ){NotificationService.showSimpleNotification(6,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=false;});}
        }
        if(!hide && ((itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedluminosite"] == '1' && (double.parse(light) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowluminosite"] || double.parse(light) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highluminosite"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          )){NotificationService.showSimpleNotification(6,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=true;});}
      }
    }
  }
  
  Type10SensorRead(ScanResult result) async{
    for(int i=0;i<Hive.box('LIST_CAPTEURS').length;i++){
      if(result.device.remoteId.str == Hive.box('LIST_CAPTEURS').getAt(i)['MacAddrs'] && Hive.box('LIST_CAPTEURS').getAt(i)['Type'] == '10'){
        var manufacturerData = Uint8List.fromList(result.advertisementData.manufacturerData[3278]!);
        var hum = (((manufacturerData[16] << 8) | manufacturerData[17]) / 100.0).toStringAsFixed(2);
        var temp = (((manufacturerData[14] << 8) | manufacturerData[15]) / 100.0).toStringAsFixed(2);
        var vol = (((manufacturerData[11] << 8) | manufacturerData[12]) / 1000.0).toStringAsFixed(2);
        if(
          items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).isEmpty || items.where((element) => element["uuid_user"] == Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"] && element["MacAddrs"] == result.device.remoteId.str).last["InfoDate"] < result.timeStamp.millisecondsSinceEpoch) {
          await Hive.box('SENSOR_READ').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": temp,
            "humidity": hum,
            "luminosite": "",
            "presure": "",
            "lowsignal_strength": result.rssi.toString(),
            "InfoDate": result.timeStamp.millisecondsSinceEpoch.toString(),
            "gps_lat": lat,
            "gps_long": long,
            "gps_time": time,
            "gps_speed": speed,
            "gps_direction": direction,
            "battery_level": vol.toString()
          });
          await Hive.box('SENSOR_READ1').add({
            "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
            "MacAddrs": result.device.remoteId.str,
            "temperature": double.parse(temp),
            "humidity": double.parse(hum),
            "InfoDate": result.timeStamp.millisecondsSinceEpoch
          });
          if( (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          ){NotificationService.showSimpleNotification(1,"SIOT Driver",/*"Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'."*/"${result.timeStamp}");setState(() {hide=false;});}
        } 
        if(!hide && ((itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedtemperature"] == '1' && (double.parse(temp) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowtemperature"] || double.parse(temp) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["hightemperature"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedhumidity"] == '1' && (double.parse(hum) < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowhumidity"] || double.parse(hum) > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highhumidity"])) ||
            (itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["checkedsignal_strength"] == '1' && (result.rssi < itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["lowsignal_strength"] || result.rssi > itemsAlert.elementAt(itemsAlert.indexWhere((item) => item["MacAddrs"] == result.device.remoteId.str))["highsignal_strength"]))
          )){NotificationService.showSimpleNotification(1,"SIOT Driver","Problèmes dans le capteur '${Hive.box('LIST_CAPTEURS').get(i)["Name"]}'.");setState(() {hide=true;});}
        
      }
    }
  }
  List<Map<String, dynamic>> items = [];
  final sensor = Hive.box('SENSOR_READ1');
  void refresh() {
    final data = sensor.keys.map((key) {
      final item = sensor.get(key);
      return {"key":key,
        "uuid_user": item["uuid_user"],
        "MacAddrs": item["MacAddrs"],
        "temperature": item["temperature"],
        "humidity": item["humidity"],
        "presure": item["presure"],
        "InfoDate": item["InfoDate"]
      };
    }).toList();
    setState(() {
      items = data.toList();
    });
  }

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
      itemsAlert = data.toList();
    });
  }
  
  @override
  void initState() {
    if(Hive.box('ACTIVITY_START_END').isNotEmpty && Hive.box('ACTIVITY_START_END').values.last["activity_type"] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) { 
        showDialog(
          context: context, 
          builder: (context) => AlertDialog(
            content: const Text("Vous avez déjà commencé une mission. Continue?"),
            actions: [
              TextButton(onPressed: (){setState(() {isStart = !isStart;});Navigator.pop(context);}, child: Text("Oui")),
              TextButton(onPressed: ()async{await Hive.box('ACTIVITY_START_END').add({
                "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
                "activity_type": '2',
                "activity_date_heur": DateTime.now().toString().substring(0,19),
                "gps_lat": lat,
                "gps_long": long,
                "gps_time": time,
                "gps_speed": speed,
                "gps_direction": direction
              });;Navigator.pop(context);}, child: Text("Non"))
            ],
          ),
        );
      });
    }
    getCurrentLocation();
    FlutterBluePlus.startScan();
    hide = false;
    scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results; print(results.last);
      if(mounted){setState(() {});}
    });
    timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      checkConnect();
    });
    timer2 = Timer.periodic(const Duration(seconds: 5), (timer) {
      getCurrentLocation();
      refreshAlert();
      refresh();
    });
    timer3 = Timer.periodic(Duration(seconds: int.parse(Hive.box('LOGGED_IN_USER').getAt(0)["user_store_interval"]) * 60), (timer) {
      taming(scanResults);
    });
    super.initState();
  }

  Future<void> checkConnect() async{
    bool result = await InternetConnection().hasInternetAccess;
    if (result) {
      print('connected');
      if(result && Hive.box('SENSOR_READ').isNotEmpty) {addSensorRead(0);}
      if(result && Hive.box('ACTIVITY_START_END').isNotEmpty) {addEnd(0);}
    }
  }

  Future<void> taming(List<ScanResult> scans) async{
    for(int i=0;i<scans.length;i++){
      await Type1SensorRead(scans[i]);
      await Type3SensorRead(scans[i]);
      await Type5SensorRead(scans[i]);
      await Type6SensorRead(scans[i]);
      await Type10SensorRead(scans[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color? iconColor = null;
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 150,
          leading: Row(
            children: [
              const SizedBox(width: 4),
              SizedBox(height: 40,width: 40,child: Image.asset('assets/images/login/logo.png',color: Colors.black,)),
              const Text('SIOT Driver',style: TextStyle(color: Colors.black,fontWeight: FontWeight.normal,fontSize: Dimens.font_sp16)),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Commencer mission',
              onPressed: !isStart ?() async{
                await Hive.box('ACTIVITY_START_END').add({
                  "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
                  "activity_type": '1',
                  "activity_date_heur": DateTime.now().toString().substring(0,19),
                  "gps_lat": lat,
                  "gps_long": long,
                  "gps_time": time,
                  "gps_speed": speed,
                  "gps_direction": direction
                });
                setState(() {isStart = !isStart;});
              } : null,
              icon: Icon(Icons.play_circle_outline,color:!isStart ?Colors.black :Colors.grey,size: 24,)
            ),
            IconButton(
              tooltip: 'Terminer mission',
              onPressed: isStart ?() async{
                await Hive.box('ACTIVITY_START_END').add({
                  "uuid_user": Hive.box('LOGGED_IN_USER').getAt(0)["uuid_user"],
                  "activity_type": '2',
                  "activity_date_heur": DateTime.now().toString().substring(0,19),
                  "gps_lat": lat,
                  "gps_long": long,
                  "gps_time": time,
                  "gps_speed": speed,
                  "gps_direction": direction
                });
                setState(() {isStart = !isStart;});
              } :null,
              icon: Icon(Icons.pause_circle_outline,color:isStart ?Colors.black :Colors.grey,size: 24,)
            ),
            IconButton(
              tooltip: 'Paramètres',
              key: _addKey,
              onPressed: _showAddMenu,
              icon: const LoadAssetImage(
                'home/setting.png',
                key: Key('add'),
                width: 24.0,
                height: 24.0,
                color: iconColor,
              ),
            )
          ],
        ),
        body: scanResults.isEmpty? Center(child: CircularProgressIndicator())
            :Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Image.asset('assets/images/home/xdd_n.png', width: 24.0, height: 24.0),
                        Gaps.hGap5,
                        const Text('Mes Capteurs',style: TextStyles.textBold18),
                      ]
                    ),
                    Text('${Hive.box('LIST_CAPTEURS').length} capteurs affecter',style: TextStyles.textDarkGray12)
                  ]
                )
              ),
              const SizedBox(height: 10),
              Expanded(child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  Column(children: [
                    for (int i = 0 ; i< scanResults.length ; i++)
                      for(int j = 0 ; j < Hive.box('LIST_CAPTEURS').length; j++)
                        if(scanResults[i].device.remoteId.str == Hive.box('LIST_CAPTEURS').get(j)["MacAddrs"])
                         Column(children: [
                          if(Hive.box('LIST_CAPTEURS').get(j)["Type"] == '1')
                            ScanResults(
                              result: scanResults[i],
                              type: '1',
                              param: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_param"],
                              print: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_print"],
                              report:Hive.box('LOGGED_IN_USER').getAt(0)["user_can_report"],
                              name: Hive.box('LIST_CAPTEURS').get(j)["Name"],
                            ),
                          if(Hive.box('LIST_CAPTEURS').get(j)["Type"] == '3')
                            ScanResults3(
                              result: scanResults[i],
                              type: '3',
                              param: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_param"],
                              print: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_print"],
                              report:Hive.box('LOGGED_IN_USER').getAt(0)["user_can_report"],
                              name: Hive.box('LIST_CAPTEURS').get(j)["Name"],
                            ),
                          if(Hive.box('LIST_CAPTEURS').get(j)["Type"] == '5')
                            ScanResults6(
                              result: scanResults[i],
                              type: '5',
                              param: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_param"],
                              print: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_print"],
                              report:Hive.box('LOGGED_IN_USER').getAt(0)["user_can_report"],
                              name: Hive.box('LIST_CAPTEURS').get(j)["Name"],
                            ),
                          if(Hive.box('LIST_CAPTEURS').get(j)["Type"] == '6')
                            ScanResults6(
                              result: scanResults[i],
                              type: '6',
                              param: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_param"],
                              print: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_print"],
                              report:Hive.box('LOGGED_IN_USER').getAt(0)["user_can_report"],
                              name: Hive.box('LIST_CAPTEURS').get(j)["Name"],
                            ),
                          if(Hive.box('LIST_CAPTEURS').get(j)["Type"] == '10')
                            ScanResults10(
                              result: scanResults[i],
                              type: '10',
                              param: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_param"],
                              print: Hive.box('LOGGED_IN_USER').getAt(0)["user_can_print"],
                              report:Hive.box('LOGGED_IN_USER').getAt(0)["user_can_report"],
                              name: Hive.box('LIST_CAPTEURS').get(j)["Name"],
                            ),
                          const SizedBox(height: 10)
                         ])
                  ])
                ]
              ))
            ])
      ),
    );
  }

  void _showAddMenu() {
    final RenderBox button = _addKey.currentContext!.findRenderObject()! as RenderBox;
    showPopupWindow<void>(
      context: context,
      isShowBg: true,
      offset: Offset(button.size.width - 8.0, -12.0),
      anchor: button,
      child: const GoodsAddMenu(),
    );
  }
}

