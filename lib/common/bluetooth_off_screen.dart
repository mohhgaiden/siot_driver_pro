import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:siot_driver_pro/core/constants/colors.dart';
import '../core/constants/styles.dart';

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.adapterState}) : super(key: key);
  final BluetoothAdapterState? adapterState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled_rounded, size: 80),
            const SizedBox(height: 3),
            const Text('Oops !', style: TextStyles.textBold16),
            const SizedBox(height: 15),
            const Text("Boutooth est non pas Activé", style: TextStyles.text),
            const SizedBox(height: 15),
            MaterialButton(
              onPressed: () async {
                await FlutterBluePlus.turnOn();
                FlutterBluePlus.startScan(
                  androidScanMode: AndroidScanMode.lowPower,
                );
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
