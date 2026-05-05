import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

/// AppBar com gradiente laranja/amarelo
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;

  const GradientAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.height = 70,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (leading != null) leading!,
              if (title != null) Expanded(child: title!),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de branding reutilizável para o header do app
class AppBrandingHeader extends StatelessWidget {
  final String? subtitle;
  final bool compact;

  const AppBrandingHeader({
    super.key,
    this.subtitle,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(responsive.scaledWidth(compact ? 8 : 12)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.6),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.currency_exchange_rounded,
            size: responsive.scaledWidth(compact ? 20 : 28),
            color: AppColors.accent,
          ),
        ),
        SizedBox(width: responsive.scaledWidth(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TROCO SEGURO',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(compact ? 16 : 20),
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(10),
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Card com gradiente premium para saldo
class GradientBalanceCard extends StatelessWidget {
  final String label;
  final String balance;
  final bool showBalance;
  final VoidCallback? onToggleVisibility;
  final Widget? bottomContent;

  const GradientBalanceCard({
    super.key,
    required this.label,
    required this.balance,
    this.showBalance = true,
    this.onToggleVisibility,
    this.bottomContent,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.darkBlue,
            AppColors.darkBlueSurface,
            Color(0xFF2A4A6C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius() * 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Padrão decorativo
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Conteúdo
          Padding(
            padding: EdgeInsets.all(responsive.responsivePadding() * 1.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: responsive.scaledWidth(16),
                              color: AppColors.accent,
                            ),
                            SizedBox(width: responsive.scaledWidth(6)),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(11),
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.scaledHeight(10)),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            showBalance ? balance : '••••••••',
                            key: ValueKey(showBalance),
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(36),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (onToggleVisibility != null)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: onToggleVisibility,
                          icon: Icon(
                            showBalance
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                if (bottomContent != null) ...[
                  SizedBox(height: responsive.scaledHeight(20)),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(20)),
                  bottomContent!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão de ação rápida com ícone animado
class QuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // No tema dark, botões outline usam branco; no light, usam azul escuro
    final outlineColor = isDark ? Colors.white : AppColors.darkBlue;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: responsive.responsiveButtonHeight(),
          decoration: BoxDecoration(
            gradient: widget.isPrimary
                ? const LinearGradient(
                    colors: [AppColors.accent, Color(0xFFE5A00D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isPrimary ? null : Colors.transparent,
            borderRadius:
                BorderRadius.circular(responsive.responsiveBorderRadius()),
            border: widget.isPrimary
                ? null
                : Border.all(color: outlineColor, width: 2),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: responsive.scaledWidth(18),
                color: widget.isPrimary ? Colors.white : outlineColor,
              ),
              SizedBox(width: responsive.scaledWidth(8)),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  fontWeight: FontWeight.w900,
                  color: widget.isPrimary ? Colors.white : outlineColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutline;
  final bool fullWidth;
  final Widget? icon;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isOutline = false,
    this.fullWidth = false,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final fontSize = responsive.responsiveFontSize(12);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // No tema dark, botões outline usam branco; no light, usam azul escuro
    final outlineColor = isDark ? Colors.white : AppColors.darkBlue;
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: responsive.responsiveButtonHeight(),
      child: Container(
        decoration: BoxDecoration(
          gradient: isOutline ? null : (isDisabled ? null : AppColors.primaryGradient),
          color: isDisabled && !isOutline ? Colors.grey : null,
          borderRadius:
              BorderRadius.circular(responsive.responsiveBorderRadius()),
          border: isOutline ? Border.all(
            color: isDisabled ? Colors.grey : outlineColor, 
            width: 2
          ) : null,
          boxShadow: isOutline || isDisabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.darkBlue.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: isOutline ? (isDisabled ? Colors.grey : outlineColor) : Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(
                horizontal: responsive.responsivePadding() * 1.2,
                vertical: responsive.responsivePadding() * 0.8),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(responsive.responsiveBorderRadius()),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOutline ? outlineColor : Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: responsive.responsiveSpacing()),
              ] else if (icon != null) ...[
                icon!,
                SizedBox(width: responsive.responsiveSpacing()),
              ],
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? EdgeInsets.all(responsive.responsivePadding()),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius:
              BorderRadius.circular(responsive.responsiveBorderRadius()),
          border: Border.all(color: scheme.outline.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class CustomInput extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final String? prefix;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  final bool obscureText;
  final bool enabled;
  final void Function(String)? onChanged;

  const CustomInput({
    super.key,
    this.label,
    this.placeholder,
    this.controller,
    this.prefixIcon,
    this.prefix,
    this.keyboardType,
    this.maxLength,
    this.maxLines,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final fontSize = responsive.responsiveFontSize(16);
    final labelFontSize = responsive.responsiveFontSize(10);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface.withOpacity(0.6),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
        SizedBox(
          height: maxLines != null && maxLines! > 1 
              ? null 
              : responsive.responsiveInputHeight(),
          child: Container(
            decoration: BoxDecoration(
              color: enabled 
                  ? scheme.surfaceContainerHighest.withOpacity(0.5)
                  : scheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius:
                  BorderRadius.circular(responsive.responsiveBorderRadius()),
              border: Border.all(color: scheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: maxLines != null && maxLines! > 1 
                  ? CrossAxisAlignment.start 
                  : CrossAxisAlignment.center,
              children: [
                if (prefixIcon != null)
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20, 
                      right: 12,
                      top: maxLines != null && maxLines! > 1 ? 16 : 0,
                    ),
                    child: prefixIcon,
                  ),
                if (prefix != null)
                  Container(
                    padding: EdgeInsets.only(
                      left: 20, 
                      right: 12,
                      top: maxLines != null && maxLines! > 1 ? 16 : 0,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        right:
                            BorderSide(color: scheme.outline.withOpacity(0.3)),
                      ),
                    ),
                    child: Text(
                      prefix!,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    maxLength: maxLength,
                    maxLines: maxLines ?? 1,
                    minLines: maxLines != null && maxLines! > 1 ? maxLines : 1,
                    obscureText: obscureText,
                    enabled: enabled,
                    onChanged: onChanged,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: enabled 
                          ? scheme.onSurface 
                          : scheme.onSurface.withOpacity(0.5),
                    ),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: maxLines != null && maxLines! > 1 ? 16 : 0,
                      ),
                      counterText: '',
                      isDense: maxLines == null || maxLines! == 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Padding(
      padding: EdgeInsets.only(bottom: responsive.responsiveSpacing() * 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(16),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'VER TUDO',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(10),
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkBlue,
                  letterSpacing: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
