class Trip {
  final String id;
  final String driverName;
  final String licensePlate;
  final String? vehicleModel;
  final String? vehicleColor;
  final String origin;
  final String destination;
  final String date;
  final String time;
  final int amount;
  final double? rating;
  final String? comment;
  final double? distance; // em km
  final int? duration; // em minutos
  final String status; // 'completed' | 'pending'

  Trip({
    required this.id,
    required this.driverName,
    required this.licensePlate,
    this.vehicleModel,
    this.vehicleColor,
    required this.origin,
    required this.destination,
    required this.date,
    required this.time,
    required this.amount,
    this.rating,
    this.comment,
    this.distance,
    this.duration,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverName': driverName,
      'licensePlate': licensePlate,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'origin': origin,
      'destination': destination,
      'date': date,
      'time': time,
      'amount': amount,
      'rating': rating,
      'comment': comment,
      'distance': distance,
      'duration': duration,
      'status': status,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    // amount may be returned as String (e.g. "2000.00"), int or double, sob
    // chaves diferentes consoante o endpoint.
    final rawAmount =
        json['amount'] ?? json['totalAmount'] ?? json['fare'] ?? json['price'];
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

    // Vehicle info pode vir como objecto {model, color, licensePlate} OU,
    // como confirmado noutros endpoints desta API (ex: qrcodes/session/start),
    // como uma única string tipo "Suzuki Alto (LD-22-11-AB)".
    final rawVehicle = json['vehicle'];
    String? vehicleModel;
    String? vehicleColor;
    String vehiclePlate = '';
    if (rawVehicle is Map) {
      vehicleModel = rawVehicle['model'] as String?;
      vehicleColor = rawVehicle['color'] as String?;
      vehiclePlate = rawVehicle['licensePlate'] as String? ?? '';
    } else if (rawVehicle is String && rawVehicle.isNotEmpty) {
      final match = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*$').firstMatch(rawVehicle);
      if (match != null) {
        vehicleModel = match.group(1)?.trim();
        vehiclePlate = match.group(2)?.trim() ?? '';
      } else {
        vehicleModel = rawVehicle;
      }
    }

    // Data/hora: aceitar 'date'+'time' separados OU um timestamp ISO único
    // (createdAt/startedAt/completedAt), que é o formato confirmado noutros
    // endpoints desta API (ex: qrcodes/session/start usa 'startedAt').
    String date = json['date'] ?? '';
    String time = json['time'] ?? '';
    if (date.isEmpty || time.isEmpty) {
      final isoRaw = json['completedAt'] ??
          json['startedAt'] ??
          json['createdAt'] ??
          json['scheduledAt'];
      final parsed =
          isoRaw is String ? DateTime.tryParse(isoRaw)?.toLocal() : null;
      if (parsed != null) {
        if (date.isEmpty) {
          date =
              '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
        }
        if (time.isEmpty) {
          time =
              '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        }
      }
    }

    // Estado: normalizar para minúsculas — o backend pode devolver
    // 'COMPLETED'/'Completed' e o resto da app compara sempre com
    // 'completed'/'cancelled'/'pending' em minúsculas.
    final rawStatus = (json['status'] ?? '').toString().toLowerCase();

    return Trip(
      id: json['id'] ?? '',
      driverName: json['driverName'] ?? '',
      licensePlate: json['licensePlate'] ?? vehiclePlate,
      vehicleModel: json['vehicleModel'] ?? vehicleModel,
      vehicleColor: json['vehicleColor'] ?? vehicleColor,
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      date: date,
      time: time,
      amount: parsedAmount,
      rating: (json['rating'] as num?)?.toDouble(),
      comment: json['comment']?.toString(),
      distance: (json['distance'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toInt(),
      status: rawStatus.isEmpty ? 'pending' : rawStatus,
    );
  }
}
