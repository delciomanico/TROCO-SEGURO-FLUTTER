/// Modelo de transação do motorista
class Transaction {
  final String id;
  final String type; // 'DEPOSIT' | 'WITHDRAWAL' | 'TRANSFER' | 'received' | 'withdrawal'
  final String description;
  final int amount; // Saldo em Kz
  final String date;
  final String time;
  final String? passengerName;
  final String? status; // 'COMPLETED' | 'PENDING' | 'FAILED' | 'completed' | 'pending'
  final String? paymentMethod;
  final DateTime? createdAt;
  final Map<String, dynamic>? receiverWallet;

  Transaction({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.time,
    this.passengerName,
    this.status,
    this.paymentMethod,
    this.createdAt,
    this.receiverWallet,
  });

  bool get isReceived => type == 'received' || type == 'DEPOSIT';
  bool get isWithdrawal => type == 'withdrawal' || type == 'WITHDRAWAL';
  bool get isRefund => type == 'refund' || type == 'REFUND';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'amount': amount,
      'date': date,
      'time': time,
      'passengerName': passengerName,
      'status': status,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt?.toIso8601String(),
      'receiverWallet': receiverWallet,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    try {
      createdAt = json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : null;
    } catch (e) {
      createdAt = null;
    }

    final date = createdAt?.toString().split(' ')[0] ?? json['date'] ?? '';
    final time = createdAt?.toString().split(' ')[1].substring(0, 5) ?? json['time'] ?? '';

    // Normaliza o tipo da API (maísculas) para o padrão interno (minúsculas)
    final rawType = (json['type'] ?? 'DEPOSIT').toString().toUpperCase();
    final direction = (json['direction'] ?? '').toString().toUpperCase();
    
    String normalizedType;
    if (direction == 'IN') {
      normalizedType = 'received';
    } else if (direction == 'OUT') {
      normalizedType = 'withdrawal';
    } else {
      switch (rawType) {
        case 'DEPOSIT':
        case 'PAYMENT':
        case 'CREDIT':
          normalizedType = 'received';
          break;
        case 'WITHDRAWAL':
        case 'DEBIT':
          normalizedType = 'withdrawal';
          break;
        case 'TRANSFER':
          normalizedType = 'transfer';
          break;
        case 'REFUND':
          normalizedType = 'refund';
          break;
        default:
          normalizedType = rawType.toLowerCase();
      }
    }

    // Pega o valor absoluto do displayAmount ou originalAmount
    final int amount = () {
      final raw = json['displayAmount'] ?? json['originalAmount'] ?? json['amount'] ?? json['value'] ?? 0;
      if (raw is num) return raw.toInt().abs();
      return double.tryParse(raw.toString())?.toInt().abs() ?? 0;
    }();

    return Transaction(
      id: json['id'] ?? '',
      type: normalizedType,
      description: json['description'] ?? '',
      amount: amount,
      date: date,
      time: time,
      passengerName: json['passengerName'] ?? json['counterparty'] ?? json['passenger']?['name'],
      status: json['status'],
      paymentMethod: json['paymentMethod'],
      createdAt: createdAt,
      receiverWallet: json['receiverWallet'] is Map
          ? (json['receiverWallet'] as Map).cast<String, dynamic>()
          : null,
    );
  }
}
