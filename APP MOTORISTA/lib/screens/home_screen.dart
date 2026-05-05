import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/models/driver_user.dart';
import 'package:troco_seguro_motorista/models/qr_config.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/widgets/qr_display_modal.dart';
import 'package:troco_seguro_motorista/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro_motorista/widgets/qr_config_modal.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:troco_seguro_motorista/screens/routes_screen.dart';
import 'package:troco_seguro_motorista/screens/earnings_screen.dart';
import 'package:troco_seguro_motorista/screens/trips_screen.dart';
import 'package:troco_seguro_motorista/screens/wallet_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  final DriverUser driver;
  final bool isOnline;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenWithdrawal;
  final VoidCallback onLogout;
  final VoidCallback? onOpenProfile;
  final bool showBottomDock;

  const HomeScreen({
    super.key,
    required this.driver,
    required this.isOnline,
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
  int todayEarnings = 0;
  int todayTrips = 0;
  final ApiService _api = ApiService();
  QrConfig? _qrConfig;

  static const bool useMockData = false; // ✅ INTEGRADO COM API REAL

  Color _accentColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.adaptiveAccent(context) : AppColors.primaryOrange;
  }

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    _loadQrConfig();
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
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        todayEarnings = 12500;
        todayTrips = 5;
      });
      return;
    }

    await _api.loadTokens();
    final result = await _api.getEarnings();
    if (result.isSuccess && result.data != null) {
      setState(() {
        todayEarnings = result.data!.todayAmount;
        todayTrips = result.data!.todayTrips;
      });
    }
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  String _getFirstName() {
    final parts = widget.driver.fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1]}';
    }
    return parts.first;
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
        amount: qr.currentAmount > 0 ? qr.currentAmount : null,
        currency: qr.currency,
        driverName:
            qr.driverName.isNotEmpty ? qr.driverName : widget.driver.fullName,
        routeName: _qrConfig!.activeRouteName,
        onClose: () {},
      ),
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
    debugPrint('QR Escaneado: $scannedData');

    final parts = scannedData.split(':');

    String passengerName = 'Passageiro';
    int amount = 0;
    String passengerId = '';

    if (scannedData.startsWith('troco_seguro:')) {
      if (parts.length >= 3) {
        passengerId = parts[2];
      }
      if (parts.length >= 4) {
        amount = int.tryParse(parts[3]) ?? 0;
      }
      if (parts.length >= 5) {
        passengerName = parts[4];
      }
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
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: EdgeInsets.all(responsive.responsivePadding()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Container(
                padding: EdgeInsets.all(responsive.scaledWidth(20)),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveAccent(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: responsive.scaledWidth(56),
                  color: AppColors.adaptiveAccent(context),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Text(
                'CARTÃO VIRTUAL DETECTADO',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(14),
                  fontWeight: FontWeight.w700,
                  color: AppColors.adaptiveAccent(context),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                passengerName,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(20),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(28)),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(36),
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'Kz',
                  suffixStyle: TextStyle(
                    fontSize: responsive.responsiveFontSize(20),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppColors.adaptiveAccent(context), width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.lightCard,
                  labelText: 'Valor da corrida',
                ),
              ),
              SizedBox(height: responsive.scaledHeight(28)),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(16),
                        ),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.textDark, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'CANCELAR',
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(14),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Digite um valor válido'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        _confirmPayment(passengerId, passengerName, tripAmount);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(16),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.adaptiveAccent(context),
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.secondaryGold
                                  : AppColors.secondaryOrange,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.adaptiveAccent(context)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'COBRAR',
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(16),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsive.scaledHeight(16)),
            ],
          ),
        ),
      ),
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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: EdgeInsets.all(responsive.responsivePadding()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(32)),
              Container(
                width: responsive.scaledWidth(100),
                height: responsive.scaledWidth(100),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: responsive.scaledWidth(64),
                  color: Colors.green,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Text(
                'PAGAMENTO RECEBIDO!',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(16)),
              Text(
                _formatCurrency(amount),
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(40),
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                'de $passengerName',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(14),
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(32)),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _loadTodayStats();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: responsive.scaledHeight(16),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'CONTINUAR',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(16)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _loadTodayStats(),
              _loadQrConfig(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              responsive.scaledWidth(18),
              responsive.scaledHeight(16),
              responsive.scaledWidth(18),
              responsive.scaledHeight(110),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopHeader(responsive),
                SizedBox(height: responsive.scaledHeight(12)),
                _buildHighlightedCard(responsive),
                SizedBox(height: responsive.scaledHeight(8)),
                _buildQuickActions(responsive),
                SizedBox(height: responsive.scaledHeight(12)),
                _buildTransactionsHeader(responsive),
                SizedBox(height: responsive.scaledHeight(10)),
                _buildTransactionsList(responsive),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          widget.showBottomDock ? _buildBottomDock(responsive) : null,
    );
  }

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  List<_HomeActionItem> _buildActions() {
    return [
      _HomeActionItem(
        icon: Icons.south_west_rounded,
        label: 'Cobrar',
        onTap: widget.isOnline ? _scanPassengerQR : widget.onToggleOnline,
      ),
      _HomeActionItem(
        icon: Icons.qr_code_2_rounded,
        label: 'QRCode',
        isLoading: _isLoadingQr,
        onTap: widget.isOnline
            ? () {
                if (_isLoadingQr) return;
                _showQRCode();
              }
            : widget.onToggleOnline,
      ),
      _HomeActionItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Carteira',
        onTap: () => _openScreen(
          WalletScreen(onOpenWithdrawal: widget.onOpenWithdrawal),
        ),
      ),
      _HomeActionItem(
        icon: Icons.logout_rounded,
        label: 'Sair',
        onTap: widget.onLogout,
      ),
    ];
  }

  Widget _buildTopHeader(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = isDark ? AppColors.darkCardElevated : AppColors.lightCard;
    final avatarBorder =
        isDark ? Colors.white.withOpacity(0.14) : AppColors.lightBorder;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final secondaryText = isDark ? Colors.white70 : AppColors.textSecondary;
    final statusBg = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final statusBorder =
        isDark ? Colors.white.withOpacity(0.1) : AppColors.lightBorder;

    return Row(
      children: [
        SizedBox(width: responsive.scaledWidth(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bom dia',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: responsive.responsiveFontSize(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(2)),
              Text(
                _getFirstName(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryText,
                  fontSize: responsive.responsiveFontSize(20),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => widget.onOpenProfile?.call(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: responsive.scaledWidth(38),
            height: responsive.scaledWidth(38),
            decoration: BoxDecoration(
              color: null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(style: BorderStyle.none),
            ),
            child: Icon(Icons.more_vert_rounded,
                color: primaryText, size: responsive.scaledWidth(20)),
          ),
        ),
        SizedBox(width: responsive.scaledWidth(12)),
      ],
    );
  }

  Widget _buildHighlightedCard(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowBase =
        isDark ? AppColors.darkBackground : AppColors.lightSurface;
    final cardText = isDark ? const Color(0xFFE6E8EC) : Colors.white;
    final cardSubtle = isDark
        ? const Color(0xFFE6E8EC).withOpacity(0.84)
        : Colors.white.withOpacity(0.9);

    return Container(
      decoration: BoxDecoration(
        color: _accentColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? _accentColor().withOpacity(0.58)
              : AppColors.primaryBlue.withOpacity(0.42),
          width: 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowBase.withOpacity(isDark ? 0.62 : 0.48),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: shadowBase.withOpacity(isDark ? 0.18 : 0.78),
            blurRadius: 6,
            offset: const Offset(-2, -2),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: shadowBase.withOpacity(isDark ? 0.78 : 0.34),
            blurRadius: 8,
            offset: const Offset(3, 3),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: isDark
                  ? Image.asset(
                      'assets/images/card_fundo.jpg',
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      'assets/images/card_fundo.jpg',
                      fit: BoxFit.cover,
                    ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.scaledWidth(16),
                vertical: responsive.scaledHeight(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'TROCO SEGURO',
                        style: TextStyle(
                          color: cardText,
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.contactless_rounded,
                        color: cardText,
                        size: responsive.scaledWidth(22),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.scaledHeight(14)),
                  Text(
                    'Saldo',
                    style: TextStyle(
                      color: cardSubtle,
                      fontSize: responsive.responsiveFontSize(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(2)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          showBalance
                              ? _formatCurrency(widget.driver.balance)
                              : '••••••••',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cardText,
                            fontSize: responsive.responsiveFontSize(30),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => showBalance = !showBalance),
                        child: Icon(
                          showBalance ? Icons.visibility : Icons.visibility_off,
                          color: cardText,
                          size: responsive.scaledWidth(20),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.scaledHeight(10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPill(
    ResponsiveHelper responsive, {
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillText = isDark ? const Color(0xFFE6E8EC) : Colors.white;
    final pillSubtle = isDark
        ? const Color(0xFFE6E8EC).withOpacity(0.84)
        : Colors.white.withOpacity(0.9);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(10),
        vertical: responsive.scaledHeight(7),
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.22)
            : Colors.white.withOpacity(0.52),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark
              ? AppColors.adaptiveAccent(context).withOpacity(0.24)
              : AppColors.primaryBlue.withOpacity(0.26),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: pillSubtle,
              fontSize: responsive.responsiveFontSize(10),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(2)),
          Text(
            value,
            style: TextStyle(
              color: pillText,
              fontSize: responsive.responsiveFontSize(12),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ResponsiveHelper responsive) {
    final actions = _buildActions();

    return Row(
      children: actions.map((action) {
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: responsive.scaledWidth(4)),
            child: _buildActionTile(responsive, action),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionTile(ResponsiveHelper responsive, _HomeActionItem action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBg = isDark ? AppColors.darkCardElevated : AppColors.lightCard;
    final tileBorder =
        isDark ? Colors.white.withOpacity(0.14) : AppColors.lightBorder;
    final iconColor = isDark ? Colors.white : AppColors.primaryBlue;
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Material(
      color: tileBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tileBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.isLoading ? null : action.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: responsive.scaledHeight(10),
            horizontal: responsive.scaledWidth(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action.isLoading)
                SizedBox(
                  width: responsive.scaledWidth(22),
                  height: responsive.scaledWidth(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.adaptiveAccent(context),
                    ),
                  ),
                )
              else
                Icon(
                  action.icon,
                  color: iconColor,
                  size: responsive.scaledWidth(20),
                ),
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                action.isLoading ? 'Aguarde' : action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: responsive.responsiveFontSize(11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsHeader(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final secondaryText = isDark ? Colors.white70 : AppColors.textSecondary;

    return Row(
      children: [
        Text(
          'Transações',
          style: TextStyle(
            color: primaryText,
            fontSize: responsive.responsiveFontSize(21),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _openScreen(const TripsScreen()),
          child: Text(
            'Ver tudo',
            style: TextStyle(
              color: secondaryText,
              fontSize: responsive.responsiveFontSize(12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final dividerColor =
        isDark ? Colors.white.withOpacity(0.06) : AppColors.lightBorder;
    final iconBg = isDark
        ? AppColors.darkBlueLight
        : AppColors.primaryBlue.withOpacity(0.12);
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final secondaryText = isDark ? Colors.white54 : AppColors.textSecondary;

    final entries = [
      _UiTransactionRow(
        name: 'Corridas de hoje',
        time: 'Atualizado agora',
        value: '+${_formatCurrency(todayEarnings)}',
        type: 'Crédito',
      ),
      _UiTransactionRow(
        name: 'Viagens concluídas',
        time: 'Hoje',
        value: '+$todayTrips',
        type: 'Viagens',
      ),
      _UiTransactionRow(
        name: 'Carteira',
        time: 'Saldo atual',
        value: _formatCurrency(widget.driver.balance),
        type: 'Disponível',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: listBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: entries.map((entry) {
          final isLast = entries.last == entry;
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scaledWidth(12),
              vertical: responsive.scaledHeight(12),
            ),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: dividerColor,
                      ),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: responsive.scaledWidth(36),
                  height: responsive.scaledWidth(36),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: responsive.scaledWidth(18),
                    color: _accentColor(),
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(2)),
                      Text(
                        entry.time,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: responsive.responsiveFontSize(11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: responsive.responsiveFontSize(13),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: responsive.scaledHeight(2)),
                    Text(
                      entry.type,
                      style: TextStyle(
                        color: _accentColor(),
                        fontSize: responsive.responsiveFontSize(10),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomDock(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dockBg = isDark ? AppColors.darkSurface : AppColors.lightCard;
    final dockBorder =
        isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dockBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDockItem(
            responsive,
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: () {},
            selected: true,
          ),
          _buildDockItem(
            responsive,
            icon: Icons.bar_chart_rounded,
            label: 'Estatística',
            onTap: () => _openScreen(EarningsScreen(driver: widget.driver)),
          ),
          GestureDetector(
            onTap: widget.onOpenWithdrawal,
            child: Container(
              width: responsive.scaledWidth(46),
              height: responsive.scaledWidth(46),
              decoration: BoxDecoration(
                color: _accentColor(),
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
            responsive,
            icon: Icons.local_taxi_rounded,
            label: 'Viagens',
            onTap: () => _openScreen(const TripsScreen()),
          ),
          _buildDockItem(
            responsive,
            icon: Icons.person_outline_rounded,
            label: 'Perfil',
            onTap: () => _openScreen(const RoutesScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildDockItem(
    ResponsiveHelper responsive, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? _accentColor()
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

class _HomeActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _HomeActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });
}

class _UiTransactionRow {
  final String name;
  final String time;
  final String value;
  final String type;

  const _UiTransactionRow({
    required this.name,
    required this.time,
    required this.value,
    required this.type,
  });
}
