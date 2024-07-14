import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:siot_driver_pro/profile/page/profile.dart';
import '../../res/colors.dart';
import '../../res/styles.dart';
import '../../widgets/load_image.dart';

class GoodsAddMenu extends StatefulWidget {

  const GoodsAddMenu({super.key});

  @override
  _GoodsAddMenuState createState() => _GoodsAddMenuState();
}

class _GoodsAddMenuState extends State<GoodsAddMenu> with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  Future<void> deleteItem1() async {
    await Hive.box('LOGGED_IN_USER').clear();
    await Hive.box('LIST_CAPTEURS').clear();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Colors.white;
    const  Color? iconColor = null;

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(right: 12.0),
          child: LoadAssetImage('goods/jt.png', width: 8.0, height: 4.0,
            color: null
          ),
        ),
        SizedBox(
          width: 120.0,
          height: 40.0,
          child: TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder:(context){return const ProfilePage();}));
            },
            icon: const LoadAssetImage('home/user2.png', width: 22, height: 22, color: iconColor,),
            label: const Align(alignment: Alignment.centerLeft,child: Text('Profile',style: TextStyles.textSize12)),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
              disabledForegroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.12),
              backgroundColor: backgroundColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(8.0), topRight: Radius.circular(8.0)),
              ),
            ),
          ),
        ),
        Container(width: 120.0, height: 0.6, color: Colours.line),
        SizedBox(
          width: 120.0,
          height: 40.0,
          child: TextButton.icon(
            onPressed: () {
              deleteItem1();Navigator.pop(context);
            },
            icon: const LoadAssetImage('home/logout.png', width: 16, height: 16, color: iconColor,),
            label: const Align(alignment: Alignment.centerLeft,child: Text('Déconnexion',style: TextStyles.textSize12)),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
              disabledForegroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.12),
              backgroundColor: backgroundColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8.0), bottomRight: Radius.circular(8.0)),
              ),
            ),
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (_, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.topRight,
          child: child,
        );
      },
      child: body,
    );
  }

}
