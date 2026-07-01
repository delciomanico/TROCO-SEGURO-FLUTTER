import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:intl/intl.dart';

class SuccessModal extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int? amount;
  final IconData? icon;
  final Color? iconColor;
  final String? primaryButtonLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;
  final bool autoDismiss;
  final Duration autoDismissDelay;

  const SuccessModal({
    super.key,
    required this.title,
    this.subtitle,
    this.amount,
    this.icon,
    this.iconColor,
    this.primaryButtonLabel,
    this.onPrimaryPressed,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
    this.autoDismiss = false,
    this.autoDismissDelay = const Duration(seconds: 3),
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    int? amount,
    IconData? icon,
    Color? iconColor,
    String? primaryButtonLabel,
    VoidCallback? onPrimaryPressed,
    String? secondaryButtonLabel,
    VoidCallback? onSecondaryPressed,
    bool autoDismiss = false,
    Duration autoDismissDelay = const Duration(seconds: 3),
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => SuccessModal(
        title: title,
        subtitle: subtitle,
        amount: amount,
        icon: icon,
        iconColor: iconColor,
        primaryButtonLabel: primaryButtonLabel,
        onPrimaryPressed: onPrimaryPressed,
        secondaryButtonLabel: secondaryButtonLabel,
        onSecondaryPressed: onSecondaryPressed,
        autoDismiss: autoDismiss,
        autoDismissDelay: autoDismissDelay,
      ),
    );
  }

  /// Shortcut for payment received success
  static Future<void> showPaymentReceived(
    BuildContext context, {
    required int amount,
    String? passengerName,
    VoidCallback? onDismiss,
  }) {
    return show(
      context,
      title: 'Pagamento Recebido!',
      subtitle: passengerName != null
          ? 'Pagamento de $passengerName recebido com sucesso'
          : 'O pagamento foi adicionado à sua carteira',
      amount: amount,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.green,
      primaryButtonLabel: 'OK',
      onPrimaryPressed: () {
        Navigator.pop(context);
        onDismiss?.call();
      },
    );
  }

  /// Shortcut for withdrawal success
  static Future<void> showWithdrawalSuccess(
    BuildContext context, {
    required int amount,
    required String method,
    VoidCallback? onDismiss,
  }) {
    return show(
      context,
      title: 'Saque Solicitado!',
      subtitle: method == 'mcx_express'
          ? 'Você receberá em minutos no seu MCX Express'
          : 'O valor será transferido em até 24 horas úteis',
      amount: amount,
      icon: Icons.send_rounded,
      iconColor: const Color(0xFFF5A623),
      primaryButtonLabel: 'ENTENDIDO',
      onPrimaryPressed: () {
        Navigator.pop(context);
        onDismiss?.call();
      },
    );
  }

  /// Shortcut for generic error
  static Future<void> showError(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return show(
      context,
      title: 'Ops! Algo deu errado',
      subtitle: message,
      icon: Icons.error_outline_rounded,
      iconColor: Colors.red,
      primaryButtonLabel: onRetry != null ? 'TENTAR NOVAMENTE' : 'OK',
      onPrimaryPressed: () {
        Navigator.pop(context);
        if (onRetry != null) {
          onRetry();
        } else {
          onDismiss?.call();
        }
      },
      secondaryButtonLabel: onRetry != null ? 'CANCELAR' : null,
      onSecondaryPressed: onRetry != null
          ? () {
              Navigator.pop(context);
              onDismiss?.call();
            }
          : null,
    );
  }

  @override
  State<SuccessModal> createState() => _SuccessModalState();
}

class _SuccessModalState extends State<SuccessModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    if (widget.autoDismiss) {
      Future.delayed(widget.autoDismissDelay, () {
        if (mounted) {
          Navigator.pop(context);
          widget.onPrimaryPressed?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final iconColor = widget.iconColor ?? Colors.green;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: EdgeInsets.all(responsive.scaledWidth(16)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: responsive.scaledHeight(12)),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Padding(
                    padding:
                        EdgeInsets.all(responsive.responsivePadding() * 1.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with pulse effect
                        _buildAnimatedIcon(responsive, iconColor),

                        SizedBox(height: responsive.scaledHeight(24)),

                        // Title
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(22),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0D2137),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Amount (if provided)
                        if (widget.amount != null) ...[
                          SizedBox(height: responsive.scaledHeight(16)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.scaledWidth(24),
                              vertical: responsive.scaledHeight(12),
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  iconColor.withValues(alpha: 0.15),
                                  iconColor.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: iconColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _formatCurrency(widget.amount!),
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(28),
                                fontWeight: FontWeight.w900,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],

                        // Subtitle
                        if (widget.subtitle != null) ...[
                          SizedBox(height: responsive.scaledHeight(12)),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(14),
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        SizedBox(height: responsive.scaledHeight(32)),

                        // Primary button
                        if (widget.primaryButtonLabel != null)
                          _buildPrimaryButton(responsive, iconColor),

                        // Secondary button
                        if (widget.secondaryButtonLabel != null) ...[
                          SizedBox(height: responsive.scaledHeight(12)),
                          _buildSecondaryButton(responsive),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedIcon(ResponsiveHelper responsive, Color iconColor) {
    return Container(
      width: responsive.scaledWidth(90),
      height: responsive.scaledWidth(90),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconColor.withValues(alpha: 0.1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: responsive.scaledWidth(90),
            height: responsive.scaledWidth(90),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
          ),
          // Icon
          Icon(
            widget.icon ?? Icons.check_circle_rounded,
            color: iconColor,
            size: responsive.scaledWidth(50),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(ResponsiveHelper responsive, Color iconColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onPrimaryPressed ?? () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: iconColor,
          padding: EdgeInsets.symmetric(
            vertical: responsive.scaledHeight(16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          widget.primaryButtonLabel!,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(14),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(ResponsiveHelper responsive) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: widget.onSecondaryPressed ?? () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: responsive.scaledHeight(16),
          ),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          widget.secondaryButtonLabel!,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(14),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0D2137),
          ),
        ),
      ),
    );
  }
}

/// Confetti Animation Widget (para celebrações)
class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool showConfetti;

  const ConfettiOverlay({
    super.key,
    required this.child,
    this.showConfetti = false,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.showConfetti) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showConfetti && !oldWidget.showConfetti) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showConfetti)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFF5A623),
      const Color(0xFF0D2137),
      Colors.amber,
      Colors.pink,
      Colors.purple,
    ];

    for (int i = 0; i < 50; i++) {
      final x = (size.width * (i / 50)) + (size.width * 0.1 * (i % 3));
      final y = size.height * progress * (1 + (i % 4) * 0.3);
      final color = colors[i % colors.length];
      final paint = Paint()
        ..color = color.withValues(alpha: 1 - progress)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x % size.width, y % size.height),
        4 + (i % 3) * 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
