import 'package:flutter/material.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:siot_driver_pro/res/colors.dart';
import '../res/styles.dart';

class GpsOffScreen extends StatelessWidget {
  const GpsOffScreen({Key? key, this.gpsEnabled, this.permission}) : super(key: key);
  final bool? gpsEnabled;
  final PermissionStatus? permission;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_off_rounded,
                  size: 80,
                ),
                const SizedBox(height: 3),
                const Text(
                  'Oops !',
                  style: TextStyles.textBold16,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Gps est Désactivé',
                  style: TextStyles.text,
                ),
                const SizedBox(height: 15),
                MaterialButton(
                  onPressed: () async{
                    await loc.Location().requestService();
                    await Permission.location.request();
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
