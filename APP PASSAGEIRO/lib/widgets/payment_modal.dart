import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/security/pin_guard.dart';
import 'package:troco_seguro/services/biometric_service.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

class PaymentModal extends StatefulWidget {
  final int amount;
  final String description;
  final String? userPin; // optional when using validator
  final Future<bool> Function(String pin)?
      pinValidator; // if provided, used instead of userPin
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const PaymentModal({
    super.key,
    required this.amount,
    required this.description,
    this.userPin,
    this.pinValidator,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String enteredPin = '';
  String? error;
  bool isLocked = false;
  String? lockMessage;
  bool biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    _tryBiometricFirst();
  }

  Future<void> _tryBiometricFirst() async {
    // If biometric is available, offer it first
    final biometric = BiometricService();
    final available = await biometric.isBiometricAvailable();
    if (available && mounted) {
      final result = await biometric.authenticate(
        reason: 'Autentique com sua biometria para confirmar o pagamento',
      );
      if (result) {
        setState(() => biometricAttempted = true);
        widget.onSuccess();
      } else {
        setState(() => biometricAttempted = true);
        // Fall back to PIN entry
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
      padding: EdgeInsets.all(responsive.responsivePadding()),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withAlpha((0.3 * 255).round()),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Icon(Icons.lock,
              size: responsive.scaledWidth(48), color: Theme.of(context).colorScheme.primary),
            SizedBox(height: responsive.scaledHeight(16)),
            Text(
              'CONFIRMAR PAGAMENTO',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Text(
              widget.description,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(14),
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            Text(
              '${widget.amount} Kz',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(20),
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(32)),
            if (error != null)
              Container(
                margin: EdgeInsets.only(bottom: responsive.scaledHeight(16)),
                padding: EdgeInsets.all(responsive.responsiveSpacing()),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                    SizedBox(width: responsive.scaledWidth(8)),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!biometricAttempted)
              Text(
                'Digite seu PIN de 6 dígitos',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color:
                      Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                ),
              )
            else
              Text(
                'Biometria não disponível. Use PIN:',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            SizedBox(height: responsive.scaledHeight(16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return Container(
                  width: responsive.scaledWidth(45),
                  height: responsive.scaledHeight(45),
                  margin: EdgeInsets.symmetric(
                      horizontal: responsive.responsiveSpacing() / 2),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: enteredPin.length > i
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(
                        responsive.responsiveBorderRadius()),
                  ),
                  child: Center(
                    child: Text(
                      enteredPin.length > i ? '•' : '',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(20),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.2,
              mainAxisSpacing: responsive.responsiveSpacing(),
              crossAxisSpacing: responsive.responsiveSpacing(),
              children: List.generate(10, (i) {
                final num = i == 9 ? 0 : i + 1;
                return GestureDetector(
                  onTap: () {
                    if (enteredPin.length < 6) {
                      setState(() {
                        enteredPin += num.toString();
                        error = null;
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                          responsive.responsiveBorderRadius()),
                    ),
                    child: Center(
                      child: Text(
                        num.toString(),
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(16),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            GestureDetector(
              onTap: () {
                if (enteredPin.isNotEmpty) {
                  setState(() => enteredPin =
                      enteredPin.substring(0, enteredPin.length - 1));
                }
              },
              child: Container(
                padding: EdgeInsets.all(responsive.responsiveSpacing()),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                      responsive.responsiveBorderRadius()),
                ),
                child: const Icon(Icons.backspace),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'CANCELAR',
                    onPressed: widget.onCancel,
                    isOutline: true,
                  ),
                ),
                SizedBox(width: responsive.responsiveSpacing()),
                Expanded(
                  child: CustomButton(
                    text: 'CONFIRMAR',
                    onPressed: enteredPin.length == 6
                        ? () async {
                            setState(() {
                              error = null;
                            });
                            bool ok = false;
                            if (widget.pinValidator != null) {
                              ok = await widget.pinValidator!(enteredPin);
                            } else if (widget.userPin != null) {
                              ok = enteredPin == widget.userPin;
                            }
                            if (ok) {
                              widget.onSuccess();
                            } else {
                              final msg =
                                  await PinGuard.lockRemainingMessage('global');
                              setState(() => error = msg ?? 'PIN incorreto');
                            }
                          }
                        : () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
