import 'package:flutter/material.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Pagamentos sem troco',
      description:
          'Pague suas corridas de táxi em Luanda de forma digital e esqueça a confusão com as notas.',
      imageAsset: 'assets/images/onboarding_1.jpg',
    ),
    OnboardingData(
      title: 'Rápido e seguro',
      description:
          'Escaneie o QR Code do taxista e confirme o pagamento com seu PIN. Simples assim!',
      imageAsset: 'assets/images/onboarding_2.jpg',
    ),
    OnboardingData(
      title: 'Controle total',
      description:
          'Acompanhe todas as suas viagens, gerencie cartões virtuais e tenha controle financeiro completo.',
      imageAsset: 'assets/images/onboarding_3.jpg',
    ),
  ];

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinish();
    }
  }

  void _skip() {
    widget.onFinish();
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
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(_pages[index], responsive),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(responsive.responsivePadding()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Troco Seguro',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(16),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: _skip,
                          child: Text(
                            'Pular',
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(14),
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: responsive.responsiveAllPadding(),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => _buildIndicator(index, responsive),
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(32)),
                      CustomButton(
                        text: _currentPage == _pages.length - 1
                            ? 'COMEÇAR'
                            : 'PRÓXIMO',
                        onPressed: _next,
                        fullWidth: true,
                      ),
                      SizedBox(height: responsive.scaledHeight(20)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data, ResponsiveHelper responsive) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(data.imageAsset, fit: BoxFit.cover),
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
                  data.title,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(26),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(12)),
                Text(
                  data.description,
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

  Widget _buildIndicator(int index, ResponsiveHelper responsive) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(4)),
      width: isActive ? responsive.scaledWidth(32) : responsive.scaledWidth(8),
      height: responsive.scaledWidth(8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(responsive.scaledWidth(4)),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String imageAsset;

  OnboardingData({
    required this.title,
    required this.description,
    required this.imageAsset,
  });
}
