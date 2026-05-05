/// Modelo de transação do motorista
class Transaction {
  final String id;
  final String type; // 'DEPOSIT' | 'WITHDRAWAL' | 'TRANSFER' | 'received' | 'withdrawal'
  final String description;
  final dynamic amount; // Pode ser string ou número
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

  bool get isReceived => type == 'received';
  bool get isWithdrawal => type == 'withdrawal';
  bool get isRefund => type == 'refund';

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

    return Transaction(
      id: json['id'] ?? '',
      type: json['type'] ?? 'DEPOSIT',
      description: json['description'] ?? '',
      amount: json['amount'] ?? 0,
      date: date,
      time: time,
      passengerName: json['passengerName'] ?? json['passenger']?['name'],
      status: json['status'],
      paymentMethod: json['paymentMethod'],
      createdAt: createdAt,
      receiverWallet: json['receiverWallet'],
    );
  }
}
