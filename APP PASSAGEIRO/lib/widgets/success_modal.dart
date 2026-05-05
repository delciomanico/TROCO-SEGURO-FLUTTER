import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/color_extensions.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

class SuccessModal extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onClose;

  const SuccessModal({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.check_circle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Theme.of(context).colorScheme.surface,
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
      padding: EdgeInsets.all(responsive.responsivePadding()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
          SizedBox(height: responsive.scaledHeight(32)),

          // Success icon with animation
          Container(
            width: responsive.scaledWidth(100),
            height: responsive.scaledWidth(100),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha((0.10 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: responsive.scaledWidth(60),
              color: Colors.green,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(24)),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(20),
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: responsive.scaledHeight(12)),

          // Message
          Text(
            message,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              color: Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: responsive.scaledHeight(32)),

          // Close button
          CustomButton(
            text: 'CONTINUAR',
            onPressed: () {
              Navigator.pop(context);
              onClose?.call();
            },
            fullWidth: true,
          ),
          SizedBox(height: responsive.scaledHeight(16)),
        ],
      ),
    );
  }

  /// Show success modal
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.check_circle,
    VoidCallback? onClose,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SuccessModal(
        title: title,
        message: message,
        icon: icon,
        onClose: onClose,
      ),
    );
  }
}
