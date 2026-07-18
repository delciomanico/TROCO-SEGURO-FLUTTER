import 'package:flutter/material.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

class CardTransferModal extends StatefulWidget {
  final List<VirtualCard> cards;
  final Future<String?> Function(String fromCardId, String toCardId, int amount, String pin)
      onTransfer;
  final VoidCallback onClose;

  const CardTransferModal({
    super.key,
    required this.cards,
    required this.onTransfer,
    required this.onClose,
  });

  @override
  State<CardTransferModal> createState() => _CardTransferModalState();
}

class _CardTransferModalState extends State<CardTransferModal> {
  String? selectedFromCardId;
  String? selectedToCardId;
  final amountController = TextEditingController();
  final pinController = TextEditingController();
  String? error;
  bool isLoading = false;

  @override
  void dispose() {
    amountController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> _submitTransfer() async {
    final amount = int.tryParse(amountController.text.trim());
    final pin = pinController.text.trim();

    if (selectedFromCardId == null ||
        selectedToCardId == null ||
        amount == null) {
      setState(() => error = 'Selecione os cartões e informe o montante');
      return;
    }

    if (selectedFromCardId == selectedToCardId) {
      setState(() => error = 'Origem e destino devem ser cartões diferentes');
      return;
    }

    if (amount <= 0) {
      setState(() => error = 'O montante deve ser maior que zero');
      return;
    }

    final sourceCard = widget.cards.firstWhere(
      (card) => card.id == selectedFromCardId,
      orElse: () => widget.cards.first,
    );

    if (amount > sourceCard.balance) {
      setState(() => error = 'Saldo insuficiente no cartão de origem');
      return;
    }

    if (pin.length != 4) {
      setState(() => error = 'PIN do cartão deve ter 4 dígitos');
      return;
    }

    setState(() {
      error = null;
      isLoading = true;
    });

    final transferError = await widget.onTransfer(
      selectedFromCardId!,
      selectedToCardId!,
      amount,
      pin,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (transferError == null) {
      widget.onClose();
      FeedbackService.showSuccess(
        context,
        message: 'Transferência entre cartões concluída com sucesso!',
      );
    } else {
      setState(() => error = transferError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cards = widget.cards;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withAlpha((0.08 * 255).round()),
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
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withAlpha((0.3 * 255).round()),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.credit_card,
                size: responsive.scaledWidth(34),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            Text(
              'TRANSFERENCIA ENTRE CARTOES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(8)),
            Text(
              'Escolha o cartao de origem, o cartao de destino e o montante a transferir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.65 * 255).round()),
                height: 1.4,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            if (error != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: responsive.scaledHeight(16)),
                padding: EdgeInsets.all(responsive.responsiveSpacing()),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha((0.08 * 255).round()),
                  borderRadius: BorderRadius.circular(
                    responsive.responsiveBorderRadius(),
                  ),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (cards.length < 2)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(responsive.responsiveSpacing()),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withAlpha((0.08 * 255).round()),
                  borderRadius: BorderRadius.circular(
                    responsive.responsiveBorderRadius(),
                  ),
                ),
                child: Text(
                  'E necessario ter pelo menos dois cartoes virtuais para fazer uma transferencia.',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              )
            else ...[
              _buildCardSelector(
                context: context,
                responsive: responsive,
                label: 'CARTAO DE ORIGEM',
                value: selectedFromCardId,
                cards: cards,
                hint: 'Selecione o cartao de origem',
                onChanged: (value) {
                  setState(() {
                    selectedFromCardId = value;
                    error = null;
                  });
                },
              ),
              SizedBox(height: responsive.scaledHeight(16)),
              _buildCardSelector(
                context: context,
                responsive: responsive,
                label: 'CARTAO DE DESTINO',
                value: selectedToCardId,
                cards: cards,
                hint: 'Selecione o cartao de destino',
                onChanged: (value) {
                  setState(() {
                    selectedToCardId = value;
                    error = null;
                  });
                },
              ),
              SizedBox(height: responsive.scaledHeight(16)),
              _buildAmountField(context, responsive),
              SizedBox(height: responsive.scaledHeight(16)),
              _buildPinField(context, responsive),
              SizedBox(height: responsive.scaledHeight(24)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : widget.onClose,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.18 * 255).round()),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.textLight : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submitTransfer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Transferir',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(13),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: responsive.scaledHeight(8)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSelector({
    required BuildContext context,
    required ResponsiveHelper responsive,
    required String label,
    required String? value,
    required List<VirtualCard> cards,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(10),
              fontWeight: FontWeight.w900,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.6 * 255).round()),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius:
                BorderRadius.circular(responsive.responsiveBorderRadius()),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: responsive.scaledWidth(16),
                vertical: responsive.scaledHeight(14),
              ),
            ),
            items: cards
                .map(
                  (card) => DropdownMenuItem<String>(
                    value: card.id,
                    child: Text(
                      '${card.name} - ${card.balance} Kz',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(BuildContext context, ResponsiveHelper responsive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'MONTANTE',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(10),
              fontWeight: FontWeight.w900,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.6 * 255).round()),
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ex: 2500',
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                responsive.responsiveBorderRadius(),
              ),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                responsive.responsiveBorderRadius(),
              ),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                responsive.responsiveBorderRadius(),
              ),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinField(BuildContext context, ResponsiveHelper responsive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'PIN DO CARTAO DE ORIGEM',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(10),
              fontWeight: FontWeight.w900,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.6 * 255).round()),
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: InputDecoration(
            hintText: '****',
            counterText: '',
            prefixIcon: const Icon(Icons.lock_outline),
            filled: true,
            fillColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                responsive.responsiveBorderRadius(),
              ),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                responsive.responsiveBorderRadius(),
              ),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                responsive.responsiveBorderRadius(),
              ),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
