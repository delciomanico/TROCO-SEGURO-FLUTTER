import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/models/transaction.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:troco_seguro_motorista/widgets/driver_bottom_dock.dart';

class WalletScreen extends StatefulWidget {
  final VoidCallback? onOpenWithdrawal;
  final bool showBottomDock;

  const WalletScreen({
    super.key,
    this.onOpenWithdrawal,
    this.showBottomDock = true,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int balance = 0;
  List<Transaction> transactions = [];
  String activeFilter = 'all';
  String searchQuery = '';
  bool isLoading = true;
  bool showBalance = false;
  final ApiService _api = ApiService();

  static const bool useMockData = false; // ✅ INTEGRADO COM API REAL

  Color _accentColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.adaptiveAccent(context) : AppColors.primaryOrange;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        balance = 45000;
        transactions = Constants.mockTransactions;
        isLoading = false;
      });
      return;
    }

    await _api.loadTokens();

    final balanceResult = await _api.getBalance();
    if (balanceResult.isSuccess && balanceResult.data != null) {
      setState(() => balance = balanceResult.data!);
    }

    final txResult = await _api.getTransactionHistory();
    if (txResult.isSuccess && txResult.data != null) {
      setState(() => transactions = txResult.data!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ts_driver_transactions',
          json.encode(transactions.map((t) => t.toJson()).toList()));
    } else {
      final prefs = await SharedPreferences.getInstance();
      final txsJson = prefs.getString('ts_driver_transactions');
      if (txsJson != null) {
        setState(() {
          transactions = (json.decode(txsJson) as List)
              .map((tx) => Transaction.fromJson(tx))
              .toList();
        });
      } else {
        setState(() => transactions = Constants.mockTransactions);
      }
    }

    setState(() => isLoading = false);
  }

  List<Transaction> get filteredTransactions {
    return transactions.where((tx) {
      final matchesType = activeFilter == 'all' || tx.type == activeFilter;
      final matchesSearch =
          tx.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (tx.passengerName
                      ?.toLowerCase()
                      .contains(searchQuery.toLowerCase()) ??
                  false);
      return matchesType && matchesSearch;
    }).toList();
  }

  Map<String, int> get stats {
    final totalReceived = transactions
        .where((t) => t.type == 'received')
        .fold(0, (sum, t) => sum + (int.tryParse(t.amount.toString()) ?? 0));
    final totalWithdrawn = transactions
        .where((t) => t.type == 'withdrawal')
        .fold(0,
            (sum, t) => sum + (int.tryParse(t.amount.toString()) ?? 0).abs());
    return {'totalReceived': totalReceived, 'totalWithdrawn': totalWithdrawn};
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageGradient = isDark
        ? AppColors.darkScreenGradient
        : const LinearGradient(
            colors: [AppColors.lightBackground, AppColors.lightSurface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Carteira'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightBackground,
        foregroundColor: isDark ? Colors.white : AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {},
            tooltip: 'Histórico',
          ),
        ],
      ),
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      bottomNavigationBar: widget.showBottomDock
          ? DriverBottomDock(
              selectedTab: DriverDockTab.wallet,
              onCenterTap: widget.onOpenWithdrawal,
            )
          : null,
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: _accentColor(),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: responsive.scaledHeight(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: responsive.scaledWidth(20),
                                  ),
                                  child: _buildBalanceCard(responsive),
                                ),
                                SizedBox(height: responsive.scaledHeight(12)),
                                _buildQuickActions(responsive),
                                SizedBox(height: responsive.scaledHeight(12)),
                                Column(
                                  children: [
                                    _buildTransactionsSection(responsive),
                                    SizedBox(
                                        height: responsive.scaledHeight(8)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg =
        isDark ? AppColors.darkBackground : AppColors.adaptiveAccent(context);
    final headerTextColor = isDark ? Colors.white : AppColors.textDark;
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(20),
          vertical: responsive.scaledHeight(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: headerTextColor,
                    size: responsive.scaledWidth(20),
                  ),
                  tooltip: 'Voltar',
                ),
                Container(
                  width: responsive.scaledWidth(44),
                  height: responsive.scaledWidth(44),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: headerTextColor.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: isDark ? _accentColor() : AppColors.textDark,
                    size: responsive.scaledWidth(24),
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: Text(
                    'Carteira',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(20),
                      color: headerTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  width: responsive.scaledWidth(44),
                  height: responsive.scaledWidth(44),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: headerTextColor.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.history,
                    color: headerTextColor,
                    size: responsive.scaledWidth(24),
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            _buildBalanceCard(responsive),
            SizedBox(height: responsive.scaledHeight(24)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowBase =
        isDark ? AppColors.darkBackground : AppColors.lightSurface;
    final cardText = isDark ? const Color(0xFFE6E8EC) : Colors.white;
    final cardSubtle = isDark
        ? const Color(0xFFE6E8EC).withOpacity(0.84)
        : Colors.white.withOpacity(0.9);

    return Container(
      width: double.infinity,
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
                horizontal: responsive.scaledWidth(18),
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
                    'Saldo disponível',
                    style: TextStyle(
                      color: cardSubtle,
                      fontSize: responsive.responsiveFontSize(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(2)),
                  GestureDetector(
                    onTap: () => setState(() => showBalance = !showBalance),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            showBalance ? _formatCurrency(balance) : '••••••••',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(30),
                              color: cardText,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          showBalance ? Icons.visibility : Icons.visibility_off,
                          color: cardText,
                          size: responsive.scaledWidth(20),
                        ),
                      ],
                    ),
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

  Widget _buildBalancePill(
    ResponsiveHelper responsive, {
    required String title,
    required String value,
    required bool isDarkCard,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseText = isDark ? const Color(0xFFE6E8EC) : Colors.white;
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
              color: baseText.withOpacity(0.8),
              fontSize: responsive.responsiveFontSize(10),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(2)),
          Text(
            value,
            style: TextStyle(
              color: baseText,
              fontSize: responsive.responsiveFontSize(12),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final withdrawBg =
        isDark ? AppColors.darkCardElevated : AppColors.primaryBlue;
    final withdrawFg = isDark ? Colors.white : AppColors.textLight;
    final historyBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final historyFg = isDark ? Colors.white : AppColors.textDark;
    final historySubtle = isDark ? Colors.white70 : AppColors.textSecondary;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onOpenWithdrawal,
              child: Container(
                padding:
                    EdgeInsets.symmetric(vertical: responsive.scaledHeight(20)),
                decoration: BoxDecoration(
                  color: withdrawBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: withdrawBg.withOpacity(isDark ? 0.28 : 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.currency_exchange_rounded,
                      color: withdrawFg,
                      size: responsive.scaledWidth(28),
                    ),
                    SizedBox(height: responsive.scaledHeight(8)),
                    Text(
                      'SACAR',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w800,
                        color: withdrawFg,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: responsive.scaledHeight(4)),
                    Text(
                      'Transferir para conta',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(10),
                        color: withdrawFg.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: responsive.scaledWidth(12)),
          Expanded(
            child: Container(
              padding:
                  EdgeInsets.symmetric(vertical: responsive.scaledHeight(20)),
              decoration: BoxDecoration(
                color: historyBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentColor(), width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: historyFg,
                    size: responsive.scaledWidth(28),
                  ),
                  SizedBox(height: responsive.scaledHeight(8)),
                  Text(
                    'HISTÓRICO',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w800,
                      color: historyFg,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(4)),
                  Text(
                    'Ver transações',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(10),
                      color: historySubtle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transações Recentes',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(16),
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(responsive, 'all', 'Todas'),
                SizedBox(width: responsive.scaledWidth(8)),
                _buildFilterChip(responsive, 'received', 'Recebido'),
                SizedBox(width: responsive.scaledWidth(8)),
                _buildFilterChip(responsive, 'withdrawal', 'Saque'),
              ],
            ),
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          if (filteredTransactions.isEmpty)
            _buildEmptyTransactions(responsive)
          else
            ...filteredTransactions.take(10).map(
                  (tx) => _buildTransactionItem(responsive, tx),
                ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      ResponsiveHelper responsive, String value, String label) {
    final isSelected = activeFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => activeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(16),
          vertical: responsive.scaledHeight(8),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor()
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(12),
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.textDark
                : (isDark ? Colors.white70 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions(ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(40)),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: Colors.grey.shade300),
            SizedBox(height: responsive.scaledHeight(12)),
            Text(
              'Nenhuma transação encontrada',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(14),
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(ResponsiveHelper responsive, Transaction tx) {
    final isReceived = tx.type == 'received';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconData =
        isReceived ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final iconColor = isReceived ? AppColors.success : AppColors.error;

    return Container(
      margin: EdgeInsets.only(bottom: responsive.scaledHeight(12)),
      padding: EdgeInsets.all(responsive.scaledWidth(16)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: responsive.scaledWidth(44),
            height: responsive.scaledWidth(44),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          SizedBox(width: responsive.scaledWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: responsive.scaledHeight(4)),
                Text(
                  '${tx.date} às ${tx.time}',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(11),
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${tx.amount > 0 ? '+' : ''}${_formatCurrency(tx.amount)}',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              fontWeight: FontWeight.w700,
              color: tx.amount > 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
