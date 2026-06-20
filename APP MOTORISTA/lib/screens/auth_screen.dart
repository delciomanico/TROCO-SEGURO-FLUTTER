import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/widgets/custom_widgets.dart'
    show CustomInput;
import 'package:troco_seguro_motorista/services/api_service.dart';

class AuthScreen extends StatefulWidget {
  final Function(
    String name,
    String phone,
    String pin, {
    String? accessToken,
    String? refreshToken,
  }) onAuth;

  const AuthScreen({
    super.key,
    required this.onAuth,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  int step = 1; // 1: auth, 3: otp (apenas registro)
  bool isLoading = false;

  final ApiService _api = ApiService();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController licensePlateController = TextEditingController();
  final TextEditingController vehicleModelController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  String? errorMessage;
  String? successMessage;

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    otpController.dispose();
    licensePlateController.dispose();
    vehicleModelController.dispose();
    pinController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('244')) {
      return '+$cleaned';
    }
    return '+244$cleaned';
  }

  Future<void> _registerFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('ts_fcm_token');
      if (token == null || token.isEmpty) {
        token = 'placeholder_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('ts_fcm_token', token);
      }
      await _api.updateFcmToken(token);
    } catch (e) {
      debugPrint('FCM token register failed: $e');
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
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: const _PasswordRecoveryModal(),
      ),
    );
  }

  Future<void> _handleContinue() async {
    setState(() {
      errorMessage = null;
      successMessage = null;
    });

    if (step == 1) {
      // Validar dados iniciais
      if (phoneController.text.length < 9) {
        setState(() => errorMessage = 'Digite um número válido');
        return;
      }

      if (!isLogin && nameController.text.isEmpty) {
        setState(() => errorMessage = 'Digite seu nome');
        return;
      }

      String pin = pinController.text;
      if (pin.length != 6) {
        setState(() => errorMessage = 'Digite o PIN completo (6 dígitos)');
        return;
      }

      setState(() => isLoading = true);

      final phoneNumber = _formatPhoneNumber(phoneController.text);

      try {
        if (isLogin) {
          // LOGIN via API
          final result = await _api.login(
            phoneNumber: phoneNumber,
            password: pin,
          );

          if (result.isSuccess) {
            _registerFcmToken();
            widget.onAuth(
              result.data?.driver?.fullName ?? (nameController.text.isEmpty ? 'Motorista' : nameController.text),
              phoneController.text,
              pin,
              accessToken: result.data?.accessToken,
              refreshToken: result.data?.refreshToken,
            );
          } else {
            setState(() => errorMessage = result.error ?? 'Erro ao fazer login');
          }
        } else {
          // REGISTRO - Chama a API de registro
          final result = await _api.register(
            fullName: nameController.text,
            phoneNumber: phoneNumber,
            password: pin,
          );

          if (result.isSuccess) {
            setState(() {
              isLogin = true; // Volta para o login
              successMessage = 'Conta criada com sucesso! Já pode entrar.';
              // Limpa o PIN para segurança, mas mantém o telefone
              pinController.clear();
            });
          } else {
            setState(() => errorMessage = result.error ?? 'Erro ao registrar');
          }
        }
      } catch (e) {
        setState(() => errorMessage = 'Erro inesperado. Tente novamente.');
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    } else if (step == 3) {
      // Verificar OTP
      if (otpController.text.length != 6) {
        setState(() => errorMessage = 'Digite o código de 6 dígitos');
        return;
      }

      setState(() => isLoading = true);

      final phoneNumber = _formatPhoneNumber(phoneController.text);
      final result = await _api.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otpController.text,
      );

      setState(() => isLoading = false);

      if (result.isSuccess) {
        String pin = pinController.text;
        widget.onAuth(
          nameController.text,
          phoneController.text,
          pin,
          accessToken: result.data?.accessToken,
          refreshToken: result.data?.refreshToken,
        );
      } else {
        setState(() => errorMessage = result.error ?? 'Código inválido');
      }
    }
  }

  void _handleBack() {
    if (step == 3) {
      setState(() {
        step = 1;
        otpController.clear();
        errorMessage = null;
        successMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageGradient = isDark
        ? AppColors.darkScreenGradient
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.lightBackground, AppColors.lightSurface],
          );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (step > 1) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: isLoading ? null : _handleBack,
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark
                                      ? Colors.white
                                      : AppColors.primaryBlue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 16,
                                ),
                                label: const Text('Voltar'),
                              ),
                            ),
                            SizedBox(height: responsive.scaledHeight(12)),
                          ],
                          _buildHeader(responsive),
                          SizedBox(height: responsive.scaledHeight(28)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.scaledWidth(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (step == 1) _buildPhoneStep(responsive),
                                if (step == 3) _buildOtpStep(responsive),
                              ],
                            ),
                          ),
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

  Widget _buildHeader(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textDark;
    final subtitleColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Column(
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: responsive.scaledWidth(112),
          height: responsive.scaledWidth(112),
          fit: BoxFit.contain,
        ),
        SizedBox(height: responsive.scaledHeight(18)),
        Text(
          step == 1
              ? (isLogin ? 'Entrar na conta' : 'Criar conta')
              : _getHeaderTitle(),
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(26),
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: responsive.scaledHeight(8)),
        Text(
          _getHeaderSubtitle(),
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(14),
            fontWeight: FontWeight.w500,
            color: subtitleColor,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: responsive.scaledHeight(16)),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: responsive.scaledWidth(72),
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.adaptiveAccent(context),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }

  String _getHeaderTitle() {
    switch (step) {
      case 3:
        return 'Confirmar código';
      default:
        return isLogin ? 'Entrar na conta' : 'Criar conta';
    }
  }

  String _getHeaderSubtitle() {
    switch (step) {
      case 3:
        return 'Digite o código SMS para validar o cadastro.';
      default:
        return 'Acesse com o seu número e continue a trabalhar com segurança.';
    }
  }

  ButtonStyle _primaryButtonStyle(ResponsiveHelper responsive) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.adaptiveAccent(context),
      foregroundColor: AppColors.textDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      minimumSize: Size(
        double.infinity,
        responsive.responsiveButtonHeight(),
      ),
    );
  }

  Widget _buildPhoneStep(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null) _buildErrorMessage(responsive),
        if (!isLogin) ...[
          CustomInput(
            label: '',
            hint: 'Nome completo',
            controller: nameController,
            prefixIcon: Icons.person_outline,
            textColor: isDark ? Colors.white : null,
          ),
          SizedBox(height: responsive.scaledHeight(16)),
        ],
        CustomInput(
          label: '',
          hint: '9XX XXX XXX',
          controller: phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          prefixText: '+244 ',
          textColor: isDark ? Colors.white : null,
        ),
        SizedBox(height: responsive.scaledHeight(18)),
        _buildPinInputSection(responsive),
        SizedBox(height: responsive.scaledHeight(32)),
        SizedBox(
          width: double.infinity,
          height: responsive.responsiveButtonHeight(),
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleContinue,
            style: _primaryButtonStyle(responsive),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    'CONTINUAR',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(16)),
        if (isLogin)
          TextButton(
            onPressed: _handleRecover,
            child: Text(
              'Esqueceu a password?',
              style: TextStyle(
                color: AppColors.adaptiveAccent(context),
                fontSize: responsive.responsiveFontSize(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        SizedBox(height: responsive.scaledHeight(8)),
        TextButton(
          onPressed: () {
            setState(() {
              isLogin = !isLogin;
              errorMessage = null;
              successMessage = null;
            });
          },
          child: RichText(
            text: TextSpan(
              text: isLogin ? 'Não tem conta? ' : 'Já tem conta? ',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondary,
                fontSize: responsive.responsiveFontSize(14),
              ),
              children: [
                TextSpan(
                  text: isLogin ? 'Registar' : 'Entrar',
                  style: TextStyle(
                    color: AppColors.adaptiveAccent(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinInputSection(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomInput(
      label: '',
      hint: isLogin ? 'PIN de acesso' : 'Crie o seu PIN',
      controller: pinController,
      keyboardType: TextInputType.number,
      obscureText: true,
      prefixIcon: Icons.lock_outline,
      maxLength: 6,
      textColor: isDark ? Colors.white : null,
    );
  }

  Widget _buildOtpStep(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (successMessage != null)
          Container(
            margin: EdgeInsets.only(bottom: responsive.scaledHeight(16)),
            padding: EdgeInsets.all(responsive.responsiveSpacing()),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.adaptiveAccent(context).withOpacity(0.16)
                  : AppColors.primaryOrange.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.adaptiveAccent(context).withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.adaptiveAccent(context),
                  size: 20,
                ),
                SizedBox(width: responsive.scaledWidth(8)),
                Expanded(
                  child: Text(
                    successMessage!,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textDark,
                      fontSize: responsive.responsiveFontSize(13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (errorMessage != null) _buildErrorMessage(responsive),
        CustomInput(
          label: '',
          hint: 'Código de verificação',
          controller: otpController,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.sms_outlined,
          textColor: isDark ? Colors.white : null,
          maxLength: 6,
        ),
        SizedBox(height: responsive.scaledHeight(16)),
        TextButton(
          onPressed: () async {
            final phoneNumber = _formatPhoneNumber(phoneController.text);
            await _api.resendOtp(phoneNumber);
            setState(() {
              successMessage = 'Código reenviado para $phoneNumber';
            });
          },
          child: Text(
            'Reenviar código',
            style: TextStyle(
              color: AppColors.adaptiveAccent(context),
              fontSize: responsive.responsiveFontSize(14),
            ),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(16)),
        SizedBox(
          width: double.infinity,
          height: responsive.responsiveButtonHeight(),
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleContinue,
            style: _primaryButtonStyle(responsive),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    'VERIFICAR',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: responsive.scaledHeight(16)),
      padding: EdgeInsets.all(responsive.responsiveSpacing()),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A1F2A) : const Color(0xFFFFF2F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC3CD)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFE0526B), size: 20),
          SizedBox(width: responsive.scaledWidth(8)),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFFFD5DD) : const Color(0xFFB23A4E),
                fontSize: responsive.responsiveFontSize(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Password Recovery Modal (3 steps) ───────────────────────────────────────
class _PasswordRecoveryModal extends StatefulWidget {
  const _PasswordRecoveryModal();

  @override
  State<_PasswordRecoveryModal> createState() => _PasswordRecoveryModalState();
}

class _PasswordRecoveryModalState extends State<_PasswordRecoveryModal> {
  final ApiService _api = ApiService();
  int _step = 1;
  bool _busy = false;

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
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _err('Insira o número de telefone');
      return;
    }
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
      phoneNumber: _phoneCtrl.text.trim(),
      otp: otp,
    );
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
      resetToken: _resetToken!,
      newPassword: pin,
    );
    setState(() => _busy = false);
    if (res.isSuccess) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Senha redefinida com sucesso. Faça login.'),
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
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;

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
                            size: 18, color: textColor),
                      ),
                    )
                  else
                    const SizedBox(width: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recuperar Senha',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textColor),
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
                          size: 18, color: textColor),
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
                    ? _buildStep1(isDark, gold, textColor)
                    : _step == 2
                        ? _buildStep2(isDark, gold, textColor)
                        : _buildStep3(isDark, gold, textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(bool isDark, Color gold, Color textColor) {
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
              fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
      const SizedBox(height: 8),
      Text('Enviaremos um código por SMS para redefinir o seu PIN.',
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.5))),
      const SizedBox(height: 28),
      _inputField('Número de telefone (+244...)', _phoneCtrl, isDark, gold,
          icon: Icons.phone_outlined, type: TextInputType.phone),
      const SizedBox(height: 28),
      _submitButton('Enviar código', _step1, isDark, gold),
    ]);
  }

  Widget _buildStep2(bool isDark, Color gold, Color textColor) {
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
              fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
      const SizedBox(height: 8),
      Text('Código de 6 dígitos enviado para ${_phoneCtrl.text.trim()}',
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.5))),
      const SizedBox(height: 28),
      _inputField('Código OTP (6 dígitos)', _otpCtrl, isDark, gold,
          icon: Icons.lock_outline, type: TextInputType.number, maxLen: 6),
      const SizedBox(height: 28),
      _submitButton('Verificar código', _step2, isDark, gold),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: _busy ? null : _step1,
          child: Text('Reenviar código',
              style: TextStyle(color: gold, fontSize: 13)),
        ),
      ),
    ]);
  }

  Widget _buildStep3(bool isDark, Color gold, Color textColor) {
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
              fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
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
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      maxLength: maxLen,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: Icon(icon, color: gold),
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
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gold, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.45),
        ),
      ),
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


