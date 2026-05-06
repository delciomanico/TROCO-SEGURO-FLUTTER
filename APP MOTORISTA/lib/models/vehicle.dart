class Vehicle {
  final String? id;
  final String licensePlate;
  final String model;
  final String color;

  Vehicle({
    this.id,
    required this.licensePlate,
    required this.model,
    required this.color,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String?,
      licensePlate: json['licensePlate'] ?? '',
      model: json['model'] ?? '',
      color: json['color'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'licensePlate': licensePlate,
      'model': model,
      'color': color,
    };
  }
}
