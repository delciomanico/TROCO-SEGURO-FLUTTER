class Complaint {
  final String id;
  final String userId;
  final String category;
  final String reasonCode;
  final String description;
  final String? transactionId;
  final String? tripId;
  final Map<String, dynamic>? metadata;
  final String createdAt;
  final String updatedAt;

  const Complaint({
    required this.id,
    required this.userId,
    required this.category,
    required this.reasonCode,
    required this.description,
    this.transactionId,
    this.tripId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      reasonCode: json['reasonCode']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      transactionId: json['transactionId']?.toString(),
      tripId: json['tripId']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  String get categoryLabel {
    switch (category.toUpperCase()) {
      case 'TRANSACTION':
        return 'Transação';
      case 'TRIP':
        return 'Viagem';
      default:
        return 'Outro';
    }
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year  $hour:$minute';
    } catch (_) {
      return createdAt;
    }
  }
}
