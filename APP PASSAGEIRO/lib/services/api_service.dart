import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/models/trip.dart';
import 'package:troco_seguro/models/faq_item.dart';
import 'package:troco_seguro/models/complaint.dart';
import 'package:troco_seguro/models/rating.dart';
import 'dart:convert';

/// Serviço para comunicação com a API do Troco Seguro
class ApiService {
  static final String baseUrl = dotenv.get('BASE_URL', fallback: 'https://trocoseguro.wemof.tech/api/v1/');

  final Dio _dio;
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  /// Construtor só para testes — injecta um [Dio] falso (ex.: mocktail)
  /// para verificar pedidos sem rede real. Não é singleton (cada chamada
  /// cria uma instância nova) e não altera o construtor por omissão usado
  /// em produção.
  @visibleForTesting
  ApiService.test(Dio dio) : _dio = dio;

  String? _accessToken;
  String? _refreshToken;

  static final ValueNotifier<int> _sessionExpired = ValueNotifier<int>(0);

  /// Notificado sempre que o token expira e a renovação falha — a UI deve
  /// terminar a sessão e voltar ao ecrã de login.
  ValueListenable<int> get sessionExpiredListenable => _sessionExpired;

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
        }
        options.headers['user-agent'] = 'TrocoSeguroApp/1.0';
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) async {
        debugPrint('API error: ${error.response?.statusCode} ${error.requestOptions.path}');

        // Se o próprio pedido de refresh falhou com 401, não tentar renová-lo
        // outra vez — isso causaria recursão infinita (o refresh passa pelo
        // mesmo interceptor). Deixa o erro propagar para _refreshTokens(),
        // cujo catch já devolve false ao chamador.
        final isRefreshRequest = error.requestOptions.path.contains('auth/refresh');

        // Tentar renovar token se expirado
        if (error.response?.statusCode == 401 && !isRefreshRequest) {
          final hadSession = isAuthenticated;
          if (_refreshToken != null) {
            bool refreshed = false;
            try {
              refreshed = await _refreshTokens();
            } catch (e) {
              debugPrint('Erro ao renovar token: $e');
            }
            if (refreshed) {
              try {
                // Repetir requisição original
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $_accessToken';
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                debugPrint('Erro ao repetir requisição: $e');
                return handler.next(error);
              }
            } else if (hadSession) {
              // Refresh token também expirou/inválido: sessão terminou de vez
              await clearTokens();
              _sessionExpired.value++;
            }
          } else if (hadSession) {
            await clearTokens();
            _sessionExpired.value++;
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// Carregar tokens salvos
  Future<void> loadTokens() async {
    final secure = SecureStorageService();
    _accessToken = await secure.readAccessToken();
    _refreshToken = await secure.readRefreshToken();

    // Migrar tokens legados do SharedPreferences se existirem
    if (_accessToken == null) {
      final prefs = await SharedPreferences.getInstance();
      final legacyAccess = prefs.getString('accessToken');
      final legacyRefresh = prefs.getString('refreshToken');
      if (legacyAccess != null) {
        await secure.saveAuthTokens(legacyAccess, legacyRefresh);
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        _accessToken = legacyAccess;
        _refreshToken = legacyRefresh;
      }
    }
  }

  /// Salvar tokens externamente e na memória
  Future<void> saveTokens(String accessToken, String? refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await SecureStorageService().saveAuthTokens(accessToken, refreshToken);
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
    await SecureStorageService().deleteAuthTokens();
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
      final response = await _dio.post('auth/register', data: {
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
      final response = await _dio.post('auth/verify-otp', data: {
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
      await _dio.post('auth/resend-otp', data: {
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
      final response = await _dio.post('auth/login', data: {
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
      await _dio.post('auth/logout');
      await clearTokens();
      return ApiResponse.success(null);
    } on DioException catch (e) {
      await clearTokens();
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<void>> deleteAccount({String? iban}) async {
    try {
      await _dio.delete('users/me',
          data: iban != null && iban.isNotEmpty ? {'iban': iban} : null);
      await clearTokens();
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Alterar senha/PIN
  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.put('users/me/pin', data: {
        'currentPin': currentPassword,
        'newPin': newPassword,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Solicitar código OTP para recuperação de senha
  Future<ApiResponse<void>> forgotPassword(String phoneNumber) async {
    try {
      await _dio.post('auth/forgot-password', data: {'phoneNumber': phoneNumber});
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Validar OTP e obter resetToken
  Future<ApiResponse<String>> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await _dio.post('auth/forgot-password/verify-otp',
          data: {'phoneNumber': phoneNumber, 'otp': otp});
      final token = response.data['resetToken'] as String;
      return ApiResponse.success(token);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Definir nova senha com resetToken
  Future<ApiResponse<void>> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _dio.post('auth/reset-password', data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
        'confirmPassword': newPassword,
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
      final response = await _dio.post('auth/refresh', data: {
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
      final response = await _dio.post('auth/verify-pin', data: {
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
      final response = await _dio.get('users/me');
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

      final response = await _dio.put('users/me', data: data);
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
      await _dio.put('users/me/pin', data: {
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

      final response = await _dio.post('transactions/deposit', data: data);
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Iniciar um carregamento de saldo via Multicaixa Express.
  ///
  /// Substitui o antigo `deposit()`/`transactions/deposit` (endpoint morto
  /// no ambiente actual — ver BACKEND_PENDING_CHANGES.md, item 10). Devolve
  /// uma referência de pagamento; o saldo só é creditado depois de o
  /// pagamento ser confirmado do lado do backend (o endpoint que confirma,
  /// `payments/webhook/simulate`, é restrito a administradores).
  Future<ApiResponse<DepositInitiateResult>> initiateDeposit({
    required int amount,
  }) async {
    try {
      final response = await _dio.post('payments/deposit/initiate', data: {
        'amount': amount,
      });
      return ApiResponse.success(DepositInitiateResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Transferir para outro utilizador (por telefone) ou directamente para um
  /// motorista já identificado por QR (por receiverId).
  Future<ApiResponse<TransactionResult>> transfer({
    required int amount,
    String? receiverPhone,
    String? receiverId,
    String? description,
  }) async {
    assert(receiverPhone != null || receiverId != null,
        'Informe receiverPhone ou receiverId');
    try {
      final data = <String, dynamic>{
        'amount': amount,
        if (receiverPhone != null) 'receiverPhone': receiverPhone,
        if (receiverId != null) 'receiverId': receiverId,
      };
      if (description != null) data['description'] = description;

      final response = await _dio.post('transactions/transfer', data: data);
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Histórico de transações
  Future<ApiResponse<List<Transaction>>> getTransactionHistory() async {
    try {
      final response = await _dio.get('transactions/history');
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
          await _dio.get('wallet/transfer/verify/${Uri.encodeComponent(phone)}');
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
      final response = await _dio.post('wallet/transfer', data: {
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
      final response = await _dio.post('wallet/transfer-to-card', data: {
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
      final response = await _dio.post('wallet/card/deposit', data: {
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
      final response = await _dio.get('qr-code/my-code');
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
      final response = await _dio.get('qrcodes/resolve', queryParameters: {
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
    String? cardId,
    double distanceKm = 0.0,
    int durationMinutes = 0,
    int seatsCount = 1,
  }) async {
    try {
      // API extrai amount do paymentToken JWT — não enviar amount no body
      final payload = <String, dynamic>{
        'driverId': driverId,
        'pin': pin,
        'origin': origin,
        'destination': destination,
        'paymentToken': paymentToken,
        'seatsCount': seatsCount,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
      };
      if (cardId != null && cardId.isNotEmpty) payload['cardId'] = cardId;
      final response = await _dio.post('payments/process', data: payload);
      return ApiResponse.success(PaymentResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ CARTÕES VIRTUAIS ============

  /// Listar cartões virtuais
  Future<ApiResponse<List<VirtualCard>>> getVirtualCards() async {
    try {
      final response = await _dio.get('virtual-cards');
      final dynamic data = response.data;
      List<dynamic> list;

      if (data is Map && data.containsKey('cards')) {
        list = data['cards'];
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }

      final cards = list.map((e) => VirtualCard.fromJson(e)).toList();
      return ApiResponse.success(cards);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Criar cartão virtual — retorna VirtualCardResponse com PAN/CVV/expiry
  /// que a UI deve exibir APENAS na criação. O pinHash NUNCA é retornado.
  Future<ApiResponse<VirtualCardResponse>> createVirtualCard(
    CreateCardPayload payload,
  ) async {
    try {
      final response =
          await _dio.post('virtual-cards', data: payload.toJson());
      return ApiResponse.success(VirtualCardResponse.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Detalhes do cartão
  Future<ApiResponse<VirtualCardQrResult>> resolveVirtualCardQr(String qrData) async {
    try {
      final response = await _dio.post('virtual-cards/resolve-qr', data: {'qrData': qrData});
      return ApiResponse.success(VirtualCardQrResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<CardBalanceResult>> getWalletBalanceByQr(String qrId) async {
    try {
      final response = await _dio.get('wallet/balance-by-qr/${Uri.encodeComponent(qrId)}');
      return ApiResponse.success(CardBalanceResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<VirtualCard>> getVirtualCard(String cardId) async {
    try {
      final response = await _dio.get('virtual-cards/$cardId');
      return ApiResponse.success(VirtualCard.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Retorna o QR payload oficial do servidor para um cartão virtual.
  /// O valor retornado é o JSON string que deve ser codificado no QR code.
  Future<ApiResponse<String>> getVirtualCardQr(String cardId) async {
    try {
      final response = await _dio.get('virtual-cards/$cardId/qr');
      // O servidor pode retornar { qrData: "..." } ou a string directamente
      final data = response.data;
      final qrString = data is String
          ? data
          : (data['qrCodeImage'] ?? data['qrData'] ?? data['qr'] ?? data['token'] ?? data.toString());
      return ApiResponse.success(qrString as String);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Excluir cartão
  Future<ApiResponse<DeleteCardResult>> deleteVirtualCard(String cardId) async {
    try {
      final response = await _dio.delete('virtual-cards/$cardId');
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
      final response = await _dio.post('virtual-cards/$cardId/topup', data: {
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
      final response = await _dio.put('virtual-cards/$cardId/status', data: {
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
      final response = await _dio.put('virtual-cards/$cardId/limit', data: {
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
      final response = await _dio.get('trips');
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
      final response = await _dio.get('trips/$tripId');
      return ApiResponse.success(Trip.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ AVALIAÇÕES ============

  /// Obter histórico de avaliações feitas por um utilizador
  Future<ApiResponse<List<Rating>>> getRatings(String userId) async {
    try {
      final response = await _dio.get('ratings/$userId');
      final raw = response.data;
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        final v = raw['ratings'] ?? raw['data'] ?? raw['items'] ?? [];
        list = v is List ? v : [];
      } else {
        list = [];
      }
      final ratings = list
          .whereType<Map<String, dynamic>>()
          .map((e) => Rating.fromJson(e))
          .toList();
      return ApiResponse.success(ratings);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

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

      await _dio.post('ratings', data: data);
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ NOTIFICAÇÕES ============

  /// Listar notificações
  Future<ApiResponse<NotificationsResult>> getNotifications() async {
    try {
      final response = await _dio.get('notifications');
      return ApiResponse.success(NotificationsResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Marcar notificação como lida
  Future<ApiResponse<void>> markNotificationRead(String notificationId) async {
    try {
      await _dio.put('notifications/$notificationId/read');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Marcar todas como lidas
  Future<ApiResponse<void>> markAllNotificationsRead() async {
    try {
      await _dio.put('notifications/read-all');
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
      await _dio.post('safety/panic', data: {
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
      final response = await _dio.get('safety/emergency-contacts');
      final raw = response.data;
      List<dynamic> items;
      if (raw is List) {
        items = raw;
      } else if (raw is Map) {
        final v = raw['contacts'] ?? raw['data'] ?? raw['emergencyContacts'] ?? [];
        items = v is List ? v : [];
      } else {
        items = [];
      }
      final list = items
          .whereType<Map<String, dynamic>>()
          .map((e) => EmergencyContact.fromJson(e))
          .toList();
      return ApiResponse.success(list);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    } catch (e) {
      return ApiResponse.error('Erro ao processar contactos: $e');
    }
  }

  Future<ApiResponse<EmergencyContact>> addEmergencyContact({
    required String name,
    required String phoneNumber,
  }) async {
    try {
      final response = await _dio.post('safety/emergency-contacts',
          data: {'name': name, 'phoneNumber': phoneNumber});
      final raw = response.data;
      final Map<String, dynamic> json = raw is Map<String, dynamic>
          ? (raw['contact'] ?? raw['emergencyContact'] ?? raw) as Map<String, dynamic>
          : <String, dynamic>{};
      return ApiResponse.success(EmergencyContact.fromJson(json));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    } catch (e) {
      return ApiResponse.error('Erro ao adicionar contacto: $e');
    }
  }

  Future<ApiResponse<void>> deleteEmergencyContact(String id) async {
    try {
      await _dio.delete('safety/emergency-contacts/$id');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ FAQ ============

  /// Listar perguntas frequentes
  Future<ApiResponse<List<FAQItem>>> getFaq() async {
    try {
      final response = await _dio.get('faq');
      final List<dynamic> data = response.data['items'] ?? response.data;
      return ApiResponse.success(
        data.map((e) => FAQItem.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ FCM ============

  Future<ApiResponse<void>> updateFcmToken(String token) async {
    try {
      await _dio.put('users/me/fcm-token', data: {'token': token});
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ AVALIAÇÃO DE VIAGEM ============

  Future<ApiResponse<void>> rateTrip({
    required String tripId,
    required int stars,
    String? comment,
  }) async {
    try {
      final data = <String, dynamic>{'stars': stars};
      if (comment != null) data['comment'] = comment;
      await _dio.post('trips/$tripId/rate', data: data);
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ LEVANTAMENTO CARTÃO ============

  Future<ApiResponse<TransactionResult>> withdrawFromVirtualCard({
    required String cardId,
    required int amount,
    required String pin,
  }) async {
    try {
      final response = await _dio.post('wallet/card/withdraw', data: {
        'cardId': cardId,
        'amount': amount,
        'pin': pin,
      });
      return ApiResponse.success(TransactionResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ ESTATÍSTICAS DE VIAGENS ============

  Future<ApiResponse<TripStats>> getTripStats() async {
    try {
      final response = await _dio.get('trips/stats');
      return ApiResponse.success(TripStats.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ RECLAMAÇÕES ============

  Future<ApiResponse<void>> createComplaint({
    required String category,
    required String reasonCode,
    required String description,
    String? transactionId,
    String? tripId,
  }) async {
    try {
      final data = <String, dynamic>{
        'category': category,
        'reasonCode': reasonCode,
        'description': description,
      };
      if (transactionId != null) data['transactionId'] = transactionId;
      if (tripId != null) data['tripId'] = tripId;
      await _dio.post('complaints', data: data);
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<List<Complaint>>> getComplaints() async {
    try {
      final response = await _dio.get('complaints');
      final list = (response.data as List)
          .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse.success(list);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<Complaint>> getComplaint(String id) async {
    try {
      final response = await _dio.get('complaints/$id');
      return ApiResponse.success(
          Complaint.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response?.statusCode == 500) {
        return ApiResponse.error('Detalhe da reclamação temporariamente indisponível.');
      }
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ LEVANTAMENTO IBAN ============

  Future<ApiResponse<void>> requestWithdrawal({
    required int amount,
    required String iban,
  }) async {
    try {
      await _dio.post('transactions/withdraw', data: {
        'amount': amount,
        'iban': iban,
      });
      return ApiResponse.success(null);
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
  // Ainda não devolvido pelo backend para transferências/pagamentos do
  // passageiro (ver BACKEND_PENDING_CHANGES.md, item 3) — fica nulo até lá,
  // sem alterar o comportamento actual.
  final int? feeAmount;

  TransactionResult({
    this.transactionId,
    this.amount,
    this.newBalance,
    this.message,
    this.feeAmount,
  });

  factory TransactionResult.fromJson(Map<String, dynamic> json) {
    return TransactionResult(
      transactionId: json['transactionId'] ?? json['id'],
      amount: json['amount'],
      newBalance: json['newBalance'] ?? json['balance'],
      message: json['message'],
      feeAmount: json['feeAmount'] ?? json['fee'] ?? json['tax'] ?? json['platformFeeApplied'],
    );
  }
}

/// Resultado de `POST payments/deposit/initiate` — carregamento de saldo
/// pendente de confirmação (ver `ApiService.initiateDeposit`).
class DepositInitiateResult {
  final String? transactionId;
  final String? reference;
  final String? status;
  final String? message;

  DepositInitiateResult({
    this.transactionId,
    this.reference,
    this.status,
    this.message,
  });

  factory DepositInitiateResult.fromJson(Map<String, dynamic> json) {
    return DepositInitiateResult(
      transactionId: json['transactionId'],
      reference: json['reference'],
      status: json['status'],
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
  final String? seatLabel;
  final String? sessionToken;
  final String? paymentToken;

  QrValidationResult({
    required this.valid,
    this.driverId,
    this.driverName,
    this.licensePlate,
    this.rating,
    this.amount,
    this.seatLabel,
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
      seatLabel: json['seatLabel'],
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
  // Ainda não devolvido pelo backend (ver BACKEND_PENDING_CHANGES.md, item
  // 3) — fica nulo até lá, sem alterar o comportamento actual.
  final int? feeAmount;

  PaymentResult({
    required this.transactionId,
    required this.amount,
    required this.newBalance,
    required this.status,
    required this.message,
    this.tripId,
    this.feeAmount,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      transactionId: json['transactionId'] ?? json['id'] ?? '',
      amount: json['amount'] ?? 0,
      newBalance: json['newBalance'] ?? json['balance'] ?? 0,
      status: json['status'] ?? 'completed',
      message: json['message'] ?? 'Pagamento realizado com sucesso',
      tripId: json['tripId'],
      feeAmount: json['feeAmount'] ?? json['fee'] ?? json['tax'] ?? json['platformFeeApplied'],
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
    // O backend não documenta o nome exacto do campo de estado lido — aceita
    // as variantes mais comuns em vez de assumir sempre 'read' (se a chave
    // real for outra, o valor por defeito 'false' fazia tudo parecer sempre
    // não lido).
    final rawRead =
        json['read'] ?? json['isRead'] ?? json['is_read'] ?? json['seen'];
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? 'info',
      title: json['title'] ?? '',
      message: json['message'] ?? json['body'] ?? '',
      read: rawRead == true || rawRead == 'true' || rawRead == 1,
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

class TripStats {
  final int totalTrips;
  final int totalSpentMonth;

  TripStats({required this.totalTrips, required this.totalSpentMonth});

  factory TripStats.fromJson(Map<String, dynamic> json) => TripStats(
        totalTrips: json['totalTrips'] ?? json['total'] ?? 0,
        totalSpentMonth:
            json['totalSpentMonth'] ?? json['totalSpent'] ?? json['monthlySpent'] ?? 0,
      );
}

class VirtualCardQrResult {
  final String? cardNumber;
  final String? ownerName;
  final String? cardId;

  VirtualCardQrResult({this.cardNumber, this.ownerName, this.cardId});

  factory VirtualCardQrResult.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map<String, dynamic>?;
    return VirtualCardQrResult(
      cardNumber: card?['cardNumber'] ?? json['cardNumber'] ?? json['number'],
      ownerName: card?['ownerName'] ?? json['ownerName'] ?? json['name'],
      cardId: card?['id'] ?? json['id'] ?? json['cardId'],
    );
  }
}

class CardBalanceResult {
  final int balance;
  final String? ownerName;
  final String? cardName;

  CardBalanceResult({required this.balance, this.ownerName, this.cardName});

  factory CardBalanceResult.fromJson(Map<String, dynamic> json) =>
      CardBalanceResult(
        balance: json['balance'] ?? json['saldo'] ?? 0,
        ownerName: json['ownerName'] ?? json['name'],
        cardName: json['cardName'] ?? json['card']?['name'],
      );
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
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        phoneNumber: (json['phoneNumber'] ?? json['phone_number'] ?? json['phone'] ?? '').toString(),
      );
}
