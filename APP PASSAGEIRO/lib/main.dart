import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro/utils/theme.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/screens/onboarding_screen.dart';
import 'package:troco_seguro/screens/auth_screen.dart';
import 'package:troco_seguro/screens/home_screen.dart';
import 'package:troco_seguro/screens/wallet_screen.dart';
import 'package:troco_seguro/screens/trips_screen.dart';
import 'package:troco_seguro/screens/cards_screen.dart';
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
import 'package:troco_seguro/services/api_service.dart' show ApiService, EmergencyContact, QrValidationResult;
import 'package:troco_seguro/widgets/complaint_modal.dart';
import 'package:troco_seguro/widgets/payment_confirmation_modal.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/services/biometric_service.dart';
import 'package:troco_seguro/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

/// Navigator raiz da app — permite voltar ao login a partir de qualquer ecrã
/// (ex: quando o token expira num pedido em segundo plano), sem precisar de
/// um BuildContext local.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await initializeDateFormatting('pt_AO', null);
  Intl.defaultLocale = 'pt_AO';
  await dotenv.load();

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
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'Troco Seguro',
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
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
  }
}

class AppController extends StatefulWidget {
  const AppController({super.key});

  @override
  State<AppController> createState() => _AppControllerState();
}

// TODO(remover após testar o redesign): força onboarding+auth a aparecerem
// sempre no arranque, ignorando os caches 'ts_onboarding'/sessão guardada.
const bool kForceOnboardingAuthForTesting = true;

class _AppControllerState extends State<AppController>
    with WidgetsBindingObserver {
  bool hasSeenOnboarding = true; // Onboarding desativado
  bool isLoading = true;
  bool _isLocked = false;
  bool _justAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService().sessionExpiredListenable.addListener(_onSessionExpired);
    _loadData();
  }

  /// Chamado quando o interceptor da API deteta que o token expirou e a
  /// renovação falhou. O AppProvider já limpa o estado de sessão (o que faz
  /// este widget re-renderizar como AuthScreen); aqui garantimos que também
  /// fechamos quaisquer ecrãs/modais empilhados por cima para o login ficar
  /// visível de imediato.
  void _onSessionExpired() {
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
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
    ApiService().sessionExpiredListenable.removeListener(_onSessionExpired);
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      hasSeenOnboarding = kForceOnboardingAuthForTesting
          ? false
          : (prefs.getBool('ts_onboarding') ?? false);
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

    setState(() => _justAuthenticated = true);
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
      return Scaffold(
        backgroundColor: AppColors.accentOf(context),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (!hasSeenOnboarding) {
      return OnboardingScreen(onFinish: _finishOnboarding);
    }

    final provider = context.watch<AppProvider>();
    final user = provider.user;

    final needsAuth = kForceOnboardingAuthForTesting
        ? (user == null || !provider.isAuthenticated || !_justAuthenticated)
        : (user == null || !provider.isAuthenticated);

    if (needsAuth) {
      return AuthScreen(onAuth: _handleAuth);
    }

    // Se app está bloqueado, mostrar tela de reautenticação
    if (_isLocked) {
      return ReauthScreen(
        phoneNumber: user.phoneNumber,
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
  final PageController _pageController = PageController();
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    // Tocar numa notificação de pagamento leva o passageiro ao separador Viagens
    NotificationService().subscribeNotificationTap((data) {
      final type = data['type'];
      if (type == 'PAYMENT_SENT' || type == 'PAYMENT_CONFIRMED') {
        _goToPage(3);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationService().checkInitialMessage());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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
        onSuccess: (_) {
          // Saldo/transações/viagens já foram invalidados dentro do modal.
          // Apenas mostrar feedback de sucesso.
          if (mounted) {
            SuccessModal.show(
              context,
              title: 'Pagamento Realizado!',
              message:
                  'Pagamento realizado com sucesso para ${driverInfo.driverName}.',
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
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: _MenuModal(onLogout: _handleLogout),
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
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          _KeepAlivePage(
            child: HomeScreen(
              onOpenScanner: _showPaymentModal,
              onOpenTopup: _showTopupModal,
              onOpenCards: () => _goToPage(2),
              onPanic: _handlePanic,
              onOpenProfile: _showProfileModal,
              onTerminateSession: _handleLogout,
            ),
          ),
          _KeepAlivePage(
            child: WalletScreen(
              onOpenTopup: _showTopupModal,
              onOpenTransfer: _showTransferModal,
            ),
          ),
          const _KeepAlivePage(child: CardsScreen()),
          const _KeepAlivePage(child: TripsScreen()),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (icon: Icons.home_rounded, label: 'Início'),
      (icon: Icons.account_balance_wallet_rounded, label: 'Carteira'),
      (icon: Icons.credit_card_rounded, label: 'Cartões'),
      (icon: Icons.route_rounded, label: 'Viagens'),
    ];

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isSelected = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _goToPage(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? AppColors.accentOf(context)
                              : isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : AppColors.textDark.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.accentOf(context)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : AppColors.textDark.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// Mantém cada aba viva dentro do PageView (evita perder scroll/estado ao deslizar).
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─── Shared sub-modal header ──────────────────────────────────────────────────
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

// ─── Menu Modal (fullscreen) ──────────────────────────────────────────────────
class _MenuModal extends StatefulWidget {
  final VoidCallback? onLogout;
  const _MenuModal({this.onLogout});
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
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: modal,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AppProvider>().user;

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
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      border: Border.all(color: AppColors.accentOf(context), width: 1.5),
                    ),
                    child: user?.photo != null && user!.photo!.isNotEmpty
                        ? ClipOval(child: Image.network(user.photo!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, size: 22, color: isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.textDark.withValues(alpha: 0.65))))
                        : Icon(Icons.person_rounded, size: 22, color: isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.textDark.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user?.fullName ?? '—',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textDark),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(user?.phoneNumber ?? '—',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45))),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.textDark.withValues(alpha: 0.65)),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            _navTile(isDark, Icons.person_outline_rounded, 'Perfil', 'Dados pessoais e métodos de pagamento', () => _openSubModal(const _ProfileModal())),
            _navTile(isDark, Icons.shield_outlined, 'Segurança', 'PIN, biometria e privacidade', () => _openSubModal(const _SecurityModal())),
            _navTile(isDark, Icons.settings_outlined, 'Configurações', 'Tema, notificações e informações', () => _openSubModal(const _SettingsModal())),
            const Spacer(),
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
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.22), width: 1.0),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Sair', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(bool isDark, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.45)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textDark)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.38))),
            ])),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }
}


