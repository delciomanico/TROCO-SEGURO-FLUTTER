import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro/services/payment_service.dart';
import 'package:troco_seguro/widgets/payment_confirmation_modal.dart';
import 'package:troco_seguro/security/pin_guard.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';
import 'package:troco_seguro/services/api_service.dart' show AppNotification;
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenScanner;
  final VoidCallback? onOpenTopup;
  final VoidCallback? onOpenCards;
  final Future<bool> Function(double latitude, double longitude)? onPanic;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onTerminateSession;

  const HomeScreen({
    super.key,
    required this.onOpenScanner,
    this.onOpenTopup,
    this.onOpenCards,
    this.onPanic,
    this.onOpenProfile,
    this.onTerminateSession,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showBalance = false;
  bool _isPanicLoading = false;

  // Panic mode state
  bool _isPanicActive = false;
  Timer? _panicTimer;
  DateTime? _panicStartTime;
  static const _panicInterval = Duration(seconds: 30);
  static const _panicMaxDuration = Duration(hours: 5);

  @override
  void dispose() {
    _panicTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmTerminateSession() async {
    final responsive = ResponsiveHelper(context);
    final shouldTerminate = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: responsive.scaledWidth(24),
            right: responsive.scaledWidth(24),
            top: responsive.scaledHeight(16),
            bottom: MediaQuery.of(context).viewInsets.bottom +
                responsive.scaledHeight(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Center(
                child: Text(
                  'Terminar sessão?',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(18),
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(12)),
              Center(
                child: Text(
                  'Tem certeza que deseja terminar a sessão nesta conta?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.72 * 255).round()),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(28)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
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
                          borderRadius: BorderRadius.circular(14),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Terminar sessão',
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
          ),
        );
      },
    );

    if (shouldTerminate == true) {
      widget.onTerminateSession?.call();
    }
  }

  Future<void> _confirmPanicAction() async {
    final responsive = ResponsiveHelper(context);
    final shouldTrigger = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: responsive.scaledWidth(24),
            right: responsive.scaledWidth(24),
            top: responsive.scaledHeight(16),
            bottom: MediaQuery.of(context).viewInsets.bottom +
                responsive.scaledHeight(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Center(
                child: Text(
                  'Acionar pânico?',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(18),
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(12)),
              Center(
                child: Text(
                  'Esta ação vai notificar as autoridades e os seus contatos de emergência.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.72 * 255).round()),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(28)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
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
                          borderRadius: BorderRadius.circular(14),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Acionar pânico',
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
          ),
        );
      },
    );

    if (shouldTrigger == true) {
      await _startPanicMode();
    }
  }

  Future<void> _confirmStopPanic() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar emergência?'),
        content: const Text('A sua localização deixará de ser partilhada com as autoridades e contactos de emergência.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (stop == true) _stopPanicMode();
  }

  Future<(double, double)> _getCurrentLocation() async {
    const double defaultLat = -8.839988;
    const double defaultLng = 13.289437;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (defaultLat, defaultLng);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return (defaultLat, defaultLng);
    }
  }

  Future<void> _startPanicMode() async {
    setState(() => _isPanicLoading = true);
    final (lat, lng) = await _getCurrentLocation();
    final success = widget.onPanic != null ? await widget.onPanic!(lat, lng) : false;
    if (!mounted) return;

    setState(() {
      _isPanicLoading = false;
      if (success) {
        _isPanicActive = true;
        _panicStartTime = DateTime.now();
      }
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao activar emergência. Tente novamente.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Loop every 30 s — backend updates GPS silently, only 1st call fires alerts
    _panicTimer = Timer.periodic(_panicInterval, (_) async {
      if (!mounted) { _panicTimer?.cancel(); return; }
      final elapsed = DateTime.now().difference(_panicStartTime!);
      if (elapsed >= _panicMaxDuration) { _stopPanicMode(); return; }
      final (la, lo) = await _getCurrentLocation();
      if (widget.onPanic != null) await widget.onPanic!(la, lo);
    });
  }

  void _stopPanicMode() {
    _panicTimer?.cancel();
    _panicTimer = null;
    if (mounted) setState(() { _isPanicActive = false; _panicStartTime = null; });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AppProvider>();
    final user = provider.user;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(responsive, user),
            if (_isPanicActive)
              GestureDetector(
                onTap: _confirmStopPanic,
                child: Container(
                  width: double.infinity,
                  color: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'EMERGÊNCIA ACTIVA — A enviar localização  •  Toque para encerrar',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => provider.refreshUserData(),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildBalanceCard(responsive, user),
                    Container(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    SizedBox(height: responsive.scaledHeight(24)),
                    _buildQuickActions(responsive),
                    SizedBox(height: responsive.scaledHeight(32)),
                    _buildRecentTransactions(responsive, provider, isDark),
                    SizedBox(height: responsive.scaledHeight(100)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveHelper responsive, User? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(14),
      ),
      child: Row(
        children: [
          // Avatar com ícone de pessoa
          GestureDetector(
            onTap: () => widget.onOpenProfile?.call(),
            child: Container(
              width: responsive.scaledWidth(42),
              height: responsive.scaledWidth(42),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                border: Border.all(color: Colors.transparent, width: 1.5),
              ),
              child: Icon(
                Icons.person_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textDark.withValues(alpha: 0.7),
                size: responsive.scaledWidth(22),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Troco Seguro',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(17),
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          Row(
            children: [
              _headerIconButton(
                icon: Icons.qr_code_scanner_rounded,
                onTap: widget.onOpenScanner,
                isDark: isDark,
                responsive: responsive,
              ),
              SizedBox(width: responsive.scaledWidth(8)),
              _headerIconButton(
                icon: Icons.notifications_outlined,
                onTap: _showNotificationsModal,
                isDark: isDark,
                responsive: responsive,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationsModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, _) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: const _NotificationsSheet(),
        );
      },
    );
  }

  Widget _buildBalanceCard(ResponsiveHelper responsive, User? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.scaledWidth(20),
        responsive.scaledHeight(20),
        responsive.scaledWidth(20),
        responsive.scaledHeight(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Saldo total',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(13),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: responsive.scaledWidth(8)),
              GestureDetector(
                onTap: () => setState(() => showBalance = !showBalance),
                child: Icon(
                  showBalance
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: responsive.scaledWidth(16),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scaledHeight(10)),
          GestureDetector(
            onTap: () => setState(() => showBalance = !showBalance),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  showBalance
                      ? NumberFormat('#,##0', 'pt_AO').format(user?.balance ?? 0)
                      : '••••••',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(38),
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textDark,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(6)),
                Padding(
                  padding: EdgeInsets.only(bottom: responsive.scaledHeight(5)),
                  child: Text(
                    'kzs',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(16),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppColors.textDark.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ResponsiveHelper responsive) {
    final mainActions = [
      (icon: Icons.qr_code, label: 'Pagar QR', onTap: _handlePayWithQr),
      (icon: Icons.account_balance_wallet_outlined, label: 'Recarregar', onTap: _handleTopup),
      (icon: Icons.qr_code_2_rounded, label: 'Meu QR', onTap: _handleShowMyQrCode),
      (icon: Icons.grid_view_rounded, label: 'Mais', onTap: _showMoreActionsModal),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: mainActions
            .map((a) => Expanded(
                  child: _buildCircularActionButton(
                    responsive,
                    icon: a.icon,
                    label: a.label,
                    onTap: a.onTap,
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showMoreActionsModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, _) {
        final responsive = ResponsiveHelper(ctx);
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: _buildMoreActionsSheet(ctx, responsive, isDark),
        );
      },
    );
  }

  Widget _buildMoreActionsSheet(
      BuildContext ctx, ResponsiveHelper responsive, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.scaledWidth(20),
                responsive.scaledHeight(16),
                responsive.scaledWidth(20),
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ações rápidas',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(18),
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: responsive.scaledWidth(36),
                      height: responsive.scaledWidth(36),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: responsive.scaledWidth(18),
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionCategory(
                      ctx: ctx,
                      responsive: responsive,
                      isDark: isDark,
                      title: 'Pagamentos',
                      items: [
                        (icon: Icons.qr_code, label: 'Pagar com QR', onTap: _handlePayWithQr),
                        (icon: Icons.qr_code_scanner, label: 'Identificar QR', onTap: _handleIdentifyQr),
                        (icon: Icons.qr_code_2_rounded, label: 'Meu QR', onTap: _handleShowMyQrCode),
                      ],
                    ),
                    _buildActionCategory(
                      ctx: ctx,
                      responsive: responsive,
                      isDark: isDark,
                      title: 'Carteira',
                      items: [
                        (icon: Icons.account_balance_wallet_outlined, label: 'Recarregar', onTap: _handleTopup),
                      ],
                    ),
                    _buildActionCategory(
                      ctx: ctx,
                      responsive: responsive,
                      isDark: isDark,
                      title: 'Segurança',
                      items: [
                        (icon: _isPanicActive ? Icons.crisis_alert_rounded : Icons.warning_amber_rounded, label: _isPanicActive ? 'Encerrar' : 'Pânico', onTap: _isPanicLoading ? () {} : (_isPanicActive ? _confirmStopPanic : _confirmPanicAction)),
                      ],
                    ),
                    SizedBox(height: responsive.scaledHeight(24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCategory({
    required BuildContext ctx,
    required ResponsiveHelper responsive,
    required bool isDark,
    required String title,
    required List<({IconData icon, String label, VoidCallback onTap})> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: responsive.scaledHeight(20)),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(11),
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.35),
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: responsive.scaledHeight(12)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: responsive.scaledHeight(12),
            crossAxisSpacing: responsive.scaledWidth(8),
            childAspectRatio: 0.85,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return _buildCircularActionButton(
              responsive,
              icon: item.icon,
              label: item.label,
              onTap: () {
                Navigator.pop(ctx);
                item.onTap();
              },
            );
          },
        ),
      ],
    );
  }

  void _handleTopup() {
    if (widget.onOpenTopup != null) {
      widget.onOpenTopup!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recarga indisponível no momento.')),
    );
  }

  Widget _buildQrCodePreview(String qrCode) {
    final normalized = qrCode.trim();

    if (normalized.startsWith('data:image')) {
      final base64Data = normalized.split(',').last;
      return Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.contain,
      );
    }

    if (normalized.startsWith('http')) {
      return Image.network(
        normalized,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.qr_code_2_rounded,
          size: 140,
        ),
      );
    }

    return SelectableText(
      normalized,
      textAlign: TextAlign.center,
    );
  }

  Future<void> _handleShowMyQrCode() async {
    final apiService = context.read<AppProvider>().apiService;
    final response = await apiService.getMyQrCode();

    if (!mounted) return;

    if (!response.isSuccess ||
        response.data == null ||
        response.data!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.error ?? 'Não foi possível carregar o seu QR Code.',
          ),
        ),
      );
      return;
    }

    final qrCode = response.data!;
    final responsive = ResponsiveHelper(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
          ),
          padding: EdgeInsets.only(
            left: responsive.scaledWidth(24),
            right: responsive.scaledWidth(24),
            top: responsive.scaledHeight(16),
            bottom: MediaQuery.of(context).viewInsets.bottom +
                responsive.scaledHeight(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Text(
                'Seu QR Code',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(12)),
              Container(
                width: responsive.scaledWidth(240),
                height: responsive.scaledWidth(240),
                padding: EdgeInsets.all(responsive.scaledWidth(16)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: _buildQrCodePreview(qrCode),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(16)),
              Text(
                'Mostre este QR code quando precisar identificar a sua conta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.72 * 255).round()),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.credit_card_rounded),
                  label: const Text('Mostrar Cartão Virtual'),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onOpenCards?.call();
                  },
                ),
              ),
              SizedBox(height: responsive.scaledHeight(10)),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleIdentifyQr() async {
    final qrData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QRScannerModal(
        title: 'IDENTIFICAR MOTORISTA',
        subtitle: 'Aponte a câmera para o QR do motorista',
        onCancel: () {},
        onQRScanned: (data) => Navigator.pop(context, data),
      ),
    );

    if (qrData == null) return;
    if (!mounted) return;

    final paymentService = PaymentService();
    final validation = await paymentService.validateQrCode(context, qrData);
    if (!mounted) return;
    if (validation == null) return;

    // Show identification info (without triggering payment)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informações do QR',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('Motorista: ${validation.driverName ?? 'Desconhecido'}'),
            Text('Veículo: ${validation.licensePlate ?? 'Desconhecido'}'),
            Text(
                'Valor: ${validation.amount != null ? '${validation.amount} Kz' : 'N/A'}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (validation.driverId != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showTransferToDriverSheet(
                        driverId: validation.driverId!,
                        driverName: validation.driverName ?? 'Motorista',
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Transferir para este motorista'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransferToDriverSheet({
    required String driverId,
    required String driverName,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverTransferSheet(
        driverId: driverId,
        driverName: driverName,
      ),
    );
  }

  Future<void> _handlePayWithQr() async {
    // Open scanner modal and get scanned data
    final qrData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QRScannerModal(
        onCancel: () {},
        onQRScanned: (data) => Navigator.pop(context, data),
      ),
    );

    if (qrData == null) return;
    if (!mounted) return;

    // Validate QR via PaymentService
    final paymentService = PaymentService();
    final validation = await paymentService.validateQrCode(context, qrData);
    if (!mounted) return;
    if (validation == null || !validation.valid) {
      // Errors are shown by PaymentService/FeedbackService
      return;
    }

    // Determine amount/origin/destination
    int amount = validation.amount ?? 0;
    String origin = 'Origem';
    String destination = 'Destino';

    // If amount not provided by QR, ask user
    if (amount == 0) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          final amountController = TextEditingController();
          final originController = TextEditingController();
          final destinationController = TextEditingController();
          return AlertDialog(
            title: const Text('Detalhes do Pagamento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor (Kz)'),
                ),
                TextField(
                  controller: originController,
                  decoration: const InputDecoration(labelText: 'Origem'),
                ),
                TextField(
                  controller: destinationController,
                  decoration: const InputDecoration(labelText: 'Destino'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final a = int.tryParse(amountController.text) ?? 0;
                  Navigator.pop(context, {
                    'amount': a,
                    'origin': originController.text.trim(),
                    'destination': destinationController.text.trim(),
                  });
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (result == null) return;
      amount = (result['amount'] as int?) ?? 0;
      origin = (result['origin'] as String?)?.isNotEmpty == true
          ? result['origin'] as String
          : origin;
      destination = (result['destination'] as String?)?.isNotEmpty == true
          ? result['destination'] as String
          : destination;
    }

    // Show confirmation modal with driver info and amount
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentConfirmationModal(
        driverInfo: validation,
        amount: amount,
        origin: origin,
        destination: destination,
        pinValidator: (pin) async {
          return await PinGuard.validatePin(
            scope: 'payment',
            enteredPin: pin,
            readExpectedPin: () => SecureStorageService().readPin(),
          );
        },
        onSuccess: (_) {
          // Dados já foram invalidados dentro do PaymentConfirmationModal.
        },
        onCancel: () {},
      ),
    );
  }

  Widget _buildCircularActionButton(
    ResponsiveHelper responsive, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: responsive.scaledWidth(58),
            height: responsive.scaledWidth(58),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentOf(context),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white,
              size: responsive.scaledWidth(24),
            ),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(11),
            color: isDark
                ? Colors.white.withValues(alpha: 0.75)
                : AppColors.textDark.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
    required ResponsiveHelper responsive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: responsive.scaledWidth(38),
        height: responsive.scaledWidth(38),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        child: Icon(
          icon,
          size: responsive.scaledWidth(20),
          color: isDark
              ? Colors.white.withValues(alpha: 0.85)
              : AppColors.textDark.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(
    ResponsiveHelper responsive,
    AppProvider provider,
    bool isDark,
  ) {
    final recent = provider.transactions.take(3).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            responsive.scaledWidth(20),
            0,
            responsive.scaledWidth(20),
            responsive.scaledHeight(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transações recentes',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(15),
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              Text(
                'Ver todas',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentOf(context),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin:
              EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            children: recent.asMap().entries.map((entry) {
              final tx = entry.value;
              final isLast = entry.key == recent.length - 1;
              return _buildTransactionTile(responsive, tx, isDark, isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    ResponsiveHelper responsive,
    Transaction tx,
    bool isDark,
    bool isLast,
  ) {
    final isOutgoing = tx.isOutgoing;
    final displayAmount = (tx.displayAmount ?? tx.amount).abs();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.scaledWidth(16),
            vertical: responsive.scaledHeight(14),
          ),
          child: Row(
            children: [
              Container(
                width: responsive.scaledWidth(40),
                height: responsive.scaledWidth(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                child: Icon(
                  isOutgoing
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: isOutgoing ? Colors.redAccent : Colors.greenAccent,
                  size: responsive.scaledWidth(18),
                ),
              ),
              SizedBox(width: responsive.scaledWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description.isNotEmpty ? tx.description : tx.type,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(13),
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: responsive.scaledHeight(2)),
                    Text(
                      '${tx.date} ${tx.time}'.trim(),
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(11),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isOutgoing ? "-" : "+"}${NumberFormat('#,##0', 'pt_AO').format(displayAmount)} kzs',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(13),
                  fontWeight: FontWeight.w700,
                  color:
                      isOutgoing ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: responsive.scaledWidth(68),
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transferência directa para um motorista identificado por QR
// ---------------------------------------------------------------------------

class _DriverTransferSheet extends StatefulWidget {
  final String driverId;
  final String driverName;

  const _DriverTransferSheet({required this.driverId, required this.driverName});

  @override
  State<_DriverTransferSheet> createState() => _DriverTransferSheetState();
}

class _DriverTransferSheetState extends State<_DriverTransferSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe um montante válido.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final provider = context.read<AppProvider>();
    final ok = await provider.transfer(
      receiverId: widget.driverId,
      amount: amount,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      FeedbackService.showSuccess(context,
          message: 'Transferência para ${widget.driverName} realizada com sucesso!');
      return;
    }
    setState(() {
      _loading = false;
      _error = provider.error ?? 'Erro ao realizar transferência.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : AppColors.textDark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Transferir para ${widget.driverName}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface)),
            const SizedBox(height: 4),
            Text('O valor sai da sua carteira Troco Seguro',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.45))),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valor',
                suffixText: 'Kz',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Descrição (opcional)',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOf(context),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Confirmar Transferência',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications fullscreen sheet
// ---------------------------------------------------------------------------

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AppProvider>().apiService;
    final result = await api.getNotifications();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _notifications = result.data!.notifications;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.error ?? 'Erro ao carregar notificações';
        _loading = false;
      });
    }
  }

  Future<void> _markRead(String id) async {
    final api = context.read<AppProvider>().apiService;
    await api.markNotificationRead(id);
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == id ? _copyRead(n) : n)
          .toList();
    });
  }

  Future<void> _markAllRead() async {
    final api = context.read<AppProvider>().apiService;
    await api.markAllNotificationsRead();
    setState(() {
      _notifications = _notifications.map(_copyRead).toList();
    });
  }

  AppNotification _copyRead(AppNotification n) => AppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        message: n.message,
        read: true,
        createdAt: n.createdAt,
      );

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.payments_outlined;
      case 'topup':
      case 'deposit':
        return Icons.account_balance_wallet_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textMain = isDark ? Colors.white : AppColors.textDark;
    final textSub = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.4);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notificações',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                        ),
                      ),
                      if (_unreadCount > 0)
                        Text(
                          '$_unreadCount não lida${_unreadCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accentOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_unreadCount > 0)
                        GestureDetector(
                          onTap: _markAllRead,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accentOf(context)
                                  .withValues(alpha: isDark ? 0.15 : 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    AppColors.accentOf(context).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'Ler todas',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentOf(context),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: textMain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Body
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentOf(context)))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  color: textSub, size: 40),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(color: textSub,
                                      fontSize: 14)),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: _loadNotifications,
                                child: Text(
                                  'Tentar novamente',
                                  style: TextStyle(
                                    color: AppColors.accentOf(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none_rounded,
                                      size: 52,
                                      color: textSub),
                                  const SizedBox(height: 12),
                                  Text('Sem notificações',
                                      style: TextStyle(
                                          color: textSub, fontSize: 15)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadNotifications,
                              color: AppColors.accentOf(context),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                itemCount: _notifications.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final n = _notifications[i];
                                  return GestureDetector(
                                    onTap: n.read ? null : () => _markRead(n.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: n.read
                                            ? cardBg
                                            : isDark
                                                ? AppColors.accentOf(context)
                                                    .withValues(alpha: 0.08)
                                                : AppColors.accentOf(context)
                                                    .withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: n.read
                                              ? (isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.06)
                                                  : Colors.black
                                                      .withValues(alpha: 0.05))
                                              : AppColors.accentOf(context)
                                                  .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.07)
                                                  : Colors.black
                                                      .withValues(alpha: 0.04),
                                              border: Border.all(
                                                color: AppColors.accentOf(context)
                                                    .withValues(alpha: 0.4),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Icon(
                                              _iconForType(n.type),
                                              size: 18,
                                              color: AppColors.accentOf(context),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        n.title,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: textMain,
                                                        ),
                                                      ),
                                                    ),
                                                    if (!n.read)
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            const BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: AppColors
                                                              .primaryGold,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  n.message,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: textSub,
                                                    height: 1.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  DateFormat(
                                                          'dd/MM/yyyy HH:mm',
                                                          'pt_AO')
                                                      .format(n.createdAt),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: textSub,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
