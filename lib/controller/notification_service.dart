// notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  static const String oneSignalAppId = '4daf0d1c-6e0e-4685-90b6-08c5f22969f1';

  // ⚠️ In production, move this key to a secure backend
  static const String oneSignalRestApiKey =
      'os_v2_app_jwxq2hdobzdilefwbdc7eklj6fjyhoulnucuyeendwyhafs5hayme6e3s5i3wounjc4vlbgmi3uik2ppgruvsnu3nzstdftub4ubqjq';

  static Future<void> sendPushNotification({
    required String token,
    required String message,
  }) async {
    if (token.trim().isEmpty || token.length < 20) {
      print("⚠️ Skipped push: Invalid OneSignal ID: $token");
      return;
    }

    final payload = {
      'app_id': oneSignalAppId,
      'include_player_ids': [token],
      'headings': {'en': 'New Message'},
      'contents': {'en': message},
    };

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $oneSignalRestApiKey',
        },
        body: jsonEncode(payload),
      );

      print("🔔 OneSignal response: ${response.statusCode} - ${response.body}");

      final result = jsonDecode(response.body);

      if (response.statusCode != 200 || result['errors'] != null) {
        throw Exception('❌ Push failed: ${result['errors'] ?? response.body}');
      }
    } catch (e) {
      print("🚨 OneSignal Exception: $e");
    }
  }
}
