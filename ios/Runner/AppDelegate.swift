import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Handle BLE state restoration on iOS (required for background BLE in release)
    if let restorationIds = launchOptions?[.bluetoothCentrals] as? [String],
       !restorationIds.isEmpty {
      // The system is relaunching the app to restore BLE state.
      // flutter_blue_plus handles the actual restoration internally;
      // we just need to NOT block this launch path.
      debugPrint("Restoring BLE central managers: \(restorationIds)")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}