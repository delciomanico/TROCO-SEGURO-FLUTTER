import 'package:troco_seguro_motorista/models/passenger.dart';

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
    return Trip(
      id: json['id'] ?? '',
      passengerName: json['passengerName'] ?? json['passenger']?['name'] ?? '',
      passengerPhone: json['passengerPhone'] ?? json['passenger']?['phone'],
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      amount: json['amount'] ?? 0,
      rating: json['rating']?.toDouble(),
      comment: json['comment'],
      status: json['status'] ?? 'completed',
      distance: json['distance']?.toDouble(),
      duration: json['duration'],
      passenger: json['passenger'] != null
          ? Passenger.fromJson(json['passenger'])
          : null,
    );
  }
}
