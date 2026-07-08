import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.qr_code_rounded,
      title: 'Receba Pagamentos',
      description:
          'Mostre seu QR Code único e receba pagamentos dos passageiros de forma instantânea e segura.',
    ),
    OnboardingPage(
      icon: Icons.trending_up_rounded,
      title: 'Acompanhe seus Ganhos',
      description:
          'Veja em tempo real seus ganhos diários, semanais e mensais. Tenha controle total do seu negócio.',
    ),
    OnboardingPage(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Saque Fácil',
      description:
          'Transfira seus ganhos para sua conta bancária ou MCX Express quando quiser. Rápido e sem complicação.',
    ),
    OnboardingPage(
      icon: Icons.verified_user_rounded,
      title: 'Segurança Total',
      description:
          'Todas as transações são protegidas com PIN e biometria. Seus dados estão seguros conosco.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              Colors.black.withValues(alpha: 0.35),
              AppColors.darkBackground.withValues(alpha: 0.94),
            ]
          : [
              Colors.white.withValues(alpha: 0.55),
              AppColors.lightBackground.withValues(alpha: 0.96),
            ],
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/card_fundo.jpg', fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child:
                Container(decoration: BoxDecoration(gradient: overlayGradient)),
          ),
          SafeArea(
            child: Column(
              children: [
                // App identity header
                Padding(
                  padding: EdgeInsets.only(
                    top: responsive.scaledHeight(12),
                    left: responsive.responsivePadding(),
                    right: responsive.responsivePadding(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent
                              .withValues(alpha: isDark ? 0.18 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              'APP DO MOTORISTA',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(10),
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Skip button — only shown when not on the last page
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: widget.onComplete,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Pular',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                              fontSize: responsive.responsiveFontSize(14),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding:
                            EdgeInsets.all(responsive.responsivePadding() * 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: responsive.scaledWidth(120),
                              height: responsive.scaledWidth(120),
                              decoration: BoxDecoration(
                                color: AppColors.adaptiveAccent(context)
                                    .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                page.icon,
                                size: responsive.scaledWidth(60),
                                color: AppColors.adaptiveAccent(context),
                              ),
                            ),
                            SizedBox(height: responsive.scaledHeight(48)),
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(28),
                                fontWeight: FontWeight.w900,
                                color:
                                    isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: responsive.scaledHeight(16)),
                            Text(
                              page.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(14),
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Page indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppColors.adaptiveAccent(context)
                            : (isDark ? Colors.white30 : AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                SizedBox(height: responsive.scaledHeight(32)),
                // Next button
                Padding(
                  padding: EdgeInsets.all(responsive.responsivePadding()),
                  child: SizedBox(
                    width: double.infinity,
                    height: responsive.responsiveButtonHeight(),
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.adaptiveAccent(context),
                        foregroundColor: AppColors.textDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              responsive.responsiveBorderRadius()),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'COMEÇAR'
                            : 'PRÓXIMO',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(14),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
