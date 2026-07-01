import 'package:flutter/material.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/utils/constants.dart';
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
      icon: Icons.payments_outlined,
      color: AppColors.primaryOrange,
    ),
    OnboardingData(
      title: 'Rápido e seguro',
      description:
          'Escaneie o QR Code do taxista e confirme o pagamento com seu PIN. Simples assim!',
      icon: Icons.qr_code_scanner,
      color: Colors.blue,
    ),
    OnboardingData(
      title: 'Controle total',
      description:
          'Acompanhe todas as suas viagens, gerencie cartões virtuais e tenha controle financeiro completo.',
      icon: Icons.credit_card,
      color: Colors.green,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
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
                      color: AppColors.accentOf(context),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], responsive);
                },
              ),
            ),
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
    );
  }

  Widget _buildPage(OnboardingData data, ResponsiveHelper responsive) {
    return Padding(
      padding: responsive.responsiveAllPadding(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: responsive.scaledWidth(200),
            height: responsive.scaledWidth(200),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: responsive.scaledWidth(100),
                color: data.color,
              ),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(60)),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(28),
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(20)),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(15),
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.6,
            ),
          ),
        ],
      ),
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
        color:
            isActive ? AppColors.accentOf(context) : Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(responsive.scaledWidth(4)),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
