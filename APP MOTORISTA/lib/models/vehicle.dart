class Vehicle {
  final String? id;
  final String licensePlate;
  final String model;
  final String color;
  final int seats;

  Vehicle({
    this.id,
    required this.licensePlate,
    required this.model,
    required this.color,
    this.seats = 4,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String?,
      licensePlate: json['licensePlate'] ?? '',
      model: json['model'] ?? '',
      color: json['color'] ?? '',
      seats: int.tryParse(json['seats']?.toString() ?? '4') ?? 4,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'licensePlate': licensePlate,
      'model': model,
      'color': color,
      'seats': seats,
    };
  }
}
