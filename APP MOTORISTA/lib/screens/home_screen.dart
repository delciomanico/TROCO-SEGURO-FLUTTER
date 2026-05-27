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
import 'package:troco_seguro_motorista/screens/routes_screen.dart';
import 'package:troco_seguro_motorista/screens/earnings_screen.dart';
import 'package:troco_seguro_motorista/screens/trips_screen.dart';
import 'package:troco_seguro_motorista/screens/vehicles_screen.dart';
import 'package:troco_seguro_motorista/screens/wallet_screen.dart';
import 'package:troco_seguro_motorista/widgets/driver_bottom_dock.dart';
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
  bool _isLoadingStats = false;
  int todayEarnings = 0;
  int todayTrips = 0;
  int currentBalance = 0; // Saldo local atualizado
  List<Transaction> transactions = [];
  final ApiService _api = ApiService();
  QrConfig? _qrConfig;

  Color _accentColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.adaptiveAccent(context) : AppColors.primaryOrange;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 HomeScreen iniciado');
    debugPrint('   Driver inicial: ${widget.driver.fullName}');
    debugPrint('   Balance padrão: 0 Kz (será carregado da API)');
    _loadTodayStats();
    _loadQrConfig();
    _loadBalance(); // Carregar saldo atualizado da API
  }

  int _parseBalance(dynamic balance) {
    if (balance == null) return 0;
    if (balance is num) return balance.toInt();
    return double.tryParse(balance.toString())?.toInt() ?? 0;
  }

  Future<void> _loadBalance() async {
    try {
      debugPrint('🔄 Carregando saldo de users/me...');
      await _api.loadTokens();
      final profileResult = await _api.getProfile();

      debugPrint('👤 Profile Success: ${profileResult.isSuccess}');

      if (profileResult.isSuccess && profileResult.data != null) {
        final profile = profileResult.data!;
        debugPrint('   Name: ${profile.fullName}');
        debugPrint('   Wallet: ${profile.wallet}');

        // Usar o saldo já processado pelo modelo DriverUser
        final newBalance = profile.balance;
        debugPrint('   Parsed balance: $newBalance Kz');

        if (mounted) {
          setState(() {
            currentBalance = newBalance;
            todayEarnings = profile.balance; // Fallback se o stats falhar
            debugPrint('✅ Saldo atualizado no estado: $currentBalance Kz');
          });
        }
      } else {
        debugPrint('❌ Erro na API: ${profileResult.error}');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao carregar saldo: $e');
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
    if (_isLoadingStats) return; // Evita múltiplas chamadas simultâneas

    setState(() => _isLoadingStats = true);
    debugPrint('🔄 Iniciando carregamento de estatísticas...');

    try {
      await _api.loadTokens();
      debugPrint('✅ Tokens carregados');

      // Carregar ganhos e transações em paralelo
      final earningsResult = await _api.getEarnings();
      final transactionsResult = await _api.getTransactionHistory(limit: 10);

      debugPrint('📊 Earnings Success: ${earningsResult.isSuccess}');
      if (earningsResult.data != null) {
        debugPrint(
            '   Today: ${earningsResult.data!.todayAmount} Kz, Trips: ${earningsResult.data!.todayTrips}');
      }

      debugPrint('💳 Transactions Success: ${transactionsResult.isSuccess}');
      if (transactionsResult.data != null) {
        debugPrint('   Total: ${transactionsResult.data!.length} transações');
      }

      if (mounted) {
        setState(() {
          // Atualizar ganhos
          if (earningsResult.isSuccess && earningsResult.data != null) {
            todayEarnings = earningsResult.data!.todayAmount;
            todayTrips = earningsResult.data!.todayTrips;
            debugPrint('✅ Ganhos atualizados: $todayEarnings Kz');
          }

          // Atualizar transações
          if (transactionsResult.isSuccess && transactionsResult.data != null) {
            transactions = transactionsResult.data!;
            debugPrint('✅ ${transactions.length} transações carregadas');
          } else {
            debugPrint(
                '⚠️ Erro ao carregar transações: ${transactionsResult.error}');
            transactions = []; // Limpar lista se houver erro
          }

          _isLoadingStats = false;
          debugPrint('🎉 Carregamento completo!');
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar estatísticas: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          transactions = []; // Limpar em caso de erro
        });
      }
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
        amount: qr.currentAmount > 0
            ? qr.currentAmount
            : ((_qrConfig?.currentFare ?? 0) > 0
                ? _qrConfig!.currentFare
                : null),
        currency: qr.currency,
        driverName:
            qr.driverName.isNotEmpty ? qr.driverName : widget.driver.fullName,
        routeName: _qrConfig?.activeRouteName,
        onClose: () {
          debugPrint('QR Modal fechado');
        },
        onUpdateAmount: (newAmount) async {
          await _api.loadTokens();
          final description = (_qrConfig?.activeRouteName != null &&
                  _qrConfig!.activeRouteName!.trim().isNotEmpty)
              ? _qrConfig!.activeRouteName!.trim()
              : 'Corrida';
          final priceResult = await _api.setQrCodePrice(
            amount: newAmount,
            description: description,
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
                    _loadBalance(); // Recarregar saldo após pagamento
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
              _loadBalance(),
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
                SizedBox(height: responsive.scaledHeight(24)),
                _buildHighlightedCard(responsive),
                SizedBox(height: responsive.scaledHeight(24)),
                _buildQuickActions(responsive),
                SizedBox(height: responsive.scaledHeight(24)),
                _buildTransactionsHeader(responsive),
                SizedBox(height: responsive.scaledHeight(10)),
                _buildTransactionsList(responsive),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomDock
          ? DriverBottomDock(
              selectedTab: DriverDockTab.home,
              driver: widget.driver,
              onOpenWithdrawal: widget.onOpenWithdrawal,
              onCenterTap:
                  widget.isOnline ? _scanPassengerQR : widget.onToggleOnline,
            )
          : null,
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
        icon: Icons.downloading_rounded,
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
        icon: Icons.directions_car_rounded,
        label: 'Veículos',
        onTap: () => _openScreen(const VehiclesScreen()),
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
                              ? _formatCurrency(currentBalance)
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
    final circleBg = isDark ? AppColors.darkCardElevated : AppColors.lightCard;
    final circleBorder =
        isDark ? Colors.white.withOpacity(0.14) : AppColors.lightBorder;
    final iconColor = isDark ? Colors.white : AppColors.primaryBlue;
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return GestureDetector(
      onTap: action.isLoading ? null : action.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.scaledWidth(50),
            height: responsive.scaledWidth(50),
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
              border: Border.all(color: circleBorder),
            ),
            child: Center(
              child: action.isLoading
                  ? SizedBox(
                      width: responsive.scaledWidth(22),
                      height: responsive.scaledWidth(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.adaptiveAccent(context),
                        ),
                      ),
                    )
                  : Icon(
                      action.icon,
                      color: iconColor,
                      size: responsive.scaledWidth(24),
                    ),
            ),
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

    // Criar lista com dados da API
    final entries = [
      // Adicionar últimas 3 transações da API
      ...transactions.take(3).map((tx) {
        final isReceived = tx.type.toLowerCase().contains('received') ||
            tx.type.toLowerCase().contains('deposit');
        final amountStr = tx.amount;

        return _UiTransactionRow(
          name: tx.description.isNotEmpty ? tx.description : tx.type,
          time: tx.date,
          value: '${isReceived ? '+' : '-'}${_formatCurrency(amountStr.abs())}',
          type: isReceived ? 'Entrada' : 'Saída',
        );
      }),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: listBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: entries.isEmpty
            ? [
                Padding(
                  padding: EdgeInsets.all(responsive.scaledHeight(24)),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: responsive.scaledWidth(40),
                        color: secondaryText,
                      ),
                      SizedBox(height: responsive.scaledHeight(12)),
                      Text(
                        'Nenhuma transação',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            : entries.asMap().entries.map((mapEntry) {
                final entry = mapEntry.value;
                final isLast = mapEntry.key == entries.length - 1;

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
