import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_pro/utils/theme.dart';
import 'package:troco_seguro_pro/services/theme_controller.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/models/driver_user.dart';
import 'package:troco_seguro_pro/models/transaction.dart';
import 'package:troco_seguro_pro/models/vehicle.dart';
import 'package:troco_seguro_pro/models/emergency_contact.dart';
import 'package:troco_seguro_pro/models/notification.dart';
import 'package:troco_seguro_pro/screens/onboarding_screen.dart';
import 'package:troco_seguro_pro/screens/splash_screen.dart';
import 'package:troco_seguro_pro/screens/auth_screen.dart';
import 'package:troco_seguro_pro/screens/home_screen.dart';
import 'package:troco_seguro_pro/screens/earnings_screen.dart';
import 'package:troco_seguro_pro/screens/trips_screen.dart';
import 'package:troco_seguro_pro/screens/wallet_screen.dart';
import 'package:troco_seguro_pro/screens/vehicles_screen.dart';
import 'package:troco_seguro_pro/screens/about_screen.dart';
import 'package:troco_seguro_pro/screens/terms_and_conditions_screen.dart';
import 'package:troco_seguro_pro/widgets/withdrawal_modal.dart';
import 'package:troco_seguro_pro/widgets/success_modal.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:troco_seguro_pro/services/secure_storage_service.dart';
import 'package:troco_seguro_pro/services/notification_service.dart';
import 'package:troco_seguro_pro/security/pin_guard.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:troco_seguro_pro/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await NotificationService().initialize();
  // Manter token FCM actualizado no backend quando o Firebase o renovar
  NotificationService().subscribeTokenRefresh((newToken) async {
    final api = ApiService();
    await api.loadTokens();
    if (api.isAuthenticated) await api.updateFcmToken(newToken);
  });
  await initializeDateFormatting('pt_AO', null);
  Intl.defaultLocale = 'pt_AO';
  await ThemeController.instance.load();

  final initialDark =
      ThemeController.instance.themeMode.value == ThemeMode.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: initialDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: initialDark ? Brightness.dark : Brightness.light,
  ));
  
  await dotenv.load();
  runApp(const TrocoSeguroMotoristaApp());
}

class TrocoSeguroMotoristaApp extends StatelessWidget {
  const TrocoSeguroMotoristaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        final darkActive = mode == ThemeMode.dark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              darkActive ? Brightness.light : Brightness.dark,
          statusBarBrightness: darkActive ? Brightness.dark : Brightness.light,
        ));
        return MaterialApp(
          title: 'Troco Seguro - Motorista',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          home: const AppController(),
        );
      },
    );
  }
}

class AppController extends StatefulWidget {
  const AppController({super.key});

  @override
  State<AppController> createState() => _AppControllerState();
}