// ─── Profile Modal ────────────────────────────────────────────────────────────
class _ProfileModal extends StatefulWidget {
  const _ProfileModal();
  @override
  State<_ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<_ProfileModal> {
  void _showEditSheet() {
    final provider = context.read<AppProvider>();
    final user = provider.user;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.fullName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
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
                const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Editar Perfil',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textDark)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline,
                      color: AppColors.accentOf(context)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                        color: AppColors.accentOf(context), width: 1.5),
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
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await provider.updateProfile(
                        fullName: nameCtrl.text.trim());
                    if (ok && mounted) {
                      FeedbackService.showSuccess(context,
                          message: 'Perfil atualizado');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOf(context),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: const Text('Guardar',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AppProvider>().user;

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
                border: Border.all(color: AppColors.accentOf(context), width: 1.5),
              ),
              child: user?.photo != null && user!.photo!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(user.photo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : AppColors.textDark.withValues(alpha: 0.65))))
                  : Icon(Icons.person_rounded,
                      size: 36,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textDark.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 10),
            Text(user?.fullName ?? '—',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textDark)),
            const SizedBox(height: 3),
            Text(user?.phoneNumber ?? '—',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.45))),
            const SizedBox(height: 28),
            _tile(isDark, Icons.edit_outlined, 'Editar perfil',
                'Nome e informações pessoais', _showEditSheet),
            _tile(isDark, Icons.payment_outlined, 'Métodos de pagamento',
                'Cartões e contas vinculadas', () {}),
            _tile(isDark, Icons.location_on_outlined, 'Endereço',
                'Morada e localização', () {}),
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
            Icon(icon,
                size: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.45)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textDark)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.38))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.2)),
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
  final BiometricService _bio$ = BiometricService();

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
        final ok = await _bio$.authenticate(
          reason: 'Confirme para ativar a biometria',
          useErrorDialogs: true,
          stickyAuth: true,
        );
        if (!ok) {
          if (mounted) FeedbackService.showInfo(context, message: 'Cancelado');
          return;
        }
        await prefs.setBool('ts_bio_enabled', true);
        if (mounted) setState(() => _bio = true);
        if (mounted) FeedbackService.showSuccess(context, message: 'Biometria ativada');
      } catch (_) {
        if (mounted) FeedbackService.showError(context, message: 'Biometria indisponível');
      }
    } else {
      await prefs.setBool('ts_bio_enabled', false);
      if (mounted) setState(() => _bio = false);
      if (mounted) FeedbackService.showInfo(context, message: 'Biometria desativada');
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
                  const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Alterar PIN',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textDark)),
                const SizedBox(height: 4),
                Text('Novo PIN de 6 dígitos numéricos',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.45))),
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
                            if (!_validPin(nw)) {
                              FeedbackService.showError(context, message: 'PIN deve ter 6 dígitos');
                              return;
                            }
                            if (nw != cf) {
                              FeedbackService.showError(context, message: 'PINs não coincidem');
                              return;
                            }
                            setSheet(() => busy = true);
                            final res = await _api.changePassword(
                                currentPassword: cur, newPassword: nw);
                            if (!ctx.mounted) return;
                            setSheet(() => busy = false);
                            if (res.isSuccess) {
                              await SecureStorageService().savePin(nw);
                              await PinGuard.resetFailures('global');
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) FeedbackService.showSuccess(context, message: 'PIN alterado');
                            } else {
                              if (mounted) FeedbackService.showError(context, message: res.error ?? 'PIN actual incorreto');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOf(context),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      elevation: 0,
                    ),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Alterar PIN',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
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
        prefixIcon: Icon(Icons.lock_outline, color: AppColors.accentOf(context)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: AppColors.accentOf(context), width: 1.5),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
      ),
    );
  }

  bool _validPin(String p) => RegExp(r'^\d{6}$').hasMatch(p);

  void _openEmergencyContacts() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, animation, _) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: const _EmergencyContactsPage(),
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
            _toggleTile(isDark, Icons.fingerprint_rounded, 'Biometria',
                'Desbloquear com impressão digital ou Face ID', _bio, _toggleBio),
            _actionTile(isDark, Icons.key_outlined, 'Alterar PIN',
                'Mudar o PIN de acesso à conta', _changePin),
            _actionTile(isDark, Icons.people_outline_rounded, 'Contactos de emergência',
                'Gerir contactos a notificar em caso de pânico', _openEmergencyContacts),
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
          Icon(icon, size: 20, color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.45)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textDark)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.38))),
            ]),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accentOf(context), activeTrackColor: AppColors.accentOf(context).withValues(alpha: 0.3), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }

  Widget _actionTile(bool isDark, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.45)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textDark)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.38))),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2)),
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
  bool _notifications = true;

  void _openFullscreen(Widget page) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, animation, _) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: page,
      ),
    );
  }

  void _showAbout() => _openFullscreen(const _AboutPage());
  void _showTerms() => _openFullscreen(const _TermsPage());

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);
    final balance = provider.user?.balance ?? 0;

    final ibanCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          title: Text('Encerrar Conta',
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A sua conta entrará num período de carência de 30 dias. Se voltar a iniciar sessão nesse período, a conta será reactivada automaticamente.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
              ),
              if (balance > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Tem ${balance} Kz na carteira. Indique um IBAN angolano para receber a transferência após os 30 dias.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ibanCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'AO06.0040.0000.XXXX.XXXX.X',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (balance > 0 && ibanCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Encerrar Conta'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final iban = balance > 0 ? ibanCtrl.text.trim() : null;
    final success = await provider.deleteAccount(iban: iban);

    if (!context.mounted) return;

    if (success) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppController()),
        (route) => false,
      );
    } else {
      FeedbackService.showError(context, message: 'Não foi possível encerrar a conta. Contacte suporte@trocoseguro.ao');
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
            _subModalHeader(context, 'Configurações', isDark, () => Navigator.pop(context)),
            const SizedBox(height: 8),
            _toggleTile(isDark, Icons.notifications_outlined, 'Notificações', 'Receber alertas e novidades', _notifications, (v) => setState(() => _notifications = v)),
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
            _actionTile(isDark, Icons.report_problem_outlined, 'Reclamações', 'Reportar um problema ou incidente', () => ComplaintModal.show(context)),
            _actionTile(isDark, Icons.info_outline_rounded, 'Sobre', 'Versão e informações do aplicativo', _showAbout),
            _actionTile(isDark, Icons.description_outlined, 'Termos e Condições', 'Política de uso e privacidade', _showTerms),
            _actionTile(isDark, Icons.privacy_tip_outlined, 'Política de Privacidade', 'Como tratamos os seus dados pessoais', () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://trocoseguro.wemof.tech/termos');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }),
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
            InkWell(
              onTap: () => _showDeleteAccountDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever_outlined, size: 20, color: Colors.red),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Encerrar Conta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                        Text('Período de carência de 30 dias — pode reactivar', style: TextStyle(fontSize: 11, color: Colors.red.withValues(alpha: 0.6))),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Colors.red.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile(bool isDark, IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.45)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textDark)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.38))),
          ])),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.accentOf(context), activeTrackColor: AppColors.accentOf(context).withValues(alpha: 0.3), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }

  Widget _actionTile(bool isDark, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.45)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textDark)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.38))),
            ])),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }
}

