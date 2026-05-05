import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';

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
    final pageGradient = isDark
        ? AppColors.darkScreenGradient
        : const LinearGradient(
            colors: [AppColors.lightBackground, AppColors.lightSurface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(responsive.responsivePadding()),
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: Text(
                    'Pular',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: responsive.responsiveFontSize(14),
                    ),
                  ),
                ),
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
                    padding: EdgeInsets.all(responsive.responsivePadding() * 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: responsive.scaledWidth(120),
                          height: responsive.scaledWidth(120),
                          decoration: BoxDecoration(
                            color: AppColors.adaptiveAccent(context).withOpacity(0.2),
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
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: responsive.scaledHeight(16)),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(14),
                            color: Colors.white70,
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
                        : Colors.white30,
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          responsive.responsiveBorderRadius()),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'COMEÇAR' : 'PRÓXIMO',
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
      )),
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

