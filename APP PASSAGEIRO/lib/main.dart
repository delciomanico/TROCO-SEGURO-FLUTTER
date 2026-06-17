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
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/widgets/payment_confirmation_modal.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/services/biometric_service.dart';

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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onOpenScanner: _showPaymentModal,
            onOpenTopup: _showTopupModal,
            onPanic: _handlePanic,
            onOpenProfile: _showProfileModal,
            onTerminateSession: _handleLogout,
          ),
          WalletScreen(
            onOpenTopup: _showTopupModal,
            onOpenTransfer: _showTransferModal,
          ),
          const CardsScreen(),
          const TripsScreen(),
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
      color: isDark ? const Color(0xFF1A1D24) : const Color(0xFF111318),
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
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGold
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? Colors.black
                              : Colors.white.withValues(alpha: 0.55),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
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
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: modal,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.read<AppProvider>().user;

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
                    child: user?.photo != null && user!.photo!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(user.photo!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.person_rounded,
                                    size: 22,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : AppColors.textDark
                                            .withValues(alpha: 0.65))))
                        : Icon(Icons.person_rounded,
                            size: 22,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.75)
                                : AppColors.textDark.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '—',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? Colors.white : AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.phoneNumber ?? '—',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.45)),
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
                      child: Icon(Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppColors.textDark.withValues(alpha: 0.65)),
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
            const SizedBox(height: 24),
            _buildNavTile(
              isDark: isDark,
              icon: Icons.person_outline_rounded,
              title: 'Perfil',
              subtitle: 'Dados pessoais e conta',
              onTap: () => _openSubModal(const _ProfileModal()),
            ),
            const SizedBox(height: 10),
            _buildNavTile(
              isDark: isDark,
              icon: Icons.shield_outlined,
              title: 'Segurança',
              subtitle: 'PIN, biometria e privacidade',
              onTap: () => _openSubModal(const _SecurityModal()),
            ),
            const SizedBox(height: 10),
            _buildNavTile(
              isDark: isDark,
              icon: Icons.settings_outlined,
              title: 'Configurações',
              subtitle: 'Tema, notificações e informações',
              onTap: () => _openSubModal(const _SettingsModal()),
            ),
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.22), width: 1.0),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Sair',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.07),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.5),
                    width: 1.2),
              ),
              child: Icon(icon,
                  size: 19,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textDark.withValues(alpha: 0.65)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.22)),
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
                  prefixIcon: const Icon(Icons.person_outline,
                      color: AppColors.primaryGold),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.15)),
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
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                border: Border.all(color: AppColors.primaryGold, width: 1.5),
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
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryGold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.15)),
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
    );
  }

  bool _validPin(String p) => RegExp(r'^\d{6}$').hasMatch(p);

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
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primaryGold, activeTrackColor: AppColors.primaryGold.withValues(alpha: 0.3), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
  bool _darkMode = false;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _darkMode = prefs.getString('ts_theme_mode') == 'dark');
  }

  void _showAbout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Troco Seguro',
            style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textDark)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Versão 1.0.0', style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45))),
          const SizedBox(height: 10),
          Text('Plataforma segura para pagamentos digitais de táxis em Luanda.', style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white : AppColors.textDark)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.w600)))],
      ),
    );
  }

  void _showTerms() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Termos e Condições',
            style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textDark)),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _term('Aceitação', 'Ao usar este aplicativo, concorda com estes termos.', isDark),
            const SizedBox(height: 10),
            _term('Privacidade', 'Dados protegidos com criptografia. Nunca partilhamos sem consentimento.', isDark),
            const SizedBox(height: 10),
            _term('Responsabilidades', 'É responsável pela confidencialidade da sua conta e PIN.', isDark),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceitar', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.w600)))],
      ),
    );
  }

  Widget _term(String title, String body, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryGold)),
      const SizedBox(height: 3),
      Text(body, style: TextStyle(fontSize: 11, height: 1.5, color: isDark ? Colors.white : AppColors.textDark)),
    ]);
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
            _toggleTile(isDark, Icons.dark_mode_outlined, 'Tema escuro', 'Alternar entre modo claro e escuro', _darkMode, (v) async {
              await ThemeController.instance.setDark(v);
              if (mounted) setState(() => _darkMode = v);
            }),
            _toggleTile(isDark, Icons.notifications_outlined, 'Notificações', 'Receber alertas e novidades', _notifications, (v) => setState(() => _notifications = v)),
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
            _actionTile(isDark, Icons.info_outline_rounded, 'Sobre', 'Versão e informações do aplicativo', _showAbout),
            _actionTile(isDark, Icons.description_outlined, 'Termos e Condições', 'Política de uso e privacidade', _showTerms),
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
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primaryGold, activeTrackColor: AppColors.primaryGold.withValues(alpha: 0.3), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
                  color: const Color(0xFF121212).withValues(alpha: 0.3),
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
                            const Text(
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
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade400,
                                            width: 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade400,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AppColors.primaryGold,
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
