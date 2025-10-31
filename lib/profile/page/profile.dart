import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
<<<<<<< HEAD
import '../../res/dimens.dart';
=======
>>>>>>> edc460f (Initial commit)
import '../../res/gaps.dart';
import '../../res/styles.dart';
import '../../widgets/load_image.dart';
import '../../widgets/my_app_bar.dart';
import '../../widgets/my_scroll_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
<<<<<<< HEAD
  
  List<Map<String, dynamic>> items = [];
  final infoUser = Hive.box('LOGGED_IN_USER');
  void refresh() {
    final data = infoUser.keys.map((key) {
      final item = infoUser.get(key);
      return {"key": key,
        "error": item["error"],
        "connection_established": item["connection_established"],
        "msg": item["msg"],
        "uuid_user": item["uuid_user"],
        "user_name": item["user_name"],
        "user_surname": item["user_surname"],
        "user_phone": item["user_phone"],
        "user_can_param": item["user_can_param"],
        "user_can_report": item["user_can_report"],
        "user_can_print": item["user_can_print"],
        "user_can_stor": item["user_can_stor"],
        "user_langue": item["user_langue"],
        "user_clear_interval": item["user_clear_interval"],
        "user_store_interval": item["user_store_interval"]
      };
    }).toList();
=======
  List<Map<String, dynamic>> items = [];
  final infoUser = Hive.box('LOGGED_IN_USER');
  void refresh() {
    final data =
        infoUser.keys.map((key) {
          final item = infoUser.get(key);
          return {
            "key": key,
            "error": item["error"],
            "connection_established": item["connection_established"],
            "msg": item["msg"],
            "uuid_user": item["uuid_user"],
            "user_name": item["user_name"],
            "user_surname": item["user_surname"],
            "user_phone": item["user_phone"],
            "user_can_param": item["user_can_param"],
            "user_can_report": item["user_can_report"],
            "user_can_print": item["user_can_print"],
            "user_can_stor": item["user_can_stor"],
            "user_langue": item["user_langue"],
            "user_clear_interval": item["user_clear_interval"],
            "user_store_interval": item["user_store_interval"],
          };
        }).toList();
>>>>>>> edc460f (Initial commit)
    setState(() {
      items = data.reversed.toList();
      print(items);
    });
  }

  List<Map<String, dynamic>> items1 = [];
  final listCapteurs = Hive.box('LIST_CAPTEURS');
  void refresh1() {
<<<<<<< HEAD
    final data = listCapteurs.keys.map((key) {
      final item = listCapteurs.get(key);
      return {"key": key,
        "MacAddrs": item["MacAddrs"],
        "Name": item["Name"],
        "Type": item["Type"],
        "RemoteAlert": item["RemoteAlert"],
        "Option_stockage": item["Option_stockage"],
        "interval_stockage": item["interval_stockage"]
      };
    }).toList();
=======
    final data =
        listCapteurs.keys.map((key) {
          final item = listCapteurs.get(key);
          return {
            "key": key,
            "MacAddrs": item["MacAddrs"],
            "Name": item["Name"],
            "Type": item["Type"],
            "RemoteAlert": item["RemoteAlert"],
            "Option_stockage": item["Option_stockage"],
            "interval_stockage": item["interval_stockage"],
          };
        }).toList();
>>>>>>> edc460f (Initial commit)
    setState(() {
      items1 = data.reversed.toList();
      print(items1);
    });
  }

  @override
  void initState() {
<<<<<<< HEAD
    refresh();refresh1();
=======
    refresh();
    refresh1();
>>>>>>> edc460f (Initial commit)
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD

=======
>>>>>>> edc460f (Initial commit)
    final List<Widget> children = [
      Gaps.vGap10,
      Row(
        children: <Widget>[
          const ClipOval(
<<<<<<< HEAD
            child: LoadAssetImage('profile/icon_avatar.png', width: 44.0, height: 44.0),
=======
            child: LoadAssetImage(
              'profile/icon_avatar.png',
              width: 44.0,
              height: 44.0,
            ),
>>>>>>> edc460f (Initial commit)
          ),
          Gaps.hGap8,
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
<<<<<<< HEAD
                  Text('${items.elementAt(0)["user_name"]} ${items.elementAt(0)["user_surname"]}'),
                  Gaps.vGap5,
                  items.elementAt(0)["user_phone"] !='' ?Text('${items.elementAt(0)["user_phone"]}'):Text("il n'y a pas de telephone",style: TextStyles.textGray12),
=======
                  Text(
                    '${items.elementAt(0)["user_name"]} ${items.elementAt(0)["user_surname"]}',
                  ),
                  Gaps.vGap5,
                  items.elementAt(0)["user_phone"] != ''
                      ? Text('${items.elementAt(0)["user_phone"]}')
                      : Text(
                        "il n'y a pas de telephone",
                        style: TextStyles.textGray12,
                      ),
>>>>>>> edc460f (Initial commit)
                ],
              ),
            ),
          ),
        ],
      ),
      Gaps.vGap10,
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LoadAssetImage('profile/icon_address.png', width: 16.0, height: 16.0),
          Gaps.hGap4,
