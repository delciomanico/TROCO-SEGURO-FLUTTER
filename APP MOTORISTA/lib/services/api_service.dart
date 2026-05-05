import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_motorista/models/driver_user.dart';
import 'package:troco_seguro_motorista/models/transaction.dart';
import 'package:troco_seguro_motorista/models/trip.dart';
import 'package:troco_seguro_motorista/models/earnings.dart';
import 'package:troco_seguro_motorista/models/faq_item.dart';

/// Serviço para comunicação com a API do Troco Seguro (App Motorista)
class ApiService {
  static const String baseUrl = 'https://troco-seguro.onrender.com/api/v1/';
  static final ApiService _instance = ApiService._internal();
  static final ValueNotifier<int> _activeRequests = ValueNotifier<int>(0);
  static final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);

  final Dio _dio;

  String? _accessToken;
  String? _refreshToken;

  ValueListenable<bool> get loadingListenable => _isLoading;

  factory ApiService() => _instance;

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
        _beginRequest();
        if (_accessToken != null && _accessToken!.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
          final tokenPreview = _accessToken!.length > 16
              ? '${_accessToken!.substring(0, 8)}...${_accessToken!.substring(_accessToken!.length - 6)}'
              : _accessToken;
          debugPrint('🔐 Authorization: Bearer $tokenPreview');
        } else {
          debugPrint('🔐 Authorization: (sem token)');
        }
        options.headers['user-agent'] = 'TrocoSeguroMotorista/1.0';
        debugPrint('🌐 ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _endRequest();
        debugPrint(
            '✅ ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        _endRequest();
        debugPrint(
            '❌ ${error.response?.statusCode} ${error.requestOptions.method} ${error.requestOptions.uri}');

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

  void _beginRequest() {
    _activeRequests.value = _activeRequests.value + 1;
    _isLoading.value = _activeRequests.value > 0;
  }

  void _endRequest() {
    if (_activeRequests.value > 0) {
      _activeRequests.value = _activeRequests.value - 1;
    }
    _isLoading.value = _activeRequests.value > 0;
  }

  /// Carregar tokens salvos
  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _refreshToken = prefs.getString('refreshToken');

    if (_accessToken != null && _accessToken!.trim().isNotEmpty) {
      debugPrint('🔑 Token carregado do storage');
    } else {
      debugPrint('🔑 Nenhum token encontrado no storage');
    }
  }

  /// Salvar tokens
  Future<void> saveTokens(String accessToken, String? refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    if (refreshToken != null) {
      await prefs.setString('refreshToken', refreshToken);
    }

    debugPrint('💾 Tokens salvos com sucesso');
  }

  /// Definir tokens em memória (uso imediato após autenticação)
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
  bool get isAuthenticated =>
      _accessToken != null && _accessToken!.trim().isNotEmpty;

  /// Renovar tokens
  Future<bool> _refreshTokens() async {
    try {
      final response = await _dio.post('auth/refresh', data: {
        'refreshToken': _refreshToken,
      });
      final authData = _extractAuthData(response.data);
      final accessToken = authData['accessToken']?.toString();
      final refreshToken = authData['refreshToken']?.toString();
      if (accessToken != null && accessToken.isNotEmpty) {
        await saveTokens(
          accessToken,
          refreshToken,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Falha ao renovar token: $e');
    }
    return false;
  }

  // ============ AUTENTICAÇÃO ============

  /// Registar novo motorista
  Future<ApiResponse<AuthResult>> register({
    required String fullName,
    required String phoneNumber,
    required String password,
    String? licensePlate,
    String? vehicleModel,
  }) async {
    try {
      final response = await _dio.post('auth/register', data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'password': password,
        'role': 'DRIVER',
        'licensePlate': licensePlate,
        'vehicleModel': vehicleModel,
      });

      final data = _payload(response.data);
      return ApiResponse.success(AuthResult(
        message: data['message'] ?? 'Registo realizado. Verifique o SMS.',
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

      final data = _payload(response.data);
      final authData = _extractAuthData(response.data);
      final accessToken = authData['accessToken']?.toString();
      final refreshToken = authData['refreshToken']?.toString();
      if (accessToken != null && accessToken.isNotEmpty) {
        await saveTokens(
          accessToken,
          refreshToken,
        );
      }

      return ApiResponse.success(AuthResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        driver: data['user'] != null
            ? DriverUser.fromJson((data['user'] as Map).cast<String, dynamic>())
            : null,
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

      final data = _payload(response.data);
      final authData = _extractAuthData(response.data);
      final accessToken = authData['accessToken']?.toString();
      final refreshToken = authData['refreshToken']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        return ApiResponse.error('Token de acesso não retornado pela API.');
      }
      await saveTokens(accessToken, refreshToken);

      return ApiResponse.success(AuthResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        driver: data['user'] != null
            ? DriverUser.fromJson((data['user'] as Map).cast<String, dynamic>())
            : null,
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

  // ============ PERFIL DO MOTORISTA ============

  /// Obter perfil do motorista
  Future<ApiResponse<DriverUser>> getProfile() async {
    try {
      try {
        final response = await _dio.get('users/me');
        return ApiResponse.success(DriverUser.fromJson(_payload(response.data)));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          final response = await _dio.get('auth/profile');
          return ApiResponse.success(DriverUser.fromJson(_payload(response.data)));
        }
        rethrow;
      }
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Atualizar perfil
  Future<ApiResponse<DriverUser>> updateProfile({
    String? fullName,
    String? email,
    String? photo,
    String? licensePlate,
    String? vehicleModel,
    String? vehicleColor,
    String? vehicleYear,
    String? bankAccount,
    String? bankName,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName;
      if (email != null) data['email'] = email;
      if (photo != null) data['photo'] = photo;
      if (licensePlate != null) data['licensePlate'] = licensePlate;
      if (vehicleModel != null) data['vehicleModel'] = vehicleModel;
      if (vehicleColor != null) data['vehicleColor'] = vehicleColor;
      if (vehicleYear != null) data['vehicleYear'] = vehicleYear;
      if (bankAccount != null) data['bankAccount'] = bankAccount;
      if (bankName != null) data['bankName'] = bankName;

      final response = await _dio.put('users/me', data: data);
      return ApiResponse.success(DriverUser.fromJson(_payload(response.data)));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Atualizar status online/offline
  Future<ApiResponse<void>> updateDriverStatus({required bool isOnline}) async {
    try {
      try {
        await _dio.patch('drivers/status', data: {
          'isOnline': isOnline,
        });
      } on DioException catch (e) {
        if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
          await _dio.put('users/me', data: {
            'isOnline': isOnline,
          });
        } else {
          rethrow;
        }
      }
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ GANHOS ============

  /// Obter resumo de ganhos e estatísticas
  Future<ApiResponse<Earnings>> getEarnings() async {
    try {
      final response = await _dio.get('trips/stats');
      return ApiResponse.success(Earnings.fromJson(_payload(response.data)));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ VIAGENS ============

  /// Listar viagens do motorista
  Future<ApiResponse<List<Trip>>> getTrips(
      {int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get('trips', queryParameters: {
        'page': page,
        'limit': limit,
      });
      final List<dynamic> data = _listPayload(response.data);
      return ApiResponse.success(data.map((t) => Trip.fromJson(t)).toList());
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    } catch (e) {
      return ApiResponse.error('Falha ao processar viagens: $e');
    }
  }

  // ============ TRANSAÇÕES ============

  /// Histórico de transações
  Future<ApiResponse<List<Transaction>>> getTransactionHistory({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get('transactions/history', queryParameters: {
        'page': page,
        'limit': limit,
      });
      final List<dynamic> data = _listPayload(response.data);
      return ApiResponse.success(
          data.map((tx) => Transaction.fromJson(tx)).toList());
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ CARTEIRA / SAQUES ============

  /// Solicitar saque
  Future<ApiResponse<void>> requestWithdrawal({
    required int amount,
    required String method, // 'bank' | 'express'
    String? bankAccount,
  }) async {
    try {
      await _dio.post('transactions/transfer', data: {
        'amount': amount,
        'method': method,
        'bankAccount': bankAccount,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Obter saldo disponível
  Future<ApiResponse<int>> getBalance() async {
    try {
      try {
        final response = await _dio.get('wallet/balance');
        final data = _payload(response.data);
        return ApiResponse.success(
            int.tryParse(data['balance'].toString()) ?? 0);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          final profileResponse = await _dio.get('users/me');
          final profile = _payload(profileResponse.data);
          final wallet = profile['wallet'];

          if (wallet is Map) {
            final walletBalance = wallet['balance'];
            return ApiResponse.success(
              int.tryParse(walletBalance.toString()) ?? 0,
            );
          }

          return ApiResponse.success(
            int.tryParse(profile['balance'].toString()) ?? 0,
          );
        }
        rethrow;
      }
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ QR CODE ============

  /// Definir/atualizar o valor do QR estático do motorista
  Future<ApiResponse<QrCodePriceResult>> setQrCodePrice({
    required int amount,
    required String description,
  }) async {
    try {
      final body = {
        'amount': amount,
        'description': description,
      };

      try {
        final response = await _dio.post('qrcodes/price', data: body);
        return ApiResponse.success(
            QrCodePriceResult.fromJson(_payload(response.data)));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          final response = await _dio.post('qr-code/payment-request', data: {
            'amount': amount,
          });
          final data = _payload(response.data);
          return ApiResponse.success(QrCodePriceResult(
            id: data['id']?.toString() ?? '',
            amount: int.tryParse(data['amount'].toString()) ?? amount,
            description: data['description']?.toString() ?? description,
            qrToken: QrTokenData.fromJson(
              (data['qrToken'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{
                    'publicToken': data['qrToken']?.toString() ??
                        data['token']?.toString() ??
                        '',
                    'isActive': true,
                  },
            ),
            validFrom: DateTime.now(),
          ));
        }
        rethrow;
      }
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Obter o QR estático atual do motorista
  Future<ApiResponse<DriverStaticQrCode>> getMyStaticQrCode() async {
    try {
      try {
        final response = await _dio.get('qrcodes/my-static');
        return ApiResponse.success(
            DriverStaticQrCode.fromJson(_payload(response.data)));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          final response = await _dio.get('qr-code/my-code');
          final data = _payload(response.data);
          return ApiResponse.success(DriverStaticQrCode(
            publicToken: data['publicToken']?.toString() ??
                data['qrToken']?.toString() ??
                data['token']?.toString() ??
                '',
            qrCodeImage: data['qrCodeImage']?.toString() ?? '',
            driverName: data['driverName']?.toString() ?? '',
            currentAmount:
                int.tryParse(data['currentAmount'].toString()) ?? 0,
            currency: data['currency']?.toString() ?? 'AOA',
          ));
        }
        rethrow;
      }
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Gerar token QR para receber pagamento
  Future<ApiResponse<String>> generatePaymentQR({required int amount}) async {
    try {
      final result = await setQrCodePrice(
        amount: amount,
        description: 'Corrida',
      );
      if (result.isSuccess && result.data != null) {
        return ApiResponse.success(result.data!.qrToken.publicToken);
      }
      return ApiResponse.error(result.error ?? 'Falha ao gerar QR de cobrança.');
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ AVALIAÇÕES ============

  /// Avaliar passageiro
  Future<ApiResponse<void>> ratePassenger({
    required String tripId,
    required double rating,
    String? comment,
  }) async {
    try {
      await _dio.post('trips/$tripId/rate', data: {
        'rating': rating,
        'comment': comment,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ FAQ ============

  /// Listar FAQs
  Future<ApiResponse<List<FAQItem>>> getFAQs() async {
    try {
      final response = await _dio.get('faq');
      final List<dynamic> data = _listPayload(response.data);
      return ApiResponse.success(data.map((f) => FAQItem.fromJson(f)).toList());
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ HELPERS ============

  Map<String, dynamic> _payload(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final nested = raw['data'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return nested.cast<String, dynamic>();
      return raw;
    }
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      final nested = map['data'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return nested.cast<String, dynamic>();
      return map;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _listPayload(dynamic raw) {
    if (raw is List) return raw;
    final map = _payload(raw);
    final nested = map['data'];
    if (nested is List) return nested;
    return <dynamic>[];
  }

  Map<String, dynamic> _extractAuthData(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['accessToken'] != null) return raw;
      final nested = raw['data'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return nested.cast<String, dynamic>();
      return raw;
    }
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      if (map['accessToken'] != null) return map;
      final nested = map['data'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return nested.cast<String, dynamic>();
      return map;
    }
    return <String, dynamic>{};
  }

  String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        return data['message'] ?? data['error'] ?? 'Erro desconhecido';
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tempo limite excedido. Verifique sua conexão.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com a internet.';
      default:
        return 'Erro de comunicação com o servidor.';
    }
  }
}

/// Resposta genérica da API
class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResponse._({this.data, this.error, required this.isSuccess});

  factory ApiResponse.success(T? data) =>
      ApiResponse._(data: data, isSuccess: true);

  factory ApiResponse.error(String error) =>
      ApiResponse._(error: error, isSuccess: false);
}

/// Resultado de autenticação
class AuthResult {
  final String? accessToken;
  final String? refreshToken;
  final DriverUser? driver;
  final String? message;
  final bool requiresOtp;

  AuthResult({
    this.accessToken,
    this.refreshToken,
    this.driver,
    this.message,
    this.requiresOtp = false,
  });
}

class QrCodePriceResult {
  final String id;
  final int amount;
  final String description;
  final QrTokenData qrToken;
  final DateTime? validFrom;

  QrCodePriceResult({
    required this.id,
    required this.amount,
    required this.description,
    required this.qrToken,
    this.validFrom,
  });

  factory QrCodePriceResult.fromJson(Map<String, dynamic> json) {
    return QrCodePriceResult(
      id: json['id']?.toString() ?? '',
      amount: int.tryParse(json['amount'].toString()) ?? 0,
      description: json['description']?.toString() ?? '',
      qrToken: QrTokenData.fromJson(
        (json['qrToken'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'].toString())
          : null,
    );
  }
}

class QrTokenData {
  final String id;
  final String publicToken;
  final bool isActive;
  final DateTime? createdAt;

  QrTokenData({
    required this.id,
    required this.publicToken,
    required this.isActive,
    this.createdAt,
  });

  factory QrTokenData.fromJson(Map<String, dynamic> json) {
    return QrTokenData(
      id: json['id']?.toString() ?? '',
      publicToken: json['publicToken']?.toString() ?? '',
      isActive: json['isActive'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class DriverStaticQrCode {
  final String publicToken;
  final String qrCodeImage;
  final String driverName;
  final int currentAmount;
  final String currency;

  DriverStaticQrCode({
    required this.publicToken,
    required this.qrCodeImage,
    required this.driverName,
    required this.currentAmount,
    required this.currency,
  });

  factory DriverStaticQrCode.fromJson(Map<String, dynamic> json) {
    return DriverStaticQrCode(
      publicToken: json['publicToken']?.toString() ?? '',
      qrCodeImage: json['qrCodeImage']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      currentAmount: int.tryParse(json['currentAmount'].toString()) ?? 0,
      currency: json['currency']?.toString() ?? 'AOA',
    );
  }
}
