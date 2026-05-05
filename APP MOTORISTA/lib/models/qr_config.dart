import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuração do QR Code do Motorista
/// O QR Code em si é único e estático (baseado no token do motorista)
/// Mas as informações associadas (rota e valor) podem ser alteradas
class QrConfig {
  final String driverToken; // Token único do motorista (não muda)
  final String? activeRouteId;
  final String? activeRouteName;
  final int currentFare; // Valor cobrado em Kz
  final DateTime? lastUpdate;

  QrConfig({
    required this.driverToken,
    this.activeRouteId,
    this.activeRouteName,
    this.currentFare = 0,
    this.lastUpdate,
  });

  /// Cria uma cópia com novos valores
  QrConfig copyWith({
    String? driverToken,
    String? activeRouteId,
    String? activeRouteName,
    int? currentFare,
    DateTime? lastUpdate,
  }) {
    return QrConfig(
      driverToken: driverToken ?? this.driverToken,
      activeRouteId: activeRouteId ?? this.activeRouteId,
      activeRouteName: activeRouteName ?? this.activeRouteName,
      currentFare: currentFare ?? this.currentFare,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'driverToken': driverToken,
      'activeRouteId': activeRouteId,
      'activeRouteName': activeRouteName,
      'currentFare': currentFare,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  /// Cria a partir de JSON
  factory QrConfig.fromJson(Map<String, dynamic> json) {
    return QrConfig(
      driverToken: json['driverToken'] ?? '',
      activeRouteId: json['activeRouteId'],
      activeRouteName: json['activeRouteName'],
      currentFare: json['currentFare'] ?? 0,
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
    );
  }

  /// Gera os dados que serão codificados no QR Code
  /// O token é único e estático, mas inclui as informações atuais
  String generateQrData() {
    final data = {
      'token': driverToken,
      'route': activeRouteName,
      'fare': currentFare,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    return 'troco_seguro_driver:${base64Encode(utf8.encode(json.encode(data)))}';
  }

  /// Salva a configuração no SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qr_config', json.encode(toJson()));
  }

  /// Carrega a configuração do SharedPreferences
  static Future<QrConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString('qr_config');
    if (configStr != null) {
      return QrConfig.fromJson(json.decode(configStr));
    }
    return null;
  }

  /// Gera um token único para o motorista (chamado apenas uma vez)
  static Future<String> generateDriverToken(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    String? existingToken = prefs.getString('driver_token');

    if (existingToken == null || existingToken.isEmpty) {
      // Gerar novo token único baseado no ID do motorista e timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tokenData = '$driverId:$timestamp';
      existingToken = base64Encode(utf8.encode(tokenData));
      await prefs.setString('driver_token', existingToken);
    }

    return existingToken;
  }
}
