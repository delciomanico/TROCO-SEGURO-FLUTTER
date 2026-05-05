class Trip {
  final String id;
  final String driverName;
  final String licensePlate;
  final String origin;
  final String destination;
  final String date;
  final String time;
  final int amount;
  final double? rating;
  final String status; // 'completed' | 'pending'

  Trip({
    required this.id,
    required this.driverName,
    required this.licensePlate,
    required this.origin,
    required this.destination,
    required this.date,
    required this.time,
    required this.amount,
    this.rating,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverName': driverName,
      'licensePlate': licensePlate,
      'origin': origin,
      'destination': destination,
      'date': date,
      'time': time,
      'amount': amount,
      'rating': rating,
      'status': status,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    // amount may be returned as String (e.g. "2000.00"), int or double.
    final rawAmount = json['amount'];
    int parsedAmount = 0;
    if (rawAmount == null) {
      parsedAmount = 0;
    } else if (rawAmount is int) {
      parsedAmount = rawAmount;
    } else if (rawAmount is double) {
      parsedAmount = rawAmount.round();
    } else if (rawAmount is String) {
      // normalize decimal separator and try parse
      final normalized = rawAmount.replaceAll(',', '.');
      final d = double.tryParse(normalized);
      if (d != null) {
        parsedAmount = d.round();
      } else {
        parsedAmount = int.tryParse(rawAmount) ?? 0;
      }
    }

    return Trip(
      id: json['id'] ?? '',
      driverName: json['driverName'] ?? '',
      licensePlate: json['licensePlate'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      amount: parsedAmount,
      rating: json['rating']?.toDouble(),
      status: json['status'] ?? 'pending',
    );
  }
}
