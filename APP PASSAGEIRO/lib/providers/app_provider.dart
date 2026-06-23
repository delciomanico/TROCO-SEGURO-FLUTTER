import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/models/trip.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/notification_service.dart';

/// Domínios de dados gerenciados pelo AppProvider.
/// Usado em [AppProvider.invalidate] para refrescar apenas o domínio afetado.
enum AppDomain { user, cards, transactions, trips }

/// Provider principal para gerenciar estado global da aplicação
class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  SharedPreferences? _prefs;

  // Estado do usuário
  User? _user;
  bool _isAuthenticated = false;
  bool _isLoadingUser = false;
  String? _error;

  // Estado dos cartões virtuais
  List<VirtualCard> _virtualCards = [];
  bool _isLoadingCards = false;
  DateTime? _cardsLastFetch;

  // Estado das transações
  List<Transaction> _transactions = [];
  bool _isLoadingTransactions = false;
  DateTime? _transactionsLastFetch;

  // Estado das viagens
  List<Trip> _trips = [];
  bool _isLoadingTrips = false;
  DateTime? _tripsLastFetch;

  // Duração do cache (5 minutos)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Aviso de tentativas de PIN restantes (ex: durante compra com cartão)
  String? _pinAttemptsWarning;
  String? get pinAttemptsWarning => _pinAttemptsWarning;

  void setPinAttemptsWarning(String? msg) {
    _pinAttemptsWarning = msg;
    notifyListeners();
  }

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoadingUser => _isLoadingUser;
  String? get error => _error;

  List<VirtualCard> get virtualCards => _virtualCards;
  bool get isLoadingCards => _isLoadingCards;

  List<Transaction> get transactions => _transactions;
  bool get isLoadingTransactions => _isLoadingTransactions;

  List<Trip> get trips => _trips;
  bool get isLoadingTrips => _isLoadingTrips;

  // Expor API Service para chamadas diretas quando necessário
  ApiService get apiService => _api;

  /// Inicializar provider
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _api.loadTokens();
    await _loadFromCache();

    // Se temos dados no cache, carregar do servidor em background
    if (_user != null) {
      _isAuthenticated = _user!.isLoggedIn;
      _refreshAllDataInBackground();
      _registerFcmToken();
    }
  }

  /// Carregar dados do cache local
  Future<void> _loadFromCache() async {
    if (_prefs == null) return;

    // Carregar usuário
    final userJson = _prefs!.getString('ts_user');
    if (userJson != null) {
      final user = User.fromJson(json.decode(userJson));

      // VERIFICAÇÃO DE DADOS MOCKADOS ANTIGOS
      // Se detectarmos o usuário mockado "Adilson Fernandes" com ID "1",
      // devemos limpar o cache para forçar o login real
      if (user.id == '1' && user.fullName == 'Adilson Fernandes') {
        debugPrint('🧹 Cache limpo: Dados mockados detectados');
        await logout(); // Limpa tudo
        return;
      }

      _user = user;
      _isAuthenticated = _user!.isLoggedIn;
    }

    // Carregar cartões
    final cardsJson = _prefs!.getString('ts_cards');
    if (cardsJson != null) {
      _virtualCards = (json.decode(cardsJson) as List)
          .map((card) => VirtualCard.fromJson(card))
          .toList();
    }

    // Carregar transações
    final txsJson = _prefs!.getString('ts_transactions');
    if (txsJson != null) {
      _transactions = (json.decode(txsJson) as List)
          .map((tx) => Transaction.fromJson(tx))
          .toList();
    }

    // Carregar viagens
    final tripsJson = _prefs!.getString('ts_trips');
    if (tripsJson != null) {
      _trips = (json.decode(tripsJson) as List)
          .map((trip) => Trip.fromJson(trip))
          .toList();
    }

    notifyListeners();
  }

  Future<void> _registerFcmToken() async {
    try {
      await NotificationService().initialize();
      final token = await NotificationService().getToken();
      if (token != null) {
        await _api.updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('Erro ao registar FCM token: $e');
    }
  }

  /// Refresh de todos os dados em background (sem loading state)
  Future<void> _refreshAllDataInBackground() async {
    try {
      // Executar todas as chamadas em paralelo
      await Future.wait([
        _fetchUserFromApi(showLoading: false),
        _fetchCardsFromApi(showLoading: false),
        _fetchTransactionsFromApi(showLoading: false),
        _fetchTripsFromApi(showLoading: false),
      ]);
    } catch (e) {
      debugPrint('Erro ao atualizar dados em background: $e');
    }
  }

  /// Buscar perfil do usuário da API
  Future<void> _fetchUserFromApi({bool showLoading = true}) async {
    if (showLoading) {
      _isLoadingUser = true;
      notifyListeners();
    }

    try {
      final result = await _api.getProfile();
      if (result.isSuccess && result.data != null) {
        _user = result.data!;
        _isAuthenticated = true;
        await _prefs?.setString('ts_user', json.encode(_user!.toJson()));
        if (showLoading) notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao buscar perfil: $e');
    } finally {
      if (showLoading) {
        _isLoadingUser = false;
        notifyListeners();
      }
    }
  }

  /// Buscar cartões virtuais da API
  Future<void> _fetchCardsFromApi({bool showLoading = true}) async {
    if (showLoading) {
      _isLoadingCards = true;
      notifyListeners();
    }

    try {
      final result = await _api.getVirtualCards();
      debugPrint(
          '🔄 Resultado getVirtualCards: success=${result.isSuccess}, count=${result.data?.length ?? 0}');

      if (result.isSuccess && result.data != null) {
        _virtualCards = result.data!;
        _cardsLastFetch = DateTime.now();
        await _prefs?.setString(
          'ts_cards',
          json.encode(_virtualCards.map((c) => c.toJson()).toList()),
        );
        debugPrint(
            '✅ Cartões atualizados: ${_virtualCards.map((c) => c.name).toList()}');
        notifyListeners(); // Sempre notificar quando dados mudam
      } else {
        debugPrint('❌ Erro ao buscar cartões: ${result.error}');
      }
    } catch (e) {
      debugPrint('❌ Exceção ao buscar cartões: $e');
    } finally {
      if (showLoading) {
        _isLoadingCards = false;
        notifyListeners();
      }
    }
  }

  /// Buscar transações da API
  Future<void> _fetchTransactionsFromApi({bool showLoading = true}) async {
    if (showLoading) {
      _isLoadingTransactions = true;
      notifyListeners();
    }

    try {
      final result = await _api.getTransactionHistory();
      if (result.isSuccess && result.data != null) {
        _transactions = result.data!;
        _transactionsLastFetch = DateTime.now();
        await _prefs?.setString(
          'ts_transactions',
          json.encode(_transactions.map((t) => t.toJson()).toList()),
        );
        if (showLoading) notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao buscar transações: $e');
    } finally {
      if (showLoading) {
        _isLoadingTransactions = false;
        notifyListeners();
      }
    }
  }

  /// Buscar viagens da API
  Future<void> _fetchTripsFromApi({bool showLoading = true}) async {
    if (showLoading) {
      _isLoadingTrips = true;
      notifyListeners();
    }

    try {
      final result = await _api.getTrips();
      if (result.isSuccess && result.data != null) {
        _trips = result.data!;
        _tripsLastFetch = DateTime.now();
        await _prefs?.setString(
          'ts_trips',
          json.encode(_trips.map((t) => t.toJson()).toList()),
        );
        if (showLoading) notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao buscar viagens: $e');
    } finally {
      if (showLoading) {
        _isLoadingTrips = false;
        notifyListeners();
      }
    }
  }

  /// Verificar se o cache está válido
  bool _isCacheValid(DateTime? lastFetch) {
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheDuration;
  }

  /// Refresh manual dos dados do usuário
  Future<void> refreshUserData() async {
    await _fetchUserFromApi(showLoading: true);
  }

  /// Refresh manual dos cartões virtuais
  Future<void> refreshVirtualCards() async {
    await _fetchCardsFromApi(showLoading: true);
  }

  /// Refresh manual das transações
  Future<void> refreshTransactions() async {
    await _fetchTransactionsFromApi(showLoading: true);
  }

  /// Refresh manual das viagens
  Future<void> refreshTrips() async {
    await _fetchTripsFromApi(showLoading: true);
  }

  /// Invalida o cache de um domínio e dispara um fetch em background (sem
  /// loading state visível). Chame isto após qualquer mutação que afete um
  /// domínio específico para que a UI reaja automaticamente.
  ///
  /// Exemplo de uso:
  /// ```dart
  /// // Após um pagamento que afeta saldo, transações e viagens:
  /// provider.invalidate(AppDomain.user);
  /// provider.invalidate(AppDomain.transactions);
  /// provider.invalidate(AppDomain.trips);
  /// ```
  void invalidate(AppDomain domain) {
    switch (domain) {
      case AppDomain.user:
        _fetchUserFromApi(showLoading: false);
      case AppDomain.cards:
        _cardsLastFetch = null;
        _fetchCardsFromApi(showLoading: false);
      case AppDomain.transactions:
        _transactionsLastFetch = null;
        _fetchTransactionsFromApi(showLoading: false);
      case AppDomain.trips:
        _tripsLastFetch = null;
        _fetchTripsFromApi(showLoading: false);
    }
  }

  /// Criar cartão virtual via API.
  /// Retorna [VirtualCardCreated] em caso de sucesso (PAN/CVV exibido 1x)
  /// ou lança uma String de erro.
  Future<VirtualCardCreated> createVirtualCard({
    required String name,
    required int initialBalance,
    required int dailyLimit,
    required String userPin,
    required String cardPin,
  }) async {
    _isLoadingCards = true;
    notifyListeners();

    try {
      debugPrint(
          '📱 Criando cartão: name=$name, balance=$initialBalance, limit=$dailyLimit');

      final payload = CreateCardPayload(
        name:           name,
        initialBalance: initialBalance,
        dailyLimit:     dailyLimit,
        userPin:        userPin,
        cardPin:        cardPin,
      );

      final result = await _api.createVirtualCard(payload);

      debugPrint(
          '📱 Response createVirtualCard: success=${result.isSuccess}, error=${result.error}');

      if (result.isSuccess && result.data != null) {
        final created = result.data!.toCreated();

        // Actualizar saldo do utilizador e lista de cartões
        await _fetchUserFromApi(showLoading: false);
        await _fetchCardsFromApi(showLoading: false);

        _isLoadingCards = false;
        notifyListeners();
        return created;
      } else {
        _isLoadingCards = false;
        notifyListeners();
        throw result.error ?? 'Erro ao criar cartão virtual.';
      }
    } catch (e) {
      _isLoadingCards = false;
      notifyListeners();
      if (e is String) rethrow;
      throw 'Erro ao criar cartão virtual.';
    }
  }

  /// Deletar cartão virtual via API
  Future<bool> deleteVirtualCard(String cardId) async {
    _isLoadingCards = true;
    notifyListeners();

    try {
      final result = await _api.deleteVirtualCard(cardId);

      if (result.isSuccess) {
        _virtualCards.removeWhere((c) => c.id == cardId);
        await _prefs?.setString(
          'ts_cards',
          json.encode(_virtualCards.map((c) => c.toJson()).toList()),
        );

        // Atualizar dados do usuário (saldo retornou)
        if (result.data != null) {
          // API retorna novo saldo, atualizar localmente
          if (_user != null) {
            _user = _user!.copyWith(balance: result.data!.walletBalance);
            await _prefs?.setString('ts_user', json.encode(_user!.toJson()));
          }
        } else {
          await _fetchUserFromApi(showLoading: false);
        }

        _isLoadingCards = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Erro ao deletar cartão: $e');
    }

    _isLoadingCards = false;
    notifyListeners();
    return false;
  }

  /// Transferir saldo entre cartões virtuais
  Future<String?> transferBetweenVirtualCards({
    required String fromCardId,
    required String toCardId,
    required int amount,
    required String pin,
  }) async {
    if (fromCardId == toCardId) return 'Selecione cartões diferentes.';
    if (amount <= 0) return 'O montante deve ser maior que zero.';

    final fromIndex = _virtualCards.indexWhere((c) => c.id == fromCardId);
    final toIndex = _virtualCards.indexWhere((c) => c.id == toCardId);
    if (fromIndex == -1 || toIndex == -1) return 'Cartão não encontrado.';

    final source = _virtualCards[fromIndex];
    final destination = _virtualCards[toIndex];

    if (source.isFrozen || source.isBlocked) return 'Cartão de origem indisponível.';
    if (destination.isFrozen || destination.isBlocked) return 'Cartão de destino indisponível.';
    if (source.balance < amount) return 'Saldo insuficiente no cartão de origem.';

    try {
      final result = await _api.transferBetweenCards(
        fromCardId: fromCardId,
        toCardId: toCardId,
        amount: amount,
        pin: pin,
      );

      if (!result.isSuccess) return result.error ?? 'Erro ao transferir entre cartões.';

      // Actualizar estado local optimistamente
      final timestamp = DateTime.now().toIso8601String();
      _virtualCards[fromIndex] = source.copyWith(
        balance: source.balance - amount,
        lastModified: timestamp,
      );
      _virtualCards[toIndex] = destination.copyWith(
        balance: destination.balance + amount,
        lastModified: timestamp,
      );
      await _prefs?.setString(
        'ts_cards',
        json.encode(_virtualCards.map((c) => c.toJson()).toList()),
      );
      notifyListeners();
      invalidate(AppDomain.cards);
      return null;
    } catch (e) {
      debugPrint('Erro ao transferir entre cartões: $e');
      return 'Erro ao transferir entre cartões.';
    }
  }

  /// Transferir saldo da carteira principal para um cartão virtual
  Future<String?> transferFromWalletToVirtualCard({
    required String cardId,
    required int amount,
  }) async {
    _isLoadingCards = true;
    notifyListeners();

    try {
      if (_user == null) {
        return 'Usuário não encontrado.';
      }

      if (amount <= 0) {
        return 'O montante deve ser maior que zero.';
      }

      final cardIndex = _virtualCards.indexWhere((card) => card.id == cardId);
      if (cardIndex == -1) {
        return 'Cartão não encontrado.';
      }

      final targetCard = _virtualCards[cardIndex];
      if (targetCard.isFrozen || targetCard.isBlocked) {
        return 'Cartão de destino indisponível.';
      }

      if (_user!.balance < amount) {
        return 'Saldo insuficiente na carteira principal.';
      }

      final timestamp = DateTime.now().toIso8601String();

      _user = _user!.copyWith(balance: _user!.balance - amount);
      _virtualCards[cardIndex] = targetCard.copyWith(
        balance: targetCard.balance + amount,
        lastModified: timestamp,
      );

      await _prefs?.setString('ts_user', json.encode(_user!.toJson()));
      await _prefs?.setString(
        'ts_cards',
        json.encode(_virtualCards.map((card) => card.toJson()).toList()),
      );

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Erro ao transferir da carteira para cartão: $e');
      return 'Erro ao transferir para cartão virtual.';
    } finally {
      _isLoadingCards = false;
      notifyListeners();
    }
  }

  /// Depositar da carteira para cartão virtual (usa API /wallet/card/deposit)
  Future<String?> depositToVirtualCard({
    required String cardId,
    required int amount,
  }) async {
    try {
      final result =
          await _api.depositToVirtualCard(cardId: cardId, amount: amount);
      if (result.isSuccess) {
        final idx = _virtualCards.indexWhere((c) => c.id == cardId);
        if (idx != -1 && result.data != null) {
          if (result.data!.newBalance != null) {
            _virtualCards[idx] =
                _virtualCards[idx].copyWith(balance: result.data!.newBalance!);
          }
          if (_user != null && result.data!.newBalance != null) {
            _user = _user!.copyWith(balance: _user!.balance - amount);
            await _prefs?.setString(
                'ts_user', json.encode(_user!.toJson()));
          }
          await _prefs?.setString(
            'ts_cards',
            json.encode(_virtualCards.map((c) => c.toJson()).toList()),
          );
          notifyListeners();
        }
        return null;
      }
      return result.error ?? 'Erro ao depositar no cartão.';
    } catch (e) {
      return 'Erro ao depositar no cartão.';
    }
  }

  /// Atualizar perfil do usuário
  Future<bool> updateProfile({
    String? fullName,
    String? email,
  }) async {
    _isLoadingUser = true;
    notifyListeners();

    try {
      final result = await _api.updateProfile(
        fullName: fullName,
        email: email,
      );

      if (result.isSuccess && result.data != null) {
        _user = result.data!;
        await _prefs?.setString('ts_user', json.encode(_user!.toJson()));
        _isLoadingUser = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Erro ao atualizar perfil: $e');
    }

    _isLoadingUser = false;
    notifyListeners();
    return false;
  }

  /// Definir usuário autenticado (pós-login/registro)
  Future<void> setAuthenticatedUser(User user,
      {String? accessToken, String? refreshToken}) async {
    _user = user;
    _isAuthenticated = true;

    // Se recebemos tokens novos, configurar API imediatamente
    if (accessToken != null) {
      _api.setTokens(accessToken, refreshToken);
      // Opcional: Salvar tokens se ainda não foram salvos (mas AuthScreen já salva)
    }

    await _prefs?.setString('ts_user', json.encode(user.toJson()));
    notifyListeners();

    // Carregar todos os dados e registar FCM após login
    await _refreshAllDataInBackground();
    _registerFcmToken();
  }

  /// Transferir para outro usuário (P2P)
  Future<bool> transfer({
    required String receiverPhone,
    required int amount,
    String? description,
  }) async {
    _error = null;

    try {
      final result = await _api.transfer(
        amount: amount,
        receiverPhone: receiverPhone,
        description: description,
      );

      if (result.isSuccess && result.data != null) {
        // Atualizar saldo local
        if (result.data!.newBalance != null) {
          updateUserBalance(result.data!.newBalance!);
        } else if (_user != null) {
          updateUserBalance(_user!.balance - amount);
        }

        // Adicionar transação local
        addTransaction(Transaction(
          id: result.data!.transactionId ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'payment',
          description: description ?? 'Transferência P2P',
          amount: -amount,
          date: DateTime.now().toString().split(' ')[0],
          time:
              '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        ));

        // Recarregar transações da API em background
        invalidate(AppDomain.transactions);

        return true;
      } else {
        _error = result.error ?? 'Erro ao realizar transferência';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao transferir: $e');
      _error = 'Erro ao realizar transferência';
      notifyListeners();
      return false;
    }
  }

  /// Fazer logout
  Future<void> logout() async {
    // Fazer logout na API
    await _api.logout();

    // Limpar estado local
    _user = null;
    _isAuthenticated = false;
    _virtualCards = [];
    _transactions = [];
    _trips = [];
    _cardsLastFetch = null;
    _transactionsLastFetch = null;
    _tripsLastFetch = null;

    // Limpar cache
    await _prefs?.remove('ts_user');
    await _prefs?.remove('ts_cards');
    await _prefs?.remove('ts_transactions');
    await _prefs?.remove('ts_trips');

    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    final result = await _api.deleteAccount();
    if (!result.isSuccess) return false;

    _user = null;
    _isAuthenticated = false;
    _virtualCards = [];
    _transactions = [];
    _trips = [];
    _cardsLastFetch = null;
    _transactionsLastFetch = null;
    _tripsLastFetch = null;

    await _prefs?.remove('ts_user');
    await _prefs?.remove('ts_cards');
    await _prefs?.remove('ts_transactions');
    await _prefs?.remove('ts_trips');

    notifyListeners();
    return true;
  }

  /// Atualizar saldo local (após pagamento/transferência)
  void updateUserBalance(int newBalance) {
    if (_user != null) {
      _user = _user!.copyWith(balance: newBalance);
      _prefs?.setString('ts_user', json.encode(_user!.toJson()));
      notifyListeners();
    }
  }

  /// Adicionar transação local (otimista)
  void addTransaction(Transaction transaction) {
    _transactions.insert(0, transaction);
    _prefs?.setString(
      'ts_transactions',
      json.encode(_transactions.map((t) => t.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Recarregar cartão virtual via API
  Future<String?> topupVirtualCard({
    required String cardId,
    required int amount,
  }) async {
    try {
      final result = await _api.topupVirtualCard(cardId: cardId, amount: amount);
      if (result.isSuccess && result.data != null) {
        final idx = _virtualCards.indexWhere((c) => c.id == cardId);
        if (idx != -1) {
          _virtualCards[idx] =
              _virtualCards[idx].copyWith(balance: result.data!.cardBalance);
          if (_user != null) {
            _user = _user!.copyWith(balance: result.data!.walletBalance);
            await _prefs?.setString('ts_user', json.encode(_user!.toJson()));
          }
          await _prefs?.setString(
            'ts_cards',
            json.encode(_virtualCards.map((c) => c.toJson()).toList()),
          );
          notifyListeners();
        }
        return null;
      }
      return result.error ?? 'Erro ao recarregar cartão';
    } catch (e) {
      return 'Erro ao recarregar cartão';
    }
  }

  /// Congelar ou ativar cartão virtual
  Future<String?> updateVirtualCardStatus({
    required String cardId,
    required String status,
  }) async {
    try {
      final result =
          await _api.updateCardStatus(cardId: cardId, status: status);
      if (result.isSuccess) {
        final idx = _virtualCards.indexWhere((c) => c.id == cardId);
        if (idx != -1) {
          final newStatus =
              status == 'frozen' ? CardStatus.frozen : CardStatus.active;
          _virtualCards[idx] = _virtualCards[idx].copyWith(status: newStatus);
          await _prefs?.setString(
            'ts_cards',
            json.encode(_virtualCards.map((c) => c.toJson()).toList()),
          );
          notifyListeners();
        }
        return null;
      }
      return result.error ?? 'Erro ao alterar status do cartão';
    } catch (e) {
      return 'Erro ao alterar status do cartão';
    }
  }

  /// Alterar limite diário do cartão virtual
  Future<String?> updateVirtualCardLimit({
    required String cardId,
    required int dailyLimit,
  }) async {
    try {
      final result =
          await _api.updateCardLimit(cardId: cardId, dailyLimit: dailyLimit);
      if (result.isSuccess) {
        final idx = _virtualCards.indexWhere((c) => c.id == cardId);
        if (idx != -1) {
          _virtualCards[idx] =
              _virtualCards[idx].copyWith(dailyLimit: dailyLimit);
          await _prefs?.setString(
            'ts_cards',
            json.encode(_virtualCards.map((c) => c.toJson()).toList()),
          );
          notifyListeners();
        }
        return null;
      }
      return result.error ?? 'Erro ao alterar limite';
    } catch (e) {
      return 'Erro ao alterar limite';
    }
  }

  /// Retirar saldo do cartão virtual para a carteira principal
  Future<bool> withdrawFromCard({
    required String cardId,
    required int amount,
    required String cardPin,
  }) async {
    try {
      final result = await _api.withdrawFromVirtualCard(
        cardId: cardId,
        amount: amount,
        pin: cardPin,
      );
      if (result.isSuccess) {
        if (result.data?.newBalance != null) {
          updateUserBalance(result.data!.newBalance!);
        }
        final idx = _virtualCards.indexWhere((c) => c.id == cardId);
        if (idx != -1) {
          _virtualCards[idx] =
              _virtualCards[idx].copyWith(balance: _virtualCards[idx].balance - amount);
          await _prefs?.setString(
            'ts_cards',
            json.encode(_virtualCards.map((c) => c.toJson()).toList()),
          );
          notifyListeners();
        }
        invalidate(AppDomain.user);
        invalidate(AppDomain.cards);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao levantar do cartão: $e');
      return false;
    }
  }

  /// Solicitar levantamento para IBAN
  Future<bool> requestWithdrawal({
    required int amount,
    required String iban,
  }) async {
    try {
      final result = await _api.requestWithdrawal(amount: amount, iban: iban);
      if (result.isSuccess) {
        invalidate(AppDomain.user);
        invalidate(AppDomain.transactions);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao solicitar levantamento: $e');
      return false;
    }
  }

  /// Acionar botão de pânico
  Future<bool> triggerPanic({
    required double latitude,
    required double longitude,
  }) async {
    _error = null;

    try {
      final result = await _api.triggerPanic(
        latitude: latitude,
        longitude: longitude,
      );

      if (result.isSuccess) {
        return true;
      } else {
        _error = result.error ?? 'Erro ao registrar alerta de pânico';
        return false;
      }
    } catch (e) {
      _error = 'Erro ao acionar pânico: $e';
      return false;
    }
  }
}
