import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/models/trip.dart';
import 'package:troco_seguro/models/faq_item.dart';
import 'dart:convert';

/// Serviço para comunicação com a API do Troco Seguro
class ApiService {
  static const String baseUrl = 'https://troco-seguro.onrender.com/api/v1';

  final Dio _dio;
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  String? _accessToken;
  String? _refreshToken;

  ApiService._internal()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
          debugPrint('🔑 Token anexado: ${_accessToken!.substring(0, 10)}...');
        } else {
          debugPrint('⚠️ Token ausente no request');
        }
        options.headers['user-agent'] = 'TrocoSeguroApp/1.0';
        debugPrint('🌐 ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('✅ ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        debugPrint(
            '❌ ${error.response?.statusCode} ${error.requestOptions.path}');

        // Tentar renovar token se expirado
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          try {
            final refreshed = await _refreshTokens();
            if (refreshed) {
              // Repetir requisição original
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_accessToken';
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            }
          } catch (e) {
            debugPrint('Erro ao renovar token: $e');
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// Carregar tokens salvos
  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _refreshToken = prefs.getString('refreshToken');
    debugPrint(
        '💾 Tokens carregados: Access=${_accessToken != null}, Refresh=${_refreshToken != null}');
  }

  /// Salvar tokens externamente e na memória
  Future<void> saveTokens(String accessToken, String? refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    if (refreshToken != null) {
      await prefs.setString('refreshToken', refreshToken);
    }
  }

  /// Definir tokens manualmente (ex: vindos de outra fonte)
  void setTokens(String accessToken, String? refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Limpar tokens
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  /// Verificar se está autenticado
  bool get isAuthenticated => _accessToken != null;

  // ============ AUTENTICAÇÃO ============

  /// Registar novo utilizador
  Future<ApiResponse<AuthResult>> register({
    required String fullName,
    required String phoneNumber,
    required String password,
    String role = 'PASSENGER',
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'password': password,
        'role': role,
      });

      return ApiResponse.success(AuthResult(
        message:
            response.data['message'] ?? 'Registo realizado. Verifique o SMS.',
        requiresOtp: true,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Verificar código OTP
  Future<ApiResponse<AuthResult>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      final response = await _dio.post('/auth/verify-otp', data: {
        'phoneNumber': phoneNumber,
        'otpCode': otpCode,
      });

      final data = response.data;
      if (data['accessToken'] != null) {
        await saveTokens(data['accessToken'], data['refreshToken']);
      }

      return ApiResponse.success(AuthResult(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        user: data['user'] != null ? User.fromJson(data['user']) : null,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Reenviar código OTP
  Future<ApiResponse<void>> resendOtp(String phoneNumber) async {
    try {
      await _dio.post('/auth/resend-otp', data: {
        'phoneNumber': phoneNumber,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Login
  Future<ApiResponse<AuthResult>> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'phoneNumber': phoneNumber,
        'password': password,
      });

      final data = response.data;
      await saveTokens(data['accessToken'], data['refreshToken']);

      return ApiResponse.success(AuthResult(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        user: data['user'] != null ? User.fromJson(data['user']) : null,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Logout
  Future<ApiResponse<void>> logout() async {
    try {
      await _dio.post('/auth/logout');
      await clearTokens();
      return ApiResponse.success(null);
    } on DioException catch (e) {
      await clearTokens();
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Alterar senha/PIN
  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.put('/users/me/pin', data: {
        'currentPin': currentPassword,
        'newPin': newPassword,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Renovar tokens
  Future<bool> _refreshTokens() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _dio.post('/auth/refresh', data: {
        'refreshToken': _refreshToken,
      });

      final data = response.data;
      await saveTokens(data['accessToken'], data['refreshToken']);
      return true;
    } catch (e) {
      await clearTokens();
      return false;
    }
  }

  /// Verificar PIN
  Future<ApiResponse<bool>> verifyPin(String pin) async {
    try {
      final response = await _dio.post('/auth/verify-pin', data: {
        'pin': pin,
      });
      return ApiResponse.success(response.data['valid'] ?? true);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ UTILIZADOR ============

  /// Obter perfil do utilizador logado
  Future<ApiResponse<User>> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      return ApiResponse.success(User.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Atualizar perfil
  Future<ApiResponse<User>> updateProfile({
    String? fullName,
    String? email,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName;
      if (email != null) data['email'] = email;

      final response = await _dio.put('/users/me', data: data);
      return ApiResponse.success(User.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Alterar PIN
  Future<ApiResponse<void>> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      await _dio.put('/users/me/pin', data: {
        'currentPin': currentPin,
        'newPin': newPin,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ TRANSAÇÕES ============

  /// Depositar (carregar carteira)
  Future<ApiResponse<TransactionResult>> deposit({
    required int amount,
    String? reference,
  }) async {
    try {
      final data = <String, dynamic>{'amount': amount};
      if (reference != null) data['reference'] = reference;

      final response = await _dio.post('/transactions/deposit', data: data);
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Transferir para outro utilizador
  Future<ApiResponse<TransactionResult>> transfer({
    required int amount,
    required String receiverPhone,
    String? description,
  }) async {
    try {
      final data = <String, dynamic>{
        'amount': amount,
        'receiverPhone': receiverPhone,
      };
      if (description != null) data['description'] = description;

      final response = await _dio.post('/transactions/transfer', data: data);
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Histórico de transações
  Future<ApiResponse<List<Transaction>>> getTransactionHistory() async {
    try {
      final response = await _dio.get('/transactions/history');
      // API pode retornar array direto ou objeto com chave 'transactions'
      final List<dynamic> data = response.data is List
          ? response.data
          : (response.data['transactions'] ?? []);
      return ApiResponse.success(
        data.map((e) => Transaction.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ CARTEIRA ============

  /// Verificar destinatário por telefone antes de transferir
  Future<ApiResponse<RecipientInfo>> verifyTransferRecipient(
      String phone) async {
    try {
      final response =
          await _dio.get('/wallet/transfer/verify/${Uri.encodeComponent(phone)}');
      return ApiResponse.success(RecipientInfo.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Transferir entre cartões virtuais próprios
  Future<ApiResponse<TransactionResult>> transferBetweenCards({
    required String fromCardId,
    required String toCardId,
    required int amount,
    required String pin,
  }) async {
    try {
      final response = await _dio.post('/wallet/transfer', data: {
        'fromCardId': fromCardId,
        'toCardId': toCardId,
        'amount': amount,
        'pin': pin,
      });
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Transferir para cartão de terceiros por número
  Future<ApiResponse<TransactionResult>> transferToExternalCard({
    required String cardNumber,
    required int amount,
    required String pin,
  }) async {
    try {
      final response = await _dio.post('/wallet/transfer-to-card', data: {
        'cardNumber': cardNumber,
        'amount': amount,
        'pin': pin,
      });
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Depositar da carteira principal para cartão virtual próprio
  Future<ApiResponse<TransactionResult>> depositToVirtualCard({
    required String cardId,
    required int amount,
  }) async {
    try {
      final response = await _dio.post('/wallet/card/deposit', data: {
        'cardId': cardId,
        'amount': amount,
      });
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ QR CODE ============

  /// Obter QR Code de identidade
  Future<ApiResponse<String>> getMyQrCode() async {
    try {
      final response = await _dio.get('/qr-code/my-code');
      return ApiResponse.success(
          response.data['qrCode'] ?? response.data['image']);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Gerar QR Code de cobrança (para taxistas)
  Future<ApiResponse<String>> generatePaymentQr(int amount) async {
    try {
      final response = await _dio.post('/qr-code/payment-request', data: {
        'amount': amount,
      });
      return ApiResponse.success(
          response.data['qrCode'] ?? response.data['image']);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Validar QR Code escaneado
  /// NOTE: The legacy `/payments/validate-qr` endpoint was removed from usage.
  /// Use [resolveQrToken] which calls `GET /qrcodes/resolve?token=` instead.

  /// Resolver QR por token (GET /qrcodes/resolve?token=)
  Future<ApiResponse<QrValidationResult>> resolveQrToken(String token) async {
    try {
      final response = await _dio.get('/qrcodes/resolve', queryParameters: {
        'token': token,
      });
      return ApiResponse.success(QrValidationResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ PAGAMENTOS ============

  /// Processar pagamento (executar transação)
  Future<ApiResponse<PaymentResult>> processPayment({
    required String driverId,
    required int amount,
    required String pin,
    required String origin,
    required String destination,
    required String paymentToken,
    double distanceKm = 0.0,
    int durationMinutes = 0,
  }) async {
    try {
      final response = await _dio.post('/payments/process', data: {
        'driverId': driverId,
        'amount': amount,
        'pin': pin,
        'origin': origin,
        'destination': destination,
        'paymentToken': paymentToken,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
      });
      return ApiResponse.success(PaymentResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ CARTÕES VIRTUAIS ============

  /// Listar cartões virtuais
  Future<ApiResponse<List<VirtualCard>>> getVirtualCards() async {
    try {
      final response = await _dio.get('/virtual-cards');
      debugPrint('💳 Response /virtual-cards (raw): ${response.data}');

      final dynamic data = response.data;
      List<dynamic> list;

      if (data is Map && data.containsKey('cards')) {
        list = data['cards'];
        debugPrint('💳 Formato com "cards": ${list.length} itens');
      } else if (data is List) {
        list = data;
        debugPrint('💳 Formato direto List: ${list.length} itens');
      } else {
        debugPrint(
            '⚠️ Formato de resposta inesperado para cartões: ${data.runtimeType}');
        list = [];
      }

      final cards = list.map((e) {
        debugPrint('💳 Parseando cartão: $e');
        return VirtualCard.fromJson(e);
      }).toList();

      debugPrint('💳 Total de cartões parseados: ${cards.length}');
      return ApiResponse.success(cards);
    } on DioException catch (e) {
      debugPrint('❌ Erro ao listar cartões: ${e.message}');
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Criar cartão virtual — retorna VirtualCardResponse com PAN/CVV/expiry
  /// que a UI deve exibir APENAS na criação. O pinHash NUNCA é retornado.
  Future<ApiResponse<VirtualCardResponse>> createVirtualCard(
    CreateCardPayload payload,
  ) async {
    try {
      debugPrint('💳 POST /virtual-cards payload: ${payload.toJson()}');
      final response =
          await _dio.post('/virtual-cards', data: payload.toJson());
      debugPrint('💳 Response createVirtualCard: ${response.data}');
      return ApiResponse.success(VirtualCardResponse.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Detalhes do cartão
  Future<ApiResponse<VirtualCard>> getVirtualCard(String cardId) async {
    try {
      final response = await _dio.get('/virtual-cards/$cardId');
      return ApiResponse.success(VirtualCard.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Excluir cartão
  Future<ApiResponse<DeleteCardResult>> deleteVirtualCard(String cardId) async {
    try {
      final response = await _dio.delete('/virtual-cards/$cardId');
      return ApiResponse.success(DeleteCardResult(
        refundedAmount: response.data['refundedAmount'] ?? 0,
        walletBalance: response.data['walletBalance'] ?? 0,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Recarregar cartão
  Future<ApiResponse<TopupCardResult>> topupVirtualCard({
    required String cardId,
    required int amount,
  }) async {
    try {
      final response = await _dio.post('/virtual-cards/$cardId/topup', data: {
        'amount': amount,
      });
      return ApiResponse.success(TopupCardResult(
        cardBalance: response.data['cardBalance'] ?? 0,
        walletBalance: response.data['walletBalance'] ?? 0,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Alterar status do cartão (congelar/ativar)
  Future<ApiResponse<String>> updateCardStatus({
    required String cardId,
    required String status, // 'active' ou 'frozen'
  }) async {
    try {
      final response = await _dio.put('/virtual-cards/$cardId/status', data: {
        'status': status,
      });
      return ApiResponse.success(response.data['status'] ?? status);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Alterar limite diário
  Future<ApiResponse<int>> updateCardLimit({
    required String cardId,
    required int dailyLimit,
  }) async {
    try {
      final response = await _dio.put('/virtual-cards/$cardId/limit', data: {
        'dailyLimit': dailyLimit,
      });
      return ApiResponse.success(response.data['dailyLimit'] ?? dailyLimit);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ VIAGENS ============

  /// Listar viagens
  Future<ApiResponse<List<Trip>>> getTrips() async {
    try {
      final response = await _dio.get('/trips');
      dynamic raw = response.data;
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {
          raw = null;
        }
      }

      List<dynamic> data = [];
      if (raw == null) {
        data = [];
      } else if (raw is Map && raw['trips'] != null) {
        final t = raw['trips'];
        if (t is List) {
          data = t;
        } else {
          data = [t];
        }
      } else if (raw is List) {
        data = raw;
      } else if (raw is Map) {
        data = [raw];
      }

      final parsed = data.map((e) {
        if (e is String) {
          try {
            return Trip.fromJson(jsonDecode(e) as Map<String, dynamic>);
          } catch (_) {
            return Trip.fromJson({
              'id': '',
              'origin': '',
              'destination': '',
              'amount': 0,
              'date': '',
              'time': '',
              'driverName': '',
              'licensePlate': '',
              'status': 'pending'
            });
          }
        }
        return Trip.fromJson(e as Map<String, dynamic>);
      }).toList();

      return ApiResponse.success(parsed);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Detalhes da viagem
  Future<ApiResponse<Trip>> getTrip(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId');
      return ApiResponse.success(Trip.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ AVALIAÇÕES ============

  /// Criar avaliação
  Future<ApiResponse<void>> createRating({
    required String targetUserId,
    required int stars,
    String? comment,
  }) async {
    try {
      final data = <String, dynamic>{
        'targetUserId': targetUserId,
        'stars': stars,
      };
      if (comment != null) data['comment'] = comment;

      await _dio.post('/ratings', data: data);
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ NOTIFICAÇÕES ============

  /// Listar notificações
  Future<ApiResponse<NotificationsResult>> getNotifications() async {
    try {
      final response = await _dio.get('/notifications');
      return ApiResponse.success(NotificationsResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Marcar notificação como lida
  Future<ApiResponse<void>> markNotificationRead(String notificationId) async {
    try {
      await _dio.put('/notifications/$notificationId/read');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Marcar todas como lidas
  Future<ApiResponse<void>> markAllNotificationsRead() async {
    try {
      await _dio.put('/notifications/read-all');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ SEGURANÇA ============

  /// Acionar botão de pânico
  Future<ApiResponse<void>> triggerPanic({
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _dio.post('/safety/panic', data: {
        'latitude': latitude,
        'longitude': longitude,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ CONTACTOS DE EMERGÊNCIA ============

  Future<ApiResponse<List<EmergencyContact>>> getEmergencyContacts() async {
    try {
      final response = await _dio.get('/safety/emergency-contacts');
      final list = ((response.data['contacts'] ?? response.data) as List)
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(list);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<EmergencyContact>> addEmergencyContact({
    required String name,
    required String phoneNumber,
  }) async {
    try {
      final response = await _dio.post('/safety/emergency-contacts',
          data: {'name': name, 'phoneNumber': phoneNumber});
      return ApiResponse.success(
          EmergencyContact.fromJson(response.data['contact'] ?? response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<void>> deleteEmergencyContact(String id) async {
    try {
      await _dio.delete('/safety/emergency-contacts/$id');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ FAQ ============

  /// Listar perguntas frequentes
  Future<ApiResponse<List<FAQItem>>> getFaq() async {
    try {
      final response = await _dio.get('/faq');
      final List<dynamic> data = response.data['items'] ?? response.data;
      return ApiResponse.success(
        data.map((e) => FAQItem.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ HELPERS ============

  String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        if (data['message'] is List) {
          return (data['message'] as List).join('. ');
        }
        return data['message'] ?? data['error'] ?? 'Erro desconhecido';
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tempo de conexão esgotado. Verifique sua internet.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com a internet.';
      case DioExceptionType.badResponse:
        return 'Erro no servidor (${e.response?.statusCode})';
      default:
        return 'Erro de comunicação com o servidor.';
    }
  }
}

// ============ MODELOS DE RESPOSTA ============

class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResponse.success(this.data)
      : error = null,
        isSuccess = true;

  ApiResponse.error(this.error)
      : data = null,
        isSuccess = false;
}

class AuthResult {
  final String? accessToken;
  final String? refreshToken;
  final User? user;
  final String? message;
  final bool requiresOtp;

  AuthResult({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.message,
    this.requiresOtp = false,
  });
}

class TransactionResult {
  final String? transactionId;
  final int? amount;
  final int? newBalance;
  final String? message;

  TransactionResult({
    this.transactionId,
    this.amount,
    this.newBalance,
    this.message,
  });

  factory TransactionResult.fromJson(Map<String, dynamic> json) {
    return TransactionResult(
      transactionId: json['transactionId'] ?? json['id'],
      amount: json['amount'],
      newBalance: json['newBalance'] ?? json['balance'],
      message: json['message'],
    );
  }
}

class QrValidationResult {
  final bool valid;
  final String? driverId;
  final String? driverName;
  final String? licensePlate;
  final double? rating;
  final int? amount;
  final String? sessionToken;
  final String? paymentToken;

  QrValidationResult({
    required this.valid,
    this.driverId,
    this.driverName,
    this.licensePlate,
    this.rating,
    this.amount,
    this.sessionToken,
    this.paymentToken,
  });

  factory QrValidationResult.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    return QrValidationResult(
      valid: json['valid'] ?? false,
      driverId: driver?['id'] ?? json['driverId'],
      driverName: driver?['name'] ?? json['driverName'],
      licensePlate: driver?['licensePlate'] ?? json['licensePlate'],
      rating: (driver?['rating'] ?? json['rating'])?.toDouble(),
      amount: json['amount'],
      // Some backends return the session/payment token under different keys
      sessionToken: json['sessionToken'] ?? json['paymentToken'],
      paymentToken: json['paymentToken'] ?? json['sessionToken'],
    );
  }
}

class PaymentResult {
  final String transactionId;
  final int amount;
  final int newBalance;
  final String status;
  final String message;
  final String? tripId;

  PaymentResult({
    required this.transactionId,
    required this.amount,
    required this.newBalance,
    required this.status,
    required this.message,
    this.tripId,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      transactionId: json['transactionId'] ?? json['id'] ?? '',
      amount: json['amount'] ?? 0,
      newBalance: json['newBalance'] ?? json['balance'] ?? 0,
      status: json['status'] ?? 'completed',
      message: json['message'] ?? 'Pagamento realizado com sucesso',
      tripId: json['tripId'],
    );
  }
}

class DeleteCardResult {
  final int refundedAmount;
  final int walletBalance;

  DeleteCardResult({
    required this.refundedAmount,
    required this.walletBalance,
  });
}

class TopupCardResult {
  final int cardBalance;
  final int walletBalance;

  TopupCardResult({
    required this.cardBalance,
    required this.walletBalance,
  });
}

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'info',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      read: json['read'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class NotificationsResult {
  final List<AppNotification> notifications;
  final int unreadCount;

  NotificationsResult({
    required this.notifications,
    required this.unreadCount,
  });

  factory NotificationsResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> notifs = json['notifications'] ?? [];
    return NotificationsResult(
      notifications: notifs.map((e) => AppNotification.fromJson(e)).toList(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class RecipientInfo {
  final String id;
  final String name;
  final String phone;

  RecipientInfo({required this.id, required this.name, required this.phone});

  factory RecipientInfo.fromJson(Map<String, dynamic> json) {
    return RecipientInfo(
      id: json['id'] ?? json['userId'] ?? '',
      name: json['fullName'] ?? json['name'] ?? '',
      phone: json['phoneNumber'] ?? json['phone'] ?? '',
    );
  }
}

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phoneNumber: json['phoneNumber'] as String,
      );
}
