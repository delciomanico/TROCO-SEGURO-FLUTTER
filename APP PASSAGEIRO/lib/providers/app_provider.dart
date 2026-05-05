import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/models/trip.dart';
import 'package:troco_seguro/services/api_service.dart';

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

  /// Transferir saldo entre cartões virtuais locais
  Future<String?> transferBetweenVirtualCards({
    required String fromCardId,
    required String toCardId,
    required int amount,
  }) async {
    _isLoadingCards = true;
    notifyListeners();

    try {
      if (fromCardId == toCardId) {
        return 'Selecione cartões diferentes.';
      }

      final fromIndex =
          _virtualCards.indexWhere((card) => card.id == fromCardId);
      final toIndex = _virtualCards.indexWhere((card) => card.id == toCardId);

      if (fromIndex == -1 || toIndex == -1) {
        return 'Cartão não encontrado.';
      }

      final sourceCard = _virtualCards[fromIndex];
      final destinationCard = _virtualCards[toIndex];

      if (sourceCard.isFrozen || sourceCard.isBlocked) {
        return 'Cartão de origem indisponível.';
      }

      if (destinationCard.isFrozen || destinationCard.isBlocked) {
        return 'Cartão de destino indisponível.';
      }

      if (amount <= 0) {
        return 'O montante deve ser maior que zero.';
      }

      if (sourceCard.balance < amount) {
        return 'Saldo insuficiente no cartão de origem.';
      }

      final timestamp = DateTime.now().toIso8601String();

      _virtualCards[fromIndex] = sourceCard.copyWith(
        balance: sourceCard.balance - amount,
        lastModified: timestamp,
      );

      _virtualCards[toIndex] = destinationCard.copyWith(
        balance: destinationCard.balance + amount,
        lastModified: timestamp,
      );

      await _prefs?.setString(
        'ts_cards',
        json.encode(_virtualCards.map((card) => card.toJson()).toList()),
      );

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Erro ao transferir entre cartões: $e');
      return 'Erro ao transferir entre cartões.';
    } finally {
      _isLoadingCards = false;
      notifyListeners();
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

    // Carregar todos os dados após login
    await _refreshAllDataInBackground();
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
        _fetchTransactionsFromApi(showLoading: false);

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

  /// Acionar botão de pânico
  Future<bool> triggerPanic({
    required double latitude,
    required double longitude,
  }) async {
    _error = null;

    try {
      debugPrint('🚨 Acionando pânico em: $latitude, $longitude');

      final result = await _api.triggerPanic(
        latitude: latitude,
        longitude: longitude,
      );

      if (result.isSuccess) {
        debugPrint('✅ Alerta de pânico registrado com sucesso!');
        return true;
      } else {
        _error = result.error ?? 'Erro ao registrar alerta de pânico';
        debugPrint('❌ Erro: ${result.error}');
        return false;
      }
    } catch (e) {
      _error = 'Erro ao acionar pânico: $e';
      debugPrint('❌ Exceção: $e');
      return false;
    }
  }
}
