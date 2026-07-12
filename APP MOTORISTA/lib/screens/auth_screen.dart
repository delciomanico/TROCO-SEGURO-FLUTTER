import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:troco_seguro_pro/widgets/otp_box_input.dart';
import 'package:troco_seguro_pro/widgets/country_code_field.dart';

enum AuthMode { choice, login, register, otp }

class AuthScreen extends StatefulWidget {
  final Function(
    String name,
    String phone,
    String pin, {
    String? accessToken,
    String? refreshToken,
  }) onAuth;

  const AuthScreen({super.key, required this.onAuth});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.choice;
  CountryCode _selectedCountry = kCountryCodes.first;
  bool _obscurePin = true;
  bool isLoading = false;
  bool _agreedToTerms = false;
  String? errorMessage;

  final ApiService _api = ApiService();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final pinController = TextEditingController();
  final otpController = TextEditingController();

  late Color primaryGold;
  late Color secondaryGold;
  late Color darkBg;
  late Color darkCard;
  late Color lightBg;
  late Color lightCard;
  late Color textColor;
  late bool isDark;

  String? _pendingPhone;
  String? _pendingPin;
  String? _pendingName;

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    pinController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String _formatPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.startsWith(_selectedCountry.dialCode)
        ? '+$cleaned'
        : '+${_selectedCountry.dialCode}$cleaned';
  }

  static const String _forbiddenAccessMessage =
      'Acesso proibido. Esta conta não é de motorista — use a app do passageiro.';

  /// Só contas com role 'DRIVER' podem entrar nesta app. Um role nulo é
  /// permitido (contas antigas podem não o ter guardado), mas qualquer role
  /// explicitamente diferente (ex: 'PASSENGER') é bloqueado.
  bool _isRoleMismatch(String? role) =>
      role != null && role.toUpperCase() != 'DRIVER';

  Future<void> _handleContinue() async {
    setState(() => errorMessage = null);

    if (phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
      setState(() => errorMessage = 'Digite um número válido');
      return;
    }
    if (_mode == AuthMode.register && nameController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Digite o seu nome');
      return;
    }
    if (pinController.text.length != 6) {
      setState(() => errorMessage = 'PIN deve ter 6 dígitos');
      return;
    }
    if (_mode == AuthMode.register && !_agreedToTerms) {
      setState(() => errorMessage = 'Aceite os Termos de Uso para continuar');
      return;
    }

    setState(() => isLoading = true);
    final phone = _formatPhone(phoneController.text);

    if (_mode == AuthMode.login) {
      final result =
          await _api.login(phoneNumber: phone, password: pinController.text);
      setState(() => isLoading = false);
      if (result.isSuccess) {
        if (_isRoleMismatch(result.data?.driver?.role)) {
          await _api.clearTokens();
          setState(() => errorMessage = _forbiddenAccessMessage);
          return;
        }
        widget.onAuth(
          nameController.text.trim().isNotEmpty
              ? nameController.text.trim()
              : (result.data?.driver?.fullName ?? 'Motorista'),
          phone,
          pinController.text,
          accessToken: result.data?.accessToken,
          refreshToken: result.data?.refreshToken,
        );
      } else {
        setState(() => errorMessage = result.error ?? 'Falha no login');
      }
    } else {
      final result = await _api.register(
        fullName: nameController.text.trim(),
        phoneNumber: phone,
        password: pinController.text,
      );
      setState(() => isLoading = false);
      if (result.isSuccess) {
        _pendingPhone = phone;
        _pendingPin = pinController.text;
        _pendingName = nameController.text.trim();
        setState(() => _mode = AuthMode.otp);
      } else {
        setState(() => errorMessage = result.error ?? 'Falha no registo');
      }
    }
  }

  Future<void> _handleOtp() async {
    if (otpController.text.length != 6) {
      setState(() => errorMessage = 'Código deve ter 6 dígitos');
      return;
    }
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final result = await _api.verifyOtp(
      phoneNumber: _pendingPhone!,
      otpCode: otpController.text,
    );
    if (!result.isSuccess) {
      setState(() {
        isLoading = false;
        errorMessage = result.error ?? 'Código inválido';
      });
      return;
    }
    // OTP verificado — fazer login
    final login = await _api.login(
      phoneNumber: _pendingPhone!,
      password: _pendingPin!,
    );
    setState(() => isLoading = false);
    if (login.isSuccess) {
      if (_isRoleMismatch(login.data?.driver?.role)) {
        await _api.clearTokens();
        setState(() => errorMessage = _forbiddenAccessMessage);
        return;
      }
      widget.onAuth(
        _pendingName ?? 'Motorista',
        _pendingPhone!,
        _pendingPin!,
        accessToken: login.data?.accessToken,
        refreshToken: login.data?.refreshToken,
      );
    } else {
      setState(() => errorMessage = login.error ?? 'Falha no login após OTP');
    }
  }

  Future<void> _resendOtp() async {
    if (_pendingPhone == null) return;
    await _api.resendOtp(_pendingPhone!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Código reenviado por SMS'),
        backgroundColor: AppColors.primaryGold,
      ));
    }
  }

  void _handleRecover() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, _) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic)),
        child: const _PasswordRecoveryModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    isDark = Theme.of(context).brightness == Brightness.dark;
    primaryGold = AppColors.primaryGold;
    secondaryGold = AppColors.secondaryGold;
    darkBg = const Color(0xFF0E0E0E);
    darkCard = const Color(0xFF1C1B1B);
    lightBg = const Color(0xFFFFFFFF);
    lightCard = const Color(0xFFF0F0F0);
    textColor = isDark ? Colors.white : darkBg;

    return Scaffold(
      backgroundColor: isDark ? darkBg : lightBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/auth_fundo.jpg', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
          _buildAuthBody(r),
        ],
      ),
    );
  }

  Widget _buildAuthBody(ResponsiveHelper r) {
    return SafeArea(
            child: _mode == AuthMode.choice
                ? _buildChoiceScreen(r)
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.scaledWidth(8),
                            vertical: r.scaledHeight(6)),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: isLoading
                                  ? null
                                  : () => setState(() {
                                        _mode = AuthMode.choice;
                                        errorMessage = null;
                                        otpController.clear();
                                        _agreedToTerms = false;
                                      }),
                              icon: Icon(Icons.arrow_back, color: primaryGold),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.scaledWidth(24)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: r.scaledHeight(12)),
                              _buildTitle(r),
                              SizedBox(height: r.scaledHeight(20)),
                              if (_mode == AuthMode.otp)
                                _buildOtpForm(r)
                              else ...[
                                _buildFormFields(r),
                              ],
                              if (errorMessage != null) ...[
                                SizedBox(height: r.scaledHeight(16)),
                                _buildError(r),
                              ],
                              SizedBox(height: r.scaledHeight(18)),
                              _buildButton(r),
                              SizedBox(height: r.scaledHeight(18)),
                              _buildFooter(r),
                              SizedBox(height: r.scaledHeight(40)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
    );
  }

  Widget _buildChoiceScreen(ResponsiveHelper r) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Column(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: r.scaledWidth(160),
                height: r.scaledWidth(160),
                fit: BoxFit.contain,
              ),
              SizedBox(height: r.scaledHeight(18)),
              Text(
                'TROCO SEGURO',
                style: TextStyle(
                  color: primaryGold,
                  fontSize: r.responsiveFontSize(24),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              SizedBox(height: r.scaledHeight(6)),
              Text(
                'Plataforma de pagamento para taxistas',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[800],
                  fontSize: r.responsiveFontSize(13),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.scaledHeight(48)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.scaledWidth(36)),
          child: Column(
            children: [
              _choiceButton(
                r,
                label: 'Criar conta',
                filled: false,
                onTap: () => setState(() {
                  _mode = AuthMode.register;
                  errorMessage = null;
                }),
              ),
              SizedBox(height: r.scaledHeight(12)),
              _choiceButton(
                r,
                label: 'Entrar',
                filled: true,
                onTap: () => setState(() {
                  _mode = AuthMode.login;
                  errorMessage = null;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choiceButton(ResponsiveHelper r,
      {required String label,
      required bool filled,
      required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      height: r.scaledHeight(56),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha((0.5 * 255).round())
                : Colors.black.withAlpha((0.15 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withAlpha((0.05 * 255).round())
                : Colors.white.withAlpha((0.8 * 255).round()),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? primaryGold : (isDark ? darkCard : Colors.white),
          foregroundColor: filled ? (isDark ? Colors.black : darkBg) : primaryGold,
          side: filled ? null : BorderSide(color: primaryGold, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: r.responsiveFontSize(16),
            fontWeight: FontWeight.w800,
            color: filled ? (isDark ? Colors.black : darkBg) : primaryGold,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ResponsiveHelper r) {
    String title;
    String subtitle;

    switch (_mode) {
      case AuthMode.login:
        title = 'Bem-vindo de volta';
        subtitle = 'Introduza os seus dados.';
        break;
      case AuthMode.register:
        title = 'Criar conta';
        subtitle = 'Preencha os seus dados.';
        break;
      case AuthMode.otp:
        title = 'Verificar conta';
        subtitle = 'Insira o código enviado por SMS';
        break;
      default:
        title = '';
        subtitle = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.responsiveFontSize(24),
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        SizedBox(height: r.scaledHeight(6)),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.responsiveFontSize(13),
            color: isDark ? Colors.white70 : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(ResponsiveHelper r) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.scaledHeight(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Telefone',
            style: TextStyle(
              fontSize: r.responsiveFontSize(13),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          SizedBox(height: r.scaledHeight(6)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CountryCodeSelector(
                selected: _selectedCountry,
                isDark: isDark,
                onChanged: (c) => setState(() => _selectedCountry = c),
              ),
              SizedBox(width: r.scaledWidth(10)),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: r.responsiveFontSize(15),
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  cursorColor: primaryGold,
                  decoration: InputDecoration(
                    hintText: '9XX XXX XXX',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.scaledWidth(16),
                        vertical: r.scaledHeight(14)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryGold, width: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(ResponsiveHelper r) {
    return Column(
      children: [
        if (_mode == AuthMode.register) ...[
          _buildField(r,
              controller: nameController,
              label: 'Nome completo',
              hint: 'Digite o seu nome',
              icon: Icons.person_outline),
          SizedBox(height: r.scaledHeight(4)),
        ],
        _buildPhoneField(r),
        SizedBox(height: r.scaledHeight(4)),
        _buildField(
          r,
          controller: pinController,
          label: 'PIN',
          hint: '••••••',
          icon: Icons.lock_outline,
          keyboardType: TextInputType.number,
          obscure: _obscurePin,
          maxLength: 6,
          suffix: IconButton(
            icon: Icon(
              _obscurePin
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: primaryGold.withValues(alpha: 0.7),
              size: r.scaledWidth(20),
            ),
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
          ),
        ),
        if (_mode == AuthMode.login)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleRecover,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Recuperar credenciais',
                style: TextStyle(
                    color: primaryGold,
                    fontWeight: FontWeight.w600,
                    fontSize: r.responsiveFontSize(13)),
              ),
            ),
          ),
        if (_mode == AuthMode.register) ...[
          SizedBox(height: r.scaledHeight(14)),
          _buildTermsRow(r),
        ],
      ],
    );
  }

  Widget _buildTermsRow(ResponsiveHelper r) {
    return GestureDetector(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Custom checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: r.scaledWidth(22),
            height: r.scaledWidth(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _agreedToTerms
                  ? primaryGold
                  : Colors.transparent,
              border: Border.all(
                color: _agreedToTerms
                    ? primaryGold
                    : (isDark ? Colors.grey[500]! : Colors.grey[400]!),
                width: 2,
              ),
            ),
            child: _agreedToTerms
                ? Icon(Icons.check,
                    size: r.scaledWidth(14),
                    color: isDark ? Colors.black : Colors.white)
                : null,
          ),
          SizedBox(width: r.scaledWidth(10)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: r.responsiveFontSize(12.5),
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Li e aceito os '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: _showTermsModal,
                      child: Text(
                        'Termos de Uso',
                        style: TextStyle(
                          fontSize: r.responsiveFontSize(12.5),
                          color: primaryGold,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: primaryGold,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' da aplicação'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, animation, _) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic)),
        child: _TermsOfUseModal(
          onAccept: () {
            setState(() => _agreedToTerms = true);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Widget _buildOtpForm(ResponsiveHelper r) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: r.scaledWidth(12), vertical: r.scaledHeight(10)),
          decoration: BoxDecoration(
            color: primaryGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _pendingPhone ?? '',
            style: TextStyle(
              fontSize: r.responsiveFontSize(13),
              fontWeight: FontWeight.w600,
              color: primaryGold,
            ),
          ),
        ),
        SizedBox(height: r.scaledHeight(20)),
        OtpBoxInput(
          controller: otpController,
          accentColor: primaryGold,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildField(
    ResponsiveHelper r, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? label,
    TextInputType? keyboardType,
    bool obscure = false,
    int? maxLength,
    String? prefix,
    Widget? suffix,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.scaledHeight(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: r.responsiveFontSize(13),
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            SizedBox(height: r.scaledHeight(6)),
          ],
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            maxLength: maxLength,
            inputFormatters: keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            style: TextStyle(
              fontSize: r.responsiveFontSize(15),
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            cursorColor: primaryGold,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              counterText: '',
              suffixIcon: suffix,
              prefixText: prefix,
              prefixStyle: TextStyle(
                fontSize: r.responsiveFontSize(15),
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: r.scaledWidth(16), vertical: r.scaledHeight(14)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryGold, width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ResponsiveHelper r) {
    return Container(
      padding: EdgeInsets.all(r.scaledWidth(12)),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withAlpha((0.25 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Colors.redAccent, size: r.scaledWidth(18)),
          SizedBox(width: r.scaledWidth(8)),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Colors.red.shade200,
                fontSize: r.responsiveFontSize(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(ResponsiveHelper r) {
    final label = _mode == AuthMode.login
        ? 'Entrar'
        : _mode == AuthMode.register
            ? 'Criar conta'
            : 'Verificar';

    return Container(
      width: double.infinity,
      height: r.scaledHeight(56),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha((0.5 * 255).round())
                : Colors.black.withAlpha((0.15 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withAlpha((0.05 * 255).round())
                : Colors.white.withAlpha((0.8 * 255).round()),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha((0.3 * 255).round())
                : Colors.black.withAlpha((0.08 * 255).round()),
            blurRadius: 6,
            offset: const Offset(2, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading || (_mode == AuthMode.register && !_agreedToTerms)
            ? null
            : (_mode == AuthMode.otp ? _handleOtp : _handleContinue),
        style: ElevatedButton.styleFrom(
          backgroundColor: (_mode == AuthMode.register && !_agreedToTerms)
              ? (isDark ? Colors.grey[800] : Colors.grey[300])
              : primaryGold,
          foregroundColor: isDark ? Colors.black : darkBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: r.scaledWidth(22),
                height: r.scaledWidth(22),
                child: const CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2.5),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: r.responsiveFontSize(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildFooter(ResponsiveHelper r) {
    if (_mode == AuthMode.otp) {
      return TextButton(
        onPressed: isLoading ? null : _resendOtp,
        child: Text(
          'Reenviar código',
          style: TextStyle(
              color: primaryGold, fontSize: r.responsiveFontSize(13)),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Terms of Use Modal ───────────────────────────────────────────────────────

class _TermsOfUseModal extends StatefulWidget {
  final VoidCallback onAccept;
  const _TermsOfUseModal({required this.onAccept});

  @override
  State<_TermsOfUseModal> createState() => _TermsOfUseModalState();
}

class _TermsOfUseModalState extends State<_TermsOfUseModal> {
  final ScrollController _scroll = ScrollController();
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_reachedEnd &&
          _scroll.offset >= _scroll.position.maxScrollExtent - 40) {
        setState(() => _reachedEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = AppColors.primaryGold;
    final bg = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subCol = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : Colors.black.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Termos de Uso',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: textCol)),
                        const SizedBox(height: 2),
                        Text('Leia com atenção antes de continuar',
                            style: TextStyle(fontSize: 12, color: subCol)),
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
                          size: 18, color: textCol),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07)),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _buildContent(textCol, subCol, gold),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (!_reachedEnd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: subCol),
                          const SizedBox(width: 4),
                          Text('Role para ler tudo',
                              style:
                                  TextStyle(fontSize: 11, color: subCol)),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Aceitar e continuar',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
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

  Widget _buildContent(Color textCol, Color subCol, Color gold) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('1. Aceitação dos Termos', textCol, gold),
        _body(
          'Ao criar uma conta na aplicação Troco Seguro — Motorista, declara que leu, compreendeu e aceita os presentes Termos de Uso. Se não concordar com algum dos termos aqui descritos, não deverá utilizar a aplicação.',
          subCol,
        ),
        _section('2. Sobre a Aplicação', textCol, gold),
        _body(
          'O Troco Seguro é uma plataforma digital de pagamento destinada a motoristas de táxi em Angola. Permite receber pagamentos dos passageiros de forma segura, gerir a carteira digital e acompanhar as viagens realizadas.',
          subCol,
        ),
        _section('3. Elegibilidade', textCol, gold),
        _body(
          'Para utilizar a aplicação como motorista, deverá:\n\n• Ter idade mínima de 18 anos;\n• Possuir carta de condução válida emitida em Angola;\n• Dispor de um veículo devidamente registado e seguro;\n• Fornecer informações verdadeiras e exactas no registo.',
          subCol,
        ),
        _section('4. Conta e Segurança', textCol, gold),
        _body(
          'É responsável pela confidencialidade do seu PIN de acesso. Não deverá partilhá-lo com terceiros. Em caso de suspeita de acesso não autorizado, deve contactar imediatamente o suporte.\n\nA Troco Seguro reserva-se o direito de suspender ou encerrar contas que violem estes termos.',
          subCol,
        ),
        _section('5. Pagamentos e Carteira', textCol, gold),
        _body(
          'Os valores recebidos são creditados na carteira digital do motorista após confirmação do pagamento pelo passageiro. Os levantamentos estão sujeitos às condições e limites definidos pela plataforma.\n\nA Troco Seguro não se responsabiliza por atrasos causados por falhas nas instituições bancárias.',
          subCol,
        ),
        _section('6. Comportamento do Motorista', textCol, gold),
        _body(
          'O motorista compromete-se a:\n\n• Prestar um serviço seguro e de qualidade;\n• Não utilizar a plataforma para fins fraudulentos;\n• Respeitar os passageiros e as leis de trânsito vigentes em Angola;\n• Não manipular avaliações ou transações.',
          subCol,
        ),
        _section('7. Privacidade dos Dados', textCol, gold),
        _body(
          'Os dados recolhidos (nome, número de telefone, localização, histórico de viagens) são utilizados exclusivamente para o funcionamento da plataforma e melhoria dos serviços. Não serão vendidos a terceiros sem o seu consentimento explícito.',
          subCol,
        ),
        _section('8. Alterações aos Termos', textCol, gold),
        _body(
          'A Troco Seguro pode actualizar estes Termos de Uso a qualquer momento. As alterações serão notificadas através da aplicação. O uso continuado após a notificação implica a aceitação dos novos termos.',
          subCol,
        ),
        _section('9. Contacto', textCol, gold),
        _body(
          'Para dúvidas ou reclamações relacionadas com estes Termos de Uso, entre em contacto connosco através do suporte disponível na aplicação ou pelo e-mail de suporte oficial da plataforma.',
          subCol,
        ),
        const SizedBox(height: 8),
        Divider(color: gold.withValues(alpha: 0.20)),
        const SizedBox(height: 8),
        Text(
          'Última actualização: Junho de 2025',
          style: TextStyle(fontSize: 11, color: subCol),
        ),
      ],
    );
  }

  Widget _section(String title, Color textCol, Color gold) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: gold,
              margin: const EdgeInsets.only(right: 8)),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textCol)),
          ),
        ],
      ),
    );
  }

  Widget _body(String text, Color subCol) {
    return Text(text,
        style: TextStyle(fontSize: 13, color: subCol, height: 1.65));
  }
}

// ─── Password Recovery Modal (3 passos) ──────────────────────────────────────

class _PasswordRecoveryModal extends StatefulWidget {
  const _PasswordRecoveryModal();

  @override
  State<_PasswordRecoveryModal> createState() => _PasswordRecoveryModalState();
}

class _PasswordRecoveryModalState extends State<_PasswordRecoveryModal> {
  final ApiService _api = ApiService();
  int _step = 1;
  bool _busy = false;
  CountryCode _selectedCountry = kCountryCodes.first;
  String _formattedPhone = '';

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _cfmPinCtrl = TextEditingController();
  bool _obscurePin = true;
  bool _obscureCfm = true;
  String? _resetToken;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPinCtrl.dispose();
    _cfmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _step1() async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _err('Insira o número de telefone');
      return;
    }
    final phone = digits.startsWith(_selectedCountry.dialCode)
        ? '+$digits'
        : '+${_selectedCountry.dialCode}$digits';
    _formattedPhone = phone;
    setState(() => _busy = true);
    final res = await _api.forgotPassword(phone);
    setState(() => _busy = false);
    if (res.isSuccess) {
      setState(() => _step = 2);
    } else {
      _err(res.error ?? 'Erro ao enviar código');
    }
  }

  Future<void> _step2() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      _err('Código deve ter 6 dígitos');
      return;
    }
    setState(() => _busy = true);
    final res = await _api.verifyForgotPasswordOtp(
        phoneNumber: _formattedPhone, otp: otp);
    setState(() => _busy = false);
    if (res.isSuccess && res.data != null) {
      _resetToken = res.data;
      setState(() => _step = 3);
    } else {
      _err(res.error ?? 'Código inválido ou expirado');
    }
  }

  Future<void> _step3() async {
    final pin = _newPinCtrl.text.trim();
    final cfm = _cfmPinCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _err('PIN deve ter 6 dígitos numéricos');
      return;
    }
    if (pin != cfm) {
      _err('PINs não coincidem');
      return;
    }
    setState(() => _busy = true);
    final res = await _api.resetPassword(
        resetToken: _resetToken!, newPassword: pin);
    setState(() => _busy = false);
    if (res.isSuccess) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Senha redefinida com sucesso. Faça login.'),
          backgroundColor: AppColors.primaryGold,
        ));
      }
    } else {
      _err(res.error ?? 'Erro ao redefinir senha');
    }
  }

  void _err(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = AppColors.primaryGold;
    final bg = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1C1B1B) : const Color(0xFFF0F0F0);
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
              child: Row(
                children: [
                  if (_step > 1)
                    GestureDetector(
                      onTap: () => setState(() => _step--),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 18, color: textCol),
                      ),
                    )
                  else
                    const SizedBox(width: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Recuperar Senha',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textCol)),
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
                          size: 18, color: textCol),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(3, (i) {
                  final active = i + 1 <= _step;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active
                            ? gold
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _step == 1
                    ? _buildStep1(isDark, gold, cardBg, textCol)
                    : _step == 2
                        ? _buildStep2(isDark, gold, cardBg, textCol)
                        : _buildStep3(isDark, gold, cardBg, textCol),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(bool isDark, Color gold, Color cardBg, Color textCol) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Passo 1 de 3',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.35))),
      const SizedBox(height: 8),
      Text('Qual é o seu número?',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: textCol)),
      const SizedBox(height: 8),
      Text('Enviaremos um código por SMS.',
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.5))),
      const SizedBox(height: 28),
      Text('Número de telefone',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700])),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CountryCodeSelector(
            selected: _selectedCountry,
            isDark: isDark,
            onChanged: (c) => setState(() => _selectedCountry = c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '9XX XXX XXX',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1.2)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: gold, width: 1.6)),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      _submitButton('Enviar código', _step1, isDark, gold),
    ]);
  }

  Widget _buildStep2(bool isDark, Color gold, Color cardBg, Color textCol) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Passo 2 de 3',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.35))),
      const SizedBox(height: 8),
      Text('Insira o código recebido',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: textCol)),
      const SizedBox(height: 8),
      Text('Código de 6 dígitos enviado para $_formattedPhone',
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.5))),
      const SizedBox(height: 28),
      OtpBoxInput(controller: _otpCtrl, accentColor: gold, isDark: isDark),
      const SizedBox(height: 28),
      _submitButton('Verificar código', _step2, isDark, gold),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: _busy ? null : _step1,
          child:
              Text('Reenviar código', style: TextStyle(color: gold, fontSize: 13)),
        ),
      ),
    ]);
  }

  Widget _buildStep3(bool isDark, Color gold, Color cardBg, Color textCol) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Passo 3 de 3',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.35))),
      const SizedBox(height: 8),
      Text('Defina um novo PIN',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: textCol)),
      const SizedBox(height: 8),
      Text('O PIN deve ter exactamente 6 dígitos numéricos.',
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.5))),
      const SizedBox(height: 28),
      _inputField('Novo PIN', _newPinCtrl, isDark, gold,
          icon: Icons.lock_outline,
          type: TextInputType.number,
          maxLen: 6,
          obscure: _obscurePin,
          onToggleObscure: () =>
              setState(() => _obscurePin = !_obscurePin)),
      const SizedBox(height: 14),
      _inputField('Confirmar PIN', _cfmPinCtrl, isDark, gold,
          icon: Icons.lock_outline,
          type: TextInputType.number,
          maxLen: 6,
          obscure: _obscureCfm,
          onToggleObscure: () =>
              setState(() => _obscureCfm = !_obscureCfm)),
      const SizedBox(height: 28),
      _submitButton('Confirmar novo PIN', _step3, isDark, gold),
    ]);
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl,
    bool isDark,
    Color gold, {
    required IconData icon,
    TextInputType type = TextInputType.text,
    int? maxLen,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: type,
          obscureText: obscure,
          maxLength: maxLen,
          decoration: InputDecoration(
            counterText: '',
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: gold,
                        size: 20),
                    onPressed: onToggleObscure)
                : null,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1.2)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1.2)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: gold, width: 1.6)),
          ),
        ),
      ],
    );
  }

  Widget _submitButton(
      String label, Future<void> Function() onPressed, bool isDark, Color gold) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
