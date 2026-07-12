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
      title: 'Receba Pagamentos',
      description:
          'Mostre seu QR Code único e receba pagamentos dos passageiros de forma instantânea e segura.',
      imageAsset: 'assets/images/onboarding_1.jpg',
    ),
    OnboardingPage(
      title: 'Acompanhe seus Ganhos',
      description:
          'Veja em tempo real seus ganhos diários, semanais e mensais. Tenha controle total do seu negócio.',
      imageAsset: 'assets/images/onboarding_2.jpg',
    ),
    OnboardingPage(
      title: 'Saque Fácil',
      description:
          'Transfira seus ganhos para sua conta bancária ou MCX Express quando quiser. Rápido e sem complicação.',
      imageAsset: 'assets/images/onboarding_3.jpg',
    ),
    OnboardingPage(
      title: 'Segurança Total',
      description:
          'Todas as transações são protegidas com PIN e biometria. Seus dados estão seguros conosco.',
      imageAsset: 'assets/images/onboarding_4.jpg',
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) => _buildPage(_pages[index], responsive),
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
                          color: AppColors.accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.45),
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
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: responsive.responsiveFontSize(14),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                const Spacer(),
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
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
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
                        backgroundColor: AppColors.accent,
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

  Widget _buildPage(OnboardingPage page, ResponsiveHelper responsive) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(page.imageAsset, fit: BoxFit.cover),
        // Vinheta radial — escurece as bordas mantendo o centro visível.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
        // Gradiente inferior — garante contraste para o texto.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.92)],
              stops: const [0.35, 1.0],
            ),
          ),
        ),
        // Gradiente superior — garante contraste para o cabeçalho/"Pular".
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
              stops: const [0.0, 0.25],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.responsivePadding(),
              0,
              responsive.responsivePadding(),
              responsive.scaledHeight(150),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page.title,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(26),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(12)),
                Text(
                  page.description,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imageAsset;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imageAsset,
  });
}
