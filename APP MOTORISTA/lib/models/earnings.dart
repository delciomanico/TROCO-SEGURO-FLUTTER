/// Modelo de ganhos do motorista
class Earnings {
  final int todayAmount;
  final int todayTrips;
  final int weekAmount;
  final int weekTrips;
  final int monthAmount;
  final int monthTrips;
  final int totalAmount;
  final int totalTrips;
  final double averageRating;
  final List<DailyEarning> dailyHistory;

  Earnings({
    required this.todayAmount,
    required this.todayTrips,
    required this.weekAmount,
    required this.weekTrips,
    required this.monthAmount,
    required this.monthTrips,
    required this.totalAmount,
    required this.totalTrips,
    required this.averageRating,
    this.dailyHistory = const [],
  });

  factory Earnings.empty() {
    return Earnings(
      todayAmount: 0,
      todayTrips: 0,
      weekAmount: 0,
      weekTrips: 0,
      monthAmount: 0,
      monthTrips: 0,
      totalAmount: 0,
      totalTrips: 0,
      averageRating: 0.0,
      dailyHistory: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'todayAmount': todayAmount,
      'todayTrips': todayTrips,
      'weekAmount': weekAmount,
      'weekTrips': weekTrips,
      'monthAmount': monthAmount,
      'monthTrips': monthTrips,
      'totalAmount': totalAmount,
      'totalTrips': totalTrips,
      'averageRating': averageRating,
      'dailyHistory': dailyHistory.map((e) => e.toJson()).toList(),
    };
  }

  factory Earnings.fromJson(Map<String, dynamic> json) {
    return Earnings(
      todayAmount: json['todayAmount'] ?? json['today']?['amount'] ?? 0,
      todayTrips: json['todayTrips'] ?? json['today']?['trips'] ?? 0,
      weekAmount: json['weekAmount'] ?? json['week']?['amount'] ?? 0,
      weekTrips: json['weekTrips'] ?? json['week']?['trips'] ?? 0,
      monthAmount: int.tryParse(json['monthSpent']?.toString() ?? '') ?? (json['monthAmount'] ?? json['month']?['amount'] ?? 0),
      monthTrips: json['monthTrips'] ?? json['month']?['trips'] ?? 0,
      totalAmount: json['totalAmount'] ?? json['total']?['amount'] ?? 0,
      totalTrips: json['totalTrips'] ?? 0,
      averageRating:
          (json['averageRating'] ?? json['rating'] ?? 0.0).toDouble(),
      dailyHistory: json['dailyHistory'] != null
          ? (json['dailyHistory'] as List)
              .map((e) => DailyEarning.fromJson(e))
              .toList()
          : [],
    );
  }
}

/// Ganhos diários para gráfico/histórico
class DailyEarning {
  final String date;
  final int amount;
  final int trips;

  DailyEarning({
    required this.date,
    required this.amount,
    required this.trips,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
      'trips': trips,
    };
  }

  factory DailyEarning.fromJson(Map<String, dynamic> json) {
    return DailyEarning(
      date: json['date'] ?? '',
      amount: json['amount'] ?? 0,
      trips: json['trips'] ?? 0,
    );
  }
}