class _AppControllerState extends State<AppController>
    with WidgetsBindingObserver {
  bool hasSeenOnboarding = true; // Onboarding desativado por padrão
  DriverUser? driver;
  List<Transaction> transactions = [];
  bool isLoading = true;
  bool _isLocked = false;
  bool isOnline = false;
  bool _showSplash = true;
  String? activeVehicleId;
  final ApiService _api = ApiService();

  // ========== MODO MOCK (DESENVOLVIMENTO) ==========
  static const bool useMockData =
      false; // Alterar para true para usar dados mock
  // =================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Quando app vai para background, marcar como bloqueado
      if (driver != null && driver!.isLoggedIn) {
        setState(() => _isLocked = true);
      }
    }
  }

  Future<bool> _tryBiometricUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final bioEnabled = prefs.getBool('ts_bio_enabled') ?? false;

    if (bioEnabled) {
      final auth = LocalAuthentication();
      try {
        final didAuth = await auth.authenticate(
          localizedReason: 'Desbloqueie Troco Seguro Motorista',
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
          ),
        );
        if (didAuth && mounted) {
          setState(() => _isLocked = false);
          return true;
        }
      } catch (e) {
        debugPrint('Biometria falhou: $e');
      }
    }
    return false;
  }

  Future<bool> _unlockWithPin(String pin) async {
    final isValid = await PinGuard.validatePin(
      scope: 'global',
      enteredPin: pin,
      readExpectedPin: () => SecureStorageService().readPin(),
    );

    if (isValid && mounted) {
      setState(() => _isLocked = false);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // ========== MODO MOCK ==========
    if (useMockData) {
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simular loading
      setState(() {
        hasSeenOnboarding = true;
        driver = Constants.mockDriver.copyWith(isLoggedIn: true);
        transactions = Constants.mockTransactions;
        isOnline = true;
        isLoading = false;
        _isLocked = false;
      });
      return;
    }
    // ================================

    // Verificar onboarding
    final hasOnboarding = prefs.getBool('ts_driver_onboarding') ?? false;

    // Carregar dados do motorista do cache
    final driverJson = prefs.getString('ts_driver');
    final txsJson = prefs.getString('ts_driver_transactions');
    final onlineStatus = prefs.getBool('ts_driver_online') ?? false;
    final savedVehicleId = prefs.getString('ts_active_vehicle_id');

    setState(() {
      hasSeenOnboarding = hasOnboarding;
      isOnline = onlineStatus;
      activeVehicleId = savedVehicleId;
      if (driverJson != null) {
        driver = DriverUser.fromJson(json.decode(driverJson));
      }
      if (txsJson != null) {
        transactions = (json.decode(txsJson) as List)
            .map((tx) => Transaction.fromJson(tx))
            .toList();
      }
      isLoading = false;
    });

    // Se logado, atualizar dados da API
    if (driver != null && driver!.isLoggedIn) {
      await _refreshFromApi();
    }
  }

  Future<void> _refreshFromApi() async {
    await _api.loadTokens();

    if (!_api.isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ts_driver');
      await prefs.remove('ts_driver_transactions');
      await prefs.setBool('ts_driver_online', false);

      if (mounted) {
        setState(() {
          driver = null;
          transactions = [];
          isOnline = false;
        });
      }
      return;
    }

    // Buscar perfil atualizado
    final profileResult = await _api.getProfile();
    if (profileResult.isSuccess && profileResult.data != null) {
      setState(() => driver = profileResult.data!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ts_driver', json.encode(driver!.toJson()));
    }

    // Buscar transações
    final txResult = await _api.getTransactionHistory();
    if (txResult.isSuccess && txResult.data != null) {
      setState(() => transactions = txResult.data!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ts_driver_transactions',
          json.encode(transactions.map((t) => t.toJson()).toList()));
    }

    // Registar/actualizar token FCM (cobre sessões restauradas do cache)
    final fcmToken = await NotificationService().getToken();
    if (fcmToken != null) {
      await _api.updateFcmToken(fcmToken);
    }
  }

  Future<void> _handleAuth(
    String name,
    String phone,
    String pin, {
    String? accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await SecureStorageService().savePin(pin);

    if (accessToken != null && accessToken.trim().isNotEmpty) {
      _api.setTokens(accessToken, refreshToken);
    }

    setState(() {
      driver = DriverUser(
        id: const Uuid().v4(),
        fullName: name,
        phoneNumber: phone,
        balance: 0,
        isLoggedIn: true,
        role: 'DRIVER',
        rating: 5.0,
        totalTrips: 0,
        licensePlate: '',
        vehicleModel: '',
        isVerified: false,
        isOnline: false,
      );
    });

    await prefs.setString('ts_driver', json.encode(driver!.toJson()));
    await prefs.setBool('ts_driver_onboarding', true);

    await _refreshFromApi();

    final fcmToken = await NotificationService().getToken();
    if (fcmToken != null) {
      await _api.updateFcmToken(fcmToken);
    }
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ts_driver');
    await prefs.remove('ts_driver_transactions');
    await prefs.setBool('ts_driver_online', false);
    await SecureStorageService().deletePin();

    setState(() {
      driver = null;
      transactions = [];
      isOnline = false;
    });
  }

  Future<void> _updateProfileName(String newName) async {
    if (driver == null) return;

    final updatedDriver = driver!.copyWith(fullName: newName);
    setState(() => driver = updatedDriver);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ts_driver', json.encode(updatedDriver.toJson()));
  }

  void _toggleOnlineStatus() async {
    if (!isOnline) {
      // Ao ativar: pedir veículo ativo primeiro
      final selectedId = await _showVehicleSelectionModal();
      if (selectedId == null) return; // cancelou
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ts_active_vehicle_id', selectedId);
      await prefs.setBool('ts_driver_online', true);
      setState(() {
        isOnline = true;
        activeVehicleId = selectedId;
      });
      await _api.updateDriverStatus(isOnline: true);
    } else {
      // Ao desativar: limpar veículo ativo
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ts_active_vehicle_id');
      await prefs.setBool('ts_driver_online', false);
      setState(() {
        isOnline = false;
        activeVehicleId = null;
      });
      await _api.updateDriverStatus(isOnline: false);
    }
  }

  Future<String?> _showVehicleSelectionModal() async {
    await _api.loadTokens();
    final result = await _api.getVehicles();
    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VehicleSelectionModal(
        vehicles: result.isSuccess ? (result.data ?? []) : [],
        error: result.error,
      ),
    );
  }

  void _showWithdrawalModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawalModal(
        availableBalance: driver?.balance ?? 0,
        onSuccess: () async {
          Navigator.pop(context);
          _showSuccessModal(
              'Saque solicitado!', 'Sua solicitaÃ§Ã£o foi enviada.');
          await _refreshFromApi();
        },
      ),
    );
  }

  void _showSuccessModal(String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SuccessModal(
        title: title,
        subtitle: message,
        primaryButtonLabel: 'OK',
        onPrimaryPressed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () => setState(() => _showSplash = false),
      );
    }

    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Tela de bloqueio com biometria + PIN
    if (_isLocked && driver != null && driver!.isLoggedIn) {
      return ReauthScreen(
        phoneNumber: driver!.phone,
        onUnlock: _unlockWithPin,
        onBiometricUnlock: _tryBiometricUnlock,
      );
    }

    // Onboarding (se necessÃ¡rio)
    if (!hasSeenOnboarding) {
      return OnboardingScreen(
        onComplete: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('ts_driver_onboarding', true);
          setState(() => hasSeenOnboarding = true);
        },
      );
    }

    // Tela de autenticaÃ§Ã£o
    if (driver == null || !driver!.isLoggedIn) {
      return AuthScreen(onAuth: _handleAuth);
    }

    // App principal
    return _MainNavigation(
      driver: driver!,
      transactions: transactions,
      isOnline: isOnline,
      activeVehicleId: activeVehicleId,
      onToggleOnline: _toggleOnlineStatus,
      onOpenWithdrawal: _showWithdrawalModal,
      onLogout: _handleLogout,
      onRefresh: _refreshFromApi,
      onUpdateProfile: _updateProfileName,
    );
  }
}

