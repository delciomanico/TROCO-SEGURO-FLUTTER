class User {
  final String? id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final int balance;
  final bool isLoggedIn;
  final String? role; // PASSENGER, DRIVER, ADMIN
  final String? photo;
  final double? rating;
  final bool? isVerified;

  User({
    this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.balance,
    this.isLoggedIn = false,
    this.role,
    this.photo,
    this.rating,
    this.isVerified,
  });

  // Alias para compatibilidade
  String get name => fullName;
  String get phone => phoneNumber;

  User copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? email,
    int? balance,
    bool? isLoggedIn,
    String? role,
    String? photo,
    double? rating,
    bool? isVerified,
  }) {
    return User(
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
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    // Suporta tanto 'wallet.balance' quanto 'balance' direto
    int balance = 0;
    int parseBalance(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = num.tryParse(value.replaceAll(',', '.'));
        return parsed?.toInt() ?? 0;
      }
      return 0;
    }

    final wallet = json['wallet'];
    if (wallet is Map && wallet['balance'] != null) {
      balance = parseBalance(wallet['balance']);
    } else if (json['balance'] != null) {
      balance = parseBalance(json['balance']);
    }

    return User(
      id: json['id'],
      fullName: json['fullName'] ?? json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone'] ?? '',
      email: json['email'],
      balance: balance,
      isLoggedIn: json['isLoggedIn'] ?? true,
      role: json['role'],
      photo: json['photo'] ?? json['avatar'],
      rating: double.tryParse(
          (json['rating'] ?? json['averageRating'])?.toString() ?? ''),
      isVerified: json['isVerified'] ?? json['verified'],
    );
  }
}
