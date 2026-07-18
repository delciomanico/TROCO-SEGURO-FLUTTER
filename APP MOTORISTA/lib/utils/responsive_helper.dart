import 'package:flutter/material.dart';

class ResponsiveHelper {
  final BuildContext context;

  ResponsiveHelper(this.context);

  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  double scaledWidth(double baseWidth) {
    return screenWidth < 600 ? baseWidth * (screenWidth / 360) : baseWidth;
  }

  double scaledHeight(double baseHeight) {
    return screenHeight < 800 ? baseHeight * (screenHeight / 800) : baseHeight;
  }

  double responsivePadding() {
    if (isMobile) return 16;
    if (isTablet) return 24;
    return 32;
  }

  double responsiveFontSize(double baseSize) {
    if (isMobile && screenWidth < 375) {
      return baseSize * 0.85;
    }
    if (screenWidth > 600) {
      return baseSize * 1.1;
    }
    return baseSize;
  }

  double responsiveSpacing() {
    if (isMobile) return 8;
    if (isTablet) return 12;
    return 16;
  }

  double responsiveBorderRadius() {
    if (isMobile) return 6;
    if (isTablet) return 8;
    return 8;
  }

  EdgeInsets responsiveHorizontalPadding() {
    final padding = responsivePadding();
    return EdgeInsets.symmetric(horizontal: padding);
  }

  EdgeInsets responsiveAllPadding() {
    final padding = responsivePadding();
    return EdgeInsets.all(padding);
  }

  EdgeInsets responsiveSymmetricPadding({
    double? horizontal,
    double? vertical,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal ?? responsivePadding(),
      vertical: vertical ?? responsivePadding(),
    );
  }

  double responsiveInputHeight() {
    return isMobile ? 48 : 56;
  }

  double responsiveButtonHeight() {
    return isMobile ? 48 : 56;
  }

  EdgeInsets responsiveContentPadding() {
    final padding = responsivePadding();
    return EdgeInsets.only(
      left: padding,
      right: padding,
      top: padding,
      bottom: padding,
    );
  }
}
