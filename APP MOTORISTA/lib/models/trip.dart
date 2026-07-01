import 'package:troco_seguro_pro/models/passenger.dart';

/// Modelo de viagem do motorista
class Trip {
  final String id;
  final String passengerName;
  final String? passengerPhone;
  final String origin;
  final String destination;
  final String date;
  final String time;
  final int amount;
  final double? rating; // Avaliação que o passageiro deu
  final String? comment; // Comentário do passageiro
  final String status; // 'completed' | 'cancelled' | 'in_progress'
  final double? distance; // em km
  final int? duration; // em minutos
  final Passenger? passenger;

  Trip({
    required this.id,
    required this.passengerName,
    this.passengerPhone,
    required this.origin,
    required this.destination,
    required this.date,
    required this.time,
    required this.amount,
    this.rating,
    this.comment,
    required this.status,
    this.distance,
    this.duration,
    this.passenger,
  });

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isInProgress => status == 'in_progress';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'origin': origin,
      'destination': destination,
      'date': date,
      'time': time,
      'amount': amount,
      'rating': rating,
      'comment': comment,
      'status': status,
      'distance': distance,
      'duration': duration,
      'passenger': passenger?.toJson(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    // Extrair nome do passageiro: campo direto ou dentro do objeto 'passenger'
    final passengerObj = json['passenger'] as Map<String, dynamic>?;
    final passengerName = json['passengerName']?.toString() ??
        passengerObj?['fullName']?.toString() ??
        passengerObj?['name']?.toString() ??
        'Passageiro';

    final passengerPhone = json['passengerPhone']?.toString() ??
        passengerObj?['phoneNumber']?.toString() ??
        passengerObj?['phone']?.toString();

    // amount pode vir como String "400.00" ou int
    final rawAmount = json['amount'];
    final amount =
        double.tryParse(rawAmount?.toString() ?? '0')?.toInt() ?? 0;

    // date e time podem vir separados ou dentro de 'createdAt'
    String date = json['date']?.toString() ?? '';
    String time = json['time']?.toString() ?? '';
    if ((date.isEmpty || time.isEmpty) && json['createdAt'] != null) {
      final createdAt = DateTime.tryParse(json['createdAt'].toString());
      if (createdAt != null) {
        final local = createdAt.toLocal();
        if (date.isEmpty) {
          date =
              '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
        }
        if (time.isEmpty) {
          time =
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        }
      }
    }

    return Trip(
      id: json['id']?.toString() ?? '',
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      date: date,
      time: time,
      amount: amount,
      rating: (json['rating'] as num?)?.toDouble(),
      comment: json['comment']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      distance: (json['distance'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toInt(),
      passenger: passengerObj != null
          ? Passenger.fromJson(passengerObj)
          : null,
    );
  }
}
