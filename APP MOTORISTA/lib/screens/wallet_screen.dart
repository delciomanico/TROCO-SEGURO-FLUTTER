import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/models/transaction.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:troco_seguro_pro/widgets/driver_bottom_dock.dart';
import 'package:troco_seguro_pro/models/driver_user.dart';

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
  bool isLoading = true;
  bool showBalance = true;
  bool _searchActive = false;
  String searchQuery = '';
  final _searchController = TextEditingController();
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    await _api.loadTokens();

    final prefs = await SharedPreferences.getInstance();
    if (balance == 0) {
      final driverJson = prefs.getString('ts_driver');
      if (driverJson != null) {
        try {
          final cached = DriverUser.fromJson(json.decode(driverJson));
          setState(() => balance = cached.balance);
        } catch (_) {}
      }
    }

    final balanceResult = await _api.getBalance();
    if (balanceResult.isSuccess && balanceResult.data != null) {
      setState(() => balance = balanceResult.data!);
    }

    final txResult = await _api.getTransactionHistory();
    if (txResult.isSuccess && txResult.data != null) {
      setState(() => transactions = txResult.data!);
      await prefs.setString('ts_driver_transactions',
          json.encode(transactions.map((t) => t.toJson()).toList()));
    } else {
      final txsJson = prefs.getString('ts_driver_transactions');
      if (txsJson != null && txsJson.trim().isNotEmpty) {
        try {
          setState(() {
            transactions = (json.decode(txsJson) as List)
                .map((tx) => Transaction.fromJson(tx))
                .toList();
          });
        } catch (_) {
          setState(() => transactions = []);
        }
      } else {
        setState(() => transactions = []);
      }
    }

    setState(() => isLoading = false);
  }

  List<Transaction> get filteredTransactions {
    return transactions.where((tx) {
      final matchesType = activeFilter == 'all' || tx.type == activeFilter;
      final matchesSearch = searchQuery.isEmpty ||
          tx.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (tx.passengerName
                  ?.toLowerCase()
                  .contains(searchQuery.toLowerCase()) ??
              false);
      return matchesType && matchesSearch;
    }).toList();
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      bottomNavigationBar: widget.showBottomDock
          ? DriverBottomDock(
              selectedTab: DriverDockTab.wallet,
              onCenterTap: widget.onOpenWithdrawal,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGold,
                  ),
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(responsive, isDark),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.scaledWidth(20),
                        ),
                        child: _buildBalanceSection(responsive, isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: responsive.scaledHeight(24)),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.scaledWidth(20),
                        ),
                        child: _buildQuickActions(responsive, isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: responsive.scaledHeight(28)),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.scaledWidth(20),
                        ),
                        child: _buildTransactionsSection(responsive, isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: responsive.scaledHeight(110)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveHelper responsive, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(14),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _searchActive
                ? GestureDetector(
                    key: const ValueKey('close'),
                    onTap: () {
                      setState(() {
                        _searchActive = false;
                        searchQuery = '';
                        _searchController.clear();
                      });
                    },
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
                        Icons.close_rounded,
                        size: responsive.scaledWidth(20),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.textDark.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('empty-left'),
                    width: responsive.scaledWidth(38),
                    height: responsive.scaledWidth(38),
                  ),
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _searchActive
                    ? TextField(
                        key: const ValueKey('search-field'),
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(15),
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar transações...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => searchQuery = v),
                      )
                    : Text(
                        key: const ValueKey('title'),
                        'Carteira',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(17),
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textDark,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _searchActive = !_searchActive),
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
                _searchActive
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
                size: responsive.scaledWidth(20),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection(ResponsiveHelper responsive, bool isDark) {
    return Container(
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
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
          Text(
            'Saldo disponível',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(13),
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(6)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => showBalance = !showBalance),
                  child: Text(
                    showBalance ? _formatCurrency(balance) : '••••••••',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(34),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => showBalance = !showBalance),
                child: Icon(
                  showBalance
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: responsive.scaledWidth(22),
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ResponsiveHelper responsive, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircularAction(
          responsive,
          isDark: isDark,
          icon: Icons.currency_exchange_rounded,
          label: 'Sacar',
          onTap: widget.onOpenWithdrawal ?? () {},
        ),
      ],
    );
  }

  Widget _buildCircularAction(
    ResponsiveHelper responsive, {
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: responsive.scaledWidth(58),
            height: responsive.scaledWidth(58),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGold,
            ),
            child: Icon(
              icon,
              color: Colors.black.withValues(alpha: 0.8),
              size: responsive.scaledWidth(24),
            ),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(11),
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withValues(alpha: 0.75)
                : AppColors.textDark.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(ResponsiveHelper responsive, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENTES',
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(11),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.35),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(12)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(responsive, isDark, 'all', 'Todas'),
              SizedBox(width: responsive.scaledWidth(8)),
              _buildFilterChip(responsive, isDark, 'received', 'Recebido'),
              SizedBox(width: responsive.scaledWidth(8)),
              _buildFilterChip(responsive, isDark, 'withdrawal', 'Saque'),
            ],
          ),
        ),
        SizedBox(height: responsive.scaledHeight(16)),
        if (filteredTransactions.isEmpty)
          _buildEmptyState(responsive, isDark)
        else
          _buildTransactionList(responsive, isDark),
      ],
    );
  }

  Widget _buildFilterChip(
    ResponsiveHelper responsive,
    bool isDark,
    String value,
    String label,
  ) {
    final isSelected = activeFilter == value;
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
              ? AppColors.primaryGold
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(12),
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.black.withValues(alpha: 0.85)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.55)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ResponsiveHelper responsive, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(40)),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: responsive.scaledWidth(44),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.15),
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            Text(
              'Nenhuma transação encontrada',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(13),
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(ResponsiveHelper responsive, bool isDark) {
    final items = filteredTransactions.take(30).toList();

    return Container(
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
        children: items.asMap().entries.map((entry) {
          final tx = entry.value;
          final isLast = entry.key == items.length - 1;
          final isReceived = tx.type == 'received';

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
                        border: Border.all(
                          color: isReceived
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.red.withValues(alpha: 0.4),
                          width: 1,
                        ),
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
                                : (isReceived ? 'Corrida recebida' : 'Saque'),
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
                            '${tx.date} às ${tx.time}',
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(11),
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.38)
                                  : Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${tx.amount > 0 ? "+" : ""}${_formatCurrency(tx.amount)}',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(13),
                        fontWeight: FontWeight.w700,
                        color: tx.amount > 0
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
    );
  }
}
