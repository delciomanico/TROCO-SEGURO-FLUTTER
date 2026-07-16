/// Modelo de passageiro (para exibição no histórico de viagens do motorista)
class Passenger {
  final String id;
  final String name;
  final String? phoneNumber;
  final double? rating;
  final String? photo;

  Passenger({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.rating,
    this.photo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'rating': rating,
      'photo': photo,
    };
  }

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      id: json['id'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone'],
      rating: double.tryParse(
          (json['rating'] ?? json['averageRating'])?.toString() ?? ''),
      photo: json['photo'] ?? json['avatar'],
    );
  }
}