// ========== Tela de ReautenticaÃ§Ã£o (Biometria + PIN) ==========
class ReauthScreen extends StatefulWidget {
  final String phoneNumber;
  final Future<bool> Function(String pin) onUnlock;
  final Future<bool> Function() onBiometricUnlock;

  const ReauthScreen({
    super.key,
    required this.phoneNumber,
    required this.onUnlock,
    required this.onBiometricUnlock,
  });

  @override
  State<ReauthScreen> createState() => _ReauthScreenState();
}

class _ReauthScreenState extends State<ReauthScreen> {
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _biometricsAvailable = false;
  String? _errorMessage;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _biometricsAvailable = canCheck && isSupported;
        });
      }

      // Tentar biometria automaticamente se disponÃ­vel
      if (_biometricsAvailable) {
        _tryBiometric();
      }
    } catch (e) {
      debugPrint('Erro ao verificar biometria: $e');
    }
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _errorMessage = null;
    });

    final success = await widget.onBiometricUnlock();

    if (mounted && !success) {
      setState(() {
        _errorMessage = 'Biometria nÃ£o reconhecida. Use o PIN.';
      });
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinControllers.map((c) => c.text).join();

    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'Digite todos os 6 dÃ­gitos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await widget.onUnlock(pin);

    if (mounted && !success) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'PIN incorreto';
        for (var controller in _pinControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;
    final visible = phone.substring(phone.length - 4);
    return '****$visible';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = AppColors.adaptiveAccent(context);
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final textSecondaryColor =
        isDark ? Colors.white70 : AppColors.textSecondary;
    final inputFillColor =
        isDark ? const Color(0xFF2A2A2A) : AppColors.lightCard;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : AppColors.lightBackground,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.scaledWidth(24),
                  vertical: responsive.scaledHeight(18),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - responsive.scaledHeight(36),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: responsive.scaledWidth(104),
                            height: responsive.scaledWidth(104),
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: responsive.scaledHeight(18)),
                          Text(
                            'Voltar ao app',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(26),
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: responsive.scaledHeight(8)),
                          Text(
                            'Confirme seu PIN ou use biometria para continuar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(14),
                              color: textSecondaryColor,
                            ),
                          ),
                          SizedBox(height: responsive.scaledHeight(10)),
                          Text(
                            _maskPhoneNumber(widget.phoneNumber),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(14),
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: responsive.scaledHeight(16)),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: responsive.scaledWidth(72),
                              height: 3,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          SizedBox(height: responsive.scaledHeight(28)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (index) {
                              return Expanded(
                                child: Container(
                                  height: 55,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: TextField(
                                    controller: _pinControllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    obscureText: _obscurePin,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: inputFillColor,
                                      contentPadding: EdgeInsets.zero,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: accentColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 5) {
                                        _focusNodes[index + 1].requestFocus();
                                      } else if (value.isEmpty && index > 0) {
                                        _focusNodes[index - 1].requestFocus();
                                      }

                                      final pin = _pinControllers
                                          .map((c) => c.text)
                                          .join();
                                      if (pin.length == 6) {
                                        _verifyPin();
                                      }
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _obscurePin = !_obscurePin),
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 16,
                              color: accentColor.withValues(alpha: 0.8),
                            ),
                            label: Text(
                              _obscurePin ? 'Ver PIN' : 'Ocultar PIN',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(12),
                                color: accentColor.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: responsive.scaledHeight(16)),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF3A1F2A)
                                    : const Color(0xFFFFF2F4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFC3CD),
                                ),
                              ),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFFFD5DD)
                                      : const Color(0xFFB23A4E),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          if (_isLoading)
                            Center(
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(
                                  color: accentColor,
                                  strokeWidth: 4,
                                ),
                              ),
                            )
                          else ...[
                            if (_biometricsAvailable) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: _tryBiometric,
                                  icon: const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 24,
                                  ),
                                  label: const Text(
                                    'Usar biometria',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _verifyPin,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? Colors.white
                                      : AppColors.textDark,
                                  side: BorderSide(
                                    color: accentColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'Verificar PIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MainNavigation extends StatefulWidget {
  final DriverUser driver;
  final List<Transaction> transactions;
  final bool isOnline;
  final String? activeVehicleId;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenWithdrawal;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh;
  final Function(String name)? onUpdateProfile;

  const _MainNavigation({
    required this.driver,
    required this.transactions,
    required this.isOnline,
    required this.activeVehicleId,
    required this.onToggleOnline,
    required this.onOpenWithdrawal,
    required this.onLogout,
    required this.onRefresh,
    this.onUpdateProfile,
  });

  @override
  State<_MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<_MainNavigation> {
  int _currentIndex = 0;

  void _showProfileModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, _) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: _MenuModal(
            driver: widget.driver,
            onLogout: widget.onLogout,
            onUpdateProfile: widget.onUpdateProfile,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            driver: widget.driver,
            isOnline: widget.isOnline,
            activeVehicleId: widget.activeVehicleId,
            onToggleOnline: widget.onToggleOnline,
            onOpenWithdrawal: widget.onOpenWithdrawal,
            onLogout: widget.onLogout,
            onOpenProfile: _showProfileModal,
            showBottomDock: false,
          ),
          EarningsScreen(
            driver: widget.driver,
            showBottomDock: false,
          ),
          const TripsScreen(showBottomDock: false),
          WalletScreen(
            onOpenWithdrawal: widget.onOpenWithdrawal,
            showBottomDock: false,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        selectedItemColor:
            isDark ? AppColors.primaryGold : AppColors.primaryOrange,
        unselectedItemColor: isDark
            ? Colors.white.withValues(alpha: 0.55)
            : AppColors.textDark.withValues(alpha: 0.60),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        elevation: isDark ? 10 : 6,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Ganhos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_taxi_rounded),
            label: 'Viagens',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Carteira',
          ),
        ],
      ),
    );
  }
}

