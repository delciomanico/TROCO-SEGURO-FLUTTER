import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.textSecondary;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sobre'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsive.scaledWidth(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: responsive.scaledWidth(100),
                height: responsive.scaledWidth(100),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),

            // App Name & Version
            Center(
              child: Column(
                children: [
                  Text(
                    'Troco Seguro Motorista',
                    style: TextStyle(
                      color: textColor,
                      fontSize: responsive.responsiveFontSize(22),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(8)),
                  Text(
                    'Versão 1.0.0',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: responsive.scaledHeight(32)),

            // Description Section
            Text(
              'Sobre a Aplicação',
              style: TextStyle(
                color: textColor,
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(16)),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Troco Seguro é uma plataforma inovadora que conecta motoristas a passageiros de forma segura e eficiente. '
                'Nossa missão é revolucionar o transporte urbano através de tecnologia de ponta e atendimento de excelência.\n\n'
                'Com Troco Seguro, você tem controle total sobre suas corridas, tarifas e dados pessoais.',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: responsive.responsiveFontSize(14),
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(28)),

            // Features Section
            Text(
              'Principais Funcionalidades',
              style: TextStyle(
                color: textColor,
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            _buildFeatureItem(
              responsive,
              icon: Icons.security_rounded,
              title: 'Segurança em Primeiro Lugar',
              description:
                  'Autenticação biométrica e PIN para proteger sua conta',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            _buildFeatureItem(
              responsive,
              icon: Icons.qr_code_2_rounded,
              title: 'QR Code Inteligente',
              description:
                  'Sistema de pagamento via QR Code configurável e transparente',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            _buildFeatureItem(
              responsive,
              icon: Icons.directions_car_rounded,
              title: 'Gerenciamento de Frota',
              description:
                  'Cadastre e gerencie múltiplos veículos na plataforma',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            _buildFeatureItem(
              responsive,
              icon: Icons.analytics_rounded,
              title: 'Estatísticas em Tempo Real',
              description: 'Acompanhe seus ganhos e desempenho diariamente',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            SizedBox(height: responsive.scaledHeight(32)),

            // Contact Section
            Text(
              'Suporte e Contato',
              style: TextStyle(
                color: textColor,
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(16)),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email_rounded, color: AppColors.primaryGold),
                      SizedBox(width: responsive.scaledWidth(12)),
                      Expanded(
                        child: Text(
                          'suporte@trocoseguro.com',
                          style: TextStyle(
                            color: textColor,
                            fontSize: responsive.responsiveFontSize(14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.scaledHeight(12)),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded, color: AppColors.primaryGold),
                      SizedBox(width: responsive.scaledWidth(12)),
                      Expanded(
                        child: Text(
                          '+244 930 000 000',
                          style: TextStyle(
                            color: textColor,
                            fontSize: responsive.responsiveFontSize(14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.scaledHeight(12)),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: AppColors.primaryGold),
                      SizedBox(width: responsive.scaledWidth(12)),
                      Expanded(
                        child: Text(
                          'Luanda, Angola',
                          style: TextStyle(
                            color: textColor,
                            fontSize: responsive.responsiveFontSize(14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: responsive.scaledHeight(32)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    ResponsiveHelper responsive, {
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required Color cardBg,
  }) {
    return Container(
      padding: EdgeInsets.all(responsive.scaledWidth(16)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(responsive.scaledWidth(10)),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGold,
              size: responsive.scaledWidth(24),
            ),
          ),
          SizedBox(width: responsive.scaledWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(4)),
                Text(
                  description,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: responsive.responsiveFontSize(12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
