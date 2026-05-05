/// Modelo de Rota de Táxi
class TaxiRoute {
  final String id;
  final String name;
  final String origin;
  final String destination;
  final TrafficStatus trafficStatus;
  final String? trafficReason;
  final int activeTaxis;
  final double distance; // em km
  final int estimatedTime; // em minutos (tempo normal)
  final int currentTime; // em minutos (tempo atual com trânsito)
  final int basePrice; // preço base em Kz
  final DateTime? lastUpdate;

  TaxiRoute({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.trafficStatus,
    this.trafficReason,
    required this.activeTaxis,
    required this.distance,
    required this.estimatedTime,
    required this.currentTime,
    required this.basePrice,
    this.lastUpdate,
  });

  factory TaxiRoute.fromJson(Map<String, dynamic> json) {
    return TaxiRoute(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      trafficStatus:
          TrafficStatus.fromString(json['trafficStatus'] ?? 'normal'),
      trafficReason: json['trafficReason'],
      activeTaxis: json['activeTaxis'] ?? 0,
      distance: (json['distance'] ?? 0).toDouble(),
      estimatedTime: json['estimatedTime'] ?? 0,
      currentTime: json['currentTime'] ?? 0,
      basePrice: json['basePrice'] ?? 0,
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'origin': origin,
      'destination': destination,
      'trafficStatus': trafficStatus.value,
      'trafficReason': trafficReason,
      'activeTaxis': activeTaxis,
      'distance': distance,
      'estimatedTime': estimatedTime,
      'currentTime': currentTime,
      'basePrice': basePrice,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  /// Retorna o atraso em minutos devido ao trânsito
  int get delay => currentTime - estimatedTime;

  /// Retorna a porcentagem de atraso
  double get delayPercentage =>
      estimatedTime > 0 ? (delay / estimatedTime) * 100 : 0;
}

/// Status do trânsito
enum TrafficStatus {
  normal('normal', 'Normal'),
  moderate('moderate', 'Moderado'),
  heavy('heavy', 'Intenso'),
  blocked('blocked', 'Bloqueado');

  final String value;
  final String label;

  const TrafficStatus(this.value, this.label);

  static TrafficStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'moderate':
        return TrafficStatus.moderate;
      case 'heavy':
        return TrafficStatus.heavy;
      case 'blocked':
        return TrafficStatus.blocked;
      default:
        return TrafficStatus.normal;
    }
  }
}
