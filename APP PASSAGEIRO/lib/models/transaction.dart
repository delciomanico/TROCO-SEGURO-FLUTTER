class Transaction {
  final String id;
  final String type; // 'payment' | 'topup' | 'DEPOSIT' | 'TRANSFER'
  final String description;
  final int amount;
  final String date;
  final String time;
  final String? status; // 'COMPLETED', 'PENDING', etc.
  final String? driver;
  final String? reason;
  final String? paymentSource;
  final String? direction; // 'IN' | 'OUT'
  final int? displayAmount; // Amount with sign
  final int? originalAmount; // Original amount (always positive)
  final String? currency;
  final String? counterparty;

  Transaction({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.time,
    this.status,
    this.driver,
    this.reason,
    this.paymentSource,
    this.direction,
    this.displayAmount,
    this.originalAmount,
    this.currency,
    this.counterparty,
  });
  
  bool get isIncoming => direction == 'IN' || (displayAmount ?? amount) > 0;
  bool get isOutgoing => direction == 'OUT' || (displayAmount ?? amount) < 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'amount': amount,
      'date': date,
      'time': time,
      'status': status,
      'driver': driver,
      'reason': reason,
      'paymentSource': paymentSource,
      'direction': direction,
      'displayAmount': displayAmount,
      'originalAmount': originalAmount,
      'currency': currency,
      'counterparty': counterparty,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Parse date and time
    String dateStr = '';
    String timeStr = '';
    
    if (json['createdAt'] != null || json['date'] != null) {
      try {
        final dateTimeStr = json['createdAt'] ?? json['date'];
        final dateTime = DateTime.parse(dateTimeStr);
        dateStr = '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
        timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        if (json['createdAt'] != null) {
          final parts = json['createdAt'].toString().split('T');
          dateStr = parts.isNotEmpty ? parts[0] : '';
          timeStr = parts.length > 1 ? parts[1].substring(0, 5) : '';
        }
      }
    }
    
    // Parse amounts - handle displayAmount, originalAmount, or fallback to amount
    int amountValue = 0;
    int? displayAmountValue;
    int? originalAmountValue;
    
    if (json['displayAmount'] != null) {
      displayAmountValue = _parseAmount(json['displayAmount']);
      amountValue = displayAmountValue;
    }
    if (json['originalAmount'] != null) {
      originalAmountValue = _parseAmount(json['originalAmount']);
    }
    if (json['amount'] != null) {
      amountValue = _parseAmount(json['amount']);
    }
    
    return Transaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'payment',
      description: json['description']?.toString() ?? '',
      amount: amountValue,
      date: dateStr,
      time: timeStr,
      status: json['status']?.toString(),
      driver: json['driver']?.toString(),
      reason: json['reason']?.toString(),
      paymentSource: json['paymentSource']?.toString(),
      direction: json['direction']?.toString(),
      displayAmount: displayAmountValue,
      originalAmount: originalAmountValue,
      currency: json['currency']?.toString() ?? 'AOA',
      counterparty: json['counterparty']?.toString(),
    );
  }
  
  static int _parseAmount(dynamic value) {
    if (value is int) {
      return value;
    } else if (value is String) {
      // Remove decimal part if present ("5000.00" -> 5000)
      final cleanAmount = value.split('.')[0];
      return int.tryParse(cleanAmount) ?? 0;
    } else if (value is double) {
      return value.toInt();
    }
    return 0;
  }
}