// ─── Emergency Contacts Page ─────────────────────────────────────────────────
class _EmergencyContactsPage extends StatefulWidget {
  const _EmergencyContactsPage();
  @override
  State<_EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<_EmergencyContactsPage> {
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
    final res = await _api.getEmergencyContacts();
    if (!mounted) return;
    setState(() { _contacts = res.data ?? []; _loading = false; });
    if (!res.isSuccess) {
      FeedbackService.showError(context, message: res.error ?? 'Erro ao carregar contactos');
    }
  }

  Future<void> _delete(EmergencyContact c) async {
    final res = await _api.deleteEmergencyContact(c.id);
    if (res.isSuccess && mounted) {
      setState(() => _contacts.removeWhere((x) => x.id == c.id));
      FeedbackService.showSuccess(context, message: '${c.name} removido');
    } else if (mounted) {
      FeedbackService.showError(context, message: res.error ?? 'Erro ao remover');
    }
  }

  void _showAddSheet(bool isDark) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xs)))),
                const SizedBox(height: 20),
                Text('Adicionar contacto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textDark)),
                const SizedBox(height: 4),
                Text('Será notificado quando acionar o botão de pânico', style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45))),
                const SizedBox(height: 20),
                _field('Nome', nameCtrl, isDark, Icons.person_outline),
                const SizedBox(height: 12),
                _field('Telefone (+244...)', phoneCtrl, isDark, Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        FeedbackService.showError(context, message: 'Preencha todos os campos');
                        return;
                      }
                      setSheet(() => busy = true);
                      final res = await _api.addEmergencyContact(name: name, phoneNumber: phone);
                      if (!ctx.mounted) return;
                      setSheet(() => busy = false);
                      if (res.isSuccess && res.data != null) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) setState(() => _contacts.add(res.data!));
                        if (mounted) FeedbackService.showSuccess(context, message: '$name adicionado');
                      } else {
                        if (mounted) FeedbackService.showError(context, message: res.error ?? 'Erro ao adicionar');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOf(context), foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      elevation: 0,
                    ),
                    child: busy
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white))
                        : const Text('Adicionar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, bool isDark, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.accentOf(context)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.accentOf(context), width: 1.5)),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAdd = _contacts.length < 3;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(context, 'Contactos de Emergência', isDark, () => Navigator.pop(context)),
            // limit badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(child: Text('${_contacts.length}/3 contactos',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.4)))),
                  if (canAdd)
                    GestureDetector(
                      onTap: () => _showAddSheet(isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.accentOf(context),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_rounded, size: 15, color: isDark ? Colors.black : Colors.white),
                          const SizedBox(width: 4),
                          Text('Adicionar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.black : Colors.white)),
                        ]),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Limite atingido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
                    ),
                ],
              ),
            ),
            Container(height: 1, margin: const EdgeInsets.only(top: 12),
                color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppColors.accentOf(context)))
                  : _contacts.isEmpty
                      ? _buildEmpty(isDark)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _contacts.length,
                          separatorBuilder: (_, __) => Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20),
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                          itemBuilder: (_, i) => _contactTile(_contacts[i], isDark),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(EmergencyContact c, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              border: Border.all(color: AppColors.accentOf(context).withValues(alpha: 0.4), width: 1.2),
            ),
            child: Center(child: Text(c.name[0].toUpperCase(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accentOf(context)))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textDark)),
            const SizedBox(height: 2),
            Text(c.phoneNumber, style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.4))),
          ])),
          GestureDetector(
            onTap: () => _delete(c),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withValues(alpha: 0.08)),
              child: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                border: Border.all(color: AppColors.accentOf(context).withValues(alpha: 0.4), width: 1.5)),
            child: Icon(Icons.people_outline_rounded, size: 32,
                color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3))),
        const SizedBox(height: 16),
        Text('Nenhum contacto', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textDark)),
        const SizedBox(height: 6),
        Text('Adicione até 3 pessoas a notificar\nem caso de emergência.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5,
                color: isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.4))),
      ]),
    );
  }
}

