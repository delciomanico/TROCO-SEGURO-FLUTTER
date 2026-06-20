enum CardStatus { active, frozen, blocked }

/// Payload sent to POST /api/v1/virtual-cards
class CreateCardPayload {
  final String name;
  final int initialBalance;
  final int dailyLimit;
  final String userPin;  // 6-digit account PIN for identity proof
  final String cardPin;  // 4-digit card PIN for purchases

  const CreateCardPayload({
    required this.name,
    required this.initialBalance,
    required this.dailyLimit,
    required this.userPin,
    required this.cardPin,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'initialBalance': initialBalance,
    'dailyLimit': dailyLimit,
    'userPin': userPin,
    'cardPin': cardPin,
  };
}

/// Holds the sensitive fields returned ONCE by the API on creation.
/// pinHash is NEVER returned — never attempt to store it.
class VirtualCardCreated {
  final VirtualCard card;      // full card object
  final String cardNumber;     // 16-digit PAN
  final String cvv;            // 3-digit CVV
  final String expiryDate;     // MM/YY

  const VirtualCardCreated({
    required this.card,
    required this.cardNumber,
    required this.cvv,
    required this.expiryDate,
  });
}

/// Response shape from POST /api/v1/virtual-cards
class VirtualCardResponse {
  final String id;
  final String name;
  final String cardNumber;
  final String cvv;
  final String expiryDate;
  final String status;   // 'ACTIVE' | 'FROZEN'
  final int balance;

  const VirtualCardResponse({
    required this.id,
    required this.name,
    required this.cardNumber,
    required this.cvv,
    required this.expiryDate,
    required this.status,
    required this.balance,
  });

  factory VirtualCardResponse.fromJson(Map<String, dynamic> json) {
    return VirtualCardResponse(
      id:         json['id']?.toString() ?? '',
      name:       json['name']?.toString() ?? '',
      cardNumber: json['cardNumber']?.toString() ?? '',
      cvv:        json['cvv']?.toString() ?? '',
      expiryDate: json['expiryDate']?.toString() ?? '',
      status:     json['status']?.toString() ?? 'ACTIVE',
      balance:    _parseInt(json['balance']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Convert to a VirtualCardCreated so the UI can show the sensitive fields
  /// once and then discard them.
  VirtualCardCreated toCreated() {
    return VirtualCardCreated(
      card: VirtualCard(
        id:        id,
        name:      name,
        balance:   balance,
        createdAt: DateTime.now().toIso8601String(),
        status:    status.toUpperCase() == 'FROZEN'
                       ? CardStatus.frozen
                       : CardStatus.active,
      ),
      cardNumber: cardNumber,
      cvv:        cvv,
      expiryDate: expiryDate,
    );
  }
}

class VirtualCard {
  final String id;
  final String name;
  final int balance;
  final String createdAt;
  final int dailyLimit; // 0 = unlimited
  final int spentToday; // spent in current day
  final CardStatus status; // active, frozen, blocked
  final String? qrToken; // Unique token for QR generation
  final String? lastModified;

  VirtualCard({
    required this.id,
    required this.name,
    required this.balance,
    required this.createdAt,
    this.dailyLimit = 0,
    this.spentToday = 0,
    this.status = CardStatus.active,
    this.qrToken,
    this.lastModified,
  });

  bool get isFrozen => status == CardStatus.frozen;
  bool get isBlocked => status == CardStatus.blocked;

  VirtualCard copyWith({
    String? id,
    String? name,
    int? balance,
    String? createdAt,
    int? dailyLimit,
    int? spentToday,
    CardStatus? status,
    String? qrToken,
    String? lastModified,
  }) {
    return VirtualCard(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      spentToday: spentToday ?? this.spentToday,
      status: status ?? this.status,
      qrToken: qrToken ?? this.qrToken,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'createdAt': createdAt,
      'dailyLimit': dailyLimit,
      'spentToday': spentToday,
      'status': status.toString().split('.').last,
      'qrToken': qrToken,
      'lastModified': lastModified,
    };
  }

  factory VirtualCard.fromJson(Map<String, dynamic> json) {
    final card = VirtualCard(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      balance: _parseInt(json['balance']),
      createdAt: json['createdAt']?.toString() ?? '',
      dailyLimit: _parseInt(json['dailyLimit']),
      spentToday: _parseInt(json['spentToday']),
      status: _parseStatus(json['status']?.toString()),
      qrToken: json['qrToken']?.toString(),
      lastModified: json['lastModified']?.toString(),
    );
    
    return card;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value.replaceAll(',', '.'));
      return parsed?.toInt() ?? 0;
    }
    return 0;
  }

  static CardStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'FROZEN':
        return CardStatus.frozen;
      case 'BLOCKED':
        return CardStatus.blocked;
      default:
        return CardStatus.active;
    }
  }
}
