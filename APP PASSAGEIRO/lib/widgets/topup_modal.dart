import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/color_extensions.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

class TopupModal extends StatelessWidget {
  final int currentBalance;
  final VoidCallback onClose;

  const TopupModal({
    super.key,
    required this.currentBalance,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final screenHeight = MediaQuery.of(context).size.height;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withAlpha((0.08 * 255).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.07 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      height: screenHeight * 0.85,
      padding: EdgeInsets.only(
        left: responsive.responsivePadding(),
        right: responsive.responsivePadding(),
        top: responsive.responsivePadding(),
        bottom: MediaQuery.of(context).viewInsets.bottom +
            responsive.responsivePadding(),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Center(
                child: Icon(Icons.account_balance,
                  size: responsive.scaledWidth(48), color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            Center(
              child: Text(
                'COMO RECARREGAR',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            Center(
              child: Text(
                'Saldo atual: $currentBalance Kz',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                ),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(32)),

            // Multicaixa Express
            _buildPaymentMethod(
              icon: Icons.atm,
              title: 'Multicaixa Express',
              steps: [
                'Vá a qualquer caixa Multicaixa Express',
                'Selecione "Pagamentos"',
                'Escolha "Pagamento de Serviços"',
                'Digite a referência da empresa Troco Seguro',
                'Digite seu número de telefone',
                'Insira o valor desejado',
                'Confirme o pagamento',
                'O saldo será creditado imediatamente',
              ],
              responsive: responsive,
            ),

            SizedBox(height: responsive.scaledHeight(24)),

            // Multicaixa
            _buildPaymentMethod(
              icon: Icons.credit_card,
              title: 'Multicaixa ATM (Referência)',
              steps: [
                'Vá ao Multicaixa ou ATM',
                'Selecione "Pagamentos"',
                'Escolha "Pagamento de Serviços"',
                'Digite a referência da empresa Troco Seguro',
                'Digite seu número de telefone',
                'Insira o valor desejado',
                'Confirme o pagamento',
                'Aguarde confirmação (até 24h)',
              ],
              responsive: responsive,
            ),

            SizedBox(height: responsive.scaledHeight(32)),

            // Info adicional
            Container(
              padding: EdgeInsets.all(responsive.responsiveSpacing()),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha((0.08 * 255).round()),
                borderRadius:
                    BorderRadius.circular(responsive.responsiveBorderRadius()),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha((0.25 * 255).round())),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  SizedBox(width: responsive.scaledWidth(12)),
                  Expanded(
                    child: Text(
                      'O saldo mínimo para recarga é de 500 Kz. Não há taxa adicional.',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(11),
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((0.85 * 255).round()),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: responsive.scaledHeight(24)),
            CustomButton(
              text: 'FECHAR',
              onPressed: onClose,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod({
    required IconData icon,
    required String title,
    required List<String> steps,
    required ResponsiveHelper responsive,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: EdgeInsets.all(responsive.responsiveSpacing()),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius:
              BorderRadius.circular(responsive.responsiveBorderRadius()),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                SizedBox(width: responsive.scaledWidth(12)),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            ...steps.asMap().entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(bottom: responsive.scaledHeight(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: responsive.responsiveFontSize(10),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: responsive.scaledWidth(12)),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(11),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.7 * 255).round()),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
