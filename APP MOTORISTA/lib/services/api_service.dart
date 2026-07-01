import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_pro/services/secure_storage_service.dart';
import 'package:troco_seguro_pro/models/driver_user.dart';
import 'package:troco_seguro_pro/models/transaction.dart';
import 'package:troco_seguro_pro/models/trip.dart';
import 'package:troco_seguro_pro/models/earnings.dart';
import 'package:troco_seguro_pro/models/faq_item.dart';
import 'package:troco_seguro_pro/models/vehicle.dart';
import 'package:troco_seguro_pro/models/emergency_contact.dart';
import 'package:troco_seguro_pro/models/notification.dart';

/// Serviço para comunicação com a API do Troco Seguro (App Motorista)
class ApiService {
  static final  String baseUrl = dotenv.get('BASE_URL') ?? 'http://localhost:3000';
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
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
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
        }
        options.headers['user-agent'] = 'TrocoSeguroMotorista/1.0';
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _endRequest();
        return handler.next(response);
      },
      onError: (error, handler) async {
        _endRequest();

        // Tentar renovar token se expirado
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          try {
            final refreshed = await _refreshTokens();
            if (refreshed) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_accessToken';
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            }
          } catch (_) {}
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

  /// Carregar tokens salvos (com migração automática de SharedPreferences)
  Future<void> loadTokens() async {
    final secure = SecureStorageService();
    String? accessToken = await secure.readAccessToken();
    String? refreshToken = await secure.readRefreshToken();

    if (accessToken == null || accessToken.trim().isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final legacyAccess = prefs.getString('accessToken');
      final legacyRefresh = prefs.getString('refreshToken');
      if (legacyAccess != null && legacyAccess.trim().isNotEmpty) {
        await secure.saveAccessToken(legacyAccess);
        if (legacyRefresh != null) {
          await secure.saveRefreshToken(legacyRefresh);
        }
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
        accessToken = legacyAccess;
        refreshToken = legacyRefresh;
      }
    }

    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Salvar tokens
  Future<void> saveTokens(String accessToken, String? refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    final secure = SecureStorageService();
    await secure.saveAccessToken(accessToken);
    if (refreshToken != null) {
      await secure.saveRefreshToken(refreshToken);
    }
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
    final secure = SecureStorageService();
    await secure.deleteAccessToken();
    await secure.deleteRefreshToken();
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
        await saveTokens(accessToken, refreshToken);
        return true;
      }
    } catch (_) {}
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
      });

      final data = _payload(response.data);
      return ApiResponse.success(AuthResult(
        message: data['message'] ?? 'Registo realizado. Verifique o SMS.',
        requiresOtp: true,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    } catch (e) {
      debugPrint('❌ Erro inesperado no registo: $e');
      return ApiResponse.error('Erro inesperado ao criar conta. Tente novamente.');
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

      // ✅ Verificar role no OTP também
      final userMap = data['user'] is Map
          ? (data['user'] as Map).cast<String, dynamic>()
          : null;
      final role = (userMap?['role'] ?? data['role'] ?? authData['role'])?.toString().toUpperCase();
      if (role != null && role != 'DRIVER') {
        debugPrint('🚫 Acesso negado no OTP: role=$role (apenas DRIVER permitido)');
        return ApiResponse.error(
          'Esta conta é de passageiro. Por favor, utilize o App Passageiro.',
        );
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        await saveTokens(accessToken, refreshToken);
      }

      return ApiResponse.success(AuthResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        driver: userMap != null ? DriverUser.fromJson(userMap) : null,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    } catch (e) {
      debugPrint('❌ Erro inesperado no verifyOtp: $e');
      return ApiResponse.error('Erro inesperado. Tente novamente.');
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

      final userMap = data['user'] != null
          ? (data['user'] as Map).cast<String, dynamic>()
          : (data['fullName'] != null || data['name'] != null ? data : null);

      // ✅ Verificar role: apenas DRIVER pode aceder ao app motorista
      final role = (userMap?['role'] ?? data['role'] ?? authData['role'])?.toString().toUpperCase();
      if (role != null && role != 'DRIVER') {
        debugPrint('🚫 Acesso negado: role=$role (apenas DRIVER permitido)');
        return ApiResponse.error(
          'Esta conta é de passageiro. Por favor, utilize o App Passageiro.',
        );
      }

      await saveTokens(accessToken, refreshToken);

      return ApiResponse.success(AuthResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
        driver: userMap != null ? DriverUser.fromJson(userMap) : null,
      ));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    } catch (e) {
      debugPrint('❌ Erro inesperado no login: $e');
      return ApiResponse.error('Erro inesperado ao entrar. Tente novamente.');
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
        final data = _payload(response.data);

        // Unificar lógica de extração de usuário (idêntica ao login)
        final userMap = data['user'] != null
            ? (data['user'] as Map).cast<String, dynamic>()
            : (data['fullName'] != null || data['name'] != null ? data : data);

        return ApiResponse.success(DriverUser.fromJson(userMap));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          final response = await _dio.get('auth/profile');
          final data = _payload(response.data);

          final userMap = data['user'] != null
              ? (data['user'] as Map).cast<String, dynamic>()
              : (data['fullName'] != null || data['name'] != null
                  ? data
                  : data);

          return ApiResponse.success(DriverUser.fromJson(userMap));
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
      await _dio.put('users/me/status', data: {'isOnline': isOnline});
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ GANHOS ============

  /// Obter resumo de ganhos e estatísticas
  Future<ApiResponse<Earnings>> getEarnings() async {
    try {
      // Buscar viagens e calcular ganhos por período a partir dos dados reais
      final tripsResponse = await _dio.get('trips', queryParameters: {
        'page': 1,
        'limit': 200, // busca suficiente para cobrir meses de histórico
      });
      final List<dynamic> rawList = _listPayload(tripsResponse.data);
      if (rawList.isNotEmpty) {
        final tripMaps = rawList
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        return ApiResponse.success(Earnings.fromTrips(tripMaps));
      }
    } on DioException catch (_) {
      // Falhou ao buscar trips — tenta users/me como fallback
    }

    try {
      final response = await _dio.get('users/me');
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

  /// Obter saldo disponível
  Future<ApiResponse<int>> getBalance() async {
    try {
      try {
        final response = await _dio.get('wallet/balance');
        final data = _payload(response.data);
        final raw = data['balance'] ?? data['amount'] ?? data['available'];
        if (raw != null) {
          return ApiResponse.success(
              double.tryParse(raw.toString())?.toInt() ?? 0);
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          final profileResult = await getProfile();
          if (profileResult.isSuccess && profileResult.data != null) {
            return ApiResponse.success(profileResult.data!.balance);
          }
          return ApiResponse.error(
              profileResult.error ?? 'Falha ao obter saldo');
        }
        rethrow;
      }
      final profileResult = await getProfile();
      if (profileResult.isSuccess && profileResult.data != null) {
        return ApiResponse.success(profileResult.data!.balance);
      }
      return ApiResponse.error(profileResult.error ?? 'Falha ao obter saldo');
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    } catch (e) {
      return ApiResponse.error('Erro ao processar saldo: $e');
    }
  }

  // ============ QR CODE ============

  /// Iniciar sessão de viagem e gerar QR Codes (pai + filhos por assento)
  Future<ApiResponse<QrSetupResult>> setupQrSession({
    required int amount,
    String? activeVehicleId,
  }) async {
    try {
      final body = <String, dynamic>{
        'pricePerSeat': amount,
        if (activeVehicleId != null && activeVehicleId.isNotEmpty)
          'vehicleId': activeVehicleId,
      };
      final response = await _dio.post('qrcodes/session/start', data: body);
      final raw = response.data;
      final map = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
      final root = map['data'] is Map
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;
      return ApiResponse.success(QrSetupResult.fromJson(root));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Encerrar sessão de viagem activa
  Future<ApiResponse<void>> endSession() async {
    try {
      await _dio.post('qrcodes/session/end');
      return ApiResponse._(data: null, isSuccess: true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 404 = não havia sessão activa
      // 500 = bug no servidor — tratar como sucesso para não bloquear o motorista
      if (status == 404 || status == 500) {
        debugPrint('endSession: status $status — a limpar estado local');
        return ApiResponse._(data: null, isSuccess: true);
      }
      return ApiResponse._(error: _parseError(e), isSuccess: false);
    }
  }

  /// Obter estado actual da sessão: assentos pagos, publicToken, receita
  Future<ApiResponse<SessionSeatsResult>> getSessionSeats() async {
    try {
      final response = await _dio.get('qrcodes/session/seats');
      final data = _payload(response.data);
      return ApiResponse.success(SessionSeatsResult.fromJson(data));
    } on DioException catch (e) {
      // 404 = sem sessão activa — não é erro, é estado normal
      // 500 = bug no servidor — tratar como sem dados para não bloquear o motorista
      if (e.response?.statusCode == 404 || e.response?.statusCode == 500) {
        return ApiResponse.success(SessionSeatsResult(active: false));
      }
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Stream SSE em tempo real dos assentos pagos (GET qrcodes/session/seats-live)
  Stream<SessionSeatsResult> streamSessionSeats() {
    late StreamController<SessionSeatsResult> controller;
    HttpClient? httpClient;
    bool cancelled = false;

    Future<void> connect() async {
      while (!cancelled) {
        httpClient = HttpClient();
        try {
          final uri = Uri.parse('${baseUrl}qrcodes/session/seats-live');
          final request = await httpClient!.getUrl(uri);
          request.headers.set('Accept', 'text/event-stream');
          request.headers.set('Cache-Control', 'no-cache');
          if (_accessToken != null) {
            request.headers.set('Authorization', 'Bearer $_accessToken');
          }
          final response = await request.close();
          // Parar em erros de autenticação — não reconectar
          if (response.statusCode == 401 || response.statusCode == 403) {
            debugPrint('SSE: auth error ${response.statusCode}, a aguardar token');
            break;
          }
          // Em caso de erro do servidor, deixar cair para reconectar
          if (response.statusCode >= 400) {
            debugPrint('SSE: erro ${response.statusCode}');
          } else {
            String buffer = '';
            await for (final chunk in response.transform(utf8.decoder)) {
              if (cancelled) break;
              buffer += chunk;
              while (buffer.contains('\n\n')) {
                final idx = buffer.indexOf('\n\n');
                final block = buffer.substring(0, idx);
                buffer = buffer.substring(idx + 2);
                for (final line in block.split('\n')) {
                  if (line.startsWith('data:')) {
                    try {
                      final raw = jsonDecode(line.substring(5).trim());
                      if (raw is Map && !cancelled && !controller.isClosed) {
                        controller.add(
                          SessionSeatsResult.fromJson(raw.cast<String, dynamic>()),
                        );
                      }
                    } catch (_) {}
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('SSE seats-live: $e');
        } finally {
          httpClient?.close(force: true);
          httpClient = null;
        }
        if (!cancelled) await Future<void>.delayed(const Duration(seconds: 5));
      }
    }

    controller = StreamController<SessionSeatsResult>(
      onListen: () => connect(),
      onCancel: () {
        cancelled = true;
        httpClient?.close(force: true);
      },
    );

    return controller.stream;
  }

  /// Fluxo 2 — Motorista escaneia QR do Passageiro e cobra
  Future<ApiResponse<PassengerQrPaymentResult>> authorizePassengerQr({
    required String qrData,
    required String passengerPin,
    required String origin,
    required String destination,
    double distanceKm = 0.0,
    int durationMinutes = 0,
    int seatsCount = 1,
    String? parentQrToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'qrData': qrData,
        'passengerPin': passengerPin,
        'origin': origin,
        'destination': destination,
        if (distanceKm > 0) 'distanceKm': distanceKm,
        if (durationMinutes > 0) 'durationMinutes': durationMinutes,
        if (seatsCount > 1) 'seatsCount': seatsCount,
        if (parentQrToken != null && parentQrToken.isNotEmpty)
          'parentQrToken': parentQrToken,
      };
      final response =
          await _dio.post('payments/authorize-passenger-qr', data: body);
      return ApiResponse.success(
          PassengerQrPaymentResult.fromJson(_payload(response.data)));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ AVALIAÇÕES ============

  /// Avaliar passageiro
  Future<ApiResponse<void>> ratePassenger({
    required String targetUserId,
    required int stars,
    String? comment,
  }) async {
    try {
      await _dio.post('ratings', data: {
        'targetUserId': targetUserId,
        'stars': stars,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ AUTH — RECUPERAÇÃO DE PASSWORD ============

  Future<ApiResponse<void>> forgotPassword(String phoneNumber) async {
    try {
      await _dio.post('auth/forgot-password', data: {'phoneNumber': phoneNumber});
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<String>> verifyForgotPasswordOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await _dio.post('auth/forgot-password/verify-otp', data: {
        'phoneNumber': phoneNumber,
        'otp': otp,
      });
      final data = _payload(response.data);
      final token = (data['resetToken'] ?? data['token'])?.toString();
      if (token == null || token.isEmpty) {
        return ApiResponse.error('Token de reset não recebido');
      }
      return ApiResponse.success(token);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

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

  // ============ SEGURANÇA — PIN ============

  Future<ApiResponse<bool>> verifyPin(String pin) async {
    try {
      await _dio.post('auth/verify-pin', data: {'pin': pin});
      return ApiResponse.success(true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        return ApiResponse.success(false);
      }
      return ApiResponse.error(_parseError(e));
    }
  }

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

  // ============ SEGURANÇA — PÂNICO ============

  Future<ApiResponse<void>> triggerPanic({
    double latitude = 0,
    double longitude = 0,
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
      final List<dynamic> data = _listPayload(response.data);
      return ApiResponse.success(
          data.map((e) => EmergencyContact.fromJson(e)).toList());
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<EmergencyContact>> addEmergencyContact({
    required String name,
    required String phoneNumber,
  }) async {
    try {
      final response = await _dio.post('safety/emergency-contacts', data: {
        'name': name,
        'phoneNumber': phoneNumber,
      });
      return ApiResponse.success(
          EmergencyContact.fromJson(_payload(response.data)));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
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

  // ============ CARTÃO VIRTUAL ============

  Future<ApiResponse<VirtualCardQrResult>> resolveVirtualCardQr(String qrData) async {
    try {
      final response = await _dio.post('virtual-cards/resolve-qr', data: {'qrData': qrData});
      return ApiResponse.success(VirtualCardQrResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // API extrai amount do paymentToken JWT — não enviar amount no body
  Future<ApiResponse<PaymentResult>> processPayment({
    required String driverId,
    required String cardId,
    required int amount,
    required String pin,
    required String paymentToken,
    String origin = '',
    String destination = '',
    double distanceKm = 0.0,
    int durationMinutes = 0,
    int seatsCount = 1,
  }) async {
    try {
      final body = <String, dynamic>{
        'driverId': driverId,
        'pin': pin,
        'paymentToken': paymentToken,
        'seatsCount': seatsCount,
        'origin': origin,
        'destination': destination,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
      };
      if (cardId.isNotEmpty) body['cardId'] = cardId;
      final response = await _dio.post('payments/process', data: body);
      return ApiResponse.success(PaymentResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Cobrar cartão virtual do passageiro (POS terminal flow)
  Future<ApiResponse<PaymentResult>> chargeVirtualCard({
    required String cardId,
    required int amount,
    required String cardPin,
  }) async {
    try {
      final response = await _dio.post('wallet/card/withdraw', data: {
        'cardId': cardId,
        'amount': amount,
        'pin': cardPin,
      });
      return ApiResponse.success(PaymentResult.fromJson(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ CONTA ============

  Future<ApiResponse<void>> deleteAccount({String? iban}) async {
    try {
      await _dio.delete('users/me', data: iban != null && iban.isNotEmpty ? {'iban': iban} : null);
      await clearTokens();
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ NOTIFICAÇÕES ============

  Future<ApiResponse<NotificationsResult>> getNotifications() async {
    try {
      final response = await _dio.get('notifications');
      final raw = response.data;
      final Map<String, dynamic> meta =
          raw is Map ? raw.cast<String, dynamic>() : {};
      final list = _listPayload(raw);
      return ApiResponse.success(NotificationsResult.fromJson(meta, list));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<void>> markNotificationRead(String id) async {
    try {
      await _dio.put('notifications/$id/read');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  Future<ApiResponse<void>> markAllNotificationsRead() async {
    try {
      await _dio.put('notifications/read-all');
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ FCM TOKEN ============

  Future<ApiResponse<void>> updateFcmToken(String token) async {
    try {
      await _dio.put('users/me/fcm-token', data: {'token': token});
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ DOCUMENTOS ============

  Future<ApiResponse<void>> uploadDocuments({
    required File license,
    required File bi,
  }) async {
    try {
      final formData = FormData.fromMap({
        'license': await MultipartFile.fromFile(license.path),
        'bi': await MultipartFile.fromFile(bi.path),
      });
      await _dio.post('users/upload-docs', data: formData);
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ DETALHE DE VIAGEM ============

  Future<ApiResponse<Trip>> getTripDetail(String tripId) async {
    try {
      final response = await _dio.get('trips/$tripId');
      return ApiResponse.success(Trip.fromJson(_payload(response.data)));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Avaliar uma viagem (POST /trips/{id}/rate)
  Future<ApiResponse<void>> rateTrip({
    required String tripId,
    required int stars,
    String? comment,
  }) async {
    try {
      await _dio.post('trips/$tripId/rate', data: {
        'stars': stars,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
      return ApiResponse.success(null);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ ESTATÍSTICAS DE VIAGENS ============

  Future<ApiResponse<Map<String, dynamic>>> getTripStats() async {
    try {
      final response = await _dio.get('trips/stats');
      return ApiResponse.success(_payload(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ AVALIAÇÃO PRÓPRIA ============

  Future<ApiResponse<double>> getMyRating(String userId) async {
    try {
      final response = await _dio.get('ratings/$userId');
      final data = _payload(response.data);
      final avg = data['average'] ?? data['averageRating'] ?? data['rating'];
      return ApiResponse.success(
          double.tryParse(avg?.toString() ?? '0') ?? 0.0);
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Ver histórico de avaliações de um utilizador
  Future<ApiResponse<List<Map<String, dynamic>>>> getRatings(
      String userId) async {
    try {
      final response = await _dio.get('ratings/$userId');
      final data = _payload(response.data);
      final list = data['ratings'] as List? ?? data['items'] as List? ?? [];
      return ApiResponse.success(
          list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList());
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ PERFIL DE MOTORISTA/PASSAGEIRO ============

  /// Ver perfil público de um utilizador (GET /users/drivers/{id})
  Future<ApiResponse<Map<String, dynamic>>> getDriverProfile(
      String userId) async {
    try {
      final response = await _dio.get('users/drivers/$userId');
      return ApiResponse.success(_payload(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ CARTEIRA — VERIFICAR DESTINATÁRIO ============

  /// Verificar destinatário de transferência por telefone
  Future<ApiResponse<Map<String, dynamic>>> verifyTransferRecipient(
      String phone) async {
    try {
      final response = await _dio.get('wallet/transfer/verify/$phone');
      return ApiResponse.success(_payload(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  // ============ DEPÓSITO (SIMULAÇÃO) ============

  /// Iniciar referência de depósito pendente
  Future<ApiResponse<Map<String, dynamic>>> initiateDeposit({
    required int amount,
  }) async {
    try {
      final response = await _dio.post('payments/deposit/initiate', data: {
        'amount': amount,
      });
      return ApiResponse.success(_payload(response.data));
    } on DioException catch (e) {
      return ApiResponse.error(_parseError(e));
    }
  }

  /// Simular webhook de confirmação de pagamento (ambiente de testes)
  Future<ApiResponse<void>> simulateDepositWebhook({
    required String reference,
  }) async {
    try {
      await _dio.post('payments/webhook/simulate', data: {
        'reference': reference,
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
    if (raw is Map) {
      if (raw['data'] is List) return raw['data'];
      if (raw['transactions'] is List) return raw['transactions'];
      if (raw['history'] is List) return raw['history'];
      if (raw['list'] is List) return raw['list'];

      // Procura qualquer lista no primeiro nível como fallback
      for (var val in raw.values) {
        if (val is List) return val;
      }

      final map = _payload(raw);
      if (map['data'] is List) return map['data'];
    }
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

  // ============== VEÍCULOS ==============

  Future<ApiResponse<Vehicle>> registerVehicle(
      String licensePlate, String model, String color, {int seats = 4}) async {
    try {
      final response = await _dio.post('fleet/vehicles', data: {
        'licensePlate': licensePlate,
        'model': model,
        'color': color,
        'seats': seats,
      });

      final data = response.data;
      // Tratar dados se estiverem envoltos num node 'data'
      final vehicleData = data['data'] ?? data;
      final vehicle = Vehicle.fromJson(vehicleData as Map<String, dynamic>);
      return ApiResponse._(data: vehicle, isSuccess: true);
    } on DioException catch (e) {
      return ApiResponse._(error: _parseError(e), isSuccess: false);
    } catch (e) {
      return ApiResponse._(error: e.toString(), isSuccess: false);
    }
  }

  Future<ApiResponse<List<Vehicle>>> getVehicles() async {
    try {
      final response = await _dio.get('fleet');

      final data = response.data;
      List<dynamic> vehiclesList = [];

      if (data is List) {
        vehiclesList = data;
      } else if (data is Map) {
        // API retorna { id, name, vehicles: [...], groups: [], createdAt }
        if (data['vehicles'] is List) {
          vehiclesList = data['vehicles'];
        } else if (data['data'] is List) {
          vehiclesList = data['data'];
        }
      }

      final vehicles = vehiclesList
          .map((v) => Vehicle.fromJson(v as Map<String, dynamic>))
          .toList();

      return ApiResponse._(data: vehicles, isSuccess: true);
    } on DioException catch (e) {
      return ApiResponse._(error: _parseError(e), isSuccess: false);
    } catch (e) {
      return ApiResponse._(error: e.toString(), isSuccess: false);
    }
  }

  Future<ApiResponse<Vehicle>> updateVehicle(
      String vehicleId, {
        String? licensePlate,
        String? model,
        String? color,
        int? seats,
      }) async {
    try {
      final data = <String, dynamic>{
        if (licensePlate != null) 'licensePlate': licensePlate,
        if (model != null) 'model': model,
        if (color != null) 'color': color,
        if (seats != null) 'seats': seats,
      };
      final response = await _dio.put('fleet/vehicles/$vehicleId', data: data);
      final vData = response.data['data'] ?? response.data;
      return ApiResponse._(data: Vehicle.fromJson(vData as Map<String, dynamic>), isSuccess: true);
    } on DioException catch (e) {
      return ApiResponse._(error: _parseError(e), isSuccess: false);
    }
  }

  Future<ApiResponse<void>> deleteVehicle(String vehicleId) async {
    try {
      await _dio.delete('fleet/vehicles/$vehicleId');
      return ApiResponse._(data: null, isSuccess: true);
    } on DioException catch (e) {
      return ApiResponse._(error: _parseError(e), isSuccess: false);
    }
  }

  String _parseError(DioException e) {
    debugPrint('❌ DioException type=${e.type} status=${e.response?.statusCode} msg=${e.message} cause=${e.error}');
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
        return 'Tempo limite excedido. Verifique sua conexão.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com o servidor. (${e.error ?? e.message})';
      default:
        return 'Erro de comunicação com o servidor. (${e.type})';
    }
  }
}

// ============ NOVOS MODELOS — QR SETUP + SESSÃO ============

class QrSetupResult {
  final QrData parentQr;
  final List<ChildQrData> childQrs;

  QrSetupResult({required this.parentQr, required this.childQrs});

  factory QrSetupResult.fromJson(Map<String, dynamic> json) {
    // API renomeou 'parentQr' para 'qrCode' — suporta ambos
    final parentQrMap =
        ((json['qrCode'] ?? json['parentQr']) as Map?)?.cast<String, dynamic>() ?? {};
    final childQrsList = json['childQrs'] as List? ?? [];
    return QrSetupResult(
      parentQr: QrData.fromJson(parentQrMap),
      childQrs: childQrsList
          .map((c) => ChildQrData.fromJson((c as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class QrData {
  final String id;
  final String publicToken;
  final String image; // data:image/png;base64,...
  final int tripPrice;

  QrData({required this.id, required this.publicToken, required this.image, required this.tripPrice});

  factory QrData.fromJson(Map<String, dynamic> json) {
    return QrData(
      id: json['id']?.toString() ?? '',
      publicToken: json['publicToken']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      // API renomeou 'tripPrice' para 'pricePerSeat' — suporta ambos
      tripPrice: int.tryParse((json['pricePerSeat'] ?? json['tripPrice'])?.toString() ?? '0') ?? 0,
    );
  }
}

class ChildQrData {
  final String id;
  final String label;
  final String publicToken;
  final String image;

  ChildQrData({required this.id, required this.label, required this.publicToken, required this.image});

  factory ChildQrData.fromJson(Map<String, dynamic> json) {
    return ChildQrData(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      publicToken: json['publicToken']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
    );
  }
}

class SessionSeatsResult {
  final bool active;
  final String? parentQrId;
  final String? publicToken;
  final int pricePerSeat;
  final int totalSeats;
  final int paidSeats;
  final int availableSeats;
  final int revenue;
  final int childQrCount;

  SessionSeatsResult({
    required this.active,
    this.parentQrId,
    this.publicToken,
    this.pricePerSeat = 0,
    this.totalSeats = 0,
    this.paidSeats = 0,
    this.availableSeats = 0,
    this.revenue = 0,
    this.childQrCount = 0,
  });

  factory SessionSeatsResult.fromJson(Map<String, dynamic> json) {
    return SessionSeatsResult(
      active: json['active'] == true,
      parentQrId: json['parentQrId']?.toString(),
      publicToken: json['publicToken']?.toString(),
      pricePerSeat:
          int.tryParse(json['pricePerSeat']?.toString() ?? '0') ?? 0,
      totalSeats:
          int.tryParse(json['totalSeats']?.toString() ?? '0') ?? 0,
      // API renomeou 'paidSeats' para 'totalPayments'
      paidSeats:
          int.tryParse((json['totalPayments'] ?? json['paidSeats'])?.toString() ?? '0') ?? 0,
      availableSeats:
          int.tryParse(json['availableSeats']?.toString() ?? '0') ?? 0,
      revenue: int.tryParse(json['revenue']?.toString() ?? '0') ?? 0,
      childQrCount:
          int.tryParse(json['childQrCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class PassengerQrPaymentResult {
  final bool success;
  final String transactionId;
  final String? tripId;
  final int platformFeeApplied;
  final int newBalance;

  PassengerQrPaymentResult({
    required this.success,
    required this.transactionId,
    this.tripId,
    this.platformFeeApplied = 0,
    this.newBalance = 0,
  });

  factory PassengerQrPaymentResult.fromJson(Map<String, dynamic> json) {
    return PassengerQrPaymentResult(
      success: json['success'] == true,
      transactionId: json['transactionId']?.toString() ??
          json['id']?.toString() ??
          '',
      tripId: json['tripId']?.toString(),
      platformFeeApplied: int.tryParse(
              json['platformFeeApplied']?.toString() ?? '0') ??
          0,
      newBalance: int.tryParse(
              (json['newBalance'] ?? json['balance'] ?? 0).toString()) ??
          0,
    );
  }
}

class VirtualCardQrResult {
  final String? cardId;
  final String? cardNumber;
  final String? ownerName;

  VirtualCardQrResult({this.cardId, this.cardNumber, this.ownerName});

  factory VirtualCardQrResult.fromJson(Map<String, dynamic> json) {
    final card = json['card'] as Map<String, dynamic>?;
    return VirtualCardQrResult(
      cardId: card?['id']?.toString() ?? json['id']?.toString() ?? json['cardId']?.toString(),
      cardNumber: card?['cardNumber']?.toString() ?? json['cardNumber']?.toString() ?? json['number']?.toString(),
      ownerName: card?['ownerName']?.toString() ?? json['ownerName']?.toString() ?? json['name']?.toString(),
    );
  }
}

class PaymentResult {
  final String transactionId;
  final int amount;
  final int newBalance;
  final String status;
  final String message;

  PaymentResult({
    required this.transactionId,
    required this.amount,
    required this.newBalance,
    required this.status,
    required this.message,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      transactionId: json['transactionId']?.toString() ?? json['id']?.toString() ?? '',
      amount: int.tryParse(json['amount'].toString()) ?? 0,
      newBalance: int.tryParse((json['newBalance'] ?? json['balance'] ?? 0).toString()) ?? 0,
      status: json['status']?.toString() ?? 'completed',
      message: json['message']?.toString() ?? 'Pagamento recebido com sucesso',
    );
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
