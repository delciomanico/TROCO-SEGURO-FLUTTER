import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/services/biometric_service.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';
import 'package:troco_seguro/security/pin_guard.dart';
import 'package:troco_seguro/services/feedback_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final ScrollController? scrollController;
  final bool useBlurBackground;

  const ProfileScreen({
    super.key,
    this.onLogout,
    this.scrollController,
    this.useBlurBackground = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notificationsEnabled = true;
  bool twoFactorEnabled = false;
  bool biometricsEnabled = false;
  bool isLoading = false;
  bool isChangingPassword = false;
  final ApiService _api = ApiService();
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _api.loadTokens();

    final prefs = await SharedPreferences.getInstance();
    final bioPref = prefs.getBool('ts_bio_enabled') ?? false;

    setState(() {
      biometricsEnabled = bioPref;
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final user = context.watch<AppProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).cardColor : AppColors.lightCard,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image - only show in dark mode
          if (isDark && widget.useBlurBackground)
            Image.asset(
              'assets/images/card_fundo.jpg',
              fit: BoxFit.cover,
            ),
          // Blur effect - only in dark mode
          if (isDark && widget.useBlurBackground)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color:
                    (isDark ? Theme.of(context).cardColor : AppColors.lightCard)
                        .withValues(alpha: 0.3),
              ),
            ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: responsive.scaledHeight(40)),
                  _buildProfileHeader(responsive, user, isDark),
                  SizedBox(height: responsive.scaledHeight(32)),
                  _buildAccountSettings(responsive, isDark),
                  SizedBox(height: responsive.scaledHeight(24)),
                  _buildSecuritySettings(responsive, isDark),
                  SizedBox(height: responsive.scaledHeight(24)),
                  _buildAppSettings(responsive, isDark),
                  SizedBox(height: responsive.scaledHeight(24)),
                  _buildHelpInfo(responsive, isDark),
                  SizedBox(height: responsive.scaledHeight(24)),
                  _buildLogoutButton(responsive, isDark),
                  SizedBox(height: responsive.scaledHeight(24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      ResponsiveHelper responsive, User? user, bool isDark) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showEditProfileSheet,
            child: Stack(
              children: [
                Container(
                  width: responsive.scaledWidth(100),
                  height: responsive.scaledWidth(100),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentOf(context),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: user?.photo != null && user!.photo!.isNotEmpty
                        ? Image.network(
                            user.photo!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultAvatar(),
                          )
                        : _buildDefaultAvatar(),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: responsive.scaledWidth(32),
                    height: responsive.scaledWidth(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentOf(context),
                      border: Border.all(
                        color: AppColors.lightBackground,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: responsive.scaledWidth(16),
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          Text(
            user?.fullName ?? 'Usuário',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(20),
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(4)),
          Text(
            user?.phoneNumber ?? 'Sem telefone',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(13),
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppColors.accentOf(context).withValues(alpha: 0.1),
      child: Icon(
        Icons.person_outline,
        size: 50,
        color: AppColors.accentOf(context),
      ),
    );
  }

  Widget _buildAccountSettings(ResponsiveHelper responsive, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informações da Conta',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(16),
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildMenuOption(
            responsive,
            'Editar Perfil',
            Icons.person_outline,
            () => _showEditProfileSheet(),
            isDark,
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildMenuOption(
            responsive,
            'Métodos de Pagamento',
            Icons.payment_outlined,
            () => _showSnack('Métodos de Pagamento'),
            isDark,
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildMenuOption(
            responsive,
            'Endereço',
            Icons.location_on_outlined,
            () => _showSnack('Endereço'),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings(ResponsiveHelper responsive, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Segurança',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(16),
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildSettingCard(
            responsive,
            'Biometria',
            'Use impressão digital ou Face ID',
            Icons.fingerprint,
            biometricsEnabled,
            (value) => _onToggleBiometrics(value ?? false),
            isDark,
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildActionCard(
            responsive,
            'Alterar PIN',
            'Altere seu PIN de segurança',
            Icons.key_outlined,
            _showChangePinSheet,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettings(ResponsiveHelper responsive, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aplicativo',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(16),
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildSettingCard(
            responsive,
            'Notificações',
            'Receba alertas sobre suas transações',
            Icons.notifications_outlined,
            notificationsEnabled,
            (value) => setState(() => notificationsEnabled = value ?? false),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(
    ResponsiveHelper responsive,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool?> onChanged,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(8),
        vertical: responsive.scaledHeight(8),
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: responsive.scaledWidth(22),
            color: AppColors.accentOf(context),
          ),
          SizedBox(width: responsive.scaledWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(2)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(11),
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accentOf(context),
            activeTrackColor: AppColors.accentOf(context).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    ResponsiveHelper responsive,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(8),
          vertical: responsive.scaledHeight(8),
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: responsive.scaledWidth(22),
              color: AppColors.accentOf(context),
            ),
            SizedBox(width: responsive.scaledWidth(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(11),
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: responsive.scaledWidth(20),
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpInfo(ResponsiveHelper responsive, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help & Info',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(16),
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildMenuOption(
            responsive,
            'Help & Support',
            Icons.help_outline,
            _showHelpSupportModal,
            isDark,
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildMenuOption(
            responsive,
            'Privacy Policy',
            Icons.privacy_tip_outlined,
            _showPrivacyPolicyModal,
            isDark,
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          _buildMenuOption(
            responsive,
            'About App',
            Icons.info_outline,
            _showAboutAppModal,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(
    ResponsiveHelper responsive,
    String title,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(8),
          vertical: responsive.scaledHeight(10),
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: responsive.scaledWidth(22),
              color: AppColors.accentOf(context),
            ),
            SizedBox(width: responsive.scaledWidth(12)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(14),
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: responsive.scaledWidth(20),
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet() {
    final provider = context.read<AppProvider>();
    final user = provider.user;
    if (user == null) return;

    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phoneNumber);
    final responsive = ResponsiveHelper(context);
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
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
            ),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.07 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          padding: EdgeInsets.all(responsive.scaledWidth(24)),
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
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Text(
                'Editar Perfil',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Text(
                'Nome completo',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.7 * 255).round()),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Digite seu nome',
                  prefixIcon: Icon(Icons.person_outline,
                      color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.20 * 255).round()),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.20 * 255).round()),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
              SizedBox(height: responsive.scaledHeight(16)),
              Text(
                'Telefone',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.7 * 255).round()),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                enabled: false,
                decoration: InputDecoration(
                  hintText: '+244 XXX XXX XXX',
                  prefixIcon: Icon(Icons.phone_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.20 * 255).round()),
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.20 * 255).round()),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.20 * 255).round()),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
              SizedBox(height: responsive.scaledHeight(24)),
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
                      // Refresh user data from provider
                      await provider.refreshUserData();
                    }
                    _showSnack('Perfil atualizado com sucesso');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                        vertical: responsive.scaledHeight(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Salvar alterações',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(ResponsiveHelper responsive, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(24)),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: const Text(
                'Sair da conta?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              content: const Text('Tem certeza que deseja sair?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onLogout?.call();
                  },
                  child: const Text(
                    'Sair',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(16)),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: Colors.red,
                size: responsive.scaledWidth(20),
              ),
              SizedBox(width: responsive.scaledWidth(8)),
              Text(
                'Sair da conta',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(14),
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onToggleBiometrics(bool enable) async {
    final prefs = await SharedPreferences.getInstance();

    if (enable) {
      try {
        // Verificar se biometria está disponível
        final isBioAvailable = await _biometricService.isBiometricAvailable();
        if (!isBioAvailable) {
          if (mounted) {
            _showSnack('Biometria não disponível neste dispositivo');
          }
          return;
        }

        // Tentar autenticar
        debugPrint('🔐 Ativando biometria...');
        final didAuth = await _biometricService.authenticate(
          reason: 'Confirme para ativar a biometria',
          useErrorDialogs: true,
        );

        if (!didAuth) {
          if (mounted) {
            _showSnack('Autenticação biométrica cancelada');
          }
          return;
        }

        // Salvar preferência apenas após autenticação bem-sucedida
        await prefs.setBool('ts_bio_enabled', true);
        if (mounted) {
          setState(() => biometricsEnabled = true);
          _showSnack('✅ Biometria ativada com sucesso');
          debugPrint('✅ Biometria ativada');
        }
      } catch (e) {
        debugPrint('❌ Erro ao ativar biometria: $e');
        if (mounted) {
          _showSnack('Erro ao ativar biometria: ${e.toString()}');
        }
      }
    } else {
      try {
        await prefs.setBool('ts_bio_enabled', false);
        if (mounted) {
          setState(() => biometricsEnabled = false);
          _showSnack('Biometria desativada');
          debugPrint('✅ Biometria desativada');
        }
      } catch (e) {
        debugPrint('❌ Erro ao desativar biometria: $e');
        if (mounted) {
          _showSnack('Erro ao desativar biometria');
        }
      }
    }
  }

  Future<void> _showChangePinSheet() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
            ),
            border: Border.all(
              color: Theme.of(ctx)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.07 * 255).round()),
                blurRadius: 8,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          padding: EdgeInsets.all(responsive.scaledWidth(24)),
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
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Text(
                'Alterar PIN',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                'Digite seu PIN atual e crie um novo PIN de 6 dígitos',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.7 * 255).round()),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              _buildPinFieldSheet('PIN atual', currentController, responsive),
              SizedBox(height: responsive.scaledHeight(16)),
              _buildPinFieldSheet('Novo PIN', newController, responsive),
              SizedBox(height: responsive.scaledHeight(16)),
              _buildPinFieldSheet(
                  'Confirmar novo PIN', confirmController, responsive),
              SizedBox(height: responsive.scaledHeight(24)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isChangingPassword
                      ? null
                      : () async {
                          final currentPin = currentController.text.trim();
                          final newPin = newController.text.trim();
                          final confirmPin = confirmController.text.trim();

                          if (!_isValidPin(newPin) ||
                              !_isValidPin(confirmPin)) {
                            _showSnack('PIN deve ter 6 dígitos numéricos');
                            return;
                          }
                          if (newPin != confirmPin) {
                            _showSnack('Novo PIN e confirmação não coincidem');
                            return;
                          }

                          setState(() => isChangingPassword = true);

                          final result = await _api.changePassword(
                            currentPassword: currentPin,
                            newPassword: newPin,
                          );

                          if (!mounted) return;
                          setState(() => isChangingPassword = false);

                          if (result.isSuccess) {
                            await SecureStorageService().savePin(newPin);
                            await PinGuard.resetFailures('global');
                            if (mounted) Navigator.pop(ctx);
                            _showSnack('PIN alterado com sucesso');
                          } else {
                            _showSnack(
                                'Erro: ${result.error ?? "PIN atual incorreto"}');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.primary,
                    foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                        vertical: responsive.scaledHeight(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                    disabledBackgroundColor:
                        Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  child: isChangingPassword
                      ? SizedBox(
                          height: responsive.scaledHeight(20),
                          width: responsive.scaledHeight(20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Alterar PIN',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinFieldSheet(String label, TextEditingController controller,
      ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(12),
            fontWeight: FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withAlpha((0.7 * 255).round()),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(8)),
        TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            prefixIcon: Icon(Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.20 * 255).round()),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.20 * 255).round()),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor:
                isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          ),
        ),
      ],
    );
  }

  bool _isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

  void _showHelpSupportModal() {
    _showFullscreenInfoModal(
      title: 'Help & Support',
      icon: Icons.support_agent,
      children: const [
        _InfoLine('Se precisar de ajuda, fale com nossa equipe de suporte.'),
        SizedBox(height: 12),
        _InfoLine('Email: suporte@trocoseguro.app'),
        _InfoLine('Telefone: +244 900 000 000'),
        _InfoLine('Horário: Segunda a Sexta, 08:00 - 18:00'),
      ],
    );
  }

  void _showPrivacyPolicyModal() {
    _showFullscreenInfoModal(
      title: 'Privacy Policy',
      icon: Icons.privacy_tip_outlined,
      children: const [
        _InfoLine('Coletamos apenas dados necessários para operação do app.'),
        SizedBox(height: 12),
        _InfoLine(
            'Seus dados de autenticação são protegidos e não são compartilhados com terceiros sem consentimento.'),
        SizedBox(height: 8),
        _InfoLine(
            'Você pode solicitar atualização ou exclusão de dados pelo suporte.'),
      ],
    );
  }

  void _showAboutAppModal() {
    _showFullscreenInfoModal(
      title: 'About App',
      icon: Icons.info_outline,
      children: const [
        _InfoLine('Troco Seguro'),
        _InfoLine('Versão 1.0.4+1'),
        SizedBox(height: 12),
        _InfoLine('Aplicativo de pagamento digital para táxis em Luanda.'),
      ],
    );
  }

  void _showInfoModal({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final responsive = ResponsiveHelper(ctx);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.scaledWidth(20),
              responsive.scaledHeight(8),
              responsive.scaledWidth(20),
              responsive.scaledHeight(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon,
                        color: AppColors.accentOf(context),
                        size: responsive.scaledWidth(24)),
                    SizedBox(width: responsive.scaledWidth(10)),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(18),
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.textLight : AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.scaledHeight(16)),
                ...children,
                SizedBox(height: responsive.scaledHeight(20)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentOf(context),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14)),
                    ),
                    child: Text(
                      'Fechar',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullscreenInfoModal({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, _, __) {
        final responsive = ResponsiveHelper(dialogContext);
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return Material(
          color:
              isDark ? Theme.of(dialogContext).cardColor : AppColors.lightCard,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    responsive.scaledWidth(8),
                    responsive.scaledHeight(8),
                    responsive.scaledWidth(16),
                    responsive.scaledHeight(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Icon(
                        icon,
                        color: AppColors.accentOf(context),
                        size: responsive.scaledWidth(24),
                      ),
                      SizedBox(width: responsive.scaledWidth(10)),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(19),
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textLight
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(dialogContext)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.12 * 255).round()),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      responsive.scaledWidth(20),
                      responsive.scaledHeight(18),
                      responsive.scaledWidth(20),
                      responsive.scaledHeight(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...children,
                        SizedBox(height: responsive.scaledHeight(24)),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentOf(context),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: responsive.scaledHeight(14),
                              ),
                            ),
                            child: Text(
                              'Fechar',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(14),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    FeedbackService.showInfo(
      context,
      message: message,
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String text;

  const _InfoLine(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: isDark ? Colors.grey[300] : Colors.grey[700],
      ),
    );
  }
}