// ─── About Page ───────────────────────────────────────────────────────────────
class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(context, 'Sobre', isDark, () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                          border: Border.all(color: AppColors.accentOf(context), width: 1.5),
                        ),
                        child: Icon(Icons.security_rounded, size: 34,
                            color: isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.textDark.withValues(alpha: 0.65)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('Troco Seguro',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.textDark)),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text('Versão 1.0.4',
                          style: TextStyle(fontSize: 12,
                              color: isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.4))),
                    ),
                    const SizedBox(height: 32),
                    _section('O que é o Troco Seguro?', isDark),
                    const SizedBox(height: 8),
                    _body('Plataforma digital que elimina a necessidade de troco físico nas viagens de táxi em Luanda. Passageiros e motoristas fazem pagamentos via QR code de forma rápida, simples e segura.', isDark),
                    const SizedBox(height: 24),
                    _section('Como funciona?', isDark),
                    const SizedBox(height: 8),
                    _step('1', 'Carregue a sua carteira com o saldo desejado.', isDark, context),
                    const SizedBox(height: 10),
                    _step('2', 'No final da viagem, escaneie o QR code do motorista.', isDark, context),
                    const SizedBox(height: 10),
                    _step('3', 'Confirme o pagamento com o seu PIN de 6 dígitos.', isDark, context),
                    const SizedBox(height: 24),
                    _section('Segurança', isDark),
                    const SizedBox(height: 8),
                    _body('Todos os pagamentos são protegidos por PIN e opcionalmente por biometria. Os tokens de sessão expiram automaticamente e os dados sensíveis nunca são armazenados em texto simples.', isDark),
                    const SizedBox(height: 24),
                    _section('Contacto', isDark),
                    const SizedBox(height: 8),
                    _body('Para suporte ou esclarecimentos, contacte-nos em suporte@trocoseguro.ao', isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String text, bool isDark) => Text(text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.textDark));

  Widget _body(String text, bool isDark) => Text(text,
      style: TextStyle(fontSize: 13, height: 1.65,
          color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55)));

  Widget _step(String num, String text, bool isDark, BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentOf(context)),
        child: Center(child: Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 13, height: 1.55,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55)))),
    ]);
  }
}

