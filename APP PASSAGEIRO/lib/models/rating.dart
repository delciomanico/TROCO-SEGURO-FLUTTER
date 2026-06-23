import 'package:intl/intl.dart';

class Rating {
  final String id;
  final int stars;
  final String? comment;
  final DateTime createdAt;
  final String? raterName;
  final String? ratedName;
  final String? tripId;

  Rating({
    required this.id,
    required this.stars,
    this.comment,
    required this.createdAt,
    this.raterName,
    this.ratedName,
    this.tripId,
  });

  String get scoreLabel {
    switch (stars) {
      case 5:
        return 'Excelente';
      case 4:
        return 'Ótimo';
      case 3:
        return 'Bom';
      case 2:
        return 'Regular';
      default:
        return 'Ruim';
    }
  }

  String get formattedDate =>
      DateFormat('dd MMM yyyy', 'pt_BR').format(createdAt);

  factory Rating.fromJson(Map<String, dynamic> json) {
    // Normaliza o score: pode vir como 'stars' ou 'score'
    final rawStars = json['stars'] ?? json['score'] ?? 0;
    final int stars = rawStars is int
        ? rawStars
        : (rawStars is double ? rawStars.round() : int.tryParse('$rawStars') ?? 0);

    // Normaliza data
    final rawDate = json['createdAt'] ?? json['created_at'] ?? json['date'];
    final DateTime createdAt =
        rawDate != null ? (DateTime.tryParse(rawDate.toString()) ?? DateTime.now()) : DateTime.now();

    // Normaliza rater (quem avaliou)
    final raterRaw = json['rater'] ?? json['ratedBy'] ?? json['reviewer'];
    String? raterName;
    if (raterRaw is Map) {
      raterName = raterRaw['fullName'] ?? raterRaw['name'];
    } else if (raterRaw is String) {
      raterName = raterRaw;
    }

    // Normaliza rated (quem foi avaliado)
    final ratedRaw = json['rated'] ?? json['targetUser'] ?? json['driver'];
    String? ratedName;
    if (ratedRaw is Map) {
      ratedName = ratedRaw['fullName'] ?? ratedRaw['name'];
    } else if (ratedRaw is String) {
      ratedName = ratedRaw;
    }

    // Trip id
    final tripRaw = json['trip'] ?? json['tripId'];
    String? tripId;
    if (tripRaw is Map) {
      tripId = tripRaw['id']?.toString();
    } else if (tripRaw is String) {
      tripId = tripRaw;
    }

    return Rating(
      id: json['id']?.toString() ?? '',
      stars: stars.clamp(1, 5),
      comment: json['comment']?.toString(),
      createdAt: createdAt,
      raterName: raterName,
      ratedName: ratedName,
      tripId: tripId,
    );
  }
}