// ─── Menu Modal fullscreen (motorista) ───────────────────────────────────────
class _MenuModal extends StatefulWidget {
  final DriverUser driver;
  final VoidCallback? onLogout;
  final Function(String name)? onUpdateProfile;

  const _MenuModal({
    required this.driver,
    this.onLogout,
    this.onUpdateProfile,
  });

  @override
  State<_MenuModal> createState() => _MenuModalState();
}

class _MenuModalState extends State<_MenuModal> {
  void _openSubModal(Widget modal) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, animation, _) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: modal,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driver = widget.driver;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      border:
                          Border.all(color: AppColors.primaryGold, width: 1.5),
                    ),
                    child: driver.photo != null && driver.photo!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              driver.photo!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person_rounded,
                                size: 22,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : AppColors.textDark
                                        .withValues(alpha: 0.65),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            size: 22,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.75)
                                : AppColors.textDark.withValues(alpha: 0.65),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.fullName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          driver.phoneNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.textDark.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 8),
            _navTile(
              isDark,
              Icons.person_outline_rounded,
              'Perfil',
              'Dados pessoais e veículos',
              () => _openSubModal(_ProfileModal(
                driver: widget.driver,
                onUpdateProfile: widget.onUpdateProfile,
              )),
            ),
            _navTile(
              isDark,
              Icons.shield_outlined,
              'Segurança',
              'PIN, biometria e privacidade',
              () => _openSubModal(const _SecurityModal()),
            ),
            _navTile(
              isDark,
              Icons.notifications_outlined,
              'Notificações',
              'Alertas e mensagens',
              () => _openSubModal(const _NotificationsModal()),
            ),
            _navTile(
              isDark,
              Icons.settings_outlined,
              'Configurações',
              'Tema, notificações e informações',
              () => _openSubModal(const _SettingsModal()),
            ),
            const Spacer(),
            // Botão de pânico
            _PanicButton(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onLogout?.call();
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.22), width: 1.0),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Sair',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(bool isDark, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-modal header helper ──────────────────────────────────────────────────
Widget _subModalHeader(
    BuildContext context, String title, bool isDark, VoidCallback onClose) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textDark,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textDark.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
      ),
      Container(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.06),
      ),
    ],
  );
}