<<<<<<< HEAD
          Expanded(child: Text("Pas d'adresse", maxLines: 2,style: TextStyles.textSize12,)),
        ],
      ),
      Gaps.vGap16,
      Text(
        '${items1.length} Capteurs Autorisé',
        style: TextStyles.textSize16,
      ),
=======
          Expanded(
            child: Text(
              "Pas d'adresse",
              maxLines: 2,
              style: TextStyles.textSize12,
            ),
          ),
        ],
      ),
      Gaps.vGap16,
      Text('${items1.length} Capteurs Autorisé', style: TextStyles.textSize16),
>>>>>>> edc460f (Initial commit)
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items1.length,
        itemBuilder: (_, index) => _buildOrderGoodsItem(index),
      ),
      Gaps.vGap8,
    ];

    return Scaffold(
      appBar: const MyAppBar(title: 'Profile'),
      body: MyScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        //bottomButton: bottomMenu,
        children: children,
<<<<<<< HEAD
      )
    );
  }

  Widget _buildOrderInfoItem(String title, String content) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: Dimens.font_sp14)),
            Gaps.hGap8,
            Text(content)
          ],
        ),
=======
>>>>>>> edc460f (Initial commit)
      ),
    );
  }

  Widget _buildOrderGoodsItem(int index) {
    final Widget item = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5.0),
<<<<<<< HEAD
          child: LoadAssetImage('profile/${items1.elementAt(index)["Type"]}.jpg', width: 36.0, height: 36.0),
=======
          child: LoadAssetImage(
            'profile/${items1.elementAt(index)["Type"]}.jpg',
            width: 36.0,
            height: 36.0,
          ),
>>>>>>> edc460f (Initial commit)
        ),
        Gaps.hGap8,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                items1.elementAt(index)["Name"],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Gaps.vGap4,
<<<<<<< HEAD
              Text(items1.elementAt(index)["MacAddrs"], style: Theme.of(context).textTheme.titleSmall),
=======
              Text(
                items1.elementAt(index)["MacAddrs"],
                style: Theme.of(context).textTheme.titleSmall,
              ),
>>>>>>> edc460f (Initial commit)
            ],
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
<<<<<<< HEAD
        border: Border(
          bottom: Divider.createBorderSide(context, width: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: item
      ),
    );
  }

  Widget _buildGoodsTag(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.0),
      ),
      height: 16.0,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: Dimens.font_sp10, height: 1.1),
      ),
    );
  }
  
  Widget _buildGoodsInfoItem(String title, String content, {Color? contentTextColor}) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(title),
            Text(content, style: TextStyle(
              color: contentTextColor ?? Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.bold
            ))
          ],
        ),
      ),
    );
  }

  void _showCallPhoneDialog(String phone) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text('是否拨打：$phone ?'),
          actions: <Widget>[
            TextButton(
              onPressed: (){},
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                //launchTelURL(phone);
                //NavigatorUtils.goBack(context);
              },
              style: ButtonStyle(
                // 按下高亮颜色
                overlayColor: MaterialStateProperty.all<Color>(Theme.of(context).colorScheme.error.withOpacity(0.2)),
              ),
              child: Text('拨打', style: TextStyle(color: Theme.of(context).colorScheme.error),),
            ),
          ],
        );
      }
    );
  }
/*
  static Future<void> launchTelURL(String phone) async {
    final Uri uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Toast.show('拨号失败！');
    }
  }*/
}

=======
        border: Border(bottom: Divider.createBorderSide(context, width: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: item,
      ),
    );
  }
}
>>>>>>> edc460f (Initial commit)
