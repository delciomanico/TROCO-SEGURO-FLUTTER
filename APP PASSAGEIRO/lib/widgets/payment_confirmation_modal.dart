import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/services/payment_service.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/widgets/rating_modal.dart';

/// Modal de confirmação simples e responsivo para pagamento
class PaymentConfirmationModal extends StatefulWidget {
  final QrValidationResult driverInfo;
  final int amount;
  final String origin;
  final String destination;
  final Future<bool> Function(String pin) pinValidator;
  /// Chamado com o [PaymentResult] após pagamento confirmado pela API.
  final void Function(PaymentResult result) onSuccess;
  final VoidCallback onCancel;

  const PaymentConfirmationModal({
    super.key,
    required this.driverInfo,
    required this.amount,
    required this.origin,
    required this.destination,
    required this.pinValidator,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<PaymentConfirmationModal> createState() =>
      _PaymentConfirmationModalState();
}

class _PaymentConfirmationModalState extends State<PaymentConfirmationModal> {
  bool _isProcessing = false;
  String _enteredPin = '';
  String? _pinError;
  late final TextEditingController _pinController;
  late final FocusNode _pinFocusNode;

  // null = wallet (main balance); non-null = virtual card id
  String? _selectedCardId;
  bool get _isCardPayment => _selectedCardId != null;
  int get _pinLength => _isCardPayment ? 4 : 6;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _pinFocusNode = FocusNode();
    _pinController.addListener(() {
      setState(() {
        _enteredPin = _pinController.text;
        _pinError = null;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_pinFocusNode);
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment(BuildContext context) async {
    if (_enteredPin.length != _pinLength) {
      setState(() => _pinError = 'PIN deve ter $_pinLength dígitos');
      return;
    }

    setState(() => _isProcessing = true);

    // Client-side PIN validation only for wallet payments.
    // Card PIN is validated server-side (we never store it locally).
    if (!_isCardPayment) {
      final pinValid = await widget.pinValidator(_enteredPin);
      if (!mounted) return;
      if (!pinValid) {
        setState(() {
          _isProcessing = false;
          _pinError = 'PIN inválido';
        });
        return;
      }
    }

    final paymentService = PaymentService();
    final result = await paymentService.processPayment(
      context: context,
      driverId: widget.driverInfo.driverId ?? '',
      amount: widget.amount,
      pin: _enteredPin,
      origin: widget.origin,
      destination: widget.destination,
      paymentToken: widget.driverInfo.paymentToken ??
          widget.driverInfo.sessionToken ??
          '',
      cardId: _selectedCardId,
      distanceKm: 0.0,
      durationMinutes: 0,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (result != null) {
      // Invalidar domínios afetados pelo pagamento antes de fechar o modal
      final provider = context.read<AppProvider>();
      provider.invalidate(AppDomain.user);
      provider.invalidate(AppDomain.transactions);
      provider.invalidate(AppDomain.trips);

      Navigator.pop(context);
      widget.onSuccess(result);

      // Mostrar modal de avaliação após pagamento bem-sucedido
      if (result.tripId != null && result.tripId!.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            RatingModal.show(
              context,
              tripId: result.tripId!,
              driverName: widget.driverInfo.driverName ?? 'Motorista',
              onSubmitRating: (tripId, rating, comment) async {
                final api = ApiService();
                final response = await api.rateTrip(
                  tripId: tripId,
                  stars: rating,
                  comment: comment,
                );
                return response.isSuccess;
              },
            );
          }
        });
      }
    }
  }

  void _selectSource(String? cardId) {
    _pinController.clear();
    setState(() {
      _selectedCardId = cardId;
      _pinError = null;
    });
    FocusScope.of(context).requestFocus(_pinFocusNode);
  }

  Widget _buildSourceSelector(BuildContext ctx, ResponsiveHelper responsive) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final provider = ctx.read<AppProvider>();
    final user = provider.user;
    final cards = provider.virtualCards
        .where((c) => c.status == CardStatus.active)
        .toList();

    final accent = AppColors.accentOf(ctx);
    final bgSelected = accent.withValues(alpha: 0.1);
    final borderSelected = accent;
    final bgUnselected = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final borderUnselected = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.1);

    Widget tile({
      required String? cardId,
      required String label,
      required String sublabel,
      required IconData icon,
    }) {
      final selected = _selectedCardId == cardId;
      return GestureDetector(
        onTap: () => _selectSource(cardId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? bgSelected : bgUnselected,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? borderSelected : borderUnselected,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18,
                  color: selected ? accent : (isDark ? Colors.white54 : Colors.black45)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? accent
                                : (isDark ? Colors.white : AppColors.textDark))),
                    Text(sublabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.45)
                                : Colors.black.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 18, color: accent),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pagar com',
            style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.onSurface)),
        const SizedBox(height: 10),
        tile(
          cardId: null,
          label: 'Carteira Principal',
          sublabel: '${user?.balance ?? 0} Kz disponíveis  •  PIN de 6 dígitos',
          icon: Icons.account_balance_wallet_outlined,
        ),
        ...cards.map((c) => tile(
              cardId: c.id,
              label: c.name,
              sublabel: '${c.balance} Kz  •  PIN de 4 dígitos',
              icon: Icons.credit_card_rounded,
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
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
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: responsive.responsivePadding(),
              right: responsive.responsivePadding(),
              top: responsive.responsivePadding(),
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  responsive.responsivePadding(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),

                // Driver info - Clean and simple
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.driverInfo.driverName ?? 'Taxista',
                        style: TextStyle(
                            fontSize: responsive.responsiveFontSize(16),
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    SizedBox(height: responsive.scaledHeight(8)),
                    Text(widget.driverInfo.licensePlate ?? 'Placa desconhecida',
                        style: TextStyle(
                            fontSize: responsive.responsiveFontSize(14),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6))),
                    if (widget.driverInfo.seatLabel != null) ...[
                      SizedBox(height: responsive.scaledHeight(8)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accentOf(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.accentOf(context).withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.airline_seat_recline_normal_rounded,
                              size: 14, color: AppColors.accentOf(context)),
                          const SizedBox(width: 5),
                          Text(widget.driverInfo.seatLabel!,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentOf(context))),
                        ]),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: responsive.scaledHeight(24)),

