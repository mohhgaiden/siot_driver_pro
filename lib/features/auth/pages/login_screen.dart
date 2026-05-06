import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import '../../../core/constants/gaps.dart';
import '../../../core/constants/styles.dart';
import '../../../core/utils/change_notifier_manage.dart';
import '../../../common/my_button.dart';
import '../../../common/my_scroll_view.dart';
import '../widgets/my_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with ChangeNotifierMixin<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _nodeText1 = FocusNode();
  final FocusNode _nodeText2 = FocusNode();
  bool _clickable = false;
  bool click = false;
  final String _copyright =
      "© Copyrights SIRIUS NET 2021. Tous droits réservés.";

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

  List<Map<String, dynamic>> _itemsAlert = [];
  final _alert = Hive.box('Alert');

  void _refreshAlert() {
    final data =
        _alert.keys.map((key) {
          final item = _alert.get(key);
          return {
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
        }).toList();
    setState(() => _itemsAlert = data);
  }

  @override
  void initState() {
    _refreshAlert();
    super.initState();
    if (Hive.box('USER_PASS').isNotEmpty) {
      click = true;
      _nameController.text = Hive.box('USER_PASS').getAt(0)['user'];
      _passwordController.text = Hive.box('USER_PASS').getAt(0)['pass'];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
    });
  }

  void _verify() {
    final bool clickable =
        _nameController.text.length >= 6 &&
        _passwordController.text.length >= 5;
    if (clickable != _clickable) {
      setState(() => _clickable = clickable);
    }
  }

  void _listCapteur(String uuid) async {
    final response = await http.post(
      Uri.parse(
        'https://sirius-iot.app/Admin/Mobile/API/SiotDriver2022/Android/list_Tags_Readings.php',
      ),
      body: {'uuid_user': uuid},
    );
    final result = jsonDecode(response.body);
    if (result['LIST_CAPTEURS']['error'] == 'false' &&
        Hive.box('LIST_CAPTEURS').isEmpty) {
      for (int i = 0; i < result['LIST_CAPTEURS']['Nbr_capteurs']; i++) {
        await Hive.box('LIST_CAPTEURS').add({
          'MacAddrs': result['LIST_CAPTEURS']['LIST'][i]['MacAddrs'],
          'Name': result['LIST_CAPTEURS']['LIST'][i]['Name'],
          'Type': result['LIST_CAPTEURS']['LIST'][i]['Type'],
          'RemoteAlert': result['LIST_CAPTEURS']['LIST'][i]['RemoteAlert'],
          'Option_stockage':
              result['LIST_CAPTEURS']['LIST'][i]['Option_stockage'],
          'interval_stockage':
              result['LIST_CAPTEURS']['LIST'][i]['interval_stockage'],
        });
        final mac = result['LIST_CAPTEURS']['LIST'][i]['MacAddrs'];
        final alreadyExists =
            _itemsAlert.isNotEmpty &&
            _itemsAlert.any(
              (e) => e['uuid_user'] == uuid && e['MacAddrs'] == mac,
            );
        if (!alreadyExists) {
          await Hive.box('Alert').add({
            'uuid_user': uuid,
            'MacAddrs': mac,
            'checkedtemperature': '0',
            'lowtemperature': -40.0,
            'hightemperature': 85.0,
            'checkedhumidity': '0',
            'lowhumidity': 0.0,
            'highhumidity': 100.0,
            'checkedpresure': '0',
            'lowpresure': 300.0,
            'highpresure': 1100.0,
            'checkedsignal_strength': '0',
            'lowsignal_strength': -105.0,
            'highsignal_strength': 0.0,
            'checkedluminosite': '0',
            'lowluminosite': 0.0,
            'highluminosite': 83000.0,
          });
        }
      }
    }
  }

  void _login(String name, String pass) async {
    final response = await http.post(
      Uri.parse(
        'https://sirius-iot.app/Admin/Mobile/API/SiotDriver2022/Android/login.php',
      ),
      body: {'username': name, 'password': pass},
    );
    final result = jsonDecode(response.body);

    if (result['LOGGED_IN_USER']['error'] == 'true') {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 72,
                    color: Color(0xFFF93963),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result['LOGGED_IN_USER']['msg'],
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF93963),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Réessayer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
    }

    if (result['LOGGED_IN_USER']['error'] == 'false') {
      if (Hive.box('LOGGED_IN_USER').isEmpty) {
        await Hive.box('LOGGED_IN_USER').add({
          'error': result['LOGGED_IN_USER']['error'],
          'connection_established':
              result['LOGGED_IN_USER']['connection_established'],
          'msg': result['LOGGED_IN_USER']['msg'],
          'uuid_user': result['LOGGED_IN_USER']['uuid_user'],
          'user_name': result['LOGGED_IN_USER']['user_name'],
          'user_surname': result['LOGGED_IN_USER']['user_surname'],
          'user_phone': result['LOGGED_IN_USER']['user_phone'],
          'user_can_param': result['LOGGED_IN_USER']['user_can_param'],
          'user_can_report': result['LOGGED_IN_USER']['user_can_report'],
          'user_can_print': result['LOGGED_IN_USER']['user_can_print'],
          'user_can_stor': result['LOGGED_IN_USER']['user_can_stor'],
          'user_langue': result['LOGGED_IN_USER']['user_langue'],
          'user_clear_interval':
              result['LOGGED_IN_USER']['user_clear_interval'],
          'user_store_interval':
              result['LOGGED_IN_USER']['user_store_interval'],
          'interval_affichage': "5",
          'interval_stockage': "10",
          'interval_sync': "30",
        });
      }
      if (click) {
        if (Hive.box('USER_PASS').isEmpty) {
          await Hive.box('USER_PASS').add({'user': name, 'pass': pass});
        } else {
          await Hive.box('USER_PASS').putAt(0, {'user': name, 'pass': pass});
        }
      } else {
        Hive.box('USER_PASS').clear();
      }
      _listCapteur(result['LOGGED_IN_USER']['uuid_user']);
    }

    setState(() {
      _passwordController.clear();
      _nameController.clear();
      _nodeText1.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient azur en haut
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.38,
              child: Container(
                color: Color.fromRGBO(62, 127, 214, 1),
                /*
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
                ),*/
              ),
            ),
            // Fond blanc arrondi en bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: size.height * 0.67,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
              ),
            ),
            // Contenu principal
            SafeArea(
              child: Column(
                children: [
                  // Logo dans le gradient
                  SizedBox(
                    height: size.height * 0.30,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/login/logo_dark.png',
                            height: 100,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'SIOT Driver',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Formulaire dans le fond blanc
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      child: MyScrollView(
                        keyboardConfig: _keyboardActionsConfig(context, [
                          _nodeText1,
                          _nodeText2,
                        ]),
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 28,
                        ),
                        bottomButton: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _copyright,
                            textAlign: TextAlign.center,
                            style: TextStyles.textGray12,
                          ),
                        ),
                        children: _buildForm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> get _buildForm => <Widget>[
    const Text('Se connecter à votre compte', style: TextStyles.textBold24),
    Gaps.vGap16,
    MyTextField(
      key: const Key('phone'),
      focusNode: _nodeText1,
      controller: _nameController,
      maxLength: 11,
      keyboardType: TextInputType.text,
      hintText: 'Utilisateur',
    ),
    Gaps.vGap12,
    MyTextField(
      key: const Key('password'),
      keyName: 'password',
      focusNode: _nodeText2,
      isInputPwd: true,
      controller: _passwordController,
      keyboardType: TextInputType.visiblePassword,
      hintText: 'Mot de passe',
    ),
    Gaps.vGap8,
    Row(
      children: [
        Text('Enregistrer le mot de passe', style: TextStyles.textGray12),
        Checkbox(
          value: click,
          onChanged: (_) => setState(() => click = !click),
        ),
      ],
    ),
    Gaps.vGap16,
    MyButton(
      key: const Key('login'),
      radius: 12.0,
      onPressed:
          _clickable
              ? () => _login(_nameController.text, _passwordController.text)
              : null,
      text: 'Se connecter',
    ),
  ];

  static KeyboardActionsConfig _keyboardActionsConfig(
    BuildContext context,
    List<FocusNode> nodes,
  ) {
    return KeyboardActionsConfig(
      keyboardBarColor: Colors.grey[200],
      actions: List.generate(
        nodes.length,
        (i) => KeyboardActionsItem(
          focusNode: nodes[i],
          toolbarButtons: [
            (node) => GestureDetector(
              onTap: node.unfocus,
              child: const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
