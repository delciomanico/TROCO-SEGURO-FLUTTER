import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:troco_seguro_pro/models/driver_user.dart';
import 'package:troco_seguro_pro/screens/earnings_screen.dart';
import 'package:troco_seguro_pro/screens/trips_screen.dart';
import 'package:troco_seguro_pro/screens/wallet_screen.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/services/feedback_service.dart';

enum DriverDockTab {
  home,
  stats,
  center,
  wallet,
  menu,
}

class DriverBottomDock extends StatelessWidget {
  final DriverDockTab selectedTab;
  final DriverUser? driver;
  final VoidCallback? onOpenWithdrawal;
  final ValueChanged<DriverDockTab>? onTabSelected;
  final VoidCallback? onCenterTap;

  const DriverBottomDock({
    super.key,
    required this.selectedTab,
    this.driver,
    this.onOpenWithdrawal,
    this.onTabSelected,
    this.onCenterTap,
  });

  Future<DriverUser?> _getDriverFallback() async {
    if (driver != null) return driver;
    final prefs = await SharedPreferences.getInstance();
    final driverJson = prefs.getString('ts_driver');
    if (driverJson == null || driverJson.isEmpty) return null;
    try {
      return DriverUser.fromJson(
        (json.decode(driverJson) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _goHome(BuildContext context) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _goStats(BuildContext context) async {
    if (selectedTab == DriverDockTab.stats) return;
    final d = await _getDriverFallback();
    if (!context.mounted) return;
    if (d == null) {
      FeedbackService.showError(context,
          message: 'Não foi possível carregar dados do motorista.');
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => EarningsScreen(driver: d)),
    );
  }

  Future<void> _goCenter(BuildContext context) async {
    if (selectedTab == DriverDockTab.center) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TripsScreen()),
    );
  }

  Future<void> _openWithdrawalOrWallet(BuildContext context) async {
    if (onOpenWithdrawal != null) {
      onOpenWithdrawal!.call();
      return;
    }
    await _goWallet(context);
  }

  Future<void> _goWallet(BuildContext context) async {
    if (selectedTab == DriverDockTab.wallet) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WalletScreen(onOpenWithdrawal: onOpenWithdrawal),
      ),
    );
  }

  Future<void> _goMenu(BuildContext context) async {
    if (selectedTab == DriverDockTab.menu) return;
    final d = await _getDriverFallback();
    if (!context.mounted) return;
    if (d == null) {
      FeedbackService.showError(context,
          message: 'Não foi possível carregar dados do motorista.');
      return;
    }
    // Profile screen was removed, go home instead or show drawer
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryGold : AppColors.primaryOrange;
    final dockBg = isDark ? AppColors.darkSurface : AppColors.lightCard;
    final dockBorder =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightBorder;

    return Container(
      margin: EdgeInsets.fromLTRB(
        responsive.scaledWidth(16),
        0,
        responsive.scaledWidth(16),
        responsive.scaledHeight(14),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(8),
        vertical: responsive.scaledHeight(7),
      ),
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: dockBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDockItem(
            context,
            responsive,
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: () {
              if (onTabSelected != null) {
                onTabSelected!(DriverDockTab.home);
                return;
              }
              _goHome(context);
            },
            selected: selectedTab == DriverDockTab.home,
          ),
          _buildDockItem(
            context,
            responsive,
            icon: Icons.bar_chart_rounded,
            label: 'Estatística',
            onTap: () {
              if (onTabSelected != null) {
                onTabSelected!(DriverDockTab.stats);
                return;
              }
              _goStats(context);
            },
            selected: selectedTab == DriverDockTab.stats,
          ),
          GestureDetector(
            onTap: () {
              if (onCenterTap != null) {
                onCenterTap!();
                return;
              }
              _openWithdrawalOrWallet(context);
            },
            child: Container(
              width: responsive.scaledWidth(46),
              height: responsive.scaledWidth(46),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.currency_exchange_rounded,
                color: isDark ? AppColors.darkSurface : AppColors.textLight,
                size: responsive.scaledWidth(26),
              ),
            ),
          ),
          _buildDockItem(
            context,
            responsive,
            icon: Icons.local_taxi_rounded,
            label: 'Viagens',
            onTap: () {
              if (onTabSelected != null) {
                onTabSelected!(DriverDockTab.wallet);
                return;
              }
              _goCenter(context);
            },
            selected: selectedTab == DriverDockTab.wallet,
          ),
          _buildDockItem(
            context,
            responsive,
            icon: Icons.person_outline_rounded,
            label: 'Perfil',
            onTap: () {
              if (onTabSelected != null) {
                onTabSelected!(DriverDockTab.menu);
                return;
              }
              _goMenu(context);
            },
            selected: selectedTab == DriverDockTab.menu,
          ),
        ],
      ),
    );
  }

  Widget _buildDockItem(
    BuildContext context,
    ResponsiveHelper responsive, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? (isDark ? AppColors.primaryGold : AppColors.primaryOrange)
        : (isDark ? Colors.white70 : AppColors.textSecondary);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: responsive.scaledWidth(19)),
            SizedBox(height: responsive.scaledHeight(4)),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: responsive.responsiveFontSize(9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
