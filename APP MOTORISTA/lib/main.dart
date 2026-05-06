import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_motorista/utils/theme.dart';
import 'package:troco_seguro_motorista/services/theme_controller.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/models/driver_user.dart';
import 'package:troco_seguro_motorista/models/transaction.dart';
import 'package:troco_seguro_motorista/screens/onboarding_screen.dart';
import 'package:troco_seguro_motorista/screens/auth_screen.dart';
import 'package:troco_seguro_motorista/screens/home_screen.dart';
import 'package:troco_seguro_motorista/screens/earnings_screen.dart';
import 'package:troco_seguro_motorista/screens/trips_screen.dart';
import 'package:troco_seguro_motorista/screens/wallet_screen.dart';
import 'package:troco_seguro_motorista/screens/vehicles_screen.dart';
import 'package:troco_seguro_motorista/screens/about_screen.dart';
import 'package:troco_seguro_motorista/screens/terms_and_conditions_screen.dart';
import 'package:troco_seguro_motorista/widgets/withdrawal_modal.dart';
import 'package:troco_seguro_motorista/widgets/success_modal.dart';
import 'package:troco_seguro_motorista/widgets/driver_bottom_dock.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:troco_seguro_motorista/services/secure_storage_service.dart';
import 'package:troco_seguro_motorista/security/pin_guard.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize locale data for date formatting (pt_AO) before runApp
  await initializeDateFormatting('pt_AO', null);
  Intl.defaultLocale = 'pt_AO';
  // Load saved theme preference
  await ThemeController.instance.load();

  final initialDark =
      ThemeController.instance.themeMode.value == ThemeMode.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: initialDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: initialDark ? Brightness.dark : Brightness.light,
  ));
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
  bool hasSeenOnboarding = true; // Onboarding desativado por padrÃ£o
  DriverUser? driver;
  List<Transaction> transactions = [];
  bool isLoading = true;
  bool _isLocked = false;
  bool isOnline = false; // Status do motorista (online/offline)
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

    setState(() {
      hasSeenOnboarding = hasOnboarding;
      isOnline = onlineStatus;
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

    // Buscar transaÃ§Ãµes
    final txResult = await _api.getTransactionHistory();
    if (txResult.isSuccess && txResult.data != null) {
      setState(() => transactions = txResult.data!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ts_driver_transactions',
          json.encode(transactions.map((t) => t.toJson()).toList()));
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

  void _toggleOnlineStatus() async {
    final newStatus = !isOnline;
    setState(() => isOnline = newStatus);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ts_driver_online', newStatus);

    // Atualizar status no servidor
    await _api.updateDriverStatus(isOnline: newStatus);
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
      onToggleOnline: _toggleOnlineStatus,
      onOpenWithdrawal: _showWithdrawalModal,
      onLogout: _handleLogout,
      onRefresh: _refreshFromApi,
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
                                    obscureText: true,
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
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenWithdrawal;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh;

  const _MainNavigation({
    required this.driver,
    required this.transactions,
    required this.isOnline,
    required this.onToggleOnline,
    required this.onOpenWithdrawal,
    required this.onLogout,
    required this.onRefresh,
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
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: _MenuDrawer(
              driver: widget.driver,
              onLogout: widget.onLogout,
            ),
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
        backgroundColor: theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.65),
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

/// Menu Drawer para motorista com funcionalidades de perfil
class _MenuDrawer extends StatefulWidget {
  final DriverUser driver;
  final VoidCallback? onLogout;

  const _MenuDrawer({
    required this.driver,
    this.onLogout,
  });

  @override
  State<_MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<_MenuDrawer> {
  bool notificationsEnabled = true;
  bool biometricsEnabled = false;
  bool darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bioPref = prefs.getBool('ts_bio_enabled') ?? false;
    final themePref = prefs.getString('ts_theme_mode');

    if (mounted) {
      setState(() {
        biometricsEnabled = bioPref;
        darkModeEnabled = themePref == 'dark';
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.adaptiveAccent(context),
      ),
    );
  }

  void _showEditProfileSheet(ResponsiveHelper responsive) {
    final nameCtrl = TextEditingController(text: widget.driver.fullName);
    final phoneCtrl = TextEditingController(text: widget.driver.phoneNumber);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.all(responsive.scaledWidth(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(20)),
                Text(
                  'Editar Perfil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(24)),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'NÃºmero de Telefone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(24)),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty ||
                        phoneCtrl.text.trim().isEmpty) {
                      _showSnack(
                          'Por favor, preencha todos os campos corretamente');
                    } else {
                      Navigator.pop(context);
                      _showSnack('Perfil atualizado com sucesso!');
                    }
                  },
                  child: const Text('Salvar AlteraÃ§Ãµes'),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordModal(ResponsiveHelper responsive) {
    Navigator.pop(context); // Fechar o drawer
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.all(responsive.scaledWidth(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(20)),
                Text(
                  'Alterar PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(24)),
                TextField(
                  controller: currentPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'PIN Atual',
                    prefixIcon: Icon(Icons.lock_outline),
                    counterText: '',
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
                TextField(
                  controller: newPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Novo PIN (6 dÃ­gitos)',
                    prefixIcon: Icon(Icons.lock_reset),
                    counterText: '',
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(24)),
                ElevatedButton(
                  onPressed: () async {
                    if (currentPinCtrl.text.length != 6 ||
                        newPinCtrl.text.length != 6) {
                      _showSnack('O PIN deve conter exatamente 6 dÃ­gitos.');
                      return;
                    }
                    final sec = SecureStorageService();
                    final savedPin = await sec.readPin();
                    if (savedPin != currentPinCtrl.text) {
                      _showSnack('O PIN atual estÃ¡ incorreto.');
                      return;
                    }

                    await sec.savePin(newPinCtrl.text);
                    Navigator.pop(context);
                    _showSnack('PIN alterado com sucesso!');
                  },
                  child: const Text('Confirmar AlteraÃ§Ã£o'),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : AppColors.lightCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header com botÃ£o de fechar
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                    iconSize: 28,
                  ),
                ),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDark
                    ? Colors.white.withAlpha((0.15 * 255).round())
                    : theme.colorScheme.onSurface
                        .withAlpha((0.12 * 255).round()),
              ),
              // InformaÃ§Ãµes do motorista
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                      child: widget.driver.photo != null &&
                              widget.driver.photo!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.driver.photo!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person_rounded,
                                    color: theme.colorScheme.primary,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: theme.colorScheme.primary,
                              size: 26,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.driver.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textLight
                                  : AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.driver.phoneNumber,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDark
                    ? Colors.white.withAlpha((0.15 * 255).round())
                    : theme.colorScheme.onSurface
                        .withAlpha((0.12 * 255).round()),
              ),
              // Menu scrollÃ¡vel
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // InformaÃ§Ãµes da Conta
                    _buildSectionTitle('Conta', isDark),
                    _buildMenuOption(
                      'Editar Perfil',
                      Icons.person_outline,
                      isDark,
                      onTap: () => _showEditProfileSheet(responsive),
                    ),
                    _buildMenuOption(
                      'Meus Veículos',
                      Icons.directions_car_outlined,
                      isDark,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const VehiclesScreen()));
                      },
                    ),
                    _buildMenuOption(
                      'Dados Bancários',
                      Icons.account_balance_outlined,
                      isDark,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Funcionalidade em desenvolvimento'),
                            backgroundColor: AppColors.adaptiveAccent(context),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // SeguranÃ§a
                    _buildSectionTitle('SeguranÃ§a', isDark),
                    _buildToggleOption(
                      'Biometria',
                      Icons.fingerprint,
                      biometricsEnabled,
                      isDark,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('ts_bio_enabled', value);
                        setState(() => biometricsEnabled = value);
                        _showSnack(value
                            ? 'Biometria ativada'
                            : 'Biometria desativada');
                      },
                    ),
                    _buildMenuOption(
                      'Alterar PIN',
                      Icons.key_outlined,
                      isDark,
                      onTap: () => _showChangePasswordModal(responsive),
                    ),
                    const SizedBox(height: 12),
                    // Aplicativo
                    _buildSectionTitle('Aplicativo', isDark),
                    _buildToggleOption(
                      'Tema Escuro',
                      Icons.dark_mode_outlined,
                      darkModeEnabled,
                      isDark,
                      onChanged: (value) async {
                        await ThemeController.instance.setDark(value);
                        setState(() => darkModeEnabled = value);
                      },
                    ),
                    _buildToggleOption(
                      'NotificaÃ§Ãµes',
                      Icons.notifications_outlined,
                      notificationsEnabled,
                      isDark,
                      onChanged: (value) {
                        setState(() => notificationsEnabled = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    // InformaÃ§Ãµes
                    _buildSectionTitle('InformaÃ§Ãµes', isDark),
                    _buildMenuOption(
                      'Sobre',
                      Icons.info_outline_rounded,
                      isDark,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AboutScreen()),
                        );
                      },
                    ),
                    _buildMenuOption(
                      'Termos e Condições',
                      Icons.description_outlined,
                      isDark,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const TermsAndConditionsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDark
                    ? Colors.white.withAlpha((0.15 * 255).round())
                    : theme.colorScheme.onSurface
                        .withAlpha((0.12 * 255).round()),
              ),
              // BotÃ£o de sair
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildMenuOption(
                  'Sair',
                  Icons.logout_rounded,
                  isDark,
                  isLogout: true,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onLogout?.call();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    String label,
    IconData icon,
    bool isDark, {
    VoidCallback? onTap,
    bool isLogout = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isLogout
                  ? Colors.red
                  : (isDark
                      ? AppColors.textLight.withOpacity(0.7)
                      : AppColors.textDark.withOpacity(0.7)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isLogout
                      ? Colors.red
                      : (isDark ? AppColors.textLight : AppColors.textDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(
    String label,
    IconData icon,
    bool value,
    bool isDark, {
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? AppColors.textLight.withOpacity(0.7)
                : AppColors.textDark.withOpacity(0.7),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 45,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
