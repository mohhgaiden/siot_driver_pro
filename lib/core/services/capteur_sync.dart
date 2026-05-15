import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

/// Synchronisation de la liste des capteurs depuis le backend.
///
/// Doit être appelée :
/// - Au login (saisie identifiants)
/// - À chaque ouverture de l'app si l'utilisateur est déjà connecté (auto-login)
/// - Optionnel : sur un bouton "Rafraîchir" dans l'UI
class CapteurSync {
  static const _endpoint =
      'https://sirius-iot.app/Admin/Mobile/API/SiotDriver2022/Android/list_Tags_Readings.php';

  /// Re-télécharge la liste des capteurs pour [uuid] et remplace
  /// le contenu de la box `LIST_CAPTEURS`. Met à jour `Alert` pour
  /// les nouveaux capteurs sans toucher aux seuils existants.
  ///
  /// Ne lève jamais d'exception : en cas d'erreur réseau ou backend,
  /// la box précédente est conservée et un log est émis.
  static Future<void> sync(String uuid) async {
    debugPrint('🔄 CapteurSync: appel API pour uuid=$uuid');
    try {
      final response = await http
          .post(Uri.parse(_endpoint), body: {'uuid_user': uuid})
          .timeout(const Duration(seconds: 15));

      debugPrint('🔄 CapteurSync: HTTP ${response.statusCode}');
      if (response.statusCode != 200) return;

      final result = jsonDecode(response.body);
      final block = result['LIST_CAPTEURS'];
      if (block == null) {
        debugPrint('❌ CapteurSync: pas de bloc LIST_CAPTEURS dans la réponse');
        return;
      }
      if (block['error'] != 'false') {
        debugPrint('❌ CapteurSync: API a renvoyé error=${block['error']}');
        return;
      }

      final nbr = block['Nbr_capteurs'] ?? 0;
      final list = block['LIST'] as List? ?? [];
      debugPrint('🔄 CapteurSync: ${list.length} capteur(s) à synchroniser');

      // ✅ On vide puis on re-remplit avec la liste à jour
      final capteursBox = Hive.box('LIST_CAPTEURS');
      final alertBox = Hive.box('Alert');

      await capteursBox.clear();

      for (int i = 0; i < nbr && i < list.length; i++) {
        final item = list[i];
        await capteursBox.add({
          'MacAddrs': (item['MacAddrs']?.toString() ?? '').trim(),
          'Name': item['Name'],
          'Name_manufacturer': item['Name_manufacturer'],
          'Type': item['Type'],
          'RemoteAlert': item['RemoteAlert'],
          'Option_stockage': item['Option_stockage'],
          'interval_stockage': item['interval_stockage'],
        });

        final mac = (item['MacAddrs']?.toString() ?? '').trim();
        // On ne crée une entrée Alert que si elle n'existe pas déjà
        // (préserve les seuils saisis par l'utilisateur)
        final alreadyExists = alertBox.values.any(
          (e) => e['uuid_user'] == uuid && e['MacAddrs'] == mac,
        );
        if (!alreadyExists) {
          await alertBox.add({
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
      debugPrint('✅ CapteurSync: ${capteursBox.length} capteurs en base');
    } catch (e, st) {
      debugPrint('❌ CapteurSync: exception $e\n$st');
    }
  }
}