                // Amount - Highlight
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Valor',
                        style: TextStyle(
                            fontSize: responsive.responsiveFontSize(12),
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6))),
                    SizedBox(height: responsive.scaledHeight(8)),
                    Text('${widget.amount} Kz',
                        style: TextStyle(
                            fontSize: responsive.responsiveFontSize(28),
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentOf(context))),
                  ],
                ),

                SizedBox(height: responsive.scaledHeight(20)),
                _buildSourceSelector(context, responsive),
                SizedBox(height: responsive.scaledHeight(20)),
                Text(
                    _isCardPayment
                        ? 'PIN do Cartão (4 dígitos)'
                        : 'PIN da Conta (6 dígitos)',
                    style: TextStyle(
                        fontSize: responsive.responsiveFontSize(12),
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: responsive.scaledHeight(12)),
                if (_pinError != null)
                  Container(
                    width: double.infinity,
                    margin:
                        EdgeInsets.only(bottom: responsive.scaledHeight(12)),
                    padding: EdgeInsets.all(responsive.responsiveSpacing()),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Text(_pinError!,
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: responsive.responsiveFontSize(12))),
                  ),

                // PIN boxes — count matches _pinLength (4 for card, 6 for wallet)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final m = responsive.scaledWidth(4);
                    final totalSpacing = m * (_pinLength * 2);
                    final available = (constraints.maxWidth - totalSpacing)
                        .clamp(0.0, double.infinity);
                    final boxSize = (available / _pinLength).clamp(36.0, 60.0);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (i) {
                        return Container(
                          width: boxSize,
                          height: boxSize,
                          margin: EdgeInsets.symmetric(
                              horizontal: responsive.scaledWidth(4)),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                                width: 2),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                          alignment: Alignment.center,
                          child: _enteredPin.length > i
                              ? Text('•',
                                  style: TextStyle(
                                      fontSize: boxSize * 0.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentOf(context)))
                              : null,
                        );
                      }),
                    );
                  },
                ),

                SizedBox(height: responsive.scaledHeight(12)),

                // Hidden TextField receives numeric input and updates PIN boxes.
                SizedBox(
                  height: 1,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: _pinLength,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: ''),
                    style:
                        const TextStyle(color: Colors.transparent, height: 0.1),
                  ),
                ),

                SizedBox(height: responsive.scaledHeight(16)),

                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'CANCELAR',
                        onPressed: _isProcessing
                            ? () {}
                            : () => Navigator.pop(context),
                        isOutline: true,
                      ),
                    ),
                    SizedBox(width: responsive.responsiveSpacing()),
                    Expanded(
                      child: CustomButton(
                        text: _isProcessing ? 'PROCESSANDO...' : 'CONFIRMAR',
                        onPressed: _isProcessing
                            ? () {}
                            : () => _confirmPayment(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
