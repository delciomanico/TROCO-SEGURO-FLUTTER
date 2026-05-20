/// Modelo do usuário motorista
class DriverUser {
  final String? id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final int balance; // Saldo em Kz
  final bool isLoggedIn;
  final String? role; // DRIVER ou PASSENGER
  final String? photo;
  final double? rating;
  final bool? isVerified;
  final int totalTrips;
  final String? licensePlate;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleYear;
  final bool isOnline;
  final DateTime? createdAt;
  final String? bankAccount;
  final String? bankName;
  final Map<String, dynamic>? wallet; // Nova estrutura do backend

  DriverUser({
    this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.balance,
    this.isLoggedIn = false,
    this.role = 'DRIVER',
    this.photo,
    this.rating,
    this.isVerified,
    this.totalTrips = 0,
    this.licensePlate,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleYear,
    this.isOnline = false,
    this.createdAt,
    this.bankAccount,
    this.bankName,
    this.wallet,
  });

  // Alias para compatibilidade
  String get name => fullName;
  String get phone => phoneNumber;

  DriverUser copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? email,
    dynamic balance,
    bool? isLoggedIn,
    String? role,
    String? photo,
    double? rating,
    bool? isVerified,
    int? totalTrips,
    String? licensePlate,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleYear,
    bool? isOnline,
    DateTime? createdAt,
    String? bankAccount,
    String? bankName,
    Map<String, dynamic>? wallet,
  }) {
    return DriverUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      balance: balance ?? this.balance,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      role: role ?? this.role,
      photo: photo ?? this.photo,
      rating: rating ?? this.rating,
      isVerified: isVerified ?? this.isVerified,
      totalTrips: totalTrips ?? this.totalTrips,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      bankAccount: bankAccount ?? this.bankAccount,
      bankName: bankName ?? this.bankName,
      wallet: wallet ?? this.wallet,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'balance': balance,
      'isLoggedIn': isLoggedIn,
      'role': role,
      'photo': photo,
      'rating': rating,
      'isVerified': isVerified,
      'totalTrips': totalTrips,
      'licensePlate': licensePlate,
      'vehicleModel': vehicleModel,
      'vehicleColor': vehicleColor,
      'vehicleYear': vehicleYear,
      'isOnline': isOnline,
      'createdAt': createdAt?.toIso8601String(),
      'bankAccount': bankAccount,
      'bankName': bankName,
    };
  }

  factory DriverUser.fromJson(Map<String, dynamic> json) {
    // Suporta tanto 'wallet.balance' quanto 'balance' direto
    int balance = 0;
    if (json['wallet'] != null && json['wallet']['balance'] != null) {
      balance = double.tryParse(json['wallet']['balance'].toString())?.toInt() ?? 0;
    } else if (json['balance'] != null) {
      balance = double.tryParse(json['balance'].toString())?.toInt() ?? 0;
    }

    // Se vier do users/me, alguns dados podem estar em json['stats'] ou json['earnings']
    final stats = json['stats'] is Map<String, dynamic> 
        ? json['stats'] as Map<String, dynamic> 
        : (json['earnings'] is Map<String, dynamic> 
            ? json['earnings'] as Map<String, dynamic> 
            : json);

    return DriverUser(
      id: json['id'],
      fullName: json['fullName'] ?? json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone'] ?? '',
      email: json['email'],
      balance: balance,
      isLoggedIn: json['isLoggedIn'] ?? true,
      role: json['role'] ?? 'DRIVER',
      photo: json['photo'] ?? json['avatar'],
      rating: (stats['rating'] ?? stats['averageRating'] ?? json['rating'] ?? json['averageRating'])?.toDouble(),
      isVerified: json['isVerified'] ?? json['verified'],
      totalTrips: stats['totalTrips'] ?? stats['totalRides'] ?? json['totalTrips'] ?? json['totalRides'] ?? 0,
      licensePlate: json['licensePlate'],
      vehicleModel: json['vehicleModel'],
      vehicleColor: json['vehicleColor'],
      vehicleYear: json['vehicleYear'],
      isOnline: json['isOnline'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      bankAccount: json['bankAccount'],
      bankName: json['bankName'],
      wallet: json['wallet'],
    );
  }
}