// ─── Terms Page ───────────────────────────────────────────────────────────────
class _TermsPage extends StatelessWidget {
  const _TermsPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _subModalHeader(context, 'Termos e Condições', isDark, () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _clause('1. Aceitação dos Termos', 'Ao registar-se e utilizar o Troco Seguro, concorda expressamente com estes Termos e Condições. Caso não concorde, deverá cessar imediatamente a utilização da aplicação.', isDark, context),
                    _clause('2. Descrição do Serviço', 'O Troco Seguro é uma plataforma de pagamentos digitais destinada a facilitar transações entre passageiros e motoristas de táxi em Angola. O serviço inclui carteira digital, pagamentos via QR code e histórico de transações.', isDark, context),
                    _clause('3. Conta e Segurança', 'É da sua exclusiva responsabilidade manter a confidencialidade do PIN e das credenciais de acesso à conta. Qualquer atividade realizada com as suas credenciais é da sua responsabilidade. Em caso de suspeita de acesso não autorizado, contacte-nos imediatamente.', isDark, context),
                    _clause('4. Pagamentos e Saldo', 'O saldo da carteira é expresso em Kwanzas (Kz) e não é convertível em dinheiro físico exceto mediante solicitação formal. Todos os pagamentos são definitivos e não reversíveis, salvo em casos de erro técnico comprovado.', isDark, context),
                    _clause('5. Privacidade dos Dados', 'Os seus dados pessoais são tratados de acordo com a legislação angolana de proteção de dados. Não partilhamos informações pessoais com terceiros sem o seu consentimento, exceto quando exigido por lei.', isDark, context),
                    _clause('6. Limitação de Responsabilidade', 'O Troco Seguro não se responsabiliza por falhas causadas por problemas de conectividade, interrupções de serviço de terceiros ou utilização indevida da aplicação pelo utilizador.', isDark, context),
                    _clause('7. Alterações aos Termos', 'Reservamo-nos o direito de atualizar estes termos a qualquer momento. Será notificado de alterações significativas através da aplicação. O uso continuado após as alterações implica aceitação dos novos termos.', isDark, context),
                    _clause('8. Contacto', 'Para questões relacionadas com estes termos, contacte: termos@trocoseguro.ao', isDark, context),
                    const SizedBox(height: 8),
                    Text('Última atualização: Junho 2026',
                        style: TextStyle(fontSize: 11,
                            color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clause(String title, String body, bool isDark, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accentOf(context))),
        const SizedBox(height: 6),
        Text(body,
            style: TextStyle(fontSize: 13, height: 1.65,
                color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55))),
      ]),
    );
  }
}

