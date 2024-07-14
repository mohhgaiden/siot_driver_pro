import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import '../../res/gaps.dart';
import '../../res/styles.dart';
import '../../util/change_notifier_manage.dart';
import '../../widgets/my_app_bar.dart';
import '../../widgets/my_button.dart';
import '../../widgets/my_scroll_view.dart';
import '../widget/my_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with ChangeNotifierMixin<LoginPage>{

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  bool _clickable = false; bool click = false;
  String tt = "© Copyrights SIRIUS NET 2021. Tous droits réservés.";

  Future<bool> onWillPop() async{
    return false;
  }

  @override
  Map<ChangeNotifier, List<VoidCallback>?>? changeNotifier() {
    final List<VoidCallback> callbacks = <VoidCallback>[_verify];
    return <ChangeNotifier, List<VoidCallback>?>{
      _nameController: callbacks,
      _passwordController: callbacks,
      _nodeText1: null,
      _nodeText2: null,
    };
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
    refreshAlert();
    super.initState();
    if(Hive.box('USER_PASS').isNotEmpty) { 
      click = true;
      _nameController.text = Hive.box('USER_PASS').getAt(0)["user"];
      _passwordController.text = Hive.box('USER_PASS').getAt(0)["pass"]; 
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    });
  }

  void _verify() {
    final String name = _nameController.text;
    final String password = _passwordController.text;
    bool clickable = true;
    if (name.isEmpty || name.length < 6) {
      clickable = false;
    }
    if (password.isEmpty || password.length < 5) {
      clickable = false;
    }
    if (clickable != _clickable) {
      setState(() {
        _clickable = clickable;
      });
    }
  }
  
  void listCapteur(String uuid) async {
    var response = await http.post(
      Uri.parse('https://admin.sirius-iot.eu/Mobile/API/SiotDriver2022/Android/list_Tags_Readings.php'),
      body: {'uuid_user': uuid}
    ); var result = jsonDecode(response.body);
    if(result['LIST_CAPTEURS']['error'] == "false" && Hive.box('LIST_CAPTEURS').isEmpty) {
      for(int i = 0;i<result['LIST_CAPTEURS']['Nbr_capteurs'];i++) {
        //fetch list Capteurs
        await Hive.box('LIST_CAPTEURS').add({
          "MacAddrs": result['LIST_CAPTEURS']['LIST'][i]["MacAddrs"],
          "Name": result['LIST_CAPTEURS']['LIST'][i]["Name"],
          "Type": result['LIST_CAPTEURS']['LIST'][i]["Type"],
          "RemoteAlert": result['LIST_CAPTEURS']['LIST'][i]["RemoteAlert"],
          "Option_stockage": result['LIST_CAPTEURS']['LIST'][i]["Option_stockage"],
          "interval_stockage": result['LIST_CAPTEURS']['LIST'][i]["interval_stockage"]
        });
        //add user Alert
        if(itemsAlert.isEmpty || itemsAlert.where((element) => element["uuid_user"] == uuid && element["MacAddrs"] == result['LIST_CAPTEURS']['LIST'][i]["MacAddrs"]).isEmpty){
          await Hive.box('Alert').add({
            "uuid_user": uuid,
            "MacAddrs": result['LIST_CAPTEURS']['LIST'][i]["MacAddrs"],
            "checkedtemperature": "0",
            "lowtemperature": -40.0,
            "hightemperature": 85.0,
            "checkedhumidity": "0",
            "lowhumidity": 0.0,
            "highhumidity": 100.0,
            "checkedpresure": "0",
            "lowpresure": 300.0,
            "highpresure": 1100.0,
            "checkedsignal_strength": "0",
            "lowsignal_strength": -105.0,
            "highsignal_strength": 0.0,
            "checkedluminosite": "0",
            "lowluminosite": 0.0,
            "highluminosite": 83000.0,
          });
        }
      }
    }
  }

  void _login(String name, String pass) async {
  
    var response = await http.post(
      Uri.parse("https://admin.sirius-iot.eu/Mobile/API/SiotDriver2022/Android/login.php"),
      body: {'username': name,'password': pass}
    ); var result = jsonDecode(response.body);
    if(result['LOGGED_IN_USER']['error'] == "true"){
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0))
          ),
          content: Container(
            height: 230,
            child: Column(children: <Widget>[
              Icon(
                Icons.error_outline_rounded,
                size: 96,
                color: Color(0xFFF93963)
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(result['LOGGED_IN_USER']['msg']),
              ),
              TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all( Color(0xFFF93963)),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ),
                onPressed: () => {},
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Expanded(child: InkWell(
                        onTap: () {Navigator.pop(context);},
                        child: Text(
                          "Réessayer",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    }
    if(result['LOGGED_IN_USER']['error'] == "false"){
      //user information 
      if(Hive.box('LOGGED_IN_USER').isEmpty) {
        await Hive.box('LOGGED_IN_USER').add({
        "error": result['LOGGED_IN_USER']['error'],
        "connection_established": result['LOGGED_IN_USER']['connection_established'],
        "msg": result['LOGGED_IN_USER']['msg'],
        "uuid_user": result['LOGGED_IN_USER']['uuid_user'],
        "user_name": result['LOGGED_IN_USER']['user_name'],
        "user_surname": result['LOGGED_IN_USER']['user_surname'],
        "user_phone": result['LOGGED_IN_USER']['user_phone'],
        "user_can_param": result['LOGGED_IN_USER']['user_can_param'],
        "user_can_report": result['LOGGED_IN_USER']['user_can_report'],
        "user_can_print": result['LOGGED_IN_USER']['user_can_print'],
        "user_can_stor": result['LOGGED_IN_USER']['user_can_stor'],
        "user_langue": result['LOGGED_IN_USER']['user_langue'],
        "user_clear_interval": result['LOGGED_IN_USER']['user_clear_interval'],
        "user_store_interval": result['LOGGED_IN_USER']['user_store_interval']
        });
      }
      if(click == true) {
        if(Hive.box('USER_PASS').isEmpty){
          await Hive.box('USER_PASS').add({
            "user": name,
            "pass": pass
          });
        } else {
          await Hive.box('USER_PASS').putAt(0, {
            "user": name,
            "pass": pass
          });           
        }
      }else{ Hive.box('USER_PASS').clear(); }
      listCapteur(result['LOGGED_IN_USER']['uuid_user']);
      
    }
    setState(() {
      _passwordController.clear();
      _nameController.clear();
      _nodeText1.requestFocus();
    });
  
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: const MyAppBar(
          isBack: false,
          centerTitle: 'SIOT Driver'
        ),
        body: MyScrollView(
          keyboardConfig: getKeyboardActionsConfig(context, <FocusNode>[_nodeText1, _nodeText2]),
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
          children: _buildBody,
          bottomButton: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tt,style: TextStyles.textGray12)
          )
        ),    
      ),
    );
  }

  List<Widget> get _buildBody => <Widget>[
    SizedBox(
      height: MediaQuery.of(context).size.width/2.5,
      width: MediaQuery.of(context).size.width/2.5,
      child: Image.asset('assets/images/ic_launcher-playstore.png')
    ),
    const Text(
      "Se connecter à votre compte",
      style: TextStyles.textBold24,
    ),
    Gaps.vGap16,
    MyTextField(
      key: const Key('phone'),
      focusNode: _nodeText1,
      controller: _nameController,
      maxLength: 11,
      keyboardType: TextInputType.text,
      hintText: "Utilisateur",
    ),
    Gaps.vGap8,
    MyTextField(
      key: const Key('password'),
      keyName: 'password',
      focusNode: _nodeText2,
      isInputPwd: true,
      controller: _passwordController,
      keyboardType: TextInputType.visiblePassword,
      hintText: "Mot de passe",
    ),
    Row(
      children: [
        Text("Enregistrer le mot de passe",style: TextStyles.textGray12),
        Checkbox(value: click, onChanged: (bool){ click = !click; setState(() {});})
      ],
    ),
    Gaps.vGap4,
    MyButton(
      key: const Key('login'),
      onPressed: _clickable ? () => _login(_nameController.text.toString(),_passwordController.text.toString()) : null,
      text: "Connecter",
    ),
  ];

  static KeyboardActionsConfig getKeyboardActionsConfig(BuildContext context, List<FocusNode> list) {
    return KeyboardActionsConfig(
      keyboardBarColor:  Colors.grey[200],
      actions: List.generate(list.length, (i) => KeyboardActionsItem(
        focusNode: list[i],
        toolbarButtons: [
          (node) {
            return GestureDetector(
              onTap: () => node.unfocus(),
              child: const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Text('Close'),
              ),
            );
          },
        ],
      )),
    );
  }
  
}

