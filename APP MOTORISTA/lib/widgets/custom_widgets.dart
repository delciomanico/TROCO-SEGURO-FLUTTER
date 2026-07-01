import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/utils/constants.dart';

/// Widget de cabeçalho com branding do motorista
class DriverBrandingHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final bool showLogo;

  const DriverBrandingHeader({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding()),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (showLogo)
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(12)),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon ?? Icons.local_taxi_rounded,
                color: AppColors.accent,
                size: responsive.scaledWidth(28),
              ),
            ),
          if (showLogo) SizedBox(width: responsive.scaledWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(18),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(12),
                      color: Colors.white70,
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

/// Botão customizado padrão do app
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final bool isOutlined;
  final IconData? icon;
  final Color? color;
  final double? width;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.isOutlined = false,
    this.icon,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final buttonColor =
        color ?? (isPrimary ? AppColors.accent : AppColors.darkBlue);

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: responsive.scaledHeight(52),
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: buttonColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _buildChild(responsive, buttonColor),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: responsive.scaledHeight(52),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: buttonColor.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _buildChild(responsive, Colors.white),
      ),
    );
  }

  Widget _buildChild(ResponsiveHelper responsive, Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: isOutlined ? textColor : Colors.white),
          SizedBox(width: responsive.scaledWidth(8)),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(14),
                fontWeight: FontWeight.w700,
                color: isOutlined ? textColor : Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: responsive.responsiveFontSize(14),
        fontWeight: FontWeight.w700,
        color: isOutlined ? textColor : Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Campo de entrada customizado
class CustomInput extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final Color? textColor;
  final TextCapitalization textCapitalization;

  const CustomInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.textColor,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final effectiveTextColor = widget.textColor ?? AppColors.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          Text(
            widget.label,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(13),
              fontWeight: FontWeight.w600,
              color: effectiveTextColor,
            ),
          ),
        if (widget.label.isNotEmpty) SizedBox(height: responsive.scaledHeight(8)),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscure,
          validator: widget.validator,
          onChanged: widget.onChanged,
          maxLength: widget.maxLength,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          textInputAction: widget.textInputAction,
          onEditingComplete: widget.onEditingComplete,
          textCapitalization: widget.textCapitalization,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(15),
            fontWeight: FontWeight.w500,
            color: effectiveTextColor,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: (widget.textColor ?? AppColors.textSecondary).withValues(alpha: 0.6),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: widget.textColor ?? AppColors.textSecondary)
                : null,
            prefixText: widget.prefixText,
            prefixStyle: TextStyle(
              color: effectiveTextColor,
              fontSize: responsive.responsiveFontSize(15),
              fontWeight: FontWeight.w500,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: widget.textColor ?? AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : widget.suffixIcon,
            counterText: '',
            filled: true,
            fillColor: widget.textColor != null
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: widget.textColor ?? AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.textColor != null
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppColors.cardBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.adaptiveAccent(context),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: responsive.responsivePadding(),
              vertical: responsive.scaledHeight(16),
            ),
          ),
        ),
      ],
    );
  }
}

/// PIN Input com caixas individuais
class PinInput extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool obscureText;
  final bool autofocus;
  final String? errorText;

  const PinInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.obscureText = true,
    this.autofocus = true,
    this.errorText,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _pin => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged?.call(_pin);
    if (_pin.length == widget.length) {
      widget.onCompleted(_pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            return Container(
              width: responsive.scaledWidth(48),
              height: responsive.scaledHeight(56),
              margin:
                  EdgeInsets.symmetric(horizontal: responsive.scaledWidth(4)),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                obscureText: _obscure,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(24),
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: widget.errorText != null
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.errorText != null
                          ? AppColors.error
                          : AppColors.cardBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.adaptiveAccent(context),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) => _onChanged(index, value),
                onTap: () {
                  _controllers[index].selection = TextSelection.fromPosition(
                    TextPosition(offset: _controllers[index].text.length),
                  );
                },
              ),
            );
          }),
        ),
        if (widget.obscureText)
          TextButton.icon(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_off : Icons.visibility,
              size: 16,
              color: AppColors.textSecondary,
            ),
            label: Text(
              _obscure ? 'Ver PIN' : 'Ocultar PIN',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(11),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (widget.errorText != null) ...[
          SizedBox(height: responsive.scaledHeight(8)),
          Text(
            widget.errorText!,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(12),
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card de estatísticas
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final cardColor = color ?? AppColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(responsive.responsivePadding()),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(8)),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: cardColor, size: responsive.scaledWidth(20)),
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            Text(
              value,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(11),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de status do motorista
class StatusBadge extends StatelessWidget {
  final bool isOnline;
  final VoidCallback? onTap;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.isOnline,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(compact ? 8 : 14),
          vertical: responsive.scaledHeight(compact ? 4 : 8),
        ),
        decoration: BoxDecoration(
          gradient: isOnline
              ? const LinearGradient(
                  colors: [AppColors.statusOnline, Color(0xFF16A34A)],
                )
              : const LinearGradient(
                  colors: [AppColors.statusOffline, Color(0xFFDC2626)],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  (isOnline ? AppColors.statusOnline : AppColors.statusOffline)
                      .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: responsive.scaledWidth(8),
              height: responsive.scaledWidth(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              SizedBox(width: responsive.scaledWidth(6)),
              Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(11),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card de transação
class TransactionCard extends StatelessWidget {
  final String description;
  final int amount;
  final String date;
  final String? time;
  final String type;
  final String? passengerName;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.description,
    required this.amount,
    required this.date,
    this.time,
    required this.type,
    this.passengerName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isReceived = type == 'received';
    final color = isReceived ? AppColors.success : AppColors.accent;
    final icon =
        isReceived ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(responsive.responsivePadding()),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(10)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: responsive.scaledWidth(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(13),
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (passengerName != null)
                    Text(
                      passengerName!,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(11),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Text(
                    '$date${time != null ? ' • $time' : ''}',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(10),
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isReceived ? '+' : '-'}$amount Kz',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(14),
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(responsive.responsivePadding() * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(24)),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: responsive.scaledWidth(48),
                color: AppColors.accent,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Text(
              title,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(13),
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: responsive.scaledHeight(24)),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet customizado
class CustomBottomSheet extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final Widget? action;

  const CustomBottomSheet({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.action,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    IconData? icon,
    required List<Widget> children,
    Widget? action,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      builder: (context) => CustomBottomSheet(
        title: title,
        icon: icon,
        action: action,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Container(
      padding: EdgeInsets.only(
        left: responsive.responsivePadding(),
        right: responsive.responsivePadding(),
        top: responsive.responsivePadding(),
        bottom: MediaQuery.of(context).viewInsets.bottom +
            responsive.responsivePadding(),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(20)),
          // Header
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(10)),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 24),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(18),
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(6)),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scaledHeight(24)),
          // Content
          ...children,
          // Action button
          if (action != null) ...[
            SizedBox(height: responsive.scaledHeight(24)),
            action!,
          ],
          SizedBox(height: responsive.scaledHeight(16)),
        ],
      ),
    );
  }
}

/// Gradiente card (para saldos, destaques, etc)
class GradientCard extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final double? borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    this.colors,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? [AppColors.accent, AppColors.accentLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius ?? 24),
        boxShadow: [
          BoxShadow(
            color: (colors?.first ?? AppColors.accent).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