/// Tela de reautenticação quando o app é bloqueado
class ReauthScreen extends StatefulWidget {
  final String phoneNumber;
  final Future<bool> Function(String pin) onUnlock;
  final Future<bool> Function() onBiometricUnlock;
  final Future<void> Function() onSwitchAccount;

  const ReauthScreen({
    super.key,
    required this.phoneNumber,
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
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      // Verificar se o utilizador activou a biometria nas definições
      final prefs = await SharedPreferences.getInstance();
      final bioEnabled = prefs.getBool('ts_bio_enabled') ?? false;
      if (!bioEnabled) return;

      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _biometricsAvailable = canCheck && isSupported;
        });
      }

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

  String _maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;
    final visible = phone.substring(phone.length - 4);
    return '****$visible';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentOf(context);
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final labelColor = isDark ? Colors.white70 : const Color(0xFF6C6C70);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo
              Image.asset(
                'assets/images/logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),

              // Título
              Text(
                'Verificar identidade',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _maskPhoneNumber(widget.phoneNumber),
                style: TextStyle(
                  fontSize: 15,
                  color: labelColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(flex: 2),

              // Campos PIN
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Text(
                      'PIN de 6 dígitos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(6, (index) {
                        return Expanded(
                          child: Container(
                          height: 52,
                          margin: EdgeInsets.only(
                            left: index == 0 ? 0 : 3,
                            right: index == 5 ? 0 : 3,
                          ),
                          child: TextField(
                            controller: _pinControllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            obscureText: _obscurePin,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFF2F2F7),
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF3A3A3C)
                                      : const Color(0xFFD1D1D6),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF3A3A3C)
                                      : const Color(0xFFD1D1D6),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: BorderSide(
                                  color: accent,
                                  width: 2.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF3B30),
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
                              final pin = _pinControllers.map((c) => c.text).join();
                              if (pin.length == 6) _verifyPin();
                            },
                          ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() => _obscurePin = !_obscurePin),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 14,
                            color: labelColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _obscurePin ? 'Mostrar PIN' : 'Ocultar PIN',
                            style: TextStyle(
                              fontSize: 13,
                              color: labelColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Erro
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: Color(0xFFFF3B30)),
                            const SizedBox(width: 5),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFFF3B30),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const Spacer(flex: 2),

              // Acções
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(
                    color: accent,
                    strokeWidth: 2.5,
                  ),
                )
              else ...[
                if (_biometricsAvailable)
                  GestureDetector(
                    onTap: _tryBiometric,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fingerprint_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'Usar biometria',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_biometricsAvailable) const SizedBox(height: 12),
                GestureDetector(
                  onTap: _verifyPin,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF3A3A3C)
                            : const Color(0xFFD1D1D6),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Confirmar PIN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    await widget.onSwitchAccount();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Trocar de conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ],

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
