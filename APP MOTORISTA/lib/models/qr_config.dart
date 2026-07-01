import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QrConfig {
  final String driverToken;
  final String? activeRouteId;
  final String? activeRouteName;
  final int currentFare;
  final DateTime? lastUpdate;
  final String? parentQrImage;      // base64 da imagem do QR pai (vindo de /qrcodes/setup)
  final String? sessionPublicToken; // publicToken da sessão activa (de /qrcodes/session/seats)
  final List<Map<String, dynamic>> childQrs; // QRs de assentos individuais

  QrConfig({
    required this.driverToken,
    this.activeRouteId,
    this.activeRouteName,
    this.currentFare = 0,
    this.lastUpdate,
    this.parentQrImage,
    this.sessionPublicToken,
    this.childQrs = const [],
  });

  QrConfig copyWith({
    String? driverToken,
    String? activeRouteId,
    String? activeRouteName,
    int? currentFare,
    DateTime? lastUpdate,
    String? parentQrImage,
    String? sessionPublicToken,
    List<Map<String, dynamic>>? childQrs,
  }) {
    return QrConfig(
      driverToken: driverToken ?? this.driverToken,
      activeRouteId: activeRouteId ?? this.activeRouteId,
      activeRouteName: activeRouteName ?? this.activeRouteName,
      currentFare: currentFare ?? this.currentFare,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      parentQrImage: parentQrImage ?? this.parentQrImage,
      sessionPublicToken: sessionPublicToken ?? this.sessionPublicToken,
      childQrs: childQrs ?? this.childQrs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverToken': driverToken,
      'activeRouteId': activeRouteId,
      'activeRouteName': activeRouteName,
      'currentFare': currentFare,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'parentQrImage': parentQrImage,
      'sessionPublicToken': sessionPublicToken,
      'childQrs': childQrs,
    };
  }

  factory QrConfig.fromJson(Map<String, dynamic> json) {
    return QrConfig(
      driverToken: json['driverToken'] ?? '',
      activeRouteId: json['activeRouteId'],
      activeRouteName: json['activeRouteName'],
      currentFare: json['currentFare'] ?? 0,
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.tryParse(json['lastUpdate'])
          : null,
      parentQrImage: json['parentQrImage'],
      sessionPublicToken: json['sessionPublicToken'],
      childQrs: json['childQrs'] is List
          ? (json['childQrs'] as List)
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList()
          : [],
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qr_config', json.encode(toJson()));
  }

  static Future<QrConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString('qr_config');
    if (configStr != null) {
      try {
        return QrConfig.fromJson(jsonDecode(configStr));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<String> generateDriverToken(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    String? existingToken = prefs.getString('driver_token');

    if (existingToken == null || existingToken.isEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tokenData = '$driverId:$timestamp';
      existingToken = base64Encode(utf8.encode(tokenData));
      await prefs.setString('driver_token', existingToken);
    }

    return existingToken;
  }
}
