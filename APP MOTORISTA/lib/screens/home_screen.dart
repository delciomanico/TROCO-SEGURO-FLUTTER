import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/models/driver_user.dart';
import 'package:troco_seguro_motorista/models/qr_config.dart';
import 'package:troco_seguro_motorista/models/transaction.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/widgets/qr_display_modal.dart';
import 'package:troco_seguro_motorista/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro_motorista/widgets/qr_config_modal.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:troco_seguro_motorista/screens/vehicles_screen.dart';
import 'package:troco_seguro_motorista/screens/earnings_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final DriverUser driver;
  final bool isOnline;
  final String? activeVehicleId;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenWithdrawal;
  final VoidCallback onLogout;
  final VoidCallback? onOpenProfile;
  final bool showBottomDock;

  const HomeScreen({
    super.key,
    required this.driver,
    required this.isOnline,
    this.activeVehicleId,
    required this.onToggleOnline,
    required this.onOpenWithdrawal,
    required this.onLogout,
    this.onOpenProfile,
    this.showBottomDock = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showBalance = true;
  bool _isLoadingQr = false;
  bool _isLoadingStats = false;
  int todayEarnings = 0;
  int todayTrips = 0;
  int currentBalance = 0;
  double? _myRating;
  List<Transaction> transactions = [];
  final ApiService _api = ApiService();
  QrConfig? _qrConfig;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    _loadQrConfig();
    _loadBalance();
    _loadRating();
  }

  Future<void> _loadRating() async {
    final driverId = widget.driver.id;
    if (driverId == null || driverId.isEmpty) return;
    await _api.loadTokens();
    final result = await _api.getMyRating(driverId);
    if (result.isSuccess && mounted) {
      setState(() => _myRating = result.data);
    }
  }

  Future<void> _loadBalance() async {
    try {
      await _api.loadTokens();
      final profileResult = await _api.getProfile();
      if (profileResult.isSuccess && profileResult.data != null) {
        final profile = profileResult.data!;
        if (mounted) {
          setState(() {
            currentBalance = profile.balance;
            todayEarnings = profile.balance;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar saldo: $e');
    }
  }

  Future<void> _loadQrConfig() async {
    var config = await QrConfig.load();
    if (config == null) {
      final token =
          await QrConfig.generateDriverToken(widget.driver.id ?? 'driver_001');
      config = QrConfig(driverToken: token);
      await config.save();
    }
    setState(() => _qrConfig = config);
  }

  Future<void> _loadTodayStats() async {
    if (_isLoadingStats) return;

    setState(() => _isLoadingStats = true);

    try {
      await _api.loadTokens();

      final earningsResult = await _api.getEarnings();
      final transactionsResult = await _api.getTransactionHistory(limit: 10);

      if (mounted) {
        setState(() {
          if (earningsResult.isSuccess && earningsResult.data != null) {
            todayEarnings = earningsResult.data!.todayAmount;
            todayTrips = earningsResult.data!.todayTrips;
          }

          if (transactionsResult.isSuccess && transactionsResult.data != null) {
            transactions = transactionsResult.data!;
          } else {
            transactions = [];
          }

          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar estatísticas: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          transactions = [];
        });
      }
    }
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  Future<void> _showQRCode() async {
    if (_qrConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carregando configuração...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _isLoadingQr = true);
    await _api.loadTokens();
    final result = await _api.getMyStaticQrCode();
    if (!mounted) return;
    setState(() => _isLoadingQr = false);

    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Não foi possível carregar o QR Code.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final qr = result.data!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QrDisplayModal(
        qrData: qr.publicToken,
        qrCodeImage: qr.qrCodeImage,
        amount: qr.currentAmount > 0
            ? qr.currentAmount
            : ((_qrConfig?.currentFare ?? 0) > 0
                ? _qrConfig!.currentFare
                : null),
        currency: qr.currency,
        driverName:
            qr.driverName.isNotEmpty ? qr.driverName : widget.driver.fullName,
        routeName: _qrConfig?.activeRouteName,
        onClose: () {},
        onUpdateAmount: (newAmount) async {
          await _api.loadTokens();
          final description = (_qrConfig?.activeRouteName != null &&
                  _qrConfig!.activeRouteName!.trim().isNotEmpty)
              ? _qrConfig!.activeRouteName!.trim()
              : 'Corrida';
          final priceResult = await _api.setQrCodePrice(
            amount: newAmount,
            description: description,
            activeVehicleId: widget.activeVehicleId,
          );

          if (priceResult.isSuccess) {
            if (_qrConfig != null) {
              final newConfig = _qrConfig!.copyWith(currentFare: newAmount);
              await newConfig.save();
              if (mounted) setState(() => _qrConfig = newConfig);
            }
            return true;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(priceResult.error ?? 'Erro ao atualizar valor'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        },
      ),
    );
  }

  void _scanPassengerQR() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QRScannerModal(
        onQRScanned: (scannedData) {
          Navigator.pop(context);
          _processScannedQR(scannedData);
        },
        onCancel: () {},
      ),
    );
  }

  void _processScannedQR(String scannedData) {
    final parts = scannedData.split(':');

    String passengerName = 'Passageiro';
    int amount = 0;
    String passengerId = '';

    if (scannedData.startsWith('troco_seguro:')) {
      if (parts.length >= 3) passengerId = parts[2];
      if (parts.length >= 4) amount = int.tryParse(parts[3]) ?? 0;
      if (parts.length >= 5) passengerName = parts[4];
    }

    _showPaymentConfirmation(
      passengerName: passengerName,
      passengerId: passengerId,
      amount: amount,
      rawData: scannedData,
    );
  }

  void _showPaymentConfirmation({
    required String passengerName,
    required String passengerId,
    required int amount,
    required String rawData,
  }) {
    final responsive = ResponsiveHelper(context);
    final amountController = TextEditingController(
      text: amount > 0 ? amount.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = isDark ? AppColors.darkCard : Colors.white;
        final primaryText = isDark ? Colors.white : AppColors.textDark;
        final subtleText = isDark
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.black.withValues(alpha: 0.4);
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.12);

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.scaledWidth(24),
              responsive.scaledHeight(16),
              responsive.scaledWidth(24),
              responsive.scaledHeight(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(24)),
                Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(18)),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: responsive.scaledWidth(52),
                    color: AppColors.primaryGold,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
                Text(
                  'CARTÃO VIRTUAL DETECTADO',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGold,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(4)),
                Text(
                  passengerName,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(20),
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(24)),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(36),
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: subtleText),
                    suffixText: 'Kz',
                    suffixStyle: TextStyle(
                      fontSize: responsive.responsiveFontSize(20),
                      fontWeight: FontWeight.w700,
                      color: subtleText,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primaryGold, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    labelText: 'Valor da corrida',
                    labelStyle: TextStyle(color: subtleText),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(24)),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: responsive.scaledHeight(16),
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'CANCELAR',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(14),
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: responsive.scaledWidth(12)),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          final tripAmount =
                              int.tryParse(amountController.text) ?? 0;
                          if (tripAmount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Digite um valor válido'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          _confirmPayment(passengerId, passengerName, tripAmount);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: responsive.scaledHeight(16),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'COBRAR',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(16),
                                fontWeight: FontWeight.w900,
                                color: Colors.black.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmPayment(String passengerId, String passengerName, int amount) {
    final responsive = ResponsiveHelper(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardColor = isDark ? AppColors.darkCard : Colors.white;
        final primaryText = isDark ? Colors.white : AppColors.textDark;
        final subtleText = isDark
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.black.withValues(alpha: 0.4);

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.scaledWidth(24),
              responsive.scaledHeight(16),
              responsive.scaledWidth(24),
              responsive.scaledHeight(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(32)),
                Container(
                  width: responsive.scaledWidth(96),
                  height: responsive.scaledWidth(96),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.15 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: responsive.scaledWidth(60),
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(20)),
                Text(
                  'PAGAMENTO RECEBIDO!',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(16),
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(12)),
                Text(
                  _formatCurrency(amount),
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(40),
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(4)),
                Text(
                  'de $passengerName',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    color: subtleText,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(32)),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _loadTodayStats();
                      _loadBalance();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: responsive.scaledHeight(16),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'CONTINUAR',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(14),
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(responsive),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _loadTodayStats(),
                    _loadBalance(),
                    _loadQrConfig(),
                  ]);
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildBalanceSection(responsive),
                    Container(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    SizedBox(height: responsive.scaledHeight(24)),
                    _buildQuickActions(responsive),
                    SizedBox(height: responsive.scaledHeight(32)),
                    _buildRecentTransactions(responsive, isDark),
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

  Widget _buildHeader(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(14),
      ),
      child: Row(
        children: [
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
          if (_myRating != null)
            Container(
              margin: EdgeInsets.only(right: responsive.scaledWidth(6)),
              padding: EdgeInsets.symmetric(
                  horizontal: responsive.scaledWidth(8),
                  vertical: responsive.scaledHeight(4)),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: responsive.scaledWidth(13),
                      color: AppColors.primaryGold),
                  SizedBox(width: responsive.scaledWidth(3)),
                  Text(
                    _myRating!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(12),
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          _headerIconButton(
            icon: widget.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            onTap: widget.onToggleOnline,
            isDark: isDark,
            responsive: responsive,
            color: widget.isOnline ? AppColors.online : AppColors.offline,
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
    required ResponsiveHelper responsive,
    Color? color,
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
          color: color ??
              (isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppColors.textDark.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _buildBalanceSection(ResponsiveHelper responsive) {
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
                      ? NumberFormat('#,##0', 'pt_AO').format(currentBalance)
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
          if (todayTrips > 0) ...[
            SizedBox(height: responsive.scaledHeight(8)),
            Text(
              '$todayTrips corrida${todayTrips != 1 ? 's' : ''} hoje',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.38),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions(ResponsiveHelper responsive) {
    final mainActions = [
      (
        icon: Icons.downloading_rounded,
        label: 'Cobrar',
        onTap: widget.isOnline ? _scanPassengerQR : widget.onToggleOnline,
      ),
      (
        icon: Icons.qr_code_2_rounded,
        label: 'QR Code',
        onTap: widget.isOnline
            ? () {
                if (_isLoadingQr) return;
                _showQRCode();
              }
            : widget.onToggleOnline,
      ),
      (
        icon: Icons.directions_car_rounded,
        label: 'Veículos',
        onTap: () => _openScreen(const VehiclesScreen()),
      ),
      (
        icon: Icons.grid_view_rounded,
        label: 'Mais',
        onTap: _showMoreActionsModal,
      ),
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
                    isLoading: a.label == 'QR Code' && _isLoadingQr,
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
                      title: 'Corridas',
                      items: [
                        (
                          icon: Icons.downloading_rounded,
                          label: 'Cobrar',
                          onTap: widget.isOnline
                              ? _scanPassengerQR
                              : widget.onToggleOnline,
                        ),
                        (
                          icon: Icons.qr_code_2_rounded,
                          label: 'Meu QR',
                          onTap: widget.isOnline
                              ? () {
                                  if (_isLoadingQr) return;
                                  _showQRCode();
                                }
                              : widget.onToggleOnline,
                        ),
                        (
                          icon: Icons.tune_rounded,
                          label: 'Config. QR',
                          onTap: _showQRConfig,
                        ),
                      ],
                    ),
                    _buildActionCategory(
                      ctx: ctx,
                      responsive: responsive,
                      isDark: isDark,
                      title: 'Veículo',
                      items: [
                        (
                          icon: Icons.directions_car_rounded,
                          label: 'Veículos',
                          onTap: () => _openScreen(const VehiclesScreen()),
                        ),
                      ],
                    ),
                    _buildActionCategory(
                      ctx: ctx,
                      responsive: responsive,
                      isDark: isDark,
                      title: 'Finanças',
                      items: [
                        (
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Levantar',
                          onTap: widget.onOpenWithdrawal,
                        ),
                        (
                          icon: Icons.bar_chart_rounded,
                          label: 'Ganhos',
                          onTap: () => _openScreen(
                              EarningsScreen(driver: widget.driver)),
                        ),
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

  void _showQRConfig() {
    if (_qrConfig == null) return;

    QrConfigModal.show(
      context,
      currentConfig: _qrConfig!,
      onConfigSaved: (newConfig) async {
        final fare = newConfig.currentFare;
        if (fare <= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Defina um valor maior que 0 para o QR Code.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await _api.loadTokens();
        final description = (newConfig.activeRouteName != null &&
                newConfig.activeRouteName!.trim().isNotEmpty)
            ? newConfig.activeRouteName!.trim()
            : 'Corrida';
        final priceResult = await _api.setQrCodePrice(
          amount: fare,
          description: description,
          activeVehicleId: widget.activeVehicleId,
        );

        if (!priceResult.isSuccess) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                priceResult.error ??
                    'Não foi possível definir o preço do QR Code na API.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await newConfig.save();
        if (!mounted) return;
        setState(() => _qrConfig = newConfig);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Preço do QR atualizado: ${_formatCurrency(newConfig.currentFare)}',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.adaptiveAccent(context),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );
  }

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Widget _buildCircularActionButton(
    ResponsiveHelper responsive, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppColors.accentOf(context);
    final iconColor = isDark
        ? Colors.black.withValues(alpha: 0.8)
        : Colors.white;
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
              color: accentColor,
            ),
            child: isLoading
                ? Padding(
                    padding: EdgeInsets.all(responsive.scaledWidth(14)),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    icon,
                    color: iconColor,
                    size: responsive.scaledWidth(24),
                  ),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(8)),
        Text(
          isLoading ? 'Aguarde' : label,
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

  Widget _buildRecentTransactions(ResponsiveHelper responsive, bool isDark) {
    final recent = transactions.take(3).toList();

    if (recent.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(20),
          vertical: responsive.scaledHeight(32),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: responsive.scaledWidth(40),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.2),
              ),
              SizedBox(height: responsive.scaledHeight(12)),
              Text(
                'Nenhuma transação',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(13),
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          margin: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
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
              final isReceived = tx.type.toLowerCase().contains('received') ||
                  tx.type.toLowerCase().contains('deposit');

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
                            isReceived
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: isReceived
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: responsive.scaledWidth(18),
                          ),
                        ),
                        SizedBox(width: responsive.scaledWidth(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.description.isNotEmpty
                                    ? tx.description
                                    : tx.type,
                                style: TextStyle(
                                  fontSize: responsive.responsiveFontSize(13),
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white : AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: responsive.scaledHeight(2)),
                              Text(
                                tx.date,
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
                          '${isReceived ? "+" : "-"}${_formatCurrency(tx.amount.abs())}',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(13),
                            fontWeight: FontWeight.w700,
                            color: isReceived
                                ? Colors.greenAccent
                                : Colors.redAccent,
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
            }).toList(),
          ),
        ),
      ],
    );
  }
}
