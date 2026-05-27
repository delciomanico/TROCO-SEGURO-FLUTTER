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

  /// Constrói Earnings calculando os valores a partir da lista de viagens
  /// retornada diretamente pelo endpoint /trips da API.
  factory Earnings.fromTrips(List<Map<String, dynamic>> trips) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int todayAmount = 0, todayTrips = 0;
    int weekAmount = 0, weekTrips = 0;
    int monthAmount = 0, monthTrips = 0;
    int totalAmount = 0, totalTrips = 0;
    double ratingSum = 0;
    int ratingCount = 0;

    // Mapa para acumular ganhos diários (últimos 7 dias) para o gráfico
    final Map<String, int> dailyMap = {};
    for (int i = 6; i >= 0; i--) {
      final d = todayStart.subtract(Duration(days: i));
      final key =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      dailyMap[key] = 0;
    }

    for (final t in trips) {
      // Só conta viagens concluídas
      final status = t['status']?.toString() ?? '';
      if (status != 'completed') continue;

      final rawAmount = t['amount'];
      final amount =
          double.tryParse(rawAmount?.toString() ?? '0')?.toInt() ?? 0;

      // Parse da data da viagem
      DateTime? tripDate;
      if (t['createdAt'] != null) {
        tripDate = DateTime.tryParse(t['createdAt'].toString())?.toLocal();
      }

      totalAmount += amount;
      totalTrips++;

      final rating = (t['rating'] as num?)?.toDouble();
      if (rating != null) {
        ratingSum += rating;
        ratingCount++;
      }

      if (tripDate != null) {
        final tripDay =
            DateTime(tripDate.year, tripDate.month, tripDate.day);

        if (!tripDay.isBefore(todayStart)) {
          todayAmount += amount;
          todayTrips++;
        }
        if (!tripDay.isBefore(weekStart)) {
          weekAmount += amount;
          weekTrips++;
        }
        if (!tripDay.isBefore(monthStart)) {
          monthAmount += amount;
          monthTrips++;
        }

        // Atualizar mapa diário se dentro dos últimos 7 dias
        if (!tripDay.isBefore(todayStart.subtract(const Duration(days: 6)))) {
          final key =
              '${tripDate.day.toString().padLeft(2, '0')}/${tripDate.month.toString().padLeft(2, '0')}';
          dailyMap[key] = (dailyMap[key] ?? 0) + amount;
        }
      }
    }

    final dailyHistory = dailyMap.entries
        .map((e) => DailyEarning(date: e.key, amount: e.value, trips: 0))
        .toList();

    return Earnings(
      todayAmount: todayAmount,
      todayTrips: todayTrips,
      weekAmount: weekAmount,
      weekTrips: weekTrips,
      monthAmount: monthAmount,
      monthTrips: monthTrips,
      totalAmount: totalAmount,
      totalTrips: totalTrips,
      averageRating: ratingCount > 0 ? ratingSum / ratingCount : 0.0,
      dailyHistory: dailyHistory,
    );
  }

  factory Earnings.fromJson(Map<String, dynamic> json) {
    // Se vier do users/me, os dados podem estar em json['stats'], json['earnings'] ou dentro de json['user']
    Map<String, dynamic> data;

    if (json.containsKey('todayAmount')) {
      data = json;
    } else if (json['stats'] is Map<String, dynamic>) {
      data = json['stats'] as Map<String, dynamic>;
    } else if (json['earnings'] is Map<String, dynamic>) {
      data = json['earnings'] as Map<String, dynamic>;
    } else if (json['user'] is Map<String, dynamic> &&
        (json['user']['stats'] is Map<String, dynamic>)) {
      data = json['user']['stats'] as Map<String, dynamic>;
    } else if (json['user'] is Map<String, dynamic> &&
        (json['user']['earnings'] is Map<String, dynamic>)) {
      data = json['user']['earnings'] as Map<String, dynamic>;
    } else {
      data = json;
    }

    return Earnings(
      todayAmount: double.tryParse(
                  (data['todayAmount'] ?? data['today']?['amount'] ?? 0)
                      .toString())
              ?.toInt() ??
          0,
      todayTrips: data['todayTrips'] ?? data['today']?['trips'] ?? 0,
      weekAmount: double.tryParse(
                  (data['weekAmount'] ?? data['week']?['amount'] ?? 0)
                      .toString())
              ?.toInt() ??
          0,
      weekTrips: data['weekTrips'] ?? data['week']?['trips'] ?? 0,
      monthAmount: double.tryParse(data['monthSpent']?.toString() ??
                  (data['monthAmount'] ?? data['month']?['amount'] ?? 0)
                      .toString())
              ?.toInt() ??
          0,
      monthTrips: data['monthTrips'] ?? data['month']?['trips'] ?? 0,
      totalAmount: double.tryParse(
                  (data['totalAmount'] ?? data['total']?['amount'] ?? 0)
                      .toString())
              ?.toInt() ??
          0,
      totalTrips: data['totalTrips'] ?? 0,
      averageRating:
          (data['averageRating'] ?? data['rating'] ?? 0.0).toDouble(),
      dailyHistory: data['dailyHistory'] != null
          ? (data['dailyHistory'] as List)
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