// ─── Profile Modal ────────────────────────────────────────────────────────────
class _ProfileModal extends StatelessWidget {
  final DriverUser driver;
  final Function(String name)? onUpdateProfile;

  const _ProfileModal({required this.driver, this.onUpdateProfile});

  void _showDocumentsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Documentos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'O upload de documentos requer a câmara ou galeria do dispositivo. Esta funcionalidade estará disponível em breve.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            _docUploadRow(isDark, Icons.credit_card_outlined, 'Licença de Condução'),
            const SizedBox(height: 12),
            _docUploadRow(isDark, Icons.badge_outlined, 'Bilhete de Identidade'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _docUploadRow(bool isDark, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
          Icon(
            Icons.cloud_upload_outlined,
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.3),
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, bool isDark) {
    final nameCtrl = TextEditingController(text: driver.fullName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Editar Perfil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon:
                      const Icon(Icons.person_outline, color: AppColors.primaryGold),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primaryGold, width: 1.5),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      onUpdateProfile?.call(name);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOf(ctx),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(
                context, 'Perfil', isDark, () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                border: Border.all(color: AppColors.primaryGold, width: 1.5),
              ),
              child: driver.photo != null && driver.photo!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        driver.photo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppColors.textDark.withValues(alpha: 0.65),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textDark.withValues(alpha: 0.65),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              driver.fullName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              driver.phoneNumber,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 28),
            _tile(isDark, Icons.edit_outlined, 'Editar perfil',
                'Nome e informações pessoais',
                () => _showEditSheet(context, isDark)),
            _tile(
              isDark,
              Icons.directions_car_outlined,
              'Meus Veículos',
              'Gerir veículos registados',
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VehiclesScreen()),
                );
              },
            ),
            _tile(isDark, Icons.account_balance_outlined, 'Dados Bancários',
                'Conta para levantamentos', () {}),
            _tile(
              isDark,
              Icons.file_upload_outlined,
              'Documentos',
              'Licença e bilhete de identidade',
              () => _showDocumentsSheet(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(bool isDark, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Security Modal ───────────────────────────────────────────────────────────
class _SecurityModal extends StatefulWidget {
  const _SecurityModal();

  @override
  State<_SecurityModal> createState() => _SecurityModalState();
}

class _SecurityModalState extends State<_SecurityModal> {
  bool _bio = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _api.loadTokens();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _bio = prefs.getBool('ts_bio_enabled') ?? false);
  }

  Future<void> _toggleBio(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    if (enable) {
      try {
        final auth = LocalAuthentication();
        final isSupported = await auth.isDeviceSupported();
        final canCheck = await auth.canCheckBiometrics;
        if (!isSupported || !canCheck) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometria indisponível neste dispositivo')),
            );
          }
          return;
        }
        final ok = await auth.authenticate(
          localizedReason: 'Confirme para ativar a biometria',
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
            stickyAuth: true,
          ),
        );
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cancelado')),
            );
          }
          return;
        }
        await prefs.setBool('ts_bio_enabled', true);
        if (mounted) setState(() => _bio = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometria ativada')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometria indisponível')),
          );
        }
      }
    } else {
      await prefs.setBool('ts_bio_enabled', false);
      if (mounted) setState(() => _bio = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometria desativada')),
        );
      }
    }
  }

  Future<void> _changePin() async {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final cfmCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool busy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Alterar PIN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Novo PIN de 6 dígitos numéricos',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 20),
                _pinField('PIN actual', curCtrl, isDark),
                const SizedBox(height: 12),
                _pinField('Novo PIN', newCtrl, isDark),
                const SizedBox(height: 12),
                _pinField('Confirmar PIN', cfmCtrl, isDark),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final cur = curCtrl.text.trim();
                            final nw = newCtrl.text.trim();
                            final cf = cfmCtrl.text.trim();
                            if (!RegExp(r'^\d{6}$').hasMatch(nw)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('PIN deve ter 6 dígitos')),
                              );
                              return;
                            }
                            if (nw != cf) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('PINs não coincidem')),
                              );
                              return;
                            }
                            setSheet(() => busy = true);
                            final sec = SecureStorageService();
                            final savedPin = await sec.readPin();
                            if (savedPin != cur) {
                              setSheet(() => busy = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('PIN actual incorreto')),
                                );
                              }
                              return;
                            }
                            final apiResult = await _api.changePin(
                              currentPin: cur,
                              newPin: nw,
                            );
                            if (!apiResult.isSuccess) {
                              debugPrint('changePin API: ${apiResult.error}');
                            }
                            await sec.savePin(nw);
                            setSheet(() => busy = false);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('PIN alterado')),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOf(context),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: busy
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white))
                        : const Text(
                            'Alterar PIN',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinField(String label, TextEditingController ctrl, bool isDark) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon:
            const Icon(Icons.lock_outline, color: AppColors.primaryGold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(context, 'Segurança', isDark,
                () => Navigator.pop(context)),
            const SizedBox(height: 8),
            _toggleTile(
              isDark,
              Icons.fingerprint_rounded,
              'Biometria',
              'Desbloquear com impressão digital ou Face ID',
              _bio,
              _toggleBio,
            ),
            _actionTile(
              isDark,
              Icons.key_outlined,
              'Alterar PIN',
              'Mudar o PIN de acesso à conta',
              _changePin,
            ),
            _actionTile(
              isDark,
              Icons.contact_phone_outlined,
              'Contactos de Emergência',
              'Gerir contactos para situações de perigo',
              () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: '',
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  transitionDuration: const Duration(milliseconds: 260),
                  pageBuilder: (ctx, animation, _) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 1), end: Offset.zero)
                        .animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOutCubic)),
                    child: const _EmergencyContactsModal(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile(bool isDark, IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryGold,
            activeTrackColor: AppColors.primaryGold.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(bool isDark, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Panic Button ─────────────────────────────────────────────────────────────
class _PanicButton extends StatefulWidget {
  @override
  State<_PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<_PanicButton> {
  bool _sending = false;
  bool _active = false;
  Timer? _timer;
  DateTime? _startTime;
  final ApiService _api = ApiService();

  static const _interval = Duration(seconds: 30);
  static const _maxDuration = Duration(hours: 5);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<(double, double)> _getLocation() async {
    try {
      bool ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) return (0.0, 0.0);
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.whileInUse || p == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
        return (pos.latitude, pos.longitude);
      }
    } catch (_) {}
    return (0.0, 0.0);
  }

  Future<void> _startPanic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Botão de Pânico'),
        content: const Text('Vai enviar a sua localização em tempo real para as autoridades e contactos de emergência.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (mounted) setState(() => _sending = true);
    await _api.loadTokens();
    final (lat, lng) = await _getLocation();
    final result = await _api.triggerPanic(latitude: lat, longitude: lng);
    if (!mounted) return;

    setState(() { _sending = false; _active = result.isSuccess; });
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Erro ao activar emergência'),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    _startTime = DateTime.now();
    _timer = Timer.periodic(_interval, (_) async {
      if (!mounted) { _timer?.cancel(); return; }
      if (DateTime.now().difference(_startTime!) >= _maxDuration) { _stopPanic(); return; }
      final (la, lo) = await _getLocation();
      await _api.triggerPanic(latitude: la, longitude: lo);
    });
  }

  void _stopPanic() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() { _active = false; _startTime = null; });
  }

  Future<void> _confirmStop() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar emergência?'),
        content: const Text('A sua localização deixará de ser partilhada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (stop == true) _stopPanic();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _sending ? null : (_active ? _confirmStop : _startPanic),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _active ? Colors.red.shade700 : Colors.red,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_sending)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else
                Icon(_active ? Icons.location_on_rounded : Icons.crisis_alert_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                _sending ? 'A activar...' : (_active ? 'EMERGÊNCIA ACTIVA — Encerrar' : 'Botão de Pânico'),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Emergency Contacts Modal ─────────────────────────────────────────────────
class _EmergencyContactsModal extends StatefulWidget {
  const _EmergencyContactsModal();

  @override
  State<_EmergencyContactsModal> createState() =>
      _EmergencyContactsModalState();
}

class _EmergencyContactsModalState extends State<_EmergencyContactsModal> {
  final ApiService _api = ApiService();
  List<EmergencyContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _api.loadTokens();
    final result = await _api.getEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = result.data ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    if (_contacts.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo de 3 contactos de emergência')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Adicionar Contacto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              _field('Nome', nameCtrl, isDark, Icons.person_outline),
              const SizedBox(height: 12),
              _field('Telefone', phoneCtrl, isDark, Icons.phone_outlined,
                  type: TextInputType.phone),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    if (name.isEmpty || phone.isEmpty) return;
                    Navigator.pop(ctx);
                    final result = await _api.addEmergencyContact(
                      name: name,
                      phoneNumber: phone,
                    );
                    if (result.isSuccess && result.data != null) {
                      if (mounted) {
                        setState(() => _contacts.add(result.data!));
                      }
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            result.error ?? 'Erro ao adicionar contacto'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOf(context),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Adicionar',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, bool isDark,
      IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(icon, color: AppColors.primaryGold),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.primaryGold, width: 1.5),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
      ),
    );
  }

  Future<void> _remove(EmergencyContact contact) async {
    final result = await _api.deleteEmergencyContact(contact.id);
    if (result.isSuccess) {
      if (mounted) {
        setState(
            () => _contacts.removeWhere((c) => c.id == contact.id));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Erro ao remover contacto'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(context, 'Contactos de Emergência', isDark,
                () => Navigator.pop(context)),
            const SizedBox(height: 8),
            if (_loading)
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryGold)))
            else
              Expanded(
                child: Column(
                  children: [
                    if (_contacts.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.contact_phone_outlined,
                                size: 48,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum contacto adicionado',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : Colors.black.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _contacts.length,
                          itemBuilder: (_, i) {
                            final c = _contacts[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryGold
                                          .withValues(alpha: 0.15),
                                    ),
                                    child: const Icon(Icons.person,
                                        color: AppColors.primaryGold,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c.phoneNumber,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.5)
                                                : Colors.black
                                                    .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _remove(c),
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red.withValues(alpha: 0.7),
                                        size: 20),
                                    tooltip: 'Remover',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (_contacts.length < 3)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _add,
                            icon: const Icon(Icons.add),
                            label: Text(
                                'Adicionar contacto (${_contacts.length}/3)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentOf(context),
                              foregroundColor: isDark
                                  ? Colors.black
                                  : Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Notifications Modal ──────────────────────────────────────────────────────
class _NotificationsModal extends StatefulWidget {
  const _NotificationsModal();

  @override
  State<_NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends State<_NotificationsModal> {
  final ApiService _api = ApiService();
  List<AppNotification> _notifications = [];
  int _unread = 0;
  bool _loading = true;
  String? _error;

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.payments_outlined;
      case 'topup':
      case 'deposit':
        return Icons.account_balance_wallet_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    await _api.loadTokens();
    final result = await _api.getNotifications();
    if (mounted) {
      setState(() {
        if (result.isSuccess) {
          _notifications = result.data?.notifications ?? [];
          _unread = result.data?.unreadCount ?? 0;
        } else {
          _error = result.error ?? 'Erro ao carregar notificações';
        }
        _loading = false;
      });
    }
  }

  Future<void> _markAll() async {
    await _api.markAllNotificationsRead();
    if (mounted) {
      setState(() {
        _notifications = _notifications
            .map((n) => AppNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  type: n.type,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
        _unread = 0;
      });
    }
  }

  Future<void> _markOne(AppNotification n) async {
    if (n.isRead) return;
    await _api.markNotificationRead(n.id);
    if (mounted) {
      setState(() {
        final idx = _notifications.indexWhere((x) => x.id == n.id);
        if (idx >= 0) {
          _notifications[idx] = AppNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
          if (_unread > 0) _unread--;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(context, 'Notificações', isDark,
                () => Navigator.pop(context)),
            if (_unread > 0)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _markAll,
                    child: Text(
                      'Marcar todas como lidas ($_unread)',
                      style: const TextStyle(color: AppColors.primaryGold),
                    ),
                  ),
                ),
              ),
            if (_loading)
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryGold)))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 40,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.45)
                                : Colors.black.withValues(alpha: 0.4),
                          )),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _load,
                        child: Text(
                          'Tentar novamente',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.primaryGold
                                : AppColors.primaryOrange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_notifications.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        size: 48,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma notificação',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: isDark ? AppColors.primaryGold : AppColors.primaryOrange,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final accent = isDark
                          ? AppColors.primaryGold
                          : AppColors.primaryOrange;
                      return GestureDetector(
                        onTap: n.isRead ? null : () => _markOne(n),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: n.isRead
                                ? (isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.02))
                                : accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: n.isRead
                                  ? (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05))
                                  : accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : Colors.black.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.4),
                                    width: 1.0,
                                  ),
                                ),
                                child: Icon(
                                  _iconForType(n.type),
                                  color: accent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: n.isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.textDark,
                                            ),
                                          ),
                                        ),
                                        if (!n.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin:
                                                const EdgeInsets.only(top: 2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (n.body.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        n.body,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.5)
                                              : Colors.black
                                                  .withValues(alpha: 0.45),
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (n.createdAt != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm', 'pt_AO')
                                            .format(n.createdAt!),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.35)
                                              : Colors.black
                                                  .withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Settings Modal ───────────────────────────────────────────────────────────
class _SettingsModal extends StatefulWidget {
  const _SettingsModal();

  @override
  State<_SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<_SettingsModal> {
  bool _darkMode = false;
  bool _notifications = true;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
          () => _darkMode = prefs.getString('ts_theme_mode') == 'dark');
    }
  }

  void _openFullscreen(Widget page) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, animation, _) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(context, 'Configurações', isDark,
                () => Navigator.pop(context)),
            const SizedBox(height: 8),
            _toggleTile(
              isDark,
              Icons.dark_mode_outlined,
              'Tema escuro',
              'Alternar entre modo claro e escuro',
              _darkMode,
              (v) async {
                await ThemeController.instance.setDark(v);
                if (mounted) setState(() => _darkMode = v);
              },
            ),
            _toggleTile(
              isDark,
              Icons.notifications_outlined,
              'Notificações',
              'Receber alertas e novidades',
              _notifications,
              (v) => setState(() => _notifications = v),
            ),
            Container(
              height: 1,
              margin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            _actionTile(
              isDark,
              Icons.info_outline_rounded,
              'Sobre',
              'Versão e informações do aplicativo',
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AboutScreen()),
                );
              },
            ),
            _actionTile(
              isDark,
              Icons.description_outlined,
              'Termos e Condições',
              'Política de uso e privacidade',
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TermsAndConditionsScreen()),
                );
              },
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            _deleteAccountTile(isDark),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ler saldo em cache para decidir se é necessário pedir IBAN
    int balance = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ts_driver');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        balance = map['balance'] as int? ?? 0;
      }
    } catch (_) {}

    final ibanCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialog) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          title: Text(
            'Encerrar Conta',
            style: TextStyle(color: isDark ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A sua conta entrará num período de carência de 30 dias. Se voltar a iniciar sessão nesse período, a conta será reactivada automaticamente.',
                style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6)),
              ),
              if (balance > 0) ...[
                const SizedBox(height: 14),
                Text(
                  'Tem $balance Kz na carteira. Indique um IBAN angolano para receber a transferência após os 30 dias.',
                  style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6), fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ibanCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'AO06.0040.0000.XXXX.XXXX.X',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                if (balance > 0 && ibanCtrl.text.trim().isEmpty) return;
                Navigator.pop(dCtx, true);
              },
              child: const Text('ENCERRAR'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final iban = balance > 0 ? ibanCtrl.text.trim() : null;
    await _api.loadTokens();
    final result = await _api.deleteAccount(iban: iban);
    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Erro ao encerrar conta'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _deleteAccountTile(bool isDark) {
    return InkWell(
      onTap: _confirmDeleteAccount,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.delete_forever_outlined,
                size: 20, color: Colors.red),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Eliminar Conta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    'Período de carência de 30 dias — pode reactivar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile(bool isDark, IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryGold,
            activeTrackColor: AppColors.primaryGold.withValues(alpha: 0.3),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(bool isDark, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== Modal de Seleção de Veículo Ativo ==========

class _VehicleSelectionModal extends StatelessWidget {
  final List<Vehicle> vehicles;
  final String? error;

  const _VehicleSelectionModal({required this.vehicles, this.error});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final subtleText = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.4);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: AppColors.primaryGold, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selecionar Veículo',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primaryText)),
                  Text('Qual veículo vais usar nesta sessão?',
                      style: TextStyle(fontSize: 13, color: subtleText)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Erro ao carregar veículos. Verifica a ligação.',
                style: TextStyle(color: Colors.red.shade400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else if (vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 48,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text('Sem veículos registados',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primaryText)),
                  const SizedBox(height: 4),
                  Text('Adiciona um veículo no separador Veículos.',
                      style: TextStyle(fontSize: 13, color: subtleText)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vehicles.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final v = vehicles[i];
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, v.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_car_rounded,
                                color: AppColors.primaryGold, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v.model,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: primaryText)),
                                const SizedBox(height: 2),
                                Text('${v.licensePlate}  •  ${v.color}',
                                    style: TextStyle(
                                        fontSize: 12, color: subtleText)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: subtleText, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (vehicles.isNotEmpty) const SizedBox(height: 8),
        ],
      ),
    );
  }
}
