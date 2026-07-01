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
    // Se vier embrulhado em 'user' ou 'data', tente extrair o mapa interno de dados do usuário
    final userData = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : (json['driver'] is Map<String, dynamic>
            ? json['driver'] as Map<String, dynamic>
            : json);

    // Suporta tanto 'wallet.balance' quanto 'balance' direto (no root ou no userData)
    int balance = 0;

    // Tentar encontrar o balance em várias localizações possíveis do JSON
    final searchNodes = [json, userData];
    for (var node in searchNodes) {
      if (node['wallet'] != null && node['wallet']['balance'] != null) {
        balance =
            double.tryParse(node['wallet']['balance'].toString())?.toInt() ?? 0;
        break;
      } else if (node['balance'] != null) {
        balance = double.tryParse(node['balance'].toString())?.toInt() ?? 0;
        break;
      }
    }

    // Se vier do users/me, alguns dados podem estar em stats ou earnings
    Map<String, dynamic> stats;
    if (json['stats'] is Map<String, dynamic>) {
      stats = json['stats'] as Map<String, dynamic>;
    } else if (userData['stats'] is Map<String, dynamic>) {
      stats = userData['stats'] as Map<String, dynamic>;
    } else if (json['earnings'] is Map<String, dynamic>) {
      stats = json['earnings'] as Map<String, dynamic>;
    } else if (userData['earnings'] is Map<String, dynamic>) {
      stats = userData['earnings'] as Map<String, dynamic>;
    } else {
      stats = userData;
    }

    return DriverUser(
      id: userData['id']?.toString() ?? json['id']?.toString(),
      fullName: userData['fullName'] ??
          userData['name'] ??
          json['fullName'] ??
          json['name'] ??
          '',
      phoneNumber: userData['phoneNumber'] ??
          userData['phone'] ??
          json['phoneNumber'] ??
          json['phone'] ??
          '',
      email: userData['email'] ?? json['email'],
      balance: balance,
      isLoggedIn: userData['isLoggedIn'] ?? json['isLoggedIn'] ?? true,
      role: userData['role'] ?? json['role'] ?? 'DRIVER',
      photo: userData['photo'] ??
          userData['avatar'] ??
          json['photo'] ??
          json['avatar'],
      rating: (stats['rating'] ??
              stats['averageRating'] ??
              userData['rating'] ??
              userData['averageRating'] ??
              json['rating'] ??
              json['averageRating'])
          ?.toDouble(),
      isVerified: userData['isVerified'] ??
          userData['verified'] ??
          json['isVerified'] ??
          json['verified'],
      totalTrips: stats['totalTrips'] ??
          stats['totalRides'] ??
          userData['totalTrips'] ??
          userData['totalRides'] ??
          json['totalTrips'] ??
          json['totalRides'] ??
          0,
      licensePlate: userData['licensePlate'] ?? json['licensePlate'],
      vehicleModel: userData['vehicleModel'] ?? json['vehicleModel'],
      vehicleColor: userData['vehicleColor'] ?? json['vehicleColor'],
      vehicleYear: userData['vehicleYear'] ?? json['vehicleYear'],
      isOnline: userData['isOnline'] ?? json['isOnline'] ?? false,
      createdAt: (userData['createdAt'] ?? json['createdAt']) != null
          ? DateTime.tryParse(
              (userData['createdAt'] ?? json['createdAt']).toString())
          : null,
      bankAccount: userData['bankAccount'] ?? json['bankAccount'],
      bankName: userData['bankName'] ?? json['bankName'],
      wallet: userData['wallet'] ?? json['wallet'],
    );
  }
}
