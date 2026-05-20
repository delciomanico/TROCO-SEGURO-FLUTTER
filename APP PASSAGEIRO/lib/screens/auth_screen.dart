import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/models/user.dart';

enum AuthMode { choice, login, register }

class AuthScreen extends StatefulWidget {
  final Function(User user, String pin,
      {String? accessToken, String? refreshToken}) onAuth;

  const AuthScreen({super.key, required this.onAuth});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  // simplified single-screen flow: no multi-step state
  bool isLoading = false;
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

  AuthMode _mode = AuthMode.choice;

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    pinController.dispose();
    otpController.dispose();
    super.dispose();
  }

  String _formatPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.startsWith('244') ? '+$cleaned' : '+244$cleaned';
  }

  Future<void> _handleContinue() async {
    setState(() => errorMessage = null);

    // Single-screen flow: validate inputs then call login or register
    if (phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
      setState(() => errorMessage = 'Digite um número válido');
      return;
    }
    if (!isLogin && nameController.text.isEmpty) {
      setState(() => errorMessage = 'Digite seu nome');
      return;
    }
    if (pinController.text.length != 6) {
      setState(() => errorMessage = 'PIN deve ter 6 dígitos');
      return;
    }

    setState(() => isLoading = true);
    final phone = _formatPhone(phoneController.text);

    if (isLogin) {
      final result =
          await _api.login(phoneNumber: phone, password: pinController.text);
      setState(() => isLoading = false);

      if (result.isSuccess) {
        final user = result.data?.user ?? _createUserFromInput(phone);
        widget.onAuth(
          user,
          pinController.text,
          accessToken: result.data?.accessToken,
          refreshToken: result.data?.refreshToken,
        );
      } else {
        setState(() => errorMessage = result.error ?? 'Falha no login');
      }
    } else {
      final result = await _api.register(
        fullName: nameController.text,
        phoneNumber: phone,
        password: pinController.text,
      );
      setState(() => isLoading = false);

      if (result.isSuccess) {
        // após registro, tentar logar automaticamente
        setState(() => isLoading = true);
        final login =
            await _api.login(phoneNumber: phone, password: pinController.text);
        setState(() => isLoading = false);
        if (login.isSuccess) {
          final user = login.data?.user ?? _createUserFromInput(phone);
          widget.onAuth(user, pinController.text,
              accessToken: login.data?.accessToken,
              refreshToken: login.data?.refreshToken);
        } else {
          setState(() =>
              errorMessage = 'Registro efetuado. Por favor verifique seu SMS.');
        }
      } else {
        setState(() => errorMessage = result.error ?? 'Falha no registro');
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void _handleBack() {
    setState(() {
      errorMessage = null;
      // simply clear transient inputs when backing
      pinController.clear();
      otpController.clear();
    });
  }

  void _handleRecover() {
    // simple placeholder: show a SnackBar. Integrate real recovery flow if available.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Iniciar recuperação de credenciais'),
    ));
  }

  User _createUserFromInput(String phone) {
    return User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: nameController.text.isEmpty ? 'Usuário' : nameController.text,
      phoneNumber: phone,
      balance: 0,
      isLoggedIn: true,
      role: 'PASSENGER',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    isDark = Theme.of(context).brightness == Brightness.dark;
    primaryGold = const Color(0xFFD4AF37);
    secondaryGold = const Color(0xFFC5A028);
    darkBg = const Color(0xFF121212);
    darkCard = const Color(0xFF1E1E1E);
    lightBg = const Color(0xFFFFFFFF);
    lightCard = const Color(0xFFF2F2F2);
    textColor = isDark ? Colors.white : darkBg;

    return Scaffold(
      backgroundColor: isDark ? darkBg : lightBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image - only show in dark mode
          if (isDark)
            Image.asset(
              'assets/images/card_fundo.jpg',
              fit: BoxFit.cover,
            ),
          // Blur effect - only in dark mode
          if (isDark)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                color: (isDark ? darkBg : lightBg).withOpacity(0.3),
              ),
            ),
          // Content
          SafeArea(
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
                                        isLogin = true;
                                        errorMessage = null;
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
                              _buildSteps(r),
                              SizedBox(height: r.scaledHeight(12)),
                              _buildTitle(r),
                              SizedBox(height: r.scaledHeight(20)),
                              _buildStep1(r),
                              _buildField(
                                r,
                                controller: pinController,
                                hint: '••••••',
                                icon: Icons.lock_outline,
                                keyboardType: TextInputType.number,
                                obscure: true,
                                maxLength: 6,
                              ),
                              if (errorMessage != null) ...[
                                SizedBox(height: r.scaledHeight(16)),
                                _buildError(r),
                              ],
                              SizedBox(height: r.scaledHeight(18)),
                              _buildButton(r),
                              SizedBox(height: r.scaledHeight(18)),
                              _buildToggle(r),
                              SizedBox(height: r.scaledHeight(40)),
                            ],
                          ),
                        ),
                      ),
                    ],
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
              Image.asset('assets/images/logo.png',
                  width: r.scaledWidth(160),
                  height: r.scaledWidth(160),
                  fit: BoxFit.contain),
              SizedBox(height: r.scaledHeight(18)),
              Text('TROCO SEGURO',
                  style: TextStyle(
                      color: primaryGold,
                      fontSize: r.responsiveFontSize(24),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6)),
              SizedBox(height: r.scaledHeight(8)),
              Text('Pagamento digital para táxis',
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[800],
                      fontSize: r.responsiveFontSize(14))),
            ],
          ),
        ),
        SizedBox(height: r.scaledHeight(36)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.scaledWidth(36)),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: r.scaledHeight(56),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    // Sombra inferior (profundidade)
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withAlpha((0.5 * 255).round())
                          : Colors.black.withAlpha((0.15 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    // Sombra superior (destaque 3D)
                    BoxShadow(
                      color: isDark
                          ? Colors.white.withAlpha((0.05 * 255).round())
                          : Colors.white.withAlpha((0.8 * 255).round()),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                      spreadRadius: 0,
                    ),
                    // Sombra lateral para profundidade
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
                  onPressed: () => setState(() {
                    _mode = AuthMode.register;
                    isLogin = false;
                    errorMessage = null;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? darkCard : Colors.white,
                    foregroundColor: primaryGold,
                    side: BorderSide(color: primaryGold, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Criar conta',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(16),
                          fontWeight: FontWeight.w800,
                          color: primaryGold)),
                ),
              ),
              SizedBox(height: r.scaledHeight(12)),
              Container(
                width: double.infinity,
                height: r.scaledHeight(56),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    // Sombra inferior (profundidade)
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withAlpha((0.5 * 255).round())
                          : Colors.black.withAlpha((0.15 * 255).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    // Sombra superior (destaque 3D)
                    BoxShadow(
                      color: isDark
                          ? Colors.white.withAlpha((0.05 * 255).round())
                          : Colors.white.withAlpha((0.8 * 255).round()),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                      spreadRadius: 0,
                    ),
                    // Sombra lateral para profundidade
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
                  onPressed: () => setState(() {
                    _mode = AuthMode.login;
                    isLogin = true;
                    errorMessage = null;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGold,
                    foregroundColor: isDark ? Colors.black : darkBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Entrar',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(16),
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // animation removed — login/register screens won't show logo or animation

  Widget _buildHeader(ResponsiveHelper r) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.scaledWidth(16),
        vertical: r.scaledHeight(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: r.scaledWidth(110),
              height: r.scaledWidth(110),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [primaryGold, secondaryGold]),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withAlpha((0.35 * 255).round())
                        : Colors.black.withAlpha((0.12 * 255).round()),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(r.scaledWidth(12)),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: r.scaledWidth(86),
                    height: r.scaledWidth(86),
                    fit: BoxFit.contain,
                    semanticLabel: 'Troco Seguro logo',
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: r.scaledHeight(8)),
        ],
      ),
    );
  }

  Widget _buildSteps(ResponsiveHelper r) {
    // single-screen now — no step indicator
    return const SizedBox.shrink();
  }

  Widget _stepDot(ResponsiveHelper r, int s) {
    // simplified dot (no active state in single-screen)
    return Container(
      width: r.scaledWidth(24),
      height: r.scaledWidth(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
      ),
      child: Center(
        child: Text(
          '$s',
          style: TextStyle(
            fontSize: r.responsiveFontSize(11),
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _stepLine(ResponsiveHelper r, bool active) {
    return Container(
      height: 2,
      margin: EdgeInsets.symmetric(horizontal: r.scaledWidth(4)),
      color:
          active ? primaryGold : (isDark ? Colors.grey[800] : Colors.grey[300]),
    );
  }

  Widget _buildTitle(ResponsiveHelper r) {
    String title = isLogin ? 'Bem-vindo!' : 'Criar conta';
    String subtitle =
        isLogin ? 'Entre com seu telefone' : 'Preencha seus dados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.responsiveFontSize(20),
            fontWeight: FontWeight.w800,
            color: primaryGold,
            letterSpacing: 1.2,
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

  Widget _buildStep1(ResponsiveHelper r) {
    return Column(
      children: [
        if (!isLogin) ...[
          _buildField(
            r,
            controller: nameController,
            hint: 'Nome completo',
            icon: Icons.person_outline,
          ),
          SizedBox(height: r.scaledHeight(16)),
        ],
        _buildField(
          r,
          controller: phoneController,
          hint: '9XX XXX XXX',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          prefix: '+244 ',
        ),
      ],
    );
  }

  Widget _buildStep2(ResponsiveHelper r) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: r.scaledWidth(12), vertical: r.scaledHeight(8)),
          decoration: BoxDecoration(
            color: primaryGold.withAlpha((0.10 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '+244 ${phoneController.text}',
            style: TextStyle(
              fontSize: r.responsiveFontSize(13),
              fontWeight: FontWeight.w600,
              color: primaryGold,
            ),
          ),
        ),
        SizedBox(height: r.scaledHeight(20)),
        _buildField(
          r,
          controller: pinController,
          hint: '••••••',
          icon: Icons.lock_outline,
          keyboardType: TextInputType.number,
          obscure: true,
          maxLength: 6,
        ),
      ],
    );
  }

  Widget _buildStep3(ResponsiveHelper r) {
    return _buildField(
      r,
      controller: otpController,
      hint: 'Código de 6 dígitos',
      icon: Icons.sms_outlined,
      keyboardType: TextInputType.number,
      maxLength: 6,
    );
  }

  Widget _buildField(
    ResponsiveHelper r, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    int? maxLength,
    String? prefix,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.scaledHeight(8)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark
              ? [
                  // Mantem profundidade apenas no modo escuro.
                  BoxShadow(
                    color: Colors.black.withAlpha((0.5 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white.withAlpha((0.05 * 255).round()),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    blurRadius: 6,
                    offset: const Offset(2, 2),
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
        child: TextField(
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
            prefixIcon: Icon(icon, color: primaryGold),
            prefixText: prefix,
            prefixStyle: TextStyle(
              fontSize: r.responsiveFontSize(15),
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
            filled: true,
            fillColor: isDark ? darkCard : lightCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryGold, width: 2),
            ),
          ),
        ),
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
    return Container(
      width: double.infinity,
      height: r.scaledHeight(52),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          // Sombra inferior (profundidade)
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha((0.5 * 255).round())
                : Colors.black.withAlpha((0.15 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          // Sombra superior (destaque 3D)
          BoxShadow(
            color: isDark
                ? Colors.white.withAlpha((0.05 * 255).round())
                : Colors.white.withAlpha((0.8 * 255).round()),
            blurRadius: 4,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
          // Sombra lateral para profundidade
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
        onPressed: isLoading ? null : _handleContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: isDark ? Colors.black : darkBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: r.scaledWidth(22),
                height: r.scaledWidth(22),
                child: const CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                isLogin ? 'Entrar' : 'Criar conta',
                style: TextStyle(
                  fontSize: r.responsiveFontSize(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildToggle(ResponsiveHelper r) {
    if (isLogin) {
      // On login: only show recover link (creation handled from choice screen)
      return Column(
        children: [
          SizedBox(height: r.scaledHeight(8)),
          TextButton(
            onPressed: _handleRecover,
            child: Text('Recuperar credenciais',
                style: TextStyle(
                    color: primaryGold, fontSize: r.responsiveFontSize(13))),
          ),
        ],
      );
    }

    // On register: do not show link to login (choice screen handles switching)
    return const SizedBox.shrink();
  }
}
