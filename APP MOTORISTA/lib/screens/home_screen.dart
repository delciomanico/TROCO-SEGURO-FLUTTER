import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:troco_seguro_pro/models/driver_user.dart';
import 'package:troco_seguro_pro/models/qr_config.dart';
import 'package:troco_seguro_pro/models/transaction.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/widgets/qr_display_modal.dart';
import 'package:troco_seguro_pro/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro_pro/widgets/qr_config_modal.dart';
import 'package:troco_seguro_pro/widgets/passenger_rating_modal.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:troco_seguro_pro/screens/vehicles_screen.dart';
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

  // Sessão activa de assentos
  bool _hasActiveSession = false;
  int _paidSeats = 0;
  int _totalSeats = 0;
  String? _sessionPublicToken;
  StreamSubscription<SessionSeatsResult>? _sseSubscription;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    _loadQrConfig();
    _loadBalance();
    _loadRating();
    _startSseStream();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startSseStream() async {
    await _api.loadTokens(); // garantir token antes de SSE e REST
    _loadSessionSeats(); // snapshot imediato via REST
    if (!mounted) return;
    _sseSubscription = _api.streamSessionSeats().listen(
      (seats) {
        if (!mounted) return;
        setState(() {
          _hasActiveSession = seats.active;
          _paidSeats = seats.paidSeats;
          _totalSeats = seats.totalSeats;
          _sessionPublicToken = seats.publicToken;
        });
      },
      onError: (e) => debugPrint('SSE error: $e'),
    );
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
    if (mounted) setState(() => _qrConfig = config);
  }

  Future<void> _loadSessionSeats() async {
    await _api.loadTokens();
    final result = await _api.getSessionSeats();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      final seats = result.data!;
      setState(() {
        _hasActiveSession = seats.active;
        _paidSeats = seats.paidSeats;
        _totalSeats = seats.totalSeats;
        _sessionPublicToken = seats.publicToken;
      });
      // Sincronizar publicToken no QrConfig local se diferente
      if (seats.publicToken != null &&
          seats.publicToken != _qrConfig?.sessionPublicToken &&
          _qrConfig != null) {
        final updated = _qrConfig!.copyWith(sessionPublicToken: seats.publicToken);
        await updated.save();
        if (mounted) setState(() => _qrConfig = updated);
      }
    } else {
      setState(() => _hasActiveSession = false);
    }
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
    final qrImage = _qrConfig?.parentQrImage;

    // Sem sessão activa — redirigir para configuração
    if (!_hasActiveSession || qrImage == null || qrImage.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !_hasActiveSession && qrImage != null && qrImage.isNotEmpty
                  ? 'Sessão expirada. Defina um novo preço para iniciar.'
                  : 'Configure o preço para iniciar uma sessão.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _showQRConfig();
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QrDisplayModal(
        qrData: _qrConfig?.sessionPublicToken ?? '',
        qrCodeImage: qrImage,
        amount: (_qrConfig?.currentFare ?? 0) > 0 ? _qrConfig!.currentFare : null,
        currency: 'AOA',
        driverName: widget.driver.fullName,
        childQrs: _qrConfig?.childQrs ?? [],
        onClose: () {},
        onUpdateAmount: (newAmount) async {
          await _api.loadTokens();
          // Encerrar sessão activa antes de iniciar nova com novo preço
          if (_hasActiveSession) await _api.endSession();
          final setupResult = await _api.setupQrSession(
            amount: newAmount,
            activeVehicleId: widget.activeVehicleId,
          );
          if (!setupResult.isSuccess || setupResult.data == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(setupResult.error ?? 'Erro ao actualizar valor'),
                backgroundColor: Colors.red,
              ));
            }
            return false;
          }
          final setup = setupResult.data!;
          final publicToken = setup.parentQr.publicToken.isNotEmpty
              ? setup.parentQr.publicToken
              : null;
          if (_qrConfig != null) {
            final newConfig = _qrConfig!.copyWith(
              currentFare: newAmount,
              parentQrImage: setup.parentQr.image.isNotEmpty
                  ? setup.parentQr.image
                  : _qrConfig!.parentQrImage,
              sessionPublicToken: publicToken ?? _qrConfig!.sessionPublicToken,
              childQrs: setup.childQrs
                  .map((c) => {'id': c.id, 'label': c.label, 'image': c.image})
                  .toList(),
            );
            await newConfig.save();
            if (mounted) {
              setState(() {
                _qrConfig = newConfig;
                _sessionPublicToken = publicToken;
                _hasActiveSession = true;
                _paidSeats = 0;
                _totalSeats = setup.childQrs.length;
              });
            }
          }
          return true;
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

  Future<void> _processScannedQR(String scannedData) async {
    // Fluxo 2 — motorista escaneia o QR estático do cartão virtual do passageiro
    Map<dynamic, dynamic>? qrJson;
    try {
      final decoded = jsonDecode(scannedData);
      if (decoded is Map) qrJson = decoded;
    } catch (_) {
      // Não é JSON válido
    }

    if (qrJson == null || qrJson['type'] != 'VIRTUAL_CARD_TRANSFER') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'QR inválido. Peça ao passageiro para mostrar o QR do cartão virtual.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final pricePerSeat = _qrConfig?.currentFare ?? 0;
    if (!_hasActiveSession || pricePerSeat <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Defina o preço e inicie uma sessão de viagem antes de cobrar.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final passengerName = qrJson['userName']?.toString() ??
        qrJson['cardName']?.toString() ??
        'Passageiro';

    if (!mounted) return;
    _showPassengerPaymentModal(
      rawQrData: scannedData,
      passengerName: passengerName,
      amount: pricePerSeat,
    );
  }

  void _showPassengerPaymentModal({
    required String rawQrData,
    required String passengerName,
    required int amount,
  }) {
    final responsive = ResponsiveHelper(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _PassengerQRPaymentModal(
        rawQrData: rawQrData,
        passengerName: passengerName,
        amount: amount,
        sessionPublicToken:
            _sessionPublicToken ?? _qrConfig?.sessionPublicToken,
        api: _api,
        responsive: responsive,
        onSuccess: (result) {
          _loadTodayStats();
          _loadBalance();
          _loadSessionSeats();

          final tripId = result.tripId;
          if (tripId != null && tripId.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                PassengerRatingModal.show(
                  context,
                  tripId: tripId,
                  passengerName: passengerName,
                  onSubmitRating: (id, stars, comment) async {
                    final response = await _api.rateTrip(
                      tripId: id,
                      stars: stars,
                      comment: comment,
                    );
                    return response.isSuccess;
                  },
                );
              }
            });
          }
        },
      ),
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
                    SizedBox(height: responsive.scaledHeight(16)),
                    if (_hasActiveSession)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.scaledWidth(20),
                          vertical: responsive.scaledHeight(8),
                        ),
                        child: _buildSeatCounter(responsive, isDark),
                      ),
                    SizedBox(height: responsive.scaledHeight(16)),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.scaledWidth(20),
        responsive.scaledHeight(20),
        responsive.scaledWidth(20),
        responsive.scaledHeight(12),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(responsive.scaledWidth(20)),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/card_fundo.jpg'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryGold, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGold.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: responsive.scaledWidth(26),
                  width: responsive.scaledWidth(26),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: responsive.scaledWidth(8)),
                Text(
                  'Troco Seguro Pro',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(13),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(18)),
            Row(
              children: [
                Text(
                  'Saldo total',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(13),
                    color: Colors.white.withValues(alpha: 0.75),
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
                    color: Colors.white.withValues(alpha: 0.65),
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
                      fontSize: responsive.responsiveFontSize(34),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.6),
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
                  color: AppColors.textDark.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
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
                    badge: a.label == 'QR Code' && _hasActiveSession && _totalSeats > 0
                        ? '$_paidSeats/$_totalSeats'
                        : null,
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

        // Veículo obrigatório para iniciar sessão
        if (widget.activeVehicleId == null || widget.activeVehicleId!.isEmpty) {
          return 'Seleccione um veículo antes de iniciar a sessão. Vá offline e escolha um veículo.';
        }

        setState(() => _isLoadingQr = true);
        await _api.loadTokens();
        // Encerrar sessão anterior antes de iniciar nova
        if (_hasActiveSession) await _api.endSession();
        final setupResult = await _api.setupQrSession(
          amount: fare,
          activeVehicleId: widget.activeVehicleId,
        );
        if (!mounted) return null;
        setState(() => _isLoadingQr = false);

        if (!setupResult.isSuccess || setupResult.data == null) {
          return setupResult.error ?? 'Não foi possível iniciar a sessão.';
        }

        final setup = setupResult.data!;
        final publicToken = setup.parentQr.publicToken.isNotEmpty
            ? setup.parentQr.publicToken
            : null;

        final updatedConfig = newConfig.copyWith(
          parentQrImage: setup.parentQr.image.isNotEmpty
              ? setup.parentQr.image
              : newConfig.parentQrImage,
          sessionPublicToken: publicToken ?? newConfig.sessionPublicToken,
          childQrs: setup.childQrs
              .map((c) => {'id': c.id, 'label': c.label, 'image': c.image})
              .toList(),
        );

        await updatedConfig.save();
        if (!mounted) return null;

        setState(() {
          _qrConfig = updatedConfig;
          _sessionPublicToken = publicToken;
          _hasActiveSession = true;
          _paidSeats = 0;
          _totalSeats = setup.childQrs.length;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sessão iniciada — ${_formatCurrency(fare)} por assento. '
                    '${setup.childQrs.length} QR${setup.childQrs.length != 1 ? "s" : ""} gerados.',
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

        return null; // sucesso
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
    String? badge,
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
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
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
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

  Widget _buildSeatCounter(ResponsiveHelper responsive, bool isDark) {
    final accent = AppColors.accentOf(context);
    final filled = _totalSeats > 0 ? _paidSeats / _totalSeats : 0.0;

    return GestureDetector(
      onTap: _loadSessionSeats,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(16),
          vertical: responsive.scaledHeight(12),
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: responsive.scaledWidth(38),
              height: responsive.scaledWidth(38),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_seat_rounded,
                color: accent,
                size: responsive.scaledWidth(20),
              ),
            ),
            SizedBox(width: responsive.scaledWidth(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sessão activa',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(11),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(3)),
                  Row(
                    children: [
                      Text(
                        '$_paidSeats / $_totalSeats assentos pagos',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.scaledHeight(5)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: filled.clamp(0.0, 1.0),
                      minHeight: responsive.scaledHeight(5),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: responsive.scaledWidth(8)),
            GestureDetector(
              onTap: _confirmEndSession,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.scaledWidth(10),
                  vertical: responsive.scaledHeight(6),
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Encerrar',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(11),
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEndSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar sessão'),
        content: const Text(
          'Tem a certeza que deseja encerrar a sessão? Os QR codes dos assentos ficarão inválidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _api.loadTokens();
    final result = await _api.endSession();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _hasActiveSession = false;
        _paidSeats = 0;
        _totalSeats = 0;
        _sessionPublicToken = null;
      });
      // Limpar QrConfig local
      if (_qrConfig != null) {
        final cleared = _qrConfig!.copyWith(
          parentQrImage: '',
          sessionPublicToken: null,
          childQrs: [],
        );
        await cleared.save();
        setState(() => _qrConfig = cleared);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessão encerrada com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Erro ao encerrar sessão.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

// ─── Passenger QR Payment Modal (Fluxo 2: motorista escaneia QR do passageiro) ─

enum _PassengerStep { info, pin, processing, success, error }

class _PassengerQRPaymentModal extends StatefulWidget {
  final String rawQrData;
  final String passengerName;
  final int amount;
  final String? sessionPublicToken;
  final ApiService api;
  final ResponsiveHelper responsive;
  final void Function(PassengerQrPaymentResult result) onSuccess;

  const _PassengerQRPaymentModal({
    required this.rawQrData,
    required this.passengerName,
    required this.amount,
    this.sessionPublicToken,
    required this.api,
    required this.responsive,
    required this.onSuccess,
  });

  @override
  State<_PassengerQRPaymentModal> createState() =>
      _PassengerQRPaymentModalState();
}

class _PassengerQRPaymentModalState extends State<_PassengerQRPaymentModal> {
  _PassengerStep _step = _PassengerStep.info;
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  String _enteredPin = '';
  String? _errorMessage;
  int _seatsCount = 1;
  PassengerQrPaymentResult? _result;

  static const int _pinLength = 6;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(
        () => setState(() => _enteredPin = _pinController.text));
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _proceedToPin() {
    if (_originController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha a origem e o destino.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _step = _PassengerStep.pin);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_pinFocusNode);
    });
  }

  Future<void> _submit() async {
    if (_enteredPin.length != _pinLength) return;

    setState(() => _step = _PassengerStep.processing);
    await widget.api.loadTokens();

    final result = await widget.api.authorizePassengerQr(
      qrData: widget.rawQrData,
      passengerPin: _enteredPin,
      origin: _originController.text.trim(),
      destination: _destinationController.text.trim(),
      seatsCount: _seatsCount,
      parentQrToken: widget.sessionPublicToken,
    );

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _step = _PassengerStep.success;
        _result = result.data;
      });
      widget.onSuccess(result.data!);
    } else {
      setState(() {
        _step = _PassengerStep.error;
        _errorMessage = result.error ?? 'Pagamento recusado pela API.';
      });
    }
  }

  void _retry() {
    _pinController.clear();
    setState(() {
      _step = _PassengerStep.info;
      _errorMessage = null;
    });
  }

  String _formatAmt(int v) {
    return '${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} Kz';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.responsive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final subtleText = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.4);
    const accent = AppColors.primaryGold;

    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            r.scaledWidth(24), r.scaledHeight(16), r.scaledWidth(24), r.scaledHeight(32)),
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
            SizedBox(height: r.scaledHeight(24)),
            if (_step == _PassengerStep.info)
              ..._buildInfoStep(r, isDark, primaryText, subtleText, accent),
            if (_step == _PassengerStep.pin)
              ..._buildPinStep(r, isDark, primaryText, subtleText, accent),
            if (_step == _PassengerStep.processing)
              ..._buildProcessingStep(r, primaryText, subtleText),
            if (_step == _PassengerStep.success)
              ..._buildSuccessStep(r, primaryText, subtleText, accent),
            if (_step == _PassengerStep.error)
              ..._buildErrorStep(r, primaryText),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInfoStep(ResponsiveHelper r, bool isDark, Color primaryText,
      Color subtleText, Color accent) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.12);

    return [
      Icon(Icons.qr_code_scanner_rounded, size: r.scaledWidth(48), color: accent),
      SizedBox(height: r.scaledHeight(8)),
      Text('PAGAMENTO DO PASSAGEIRO',
          style: TextStyle(
              fontSize: r.responsiveFontSize(12),
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.8)),
      SizedBox(height: r.scaledHeight(4)),
      Text(widget.passengerName,
          style: TextStyle(
              fontSize: r.responsiveFontSize(18),
              fontWeight: FontWeight.w700,
              color: primaryText)),
      SizedBox(height: r.scaledHeight(4)),
      Text(_formatAmt(widget.amount),
          style: TextStyle(
              fontSize: r.responsiveFontSize(28),
              fontWeight: FontWeight.w900,
              color: primaryText)),
      SizedBox(height: r.scaledHeight(20)),
      TextField(
        controller: _originController,
        style: TextStyle(fontSize: r.responsiveFontSize(14), color: primaryText),
        decoration: InputDecoration(
          labelText: 'Origem',
          hintText: 'Ex: Roque Santeiro',
          labelStyle: TextStyle(color: subtleText),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
          prefixIcon: Icon(Icons.location_on_outlined, color: subtleText),
        ),
      ),
      SizedBox(height: r.scaledHeight(12)),
      TextField(
        controller: _destinationController,
        style: TextStyle(fontSize: r.responsiveFontSize(14), color: primaryText),
        decoration: InputDecoration(
          labelText: 'Destino',
          hintText: 'Ex: Talatona',
          labelStyle: TextStyle(color: subtleText),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
          prefixIcon:
              Icon(Icons.flag_outlined, color: subtleText),
        ),
      ),
      SizedBox(height: r.scaledHeight(16)),
      // Selector de assentos
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.scaledWidth(16),
          vertical: r.scaledHeight(12),
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.event_seat_rounded, color: accent, size: r.scaledWidth(20)),
            SizedBox(width: r.scaledWidth(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nº de assentos',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(11),
                          color: subtleText,
                          fontWeight: FontWeight.w600)),
                  Text(
                    'Total: ${_formatAmt(widget.amount * _seatsCount)}',
                    style: TextStyle(
                        fontSize: r.responsiveFontSize(13),
                        fontWeight: FontWeight.w800,
                        color: primaryText),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _seatsCount > 1
                      ? () => setState(() => _seatsCount--)
                      : null,
                  child: AnimatedOpacity(
                    opacity: _seatsCount > 1 ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: r.scaledWidth(36),
                      height: r.scaledWidth(36),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.remove_rounded, color: accent, size: r.scaledWidth(18)),
                    ),
                  ),
                ),
                SizedBox(width: r.scaledWidth(14)),
                Text(
                  '$_seatsCount',
                  style: TextStyle(
                    fontSize: r.responsiveFontSize(22),
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
                SizedBox(width: r.scaledWidth(14)),
                GestureDetector(
                  onTap: _seatsCount < 10
                      ? () => setState(() => _seatsCount++)
                      : null,
                  child: AnimatedOpacity(
                    opacity: _seatsCount < 10 ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: r.scaledWidth(36),
                      height: r.scaledWidth(36),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, color: Colors.black, size: r.scaledWidth(18)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SizedBox(height: r.scaledHeight(10)),
      Text(
        'Se houver tarifa da plataforma, ela será apresentada no recibo após a confirmação.',
        style: TextStyle(fontSize: r.responsiveFontSize(11), color: subtleText),
      ),
      SizedBox(height: r.scaledHeight(16)),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: r.scaledHeight(16)),
              decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('CANCELAR',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: primaryText))),
            ),
          ),
        ),
        SizedBox(width: r.scaledWidth(12)),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _proceedToPin,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: r.scaledHeight(16)),
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('CONTINUAR',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(14),
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withValues(alpha: 0.85)))),
            ),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _buildPinStep(ResponsiveHelper r, bool isDark, Color primaryText,
      Color subtleText, Color accent) {
    return [
      Icon(Icons.lock_rounded, size: r.scaledWidth(44), color: accent),
      SizedBox(height: r.scaledHeight(10)),
      Text('PIN DO PASSAGEIRO',
          style: TextStyle(
              fontSize: r.responsiveFontSize(12),
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.8)),
      SizedBox(height: r.scaledHeight(4)),
      Text(widget.passengerName,
          style: TextStyle(
              fontSize: r.responsiveFontSize(16),
              fontWeight: FontWeight.w700,
              color: primaryText)),
      SizedBox(height: r.scaledHeight(16)),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          'Peça ao passageiro para digitar o seu PIN de 6 dígitos',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: r.responsiveFontSize(13), color: primaryText),
        ),
      ),
      SizedBox(height: r.scaledHeight(20)),
      LayoutBuilder(builder: (context, constraints) {
        final boxSize =
            ((constraints.maxWidth - r.scaledWidth(6) * _pinLength * 2) /
                    _pinLength)
                .clamp(36.0, 52.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              _pinLength,
              (i) => Container(
                    width: boxSize,
                    height: boxSize,
                    margin: EdgeInsets.symmetric(horizontal: r.scaledWidth(4)),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.04),
                      border: Border.all(
                        color: _enteredPin.length > i
                            ? accent
                            : (isDark ? Colors.white30 : Colors.black26),
                        width: _enteredPin.length > i ? 2 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: _enteredPin.length > i
                        ? Text('•',
                            style: TextStyle(
                                fontSize: boxSize * 0.5,
                                fontWeight: FontWeight.bold,
                                color: accent))
                        : null,
                  )),
        );
      }),
      SizedBox(height: r.scaledHeight(8)),
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
            counterText: '',
          ),
          style: const TextStyle(color: Colors.transparent, height: 0.1),
        ),
      ),
      SizedBox(height: r.scaledHeight(20)),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _step = _PassengerStep.info),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: r.scaledHeight(16)),
              decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('VOLTAR',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: primaryText))),
            ),
          ),
        ),
        SizedBox(width: r.scaledWidth(12)),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _enteredPin.length == _pinLength ? _submit : null,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: r.scaledHeight(16)),
              decoration: BoxDecoration(
                  color: _enteredPin.length == _pinLength
                      ? accent
                      : accent.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('CONFIRMAR',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(14),
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withValues(alpha: 0.85)))),
            ),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _buildProcessingStep(
      ResponsiveHelper r, Color primaryText, Color subtleText) {
    return [
      SizedBox(height: r.scaledHeight(32)),
      const CircularProgressIndicator(color: AppColors.primaryGold),
      SizedBox(height: r.scaledHeight(24)),
      Text('A processar pagamento…',
          style: TextStyle(
              fontSize: r.responsiveFontSize(16),
              fontWeight: FontWeight.w600,
              color: primaryText)),
      SizedBox(height: r.scaledHeight(8)),
      Text('Aguarde um momento',
          style: TextStyle(fontSize: r.responsiveFontSize(13), color: subtleText)),
      SizedBox(height: r.scaledHeight(48)),
    ];
  }

  List<Widget> _buildSuccessStep(
      ResponsiveHelper r, Color primaryText, Color subtleText, Color accent) {
    final totalAmount = widget.amount * _seatsCount;
    final fee = _result?.platformFeeApplied ?? 0;
    return [
      Container(
        width: r.scaledWidth(88),
        height: r.scaledWidth(88),
        decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(Icons.check_circle_rounded,
            size: r.scaledWidth(56), color: Colors.green),
      ),
      SizedBox(height: r.scaledHeight(16)),
      Text('PAGAMENTO RECEBIDO!',
          style: TextStyle(
              fontSize: r.responsiveFontSize(16),
              fontWeight: FontWeight.w900,
              color: Colors.green,
              letterSpacing: 0.5)),
      SizedBox(height: r.scaledHeight(8)),
      Text(_formatAmt(totalAmount),
          style: TextStyle(
              fontSize: r.responsiveFontSize(36),
              fontWeight: FontWeight.w900,
              color: primaryText)),
      SizedBox(height: r.scaledHeight(4)),
      Text(
        _seatsCount > 1
            ? 'de ${widget.passengerName} · $_seatsCount assentos'
            : 'de ${widget.passengerName}',
        style: TextStyle(fontSize: r.responsiveFontSize(14), color: subtleText),
      ),
      if (fee > 0) ...[
        SizedBox(height: r.scaledHeight(16)),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: r.scaledWidth(16), vertical: r.scaledHeight(10)),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: r.scaledWidth(16), color: accent),
              SizedBox(width: r.scaledWidth(8)),
              Text('Tarifa da plataforma aplicada: ${_formatAmt(fee)}',
                  style: TextStyle(
                      fontSize: r.responsiveFontSize(12),
                      fontWeight: FontWeight.w700,
                      color: primaryText)),
            ],
          ),
        ),
      ],
      SizedBox(height: r.scaledHeight(32)),
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.scaledHeight(16)),
            decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text('CONTINUAR',
                    style: TextStyle(
                        fontSize: r.responsiveFontSize(14),
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withValues(alpha: 0.85)))),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildErrorStep(ResponsiveHelper r, Color primaryText) {
    return [
      Container(
        width: r.scaledWidth(88),
        height: r.scaledWidth(88),
        decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(Icons.cancel_rounded,
            size: r.scaledWidth(56), color: Colors.red),
      ),
      SizedBox(height: r.scaledHeight(16)),
      Text('PAGAMENTO RECUSADO',
          style: TextStyle(
              fontSize: r.responsiveFontSize(15),
              fontWeight: FontWeight.w900,
              color: Colors.red,
              letterSpacing: 0.5)),
      SizedBox(height: r.scaledHeight(10)),
      Text(_errorMessage ?? 'Tente novamente.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: r.responsiveFontSize(13), color: primaryText)),
      SizedBox(height: r.scaledHeight(28)),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: r.scaledHeight(16)),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('FECHAR',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: primaryText))),
            ),
          ),
        ),
        SizedBox(width: r.scaledWidth(12)),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _retry,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: r.scaledHeight(16)),
              decoration: BoxDecoration(
                  color: AppColors.primaryGold,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('TENTAR NOVAMENTE',
                      style: TextStyle(
                          fontSize: r.responsiveFontSize(13),
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withValues(alpha: 0.85)))),
            ),
          ),
        ),
      ]),
    ];
  }
}

