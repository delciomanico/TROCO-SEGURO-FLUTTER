import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
        title: const Text('Termos e Condições'),
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
            _buildSection(
              responsive,
              title: '1. Aceitação dos Termos',
              content:
                  'Ao utilizar a plataforma Troco Seguro, você concorda em aceitar e cumprir estes Termos e Condições. '
                  'Se você não concorda com qualquer parte destes termos, por favor, não utilize a plataforma.',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '2. Uso da Plataforma',
              content:
                  'Você concorda em utilizar a Troco Seguro apenas para fins legais e de forma compatível com as leis aplicáveis. '
                  'É proibido:\n'
                  '• Usar a plataforma para fins ilegais ou prejudiciais\n'
                  '• Transferir sua conta para terceiros\n'
                  '• Colocar dados falsos ou enganosos\n'
                  '• Prejudicar ou interferir com os sistemas da plataforma',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '3. Responsabilidade do Motorista',
              content: 'Como motorista, você é responsável por:\n'
                  '• Manter seu veículo em bom estado de funcionamento\n'
                  '• Cumprir todas as leis de trânsito\n'
                  '• Tratar os passageiros com respeito e educação\n'
                  '• Manter a confidencialidade de suas credenciais de acesso\n'
                  '• Relatar qualquer atividade suspeita',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '4. Pagamentos e Tarifas',
              content:
                  'Você concorda que as tarifas cobradas pela plataforma são justas e transparentes. '
                  'Você pode visualizar e aceitar a tarifa antes de iniciar uma corrida. '
                  'Você é responsável por manter as informações de pagamento atualizadas.',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '5. Privacidade e Dados Pessoais',
              content:
                  'Seus dados pessoais serão coletados, processados e armazenados de acordo com nossa Política de Privacidade. '
                  'A Troco Seguro garante a proteção de seus dados através de criptografia e medidas de segurança avançadas.',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '6. Limitação de Responsabilidade',
              content: 'A Troco Seguro não é responsável por:\n'
                  '• Danos diretos ou indiretos resultantes do uso da plataforma\n'
                  '• Perda de dados ou lucros cessantes\n'
                  '• Erros técnicos ou interrupções de serviço\n'
                  '• Ações de terceiros',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '7. Segurança de Conta',
              content:
                  'Você é responsável por manter a confidencialidade de sua senha e PIN. '
                  'Notifique a Troco Seguro imediatamente se suspeitar de acesso não autorizado à sua conta. '
                  'A plataforma não será responsável por perda de dados resultante de sua negligência.',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '8. Modificações dos Termos',
              content:
                  'A Troco Seguro se reserva o direito de modificar estes Termos e Condições a qualquer momento. '
                  'As modificações serão eficazes imediatamente após a publicação. '
                  'Seu uso contínuo da plataforma após as mudanças constitui aceição dos novos termos.',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '9. Rescisão de Conta',
              content:
                  'A Troco Seguro pode suspender ou encerrar sua conta se violarmos estes Termos e Condições. '
                  'Você pode solicitar o encerramento de sua conta a qualquer momento através das configurações.',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            _buildSection(
              responsive,
              title: '10. Lei Aplicável',
              content:
                  'Estes Termos e Condições são regidos pelas leis de Angola. '
                  'Qualquer disputa será resolvida nos tribunais competentes de Luanda.',
              isDark: isDark,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              cardBg: cardBg,
            ),
            SizedBox(height: responsive.scaledHeight(32)),
            Center(
              child: Text(
                'Última atualização: Maio de 2026',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: responsive.responsiveFontSize(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(32)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ResponsiveHelper responsive, {
    required String title,
    required String content,
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required Color cardBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: responsive.responsiveFontSize(16),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: responsive.scaledHeight(10)),
        Container(
          padding: EdgeInsets.all(responsive.scaledWidth(14)),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: responsive.responsiveFontSize(13),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(18)),
      ],
    );
  }
}
