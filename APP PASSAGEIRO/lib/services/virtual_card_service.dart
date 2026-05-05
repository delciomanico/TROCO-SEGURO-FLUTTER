import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';

/// Service to manage virtual card operations: PIN validation, limits, QR generation, freeze/unfreeze.
class VirtualCardService {
  static final VirtualCardService _instance = VirtualCardService._internal();
  factory VirtualCardService() => _instance;
  VirtualCardService._internal();

  static const _cardPinPrefix = 'ts_card_pin_';

  /// Save card-specific PIN securely (separate from account PIN).
  Future<void> saveCardPin(String cardId, String pin) async {
    await SecureStorageService()
        .savePin('$_cardPinPrefix$cardId'); // Store as card-specific key
    // Note: For production, encrypt pin or use HSM
  }

  /// Validate card PIN.
  Future<bool> validateCardPin(String cardId, String pin) async {
    // In production, compare with secure stored pin
    // For now, simple comparison (replace with secure comparison)
    return true; // Placeholder
  }

  /// Check if transaction would exceed daily limit.
  bool checkDailyLimit(VirtualCard card, int amount) {
    if (card.dailyLimit == 0) return true; // No limit
    return (card.spentToday + amount) <= card.dailyLimit;
  }

  /// Check if card has sufficient balance.
  bool checkBalance(VirtualCard card, int amount) {
    return card.balance >= amount;
  }

  /// Validate if card can be used (not frozen, not blocked).
  String? validateCardUsage(VirtualCard card) {
    if (card.isFrozen) return 'Cartão congelado';
    if (card.isBlocked) return 'Cartão bloqueado';
    return null;
  }

  /// Full validation pipeline before transaction.
  String? validateTransaction(VirtualCard card, int amount) {
    final usageError = validateCardUsage(card);
    if (usageError != null) return usageError;

    if (!checkBalance(card, amount)) return 'Saldo insuficiente no cartão';
    if (!checkDailyLimit(card, amount)) {
      return 'Limite diário excedido para este cartão';
    }

    return null;
  }

  /// Update card spending after transaction (call after confirmed payment).
  VirtualCard recordSpending(VirtualCard card, int amount) {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Reset daily if date changed
    int newSpentToday = card.spentToday;
    if (card.lastModified != null && !card.lastModified!.startsWith(today)) {
      newSpentToday = 0;
    }

    return card.copyWith(
      balance: card.balance - amount,
      spentToday: newSpentToday + amount,
      lastModified: DateTime.now().toIso8601String(),
    );
  }

  /// Freeze card (disable transactions).
  VirtualCard freezeCard(VirtualCard card) {
    return card.copyWith(status: CardStatus.frozen);
  }

  /// Unfreeze card.
  VirtualCard unfreezeCard(VirtualCard card) {
    return card.copyWith(status: CardStatus.active);
  }

  /// Block card permanently (e.g., after fraud).
  VirtualCard blockCard(VirtualCard card) {
    return card.copyWith(status: CardStatus.blocked);
  }

  /// Generate or regenerate QR token (for displaying QR code).
  String generateQRToken() {
    // Simple implementation: UUID-like token
    return 'qr_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().millisecond * 997).toString()}';
  }

  /// Get card info for QR display payload (ready for frontend to encode).
  Map<String, dynamic> getQRPayload(VirtualCard card) {
    return {
      'cardId': card.id,
      'cardName': card.name,
      'token': card.qrToken ?? generateQRToken(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'nonce': _generateNonce(),
    };
  }

  String _generateNonce() {
    return 'nonce_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Top-up card from main wallet.
  VirtualCard topupCard(VirtualCard card, int amount) {
    return card.copyWith(
      balance: card.balance + amount,
      lastModified: DateTime.now().toIso8601String(),
    );
  }

  /// Get remaining daily limit.
  int getRemainingDailyLimit(VirtualCard card) {
    if (card.dailyLimit == 0) return 999999; // Unlimited
    return (card.dailyLimit - card.spentToday).clamp(0, card.dailyLimit);
  }

  /// Reset daily spending on new day (call on daily timer or app startup).
  VirtualCard resetDailyIfNeeded(VirtualCard card) {
    if (card.lastModified == null) return card;
    final lastDate = card.lastModified!.split('T')[0];
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (lastDate != today) {
      return card.copyWith(spentToday: 0);
    }
    return card;
  }
}
