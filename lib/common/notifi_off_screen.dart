import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:siot_driver_pro/core/constants/colors.dart';
import '../core/constants/styles.dart';

class NotifiOffScreen extends StatelessWidget {
  const NotifiOffScreen({Key? key, this.notify, this.background})
    : super(key: key);
  final PermissionStatus? notify;
  final PermissionStatus? background;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 80),
            const SizedBox(height: 3),
            const Text('Oops !', style: TextStyles.textBold16),
            const SizedBox(height: 15),
            const Text('Notifications non pas Activé', style: TextStyles.text),
            const SizedBox(height: 15),
            MaterialButton(
              onPressed: () async {
                await Permission.notification.request();
                await Permission.ignoreBatteryOptimizations.request();
              },
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: Colours.app_main,
              child: const Text('Activer'),
            ),
          ],
        ),
      ),
    );
  }
}
