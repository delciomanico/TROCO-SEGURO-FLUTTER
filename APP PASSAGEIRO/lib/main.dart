import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro/utils/theme.dart';
import 'package:troco_seguro/services/theme_controller.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/screens/onboarding_screen.dart';
import 'package:troco_seguro/screens/auth_screen.dart';
import 'package:troco_seguro/screens/home_screen.dart';
import 'package:troco_seguro/screens/wallet_screen.dart';
import 'package:troco_seguro/screens/trips_screen.dart';
import 'package:troco_seguro/screens/profile_screen.dart';
import 'package:troco_seguro/widgets/virtual_cards_fullscreen.dart';
import 'package:troco_seguro/widgets/topup_modal.dart';
import 'package:troco_seguro/widgets/transfer_modal.dart';
import 'package:troco_seguro/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro/widgets/success_modal.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';
import 'package:troco_seguro/security/pin_guard.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/services/payment_service.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/widgets/payment_confirmation_modal.dart';
import 'package:troco_seguro/services/feedback_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize locale data for date formatting (pt_AO) before runApp
  await initializeDateFormatting('pt_AO', null);
  Intl.defaultLocale = 'pt_AO';
  // Load saved theme preference
  await ThemeController.instance.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TrocoSeguroApp());
}

class TrocoSeguroApp extends StatelessWidget {
  const TrocoSeguroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return ChangeNotifierProvider(
          create: (_) => AppProvider()..initialize(),
          child: MaterialApp(
            title: 'Troco Seguro',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AppController(),
          ),
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
  bool hasSeenOnboarding = true; // Onboarding desativado
  bool isLoading = true;
  bool _isLocked = false;

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
      final provider = context.read<AppProvider>();
      if (provider.isAuthenticated) {
        setState(() => _isLocked = true);
      }
    }
    // Não tenta biometria automaticamente - deixa o usuário escolher na tela
  }

  Future<bool> _tryBiometricUnlock() async {
    final prefs = await SharedPreferences.getInstance();
    final bioEnabled = prefs.getBool('ts_bio_enabled') ?? false;

    if (bioEnabled) {
      final auth = LocalAuthentication();
      try {
        final didAuth = await auth.authenticate(
          localizedReason: 'Desbloqueie Troco Seguro',
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
    final provider = context.read<AppProvider>();

    setState(() {
      hasSeenOnboarding = prefs.getBool('ts_onboarding') ?? false;
      isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ts_onboarding', hasSeenOnboarding);
  }

  void _finishOnboarding() {
    setState(() {
      hasSeenOnboarding = true;
    });
    _saveData();
  }

  void _handleAuth(User user, String pin,
      {String? accessToken, String? refreshToken}) async {
    // Store PIN securely
    SecureStorageService().savePin(pin);

    final provider = context.read<AppProvider>();

    // Set the user AND tokens directly
    await provider.setAuthenticatedUser(user,
        accessToken: accessToken, refreshToken: refreshToken);

    _saveData();
  }

  Future<void> _handleSwitchAccount() async {
    final provider = context.read<AppProvider>();

    await provider.logout();
    await SecureStorageService().deletePin();

    if (mounted) {
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.darkBlue,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (!hasSeenOnboarding) {
      return OnboardingScreen(onFinish: _finishOnboarding);
    }

    final provider = context.watch<AppProvider>();
    final user = provider.user;

    if (user == null || !provider.isAuthenticated) {
      return AuthScreen(onAuth: _handleAuth);
    }

    // Se app está bloqueado, mostrar tela de reautenticação
    if (_isLocked) {
      return ReauthScreen(
        onUnlock: _unlockWithPin,
        onBiometricUnlock: _tryBiometricUnlock,
        onSwitchAccount: _handleSwitchAccount,
      );
    }

    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  Future<void> _handleLogout() async {
    final provider = context.read<AppProvider>();

    // Fazer logout via provider
    await provider.logout();

    // Limpar PIN seguro
    await SecureStorageService().deletePin();

    // Força rebuild do AppController
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppController()),
        (route) => false,
      );
    }
  }

  /// Acionar botão de pânico
  Future<bool> _handlePanic(double latitude, double longitude) async {
    final provider = context.read<AppProvider>();
    return await provider.triggerPanic(
      latitude: latitude,
      longitude: longitude,
    );
  }

  void _showPaymentFlow() {
    final provider = context.read<AppProvider>();
    if (provider.user == null) return;

    // Passo 1: Escanear QR Code
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => QRScannerModal(
        onQRScanned: (scannedQRData) async {
          Navigator.pop(context); // Fechar scanner

          // Passo 2: Validar QR Code
          final paymentService = PaymentService();
          final driverInfo = await paymentService.validateQrCode(
            context,
            scannedQRData,
          );

          if (!mounted) return;

          if (driverInfo != null) {
            // Passo 3: Mostrar confirmação de pagamento
            _showPaymentConfirmationFlow(driverInfo);
          }
        },
        onCancel: () {},
      ),
    );
  }

  void _showPaymentConfirmationFlow(QrValidationResult driverInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentConfirmationModal(
        driverInfo: driverInfo,
        amount: 2500, // Valor padrão da viagem
        origin: 'Aeroporto',
        destination: 'Hotel',
        pinValidator: (entered) async {
          // Validar PIN com PinGuard
          return PinGuard.validatePin(
            scope: 'global',
            enteredPin: entered,
            readExpectedPin: () => SecureStorageService().readPin(),
          );
        },
        onSuccess: () {
          final provider = context.read<AppProvider>();
          if (provider.user != null) {
            // Atualizar saldo
            final newBalance = provider.user!.balance - 2500;
            provider.updateUserBalance(newBalance);

            // Mostrar sucesso
            SuccessModal.show(
              context,
              title: 'Pagamento Realizado!',
              message:
                  'Pagamento de 2500 Kz realizado com sucesso para ${driverInfo.driverName}.',
              icon: Icons.check_circle,
            );
          }
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _showPaymentModal() {
    _showPaymentFlow();
  }

  void _showTopupModal() {
    final provider = context.read<AppProvider>();
    final user = provider.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TopupModal(
        currentBalance: user.balance,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showTransferModal() {
    final provider = context.read<AppProvider>();
    final user = provider.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferModal(
        currentBalance: user.balance,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showVirtualCardsFullscreen() {
    final provider = context.read<AppProvider>();
    final cardHolderName = provider.user?.fullName.trim().isNotEmpty == true
        ? provider.user!.fullName
        : 'Utilizador';

    showVirtualCardsFullscreen(
      context,
      cards: provider.virtualCards,
      cardHolderName: cardHolderName,
      onCreateCard: ({
        required String name,
        required int initialBalance,
        required int dailyLimit,
        required String userPin,
        required String cardPin,
      }) async {
        return provider.createVirtualCard(
          name: name,
          initialBalance: initialBalance,
          dailyLimit: dailyLimit,
          userPin: userPin,
          cardPin: cardPin,
        );
      },
      onDeleteCard: (cardId) async {
        await provider.deleteVirtualCard(cardId);
      },
      onClose: () {},
    );
  }

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
              onLogout: _handleLogout,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onOpenScanner: _showPaymentModal,
            onOpenVirtualCards: _showVirtualCardsFullscreen,
            onOpenTopup: _showTopupModal,
            onPanic: _handlePanic,
            onOpenProfile: _showProfileModal,
            onTerminateSession: _handleLogout,
          ),
          WalletScreen(
            onOpenTopup: _showTopupModal,
            onOpenTransfer: _showTransferModal,
          ),
          const TripsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BottomNavigationBar(
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
          label: 'Início',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Carteira',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.route_rounded),
          label: 'Viagens',
        ),
      ],
    );
  }
}

/// Menu Drawer com todas as funcionalidades do perfil
class _MenuDrawer extends StatefulWidget {
  final VoidCallback? onLogout;

  const _MenuDrawer({this.onLogout});

  @override
  State<_MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<_MenuDrawer> {
  bool notificationsEnabled = true;
  bool biometricsEnabled = false;
  bool darkModeEnabled = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _api.loadTokens();
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

  void _showEditProfileSheet() {
    final provider = context.read<AppProvider>();
    final user = provider.user;
    if (user == null) return;

    final nameController = TextEditingController(text: user.fullName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.25 * 255).round()),
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
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nome completo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.7 * 255).round()),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Digite seu nome',
                  prefixIcon: Icon(Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.20 * 255).round()),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.20 * 255).round()),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Theme.of(context).colorScheme.surface
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final provider = context.read<AppProvider>();
                    Navigator.pop(context);

                    final result = await _api.updateProfile(
                      fullName: nameController.text,
                    );

                    if (result.isSuccess && result.data != null) {
                      await provider.refreshUserData();
                      if (mounted) {
                        FeedbackService.showSuccess(
                          this.context,
                          message: 'Perfil atualizado com sucesso',
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Salvar Alterações',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePinSheet() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isChanging = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
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
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.25 * 255).round()),
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
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Digite seu PIN atual e crie um novo PIN de 6 dígitos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.7 * 255).round()),
                  ),
                ),
                const SizedBox(height: 24),
                _buildPinField('PIN atual', currentController, ctx, isDark),
                const SizedBox(height: 16),
                _buildPinField('Novo PIN', newController, ctx, isDark),
                const SizedBox(height: 16),
                _buildPinField(
                    'Confirmar novo PIN', confirmController, ctx, isDark),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isChanging
                        ? null
                        : () async {
                            final currentPin = currentController.text.trim();
                            final newPin = newController.text.trim();
                            final confirmPin = confirmController.text.trim();

                            if (!_isValidPin(newPin) ||
                                !_isValidPin(confirmPin)) {
                              FeedbackService.showError(
                                this.context,
                                message: 'PIN deve ter 6 dígitos numéricos',
                              );
                              return;
                            }
                            if (newPin != confirmPin) {
                              FeedbackService.showError(
                                this.context,
                                message: 'Novo PIN e confirmação não coincidem',
                              );
                              return;
                            }

                            setModalState(() => isChanging = true);

                            final result = await _api.changePassword(
                              currentPassword: currentPin,
                              newPassword: newPin,
                            );

                            setModalState(() => isChanging = false);

                            if (result.isSuccess) {
                              await SecureStorageService().savePin(newPin);
                              await PinGuard.resetFailures('global');
                              if (mounted) Navigator.pop(ctx);
                              FeedbackService.showSuccess(
                                this.context,
                                message: 'PIN alterado com sucesso',
                              );
                            } else {
                              FeedbackService.showError(
                                this.context,
                                message:
                                    'Erro: ${result.error ?? "PIN atual incorreto"}',
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.primary,
                      foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor:
                          Theme.of(ctx).colorScheme.primary.withOpacity(0.6),
                    ),
                    child: isChanging
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Alterar PIN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(
    String label,
    TextEditingController controller,
    BuildContext ctx,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx)
                .colorScheme
                .onSurface
                .withAlpha((0.7 * 255).round()),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            prefixIcon: Icon(Icons.lock_outline,
                color: Theme.of(ctx).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.20 * 255).round()),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(ctx)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.20 * 255).round()),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(ctx).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor:
                isDark ? Theme.of(ctx).colorScheme.surface : Colors.white,
          ),
        ),
      ],
    );
  }

  bool _isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  void _showAboutModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Sobre',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Troco Seguro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versão 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sua plataforma segura para gerenciar e realizar transações de forma rápida e protegida.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(ctx).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Desenvolvido com ❤️',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Para proporcionar a melhor experiência de segurança nas transações.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Fechar',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Termos e Condições',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTermSection(
                'Aceitação dos Termos',
                'Ao usar este aplicativo, você concorda com estes termos e condições. Se você não concorda, não use o aplicativo.',
                isDark,
              ),
              const SizedBox(height: 12),
              _buildTermSection(
                'Privacidade e Segurança',
                'Seus dados são protegidos com criptografia de ponta. Nunca compartilhamos suas informações com terceiros sem consentimento.',
                isDark,
              ),
              const SizedBox(height: 12),
              _buildTermSection(
                'Responsabilidades do Usuário',
                'Você é responsável por manter a confidencialidade de sua conta e PIN. O Troco Seguro não se responsabiliza por uso indevido.',
                isDark,
              ),
              const SizedBox(height: 12),
              _buildTermSection(
                'Limitações de Responsabilidade',
                'O Troco Seguro é fornecido "como está". Não garantimos disponibilidade ininterrupta do serviço.',
                isDark,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Aceitar',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermSection(String title, String content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: isDark ? AppColors.textLight : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.read<AppProvider>();
    final user = provider.user;

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
              // Header com botão de fechar
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
              // Informações do usuário
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
                      child: user?.photo != null && user!.photo!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                user.photo!,
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
                            user?.fullName ?? 'Usuário',
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
                            user?.phoneNumber ?? 'Sem telefone',
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
              // Menu scrollável
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Informações da Conta
                    _buildSectionTitle('Conta', isDark),
                    _buildMenuOption(
                      'Editar Perfil',
                      Icons.person_outline,
                      isDark,
                      onTap: _showEditProfileSheet,
                    ),
                    _buildMenuOption(
                      'Métodos de Pagamento',
                      Icons.payment_outlined,
                      isDark,
                      onTap: () {},
                    ),
                    _buildMenuOption(
                      'Endereço',
                      Icons.location_on_outlined,
                      isDark,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    // Segurança
                    _buildSectionTitle('Segurança', isDark),
                    _buildToggleOption(
                      'Biometria',
                      Icons.fingerprint,
                      biometricsEnabled,
                      isDark,
                      onChanged: (value) {
                        setState(() => biometricsEnabled = value);
                      },
                    ),
                    _buildMenuOption(
                      'Alterar PIN',
                      Icons.key_outlined,
                      isDark,
                      onTap: _showChangePinSheet,
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
                      'Notificações',
                      Icons.notifications_outlined,
                      notificationsEnabled,
                      isDark,
                      onChanged: (value) {
                        setState(() => notificationsEnabled = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Informações
                    _buildSectionTitle('Informações', isDark),
                    _buildMenuOption(
                      'Sobre',
                      Icons.info_outline_rounded,
                      isDark,
                      onTap: _showAboutModal,
                    ),
                    _buildMenuOption(
                      'Termos e Condições',
                      Icons.description_outlined,
                      isDark,
                      onTap: _showTermsModal,
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
              // Botão de sair
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

/// Tela de reautenticação quando o app é bloqueado
class ReauthScreen extends StatefulWidget {
  final Future<bool> Function(String pin) onUnlock;
  final Future<bool> Function() onBiometricUnlock;
  final Future<void> Function() onSwitchAccount;

  const ReauthScreen({
    super.key,
    required this.onUnlock,
    required this.onBiometricUnlock,
    required this.onSwitchAccount,
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
        _errorMessage = 'Biometria não reconhecida. Use o PIN.';
      });
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinControllers.map((c) => c.text).join();

    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'Digite todos os 6 dígitos';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F1115),
                    Color(0xFF1A1D24),
                    Color(0xFF2A2416),
                    Color(0xFF13151A),
                  ],
                  stops: [0.0, 0.42, 0.72, 1.0],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFFFFCF6), Colors.white],
                  stops: [0.0, 0.55, 1.0],
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isDark)
              Image.asset(
                'assets/images/card_fundo.jpg',
                fit: BoxFit.cover,
              ),
            if (isDark)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(
                  color: const Color(0xFF121212).withOpacity(0.3),
                ),
              ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Bem-vindo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) {
                                return Expanded(
                                  child: Container(
                                    height: 55,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
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
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF121212),
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: isDark
                                            ? AppColors.darkBlueSurface
                                            : Colors.grey.shade100,
                                        contentPadding: EdgeInsets.zero,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AppColors.accent,
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
                            const SizedBox(height: 16),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (_biometricsAvailable) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _tryBiometric,
                                  icon: const Icon(Icons.fingerprint, size: 28),
                                  label: const Text(
                                    'Usar Biometria',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _verifyPin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Entrar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        await widget.onSwitchAccount();
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side:
                                      const BorderSide(color: AppColors.accent),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Trocar de conta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
