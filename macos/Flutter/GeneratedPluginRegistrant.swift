//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import connectivity_plus
<<<<<<< HEAD
import flutter_blue_plus
import flutter_local_notifications
import geolocator_apple
import location
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  ConnectivityPlugin.register(with: registry.registrar(forPlugin: "ConnectivityPlugin"))
=======
import flutter_blue_plus_darwin
import flutter_local_notifications
import geolocator_apple
import location
import open_file_mac
import path_provider_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  ConnectivityPlusPlugin.register(with: registry.registrar(forPlugin: "ConnectivityPlusPlugin"))
>>>>>>> edc460f (Initial commit)
  FlutterBluePlusPlugin.register(with: registry.registrar(forPlugin: "FlutterBluePlusPlugin"))
  FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin"))
  GeolocatorPlugin.register(with: registry.registrar(forPlugin: "GeolocatorPlugin"))
  LocationPlugin.register(with: registry.registrar(forPlugin: "LocationPlugin"))
<<<<<<< HEAD
=======
  OpenFilePlugin.register(with: registry.registrar(forPlugin: "OpenFilePlugin"))
>>>>>>> edc460f (Initial commit)
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
}
