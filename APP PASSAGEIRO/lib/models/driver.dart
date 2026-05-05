class Driver {
  final String id;
  final String name;
  final String licensePlate;
  final double rating;
  final int totalRides;
  final double distance; // distância em km
  final String location;
  final bool isAvailable;

  Driver({
    required this.id,
    required this.name,
    required this.licensePlate,
    required this.rating,
    required this.totalRides,
    required this.distance,
    required this.location,
    this.isAvailable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'licensePlate': licensePlate,
      'rating': rating,
      'totalRides': totalRides,
      'distance': distance,
      'location': location,
      'isAvailable': isAvailable,
    };
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      licensePlate: json['licensePlate'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalRides: json['totalRides'] ?? 0,
      distance: (json['distance'] ?? 0.0).toDouble(),
      location: json['location'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
    );
  }
}
