import Flutter
import UIKit
import CoreBluetooth
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Required for iOS foreground notifications
    UNUserNotificationCenter.current().delegate = self

    // Handle BLE state restoration
    if let restorationIds = launchOptions?[.bluetoothCentrals] as? [String],
       !restorationIds.isEmpty {

      debugPrint("Restoring BLE central managers: \(restorationIds)")
    }

    GeneratedPluginRegistrant.register(with: self)

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }
}