import 'package:flutter/material.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/trip.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/faq_item.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/utils/constants.dart';

/// Service para gerenciar toda a lógica de negócio do app
class AppService extends ChangeNotifier {
  final ApiService _api = ApiService();

  User? user;
  List<VirtualCard> virtualCards = [];
  List<Transaction> transactions = [];
  List<Trip> trips = [];
  List<FAQItem> faqItems = [];
  bool hasSeenOnboarding = false;
  bool isLoading = false;
  String? errorMessage;

  // Estado de conexão
  bool _useOfflineMode = false;
  bool get isOnline => !_useOfflineMode;
  bool get isAuthenticated => _api.isAuthenticated;

  AppService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _api.loadTokens();
    if (_api.isAuthenticated) {
      await refreshUserData();
    } else {
      // Quando offline, deixar listas vazias (sem dados mock)
      _setOfflineState();
    }
  }

  void _setOfflineState() {
    // Não usar dados mock - apenas inicializar listas vazias
    virtualCards = [];
    transactions = [];
    trips = [];
    faqItems = [];
    notifyListeners();
  }

  void _setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  // ============ AUTH ============

  /// Registar novo utilizador
  Future<bool> register({
    required String fullName,
    required String phoneNumber,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);

    final result = await _api.register(
      fullName: fullName,
      phoneNumber: phoneNumber,
      password: password,
    );

    _setLoading(false);

    if (result.isSuccess) {
      return true;
    } else {
      _setError(result.error);
      return false;
    }
  }

  /// Verificar OTP
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    _setLoading(true);
    _setError(null);

    final result = await _api.verifyOtp(
      phoneNumber: phoneNumber,
      otpCode: otpCode,
    );

    _setLoading(false);

    if (result.isSuccess && result.data != null) {
      if (result.data!.user != null) {
        user = result.data!.user;
      }
      await refreshUserData();
      return true;
    } else {
      _setError(result.error);
      return false;
    }
  }

  /// Login
  Future<bool> login({
    required String phoneNumber,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);

    final result = await _api.login(
      phoneNumber: phoneNumber,
      password: password,
    );

    _setLoading(false);

    if (result.isSuccess && result.data != null) {
      if (result.data!.user != null) {
        user = result.data!.user;
      }
      await refreshUserData();
      return true;
    } else {
      _setError(result.error);
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _api.logout();
    user = null;
    virtualCards = [];
    transactions = [];
    trips = [];
    hasSeenOnboarding = false;
    notifyListeners();
  }

  /// Atualizar dados do utilizador
  Future<void> refreshUserData() async {
    try {
      final profileResult = await _api.getProfile();
      if (profileResult.isSuccess && profileResult.data != null) {
        user = profileResult.data!.copyWith(isLoggedIn: true);
      }

      // Carregar dados em paralelo
      final results = await Future.wait([
        _api.getTransactionHistory(),
        _api.getVirtualCards(),
        _api.getTrips(),
      ]);

      if (results[0].isSuccess) {
        transactions =
            (results[0] as ApiResponse<List<Transaction>>).data ?? [];
      }
      if (results[1].isSuccess) {
        virtualCards =
            (results[1] as ApiResponse<List<VirtualCard>>).data ?? [];
      }
      if (results[2].isSuccess) {
        trips = (results[2] as ApiResponse<List<Trip>>).data ?? [];
      }

      _useOfflineMode = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao atualizar dados: $e');
      _useOfflineMode = true;
      if (user == null) {
        _setOfflineState();
      }
    }
  }

  /// Verificar PIN
  Future<bool> verifyPin(String pin) async {
    final result = await _api.verifyPin(pin);
    return result.isSuccess && (result.data ?? false);
  }

  /// Alterar PIN
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    _setLoading(true);
    final result = await _api.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );
    _setLoading(false);

    if (!result.isSuccess) {
      _setError(result.error);
    }
    return result.isSuccess;
  }

  // Método legado para compatibilidade
  void handleAuth(String name, String phone, String pin) {
    user = User(
      fullName: name,
      phoneNumber: phone,
      balance: 15000,
      isLoggedIn: true,
    );
    notifyListeners();
  }

  void finishOnboarding() {
    hasSeenOnboarding = true;
    notifyListeners();
  }

  // ============ WALLET ============

  /// Carregar carteira (depósito)
  Future<bool> topupWallet(int amount, {String? reference}) async {
    _setLoading(true);
    _setError(null);

    final result = await _api.deposit(amount: amount, reference: reference);

    _setLoading(false);

    if (result.isSuccess && result.data != null) {
      // Atualizar saldo
      if (result.data!.newBalance != null) {
        user = user?.copyWith(balance: result.data!.newBalance);
      } else {
        user = user?.copyWith(balance: (user?.balance ?? 0) + amount);
      }

      // Adicionar transação localmente
      _addTransaction('topup', 'Carregamento Multicaixa', amount);

      notifyListeners();
      return true;
    } else {
      _setError(result.error);
      return false;
    }
  }

  /// Transferir para outro utilizador
  Future<bool> transfer({
    required String receiverPhone,
    required int amount,
    String? description,
  }) async {
    _setLoading(true);
    _setError(null);

    final result = await _api.transfer(
      amount: amount,
      receiverPhone: receiverPhone,
      description: description,
    );

    _setLoading(false);

    if (result.isSuccess && result.data != null) {
      if (result.data!.newBalance != null) {
        user = user?.copyWith(balance: result.data!.newBalance);
      } else {
        user = user?.copyWith(balance: (user?.balance ?? 0) - amount);
      }

      _addTransaction('payment', description ?? 'Transferência', -amount);

      notifyListeners();
      return true;
    } else {
      _setError(result.error);
      return false;
    }
  }

  // Método legado para compatibilidade
  void transferToPhone(String phone, int amount) {
    if (user != null && user!.balance >= amount) {
      user = user!.copyWith(balance: user!.balance - amount);
      _addTransaction('payment', 'Transferência para $phone', -amount);
      notifyListeners();
    }
  }

  // ============ PAYMENT ============

  /// Validar QR Code
  Future<QrValidationResult?> validateQrCode(String qrData) async {
    _setLoading(true);
    try {
      // Tentar extrair token embutido no QR (query param, token=, ou JWT-like)
      String token = '';
      try {
        final parsed = Uri.tryParse(qrData);
        if (parsed != null && parsed.queryParameters.containsKey('token')) {
          token = parsed.queryParameters['token'] ?? '';
        }
      } catch (_) {}

      if (token.isEmpty) {
        if (qrData.contains('token=')) {
          final parts = qrData.split('token=');
          if (parts.length > 1) token = parts[1];
        } else if (qrData.startsWith('eyJ')) {
          token = qrData;
        }
      }

      final tokenParam = token.isNotEmpty ? token : qrData;
      final result = await _api.resolveQrToken(tokenParam);

      _setLoading(false);

      if (result.isSuccess) {
        return result.data;
      } else {
        _setError(result.error);
        return null;
      }
    } catch (e) {
      _setLoading(false);
      _setError(e.toString());
      return null;
    }
  }

  /// Processar pagamento
  Future<bool> processPayment(String sourceId, int amount,
      {String? driverId}) async {
    _setLoading(true);
    _setError(null);

    if (driverId != null) {
      // Pagamento via API
      final result = await _api.transfer(
        amount: amount,
        receiverPhone: driverId,
        description: 'Pagamento de corrida',
      );

      _setLoading(false);

      if (result.isSuccess) {
        if (result.data?.newBalance != null) {
          user = user?.copyWith(balance: result.data!.newBalance);
        }
        await refreshUserData();
        return true;
      } else {
        _setError(result.error);
        return false;
      }
    }

    // Modo offline/local
    _setLoading(false);

    if (sourceId == 'main') {
      if (user != null && user!.balance >= amount) {
        user = user!.copyWith(balance: user!.balance - amount);
        _addTransaction('payment', 'Viagem - Taxista', -amount);
        notifyListeners();
        return true;
      }
    } else {
      final cardIndex = virtualCards.indexWhere((c) => c.id == sourceId);
      if (cardIndex != -1 && virtualCards[cardIndex].balance >= amount) {
        virtualCards[cardIndex] = virtualCards[cardIndex]
            .copyWith(balance: virtualCards[cardIndex].balance - amount);
        _addTransaction(
            'payment', 'Viagem - ${virtualCards[cardIndex].name}', -amount);
        notifyListeners();
        return true;
      }
    }

    return false;
  }

  // ============ VIRTUAL CARDS ============

  /// Criar cartão virtual
  Future<bool> createVirtualCard({
    required String name,
    required int initialBalance,
    required int dailyLimit,
    required String pin,
  }) async {
    _setLoading(true);
    _setError(null);

    final result = await _api.createVirtualCard(
      name: name,
      initialBalance: initialBalance,
      dailyLimit: dailyLimit,
      pin: pin,
    );

    _setLoading(false);

    if (result.isSuccess && result.data != null) {
      virtualCards.add(result.data!);
      // Deduzir do saldo principal
      user = user?.copyWith(balance: (user?.balance ?? 0) - initialBalance);
      notifyListeners();
      return true;
    } else {
      _setError(result.error);

      // Fallback local
      final newCard = VirtualCard(
        id: 'CARD-${DateTime.now().millisecondsSinceEpoch}-XXXX',
        name: name,
        balance: initialBalance,
        createdAt: DateTime.now().toString().split(' ')[0],
        dailyLimit: dailyLimit,
      );
      virtualCards.add(newCard);
      user = user?.copyWith(balance: (user?.balance ?? 0) - initialBalance);
      notifyListeners();
      return true;
    }
  }

  /// Excluir cartão virtual
  Future<bool> deleteVirtualCard(String cardId) async {
    _setLoading(true);

    final result = await _api.deleteVirtualCard(cardId);

    _setLoading(false);

    if (result.isSuccess && result.data != null) {
      virtualCards.removeWhere((c) => c.id == cardId);
      user = user?.copyWith(balance: result.data!.walletBalance);
      notifyListeners();
      return true;
    } else {
      // Fallback local
      final card = virtualCards.firstWhere((c) => c.id == cardId,
          orElse: () =>
              VirtualCard(id: '', name: '', balance: 0, createdAt: ''));
      virtualCards.removeWhere((c) => c.id == cardId);
      user = user?.copyWith(balance: (user?.balance ?? 0) + card.balance);
      notifyListeners();
      return true;
    }
  }

  /// Recarregar cartão virtual
  Future<bool> topupVirtualCard(String cardId, int amount) async {
    _setLoading(true);

    final result = await _api.topupVirtualCard(cardId: cardId, amount: amount);

    _setLoading(false);

    if (result.isSuccess && result.data != null) {
      final cardIndex = virtualCards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1) {
        virtualCards[cardIndex] =
            virtualCards[cardIndex].copyWith(balance: result.data!.cardBalance);
      }
      user = user?.copyWith(balance: result.data!.walletBalance);
      _addTransaction(
          'payment', 'Carregamento ${virtualCards[cardIndex].name}', -amount);
      notifyListeners();
      return true;
    } else {
      // Fallback local
      final cardIndex = virtualCards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1 && user != null && user!.balance >= amount) {
        virtualCards[cardIndex] = virtualCards[cardIndex]
            .copyWith(balance: virtualCards[cardIndex].balance + amount);
        user = user!.copyWith(balance: user!.balance - amount);
        _addTransaction(
            'payment', 'Carregamento ${virtualCards[cardIndex].name}', -amount);
        notifyListeners();
        return true;
      }
      return false;
    }
  }

  /// Congelar/ativar cartão
  Future<bool> updateCardStatus(String cardId, String status) async {
    final result = await _api.updateCardStatus(cardId: cardId, status: status);

    if (result.isSuccess) {
      final cardIndex = virtualCards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1) {
        virtualCards[cardIndex] = virtualCards[cardIndex].copyWith(
          status: status == 'frozen' ? CardStatus.frozen : CardStatus.active,
        );
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  /// Alterar limite do cartão
  Future<bool> updateCardLimit(String cardId, int dailyLimit) async {
    final result =
        await _api.updateCardLimit(cardId: cardId, dailyLimit: dailyLimit);

    if (result.isSuccess) {
      final cardIndex = virtualCards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1) {
        virtualCards[cardIndex] = virtualCards[cardIndex].copyWith(
          dailyLimit: dailyLimit,
        );
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  // ============ TRIPS ============

  /// Avaliar viagem
  Future<bool> rateTrip(String tripId, int stars, {String? comment}) async {
    // Buscar o driverId da viagem
    final trip = trips.firstWhere((t) => t.id == tripId,
        orElse: () => Trip(
              id: '',
              driverName: '',
              licensePlate: '',
              origin: '',
              destination: '',
              date: '',
              time: '',
              amount: 0,
              status: '',
            ));

    // Por enquanto usar tripId como targetUserId
    final result = await _api.createRating(
      targetUserId: tripId,
      stars: stars,
      comment: comment,
    );

    if (result.isSuccess) {
      // Atualizar a viagem localmente
      final tripIndex = trips.indexWhere((t) => t.id == tripId);
      if (tripIndex != -1) {
        // Trip não tem copyWith, então recriar
        final oldTrip = trips[tripIndex];
        trips[tripIndex] = Trip(
          id: oldTrip.id,
          driverName: oldTrip.driverName,
          licensePlate: oldTrip.licensePlate,
          origin: oldTrip.origin,
          destination: oldTrip.destination,
          date: oldTrip.date,
          time: oldTrip.time,
          amount: oldTrip.amount,
          rating: stars.toDouble(),
          status: oldTrip.status,
        );
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  // ============ FAQ ============

  /// Carregar FAQ da API
  Future<void> loadFaq() async {
    final result = await _api.getFaq();
    if (result.isSuccess && result.data != null) {
      faqItems = result.data!;
    } else {
      faqItems = Constants.faqData;
    }
    notifyListeners();
  }

  // ============ NOTIFICATIONS ============

  /// Obter notificações
  Future<NotificationsResult?> getNotifications() async {
    final result = await _api.getNotifications();
    if (result.isSuccess) {
      return result.data;
    }
    return null;
  }

  /// Marcar notificação como lida
  Future<void> markNotificationRead(String notificationId) async {
    await _api.markNotificationRead(notificationId);
  }

  /// Marcar todas como lidas
  Future<void> markAllNotificationsRead() async {
    await _api.markAllNotificationsRead();
  }

  // ============ SAFETY ============

  /// Acionar botão de pânico
  Future<bool> triggerPanic({
    required double latitude,
    required double longitude,
  }) async {
    final result = await _api.triggerPanic(
      latitude: latitude,
      longitude: longitude,
    );
    return result.isSuccess;
  }

  // ============ HELPERS ============

  void _addTransaction(String type, String description, int amount) {
    transactions.insert(
      0,
      Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        description: description,
        amount: amount,
        date: DateTime.now().toString().split(' ')[0],
        time:
            '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
      ),
    );
  }

  int getSourceBalance(String sourceId) {
    if (sourceId == 'main') return user?.balance ?? 0;
    final card = virtualCards.firstWhere(
      (c) => c.id == sourceId,
      orElse: () => VirtualCard(
        id: '',
        name: '',
        balance: 0,
        createdAt: '',
      ),
    );
    return card.balance;
  }

  VirtualCard? getVirtualCard(String cardId) {
    try {
      return virtualCards.firstWhere((c) => c.id == cardId);
    } catch (e) {
      return null;
    }
  }
}
