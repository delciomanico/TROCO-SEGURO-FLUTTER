import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/utils/formatters.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro/security/pin_guard.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';

class WalletScreen extends StatefulWidget {
  final VoidCallback? onOpenTopup;
  final VoidCallback? onOpenTransfer;

  const WalletScreen({
    super.key,
    this.onOpenTopup,
    this.onOpenTransfer,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String activeFilter = 'all';
  String searchQuery = '';
  bool showBalance = false;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// `wallet/transfer-to-user` (pagar um motorista identificado por QR) é
  /// tecnicamente uma transferência para o backend (`type: "transfer"`,
  /// ver BACKEND_PENDING_CHANGES.md), mas do ponto de vista do utilizador
  /// é o pagamento de uma viagem — por isso aparecia como "nenhuma
  /// transação" no separador "Pagamentos". Reconhecemos pela descrição
  /// que esse fluxo usa (ver `AppProvider.transferToUser`), já que é a
  /// única forma disponível no cliente de distinguir das transferências
  /// P2P genéricas (que devem continuar em "Transferências").
  bool _isRidePaymentTransfer(Transaction tx) {
    final desc = tx.description.toLowerCase();
    return desc.startsWith('transferência directa') ||
        desc.startsWith('transferência para');
  }

  List<Transaction> getFilteredTransactions(List<Transaction> transactions) {
    return transactions.where((tx) {
      final type = tx.type.toLowerCase();
      final matchesType = activeFilter == 'all' ||
          type == activeFilter ||
          (activeFilter == 'topup' && type == 'deposit') ||
          (activeFilter == 'payment' &&
              type == 'transfer' &&
              _isRidePaymentTransfer(tx));
      final matchesSearch =
          tx.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (tx.driver?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false);
      return matchesType && matchesSearch;
    }).toList();
  }

  // ── Modais ──────────────────────────────────────────────────

  Future<void> _showDepositToCardModal() async {
    final provider = context.read<AppProvider>();
    final didTransfer = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DepositToCardSheet(
        cards: provider.virtualCards,
        onDeposit: (cardId, amount) =>
            provider.depositToVirtualCard(cardId: cardId, amount: amount),
      ),
    );
    if (!mounted) return;
    if (didTransfer == true) {
      FeedbackService.showSuccess(context,
          message: 'Depósito para cartão virtual concluído!');
    }
  }

  Future<void> _showExternalCardModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ExternalCardSheet(),
    );
    if (!mounted) return;
  }

  Future<void> _showQrBalanceModal() async {
    final qrData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRScannerModal(
        title: 'ESCANEAR QR DO CARTÃO',
        subtitle: 'Aponte a câmera para o QR do cartão',
        onCancel: () {},
        onQRScanned: (data) => Navigator.pop(context, data),
      ),
    );
    if (qrData == null || !mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrBalanceSheet(qrData: qrData),
    );
  }

  Future<void> _showWithdrawalModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WithdrawalSheet(),
    );
    if (!mounted) return;
  }

  Future<void> _showTransferModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TransferSheet(),
    );
    if (!mounted) return;
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AppProvider>();
    final user = provider.user;
    final filteredTxs = getFilteredTransactions(provider.transactions);
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildWalletHeader(isDark, responsive),
            Expanded(
              child: provider.isLoadingTransactions
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentOf(context)))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await Future.wait([
                          provider.refreshUserData(),
                          provider.refreshTransactions(),
                        ]);
                      },
                      color: AppColors.accentOf(context),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildBalanceSection(isDark, user, responsive),
                          Container(
                            height: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          SizedBox(height: responsive.scaledHeight(24)),
                          _buildQuickActions(isDark, responsive),
                          SizedBox(height: responsive.scaledHeight(28)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: responsive.scaledWidth(20)),
                            child: _buildFilters(isDark),
                          ),
                          SizedBox(height: responsive.scaledHeight(12)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: responsive.scaledWidth(20)),
                            child: filteredTxs.isEmpty
                                ? _buildEmptyState(isDark)
                                : Column(
                                    children: filteredTxs
                                        .map((tx) => _buildTransactionItem(
                                            tx, isDark, responsive))
                                        .toList(),
                                  ),
                          ),
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

  // ── Widgets ──────────────────────────────────────────────────

  Widget _buildWalletHeader(bool isDark, ResponsiveHelper responsive) {
    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(10),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: _showSearch
            ? Row(
                key: const ValueKey('search'),
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      autofocus: true,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textDark,
                        fontSize: responsive.responsiveFontSize(14),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar transações...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.38)
                              : Colors.black.withValues(alpha: 0.32),
                          fontSize: responsive.responsiveFontSize(14),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.accentOf(context),
                          size: responsive.scaledWidth(20),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.04),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 11),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: AppColors.accentOf(context).withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(8)),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSearch = false;
                        searchQuery = '';
                      });
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
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
                        size: responsive.scaledWidth(18),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.textDark.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('title'),
                children: [
                  Text(
                    'Carteira',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(22),
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showSearch = true),
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
                        Icons.search_rounded,
                        size: responsive.scaledWidth(20),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBalanceSection(
      bool isDark, User? user, ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.scaledWidth(20),
        responsive.scaledHeight(20),
        responsive.scaledWidth(20),
        responsive.scaledHeight(12),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(responsive.scaledWidth(24)),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/card_fundo.jpg'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  height: responsive.scaledWidth(36),
                  width: responsive.scaledWidth(36),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: responsive.scaledWidth(10)),
                Text(
                  'Troco Seguro',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(17),
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
                  'Saldo disponível',
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
                        ? AppFormatters.currency(user?.balance ?? 0)
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
                    padding:
                        EdgeInsets.only(bottom: responsive.scaledHeight(5)),
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, ResponsiveHelper responsive) {
    final mainActions = [
      (icon: Icons.add_circle_outline_rounded, label: 'Recarregar',
          onTap: () => widget.onOpenTopup?.call()),
      (icon: Icons.send_rounded, label: 'Transferir',
          onTap: _showTransferModal),
      (icon: Icons.account_balance_rounded, label: 'Levantar',
          onTap: _showWithdrawalModal),
      (icon: Icons.grid_view_rounded, label: 'Mais',
          onTap: () => _showMoreWalletActionsModal(isDark, responsive)),
    ];

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: mainActions
            .map((a) => Expanded(
                  child: _buildCircularActionButton(
                    responsive,
                    isDark: isDark,
                    icon: a.icon,
                    label: a.label,
                    onTap: a.onTap,
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showMoreWalletActionsModal(bool isDark, ResponsiveHelper responsive) {
    final moreActions = [
      (icon: Icons.credit_card_rounded, label: 'P/ Cartão',
          onTap: _showDepositToCardModal),
      (icon: Icons.swap_horiz_rounded, label: 'Cartão Ext.',
          onTap: _showExternalCardModal),
      (icon: Icons.qr_code_scanner_rounded, label: 'Saldo QR',
          onTap: _showQrBalanceModal),
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, _) {
        final r = ResponsiveHelper(ctx);
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: Scaffold(
            backgroundColor: dark ? AppColors.darkBackground : Colors.white,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      r.scaledWidth(20),
                      r.scaledHeight(16),
                      r.scaledWidth(20),
                      0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mais opções',
                          style: TextStyle(
                            fontSize: r.responsiveFontSize(18),
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: r.scaledWidth(36),
                            height: r.scaledWidth(36),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: r.scaledWidth(18),
                              color: dark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.scaledHeight(20)),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: r.scaledWidth(20)),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: moreActions.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: r.scaledHeight(12),
                        crossAxisSpacing: r.scaledWidth(8),
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (_, index) {
                        final item = moreActions[index];
                        return _buildCircularActionButton(
                          r,
                          isDark: dark,
                          icon: item.icon,
                          label: item.label,
                          onTap: () {
                            Navigator.pop(ctx);
                            item.onTap();
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(height: r.scaledHeight(32)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircularActionButton(
    ResponsiveHelper responsive, {
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: responsive.scaledWidth(58),
            height: responsive.scaledWidth(58),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryGold, AppColors.secondaryGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                  blurRadius: 3,
                  offset: const Offset(-1, -1),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.black.withValues(alpha: 0.8),
              size: responsive.scaledWidth(24),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          SizedBox(
            width: responsive.scaledWidth(68),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(11),
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', 'Todas', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('payment', 'Pagamentos', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('topup', 'Recargas', isDark),
          const SizedBox(width: 8),
          _buildFilterChip('transfer', 'Transferências', isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isActive = activeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => activeFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accentOf(context)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isActive
                ? AppColors.accentOf(context)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.07)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive
                ? Colors.black
                : (isDark
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textDark.withValues(alpha: 0.65)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma transação',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      Transaction tx, bool isDark, ResponsiveHelper responsive) {
    final isIncoming = tx.isIncoming;
    final displayValue = (tx.originalAmount ?? tx.amount).abs();
    final counterpartyName = tx.counterparty ?? tx.driver ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: responsive.scaledHeight(10)),
      padding: EdgeInsets.all(responsive.scaledWidth(14)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.scaledWidth(44),
            height: responsive.scaledWidth(44),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04),
              border: Border.all(
                color: AppColors.accentOf(context).withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isIncoming ? Colors.greenAccent : Colors.redAccent,
              size: responsive.scaledWidth(20),
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
                if (counterpartyName.isNotEmpty) ...[
                  SizedBox(height: responsive.scaledHeight(2)),
                  Text(
                    counterpartyName,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(11),
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
            '${isIncoming ? "+" : "-"}${NumberFormat('#,##0', 'pt_AO').format(displayValue)} kzs',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(13),
              fontWeight: FontWeight.w700,
              color: isIncoming ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet: Depositar em cartão virtual próprio ──────────────────────────────

class _DepositToCardSheet extends StatefulWidget {
  final List<VirtualCard> cards;
  final Future<String?> Function(String cardId, int amount) onDeposit;

  const _DepositToCardSheet({required this.cards, required this.onDeposit});

  @override
  State<_DepositToCardSheet> createState() => _DepositToCardSheetState();
}

class _DepositToCardSheetState extends State<_DepositToCardSheet> {
  final _amountCtrl = TextEditingController();
  String? _selectedCardId;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (_selectedCardId == null || amount == null || amount <= 0) {
      setState(() => _error = 'Selecione o cartão e informe um montante válido.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final err = await widget.onDeposit(_selectedCardId!, amount);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetWrapper(
      title: 'DEPOSITAR NO CARTÃO',
      subtitle: 'Mova saldo da carteira para um dos seus cartões virtuais.',
      icon: Icons.credit_card_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) _ErrorBanner(_error!),
          if (widget.cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhum cartão virtual disponível.',
                style: TextStyle(color: Colors.red[400]),
              ),
            )
          else
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Cartão de destino',
                  border: OutlineInputBorder()),
              items: widget.cards
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name}  •  ${c.balance} Kz'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCardId = v),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Montante (Kz)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 18),
          _ActionRow(
            loading: _loading,
            onConfirm: _submit,
            confirmLabel: 'Depositar',
          ),
        ],
      ),
    );
  }
}

// ── Sheet: Transferir para cartão externo ───────────────────────────────────

class _ExternalCardSheet extends StatefulWidget {
  const _ExternalCardSheet();

  @override
  State<_ExternalCardSheet> createState() => _ExternalCardSheetState();
}

class _ExternalCardSheetState extends State<_ExternalCardSheet> {
  final _cardCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _showPin = false;
  String? _resolvedOwner;

  Future<void> _scanCardQr() async {
    final qrData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRScannerModal(
        title: 'ESCANEAR QR DO CARTÃO',
        subtitle: 'Aponte a câmera para o QR do cartão',
        onCancel: () {},
        onQRScanned: (data) => Navigator.pop(context, data),
      ),
    );
    if (qrData == null || !mounted) return;

    setState(() => _loading = true);
    final result = await ApiService().resolveVirtualCardQr(qrData);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess && result.data?.cardNumber != null) {
      setState(() {
        _cardCtrl.text = result.data!.cardNumber!;
        _resolvedOwner = result.data!.ownerName;
        _error = null;
      });
    } else {
      setState(() => _error = result.error ?? 'QR inválido ou não é um cartão virtual.');
    }
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _amountCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cardNumber = _cardCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.trim());
    final pin = _pinCtrl.text.trim();

    if (cardNumber.isEmpty || amount == null || amount <= 0 || pin.length < 6) {
      setState(() => _error =
          'Preencha todos os campos. O PIN deve ter 6 dígitos.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final api = ApiService();
    final result = await api.transferToExternalCard(
      cardNumber: cardNumber,
      amount: amount,
      pin: pin,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop();
      FeedbackService.showSuccess(context,
          message: 'Transferência para cartão externo realizada!');
      return;
    }

    setState(() {
      _loading = false;
      _error = result.error ?? 'Erro ao transferir para cartão externo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetWrapper(
      title: 'CARTÃO EXTERNO',
      subtitle: 'Transfira para um cartão virtual de terceiros.',
      icon: Icons.swap_horiz_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) _ErrorBanner(_error!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _cardCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Número do cartão',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: IconButton.filled(
                  onPressed: _loading ? null : _scanCardQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Ler QR do cartão',
                ),
              ),
            ],
          ),
          if (_resolvedOwner != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(_resolvedOwner!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Montante (Kz)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrl,
            obscureText: !_showPin,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN da conta (6 dígitos)',
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_showPin
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () => setState(() => _showPin = !_showPin),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _ActionRow(
            loading: _loading,
            onConfirm: _submit,
            confirmLabel: 'Transferir',
          ),
        ],
      ),
    );
  }
}

// ── Sheet: Transferência P2P com verificação ────────────────────────────────

class _TransferSheet extends StatefulWidget {
  const _TransferSheet();

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _error;
  String? _recipientName;
  bool _loading = false;
  bool _verified = false;
  // Preenchido quando o QR escaneado é o QR de sessão/viagem do motorista
  // (mostrado em "Meu QR" no App Motorista), em vez do QR de identidade do
  // passageiro (que traz o telefone em JSON). Nesse caso a transferência
  // usa wallet/transfer-to-user (por ID + PIN) em vez do fluxo por telefone.
  String? _driverId;

  Future<void> _scanQr() async {
    final qrData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QRScannerModal(
        title: 'ESCANEAR QR',
        subtitle: 'Aponte a câmera para o QR do destinatário',
        onCancel: () {},
        onQRScanned: (data) => Navigator.pop(context, data),
      ),
    );
    if (qrData == null || !mounted) return;

    try {
      final decoded = jsonDecode(qrData) as Map<String, dynamic>;
      final phone = decoded['phoneNumber'] ?? decoded['phone'] ?? decoded['receiverPhone'];
      if (phone != null) {
        setState(() {
          _phoneCtrl.text = _stripCountryCode(phone.toString());
          _driverId = null;
          _verified = false;
          _recipientName = null;
          _error = null;
        });
      } else {
        setState(() => _error = 'QR não contém número de telefone.');
      }
      return;
    } catch (_) {
      // Não é o QR de identidade do passageiro — tentar resolver como QR
      // de sessão/motorista antes de desistir.
    }

    // Extrair o token do payload do QR (mesma lógica de
    // PaymentService.validateQrCode: query param "token", substring
    // "token=..." ou o próprio qrData como fallback).
    String token = '';
    try {
      final parsed = Uri.tryParse(qrData);
      if (parsed != null && parsed.queryParameters.containsKey('token')) {
        token = parsed.queryParameters['token'] ?? '';
      }
    } catch (_) {}
    if (token.isEmpty && qrData.contains('token=')) {
      final parts = qrData.split('token=');
      if (parts.length > 1) token = parts[1];
    }
    final tokenParam = token.isNotEmpty ? token : qrData;

    final resolved = await ApiService().resolveQrToken(tokenParam);
    if (!mounted) return;
    if (resolved.isSuccess &&
        resolved.data != null &&
        resolved.data!.valid &&
        resolved.data!.driverId != null) {
      setState(() {
        _driverId = resolved.data!.driverId;
        _phoneCtrl.clear();
        _recipientName = resolved.data!.driverName ?? 'Motorista';
        _verified = true;
        _error = null;
      });
    } else {
      setState(() => _error = 'QR inválido.');
    }
  }

  /// O QR devolve o número completo (`+244XXXXXXXXX`), mas o campo só
  /// guarda os 9 dígitos locais — o indicativo é fixo e mostrado à parte.
  String _stripCountryCode(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.startsWith('244') && digits.length > 9
        ? digits.substring(digits.length - 9)
        : digits;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final digits = _phoneCtrl.text.trim();
    if (digits.length != 9) {
      setState(() => _error = 'Informe os 9 dígitos do número.');
      return;
    }
    final phone = '+244$digits';
    setState(() {
      _error = null;
      _loading = true;
    });
    final api = ApiService();
    final result = await api.verifyTransferRecipient(phone);
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _recipientName = result.data!.name.isNotEmpty
            ? result.data!.name
            : 'Utilizador verificado';
        _verified = true;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.error ?? 'Destinatário não encontrado.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe um montante válido.');
      return;
    }

    if (_driverId != null) {
      await _submitToDriver(amount);
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });
    final provider = context.read<AppProvider>();
    final result = await provider.transfer(
      amount: amount,
      receiverPhone: '+244${_phoneCtrl.text.trim()}',
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop();
      final fee = result.feeAmount;
      FeedbackService.showSuccess(
        context,
        message: (fee != null && fee > 0)
            ? 'Transferência realizada com sucesso! Tarifa aplicada: $fee Kz.'
            : 'Transferência realizada com sucesso!',
      );
      return;
    }
    final errMsg = provider.error;
    setState(() {
      _loading = false;
      _error = errMsg ?? 'Erro ao realizar transferência.';
    });
  }

  /// Transferência para um motorista identificado pelo QR de sessão/viagem
  /// — usa `wallet/transfer-to-user`, que exige o PIN de conta como
  /// confirmação extra (ver `_transferToDriver` em home_screen.dart, o
  /// fluxo "Identificar QR" que já fazia isto).
  Future<void> _submitToDriver(int amount) async {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 6) {
      setState(() => _error = 'PIN deve ter 6 dígitos.');
      return;
    }
    final isValid = await PinGuard.validatePin(
      scope: 'transfer_to_user',
      enteredPin: pin,
      readExpectedPin: () => SecureStorageService().readPin(),
    );
    if (!mounted) return;
    if (!isValid) {
      setState(() => _error = 'PIN incorrecto.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });
    final provider = context.read<AppProvider>();
    final result = await provider.transferToUser(
      targetUserId: _driverId!,
      amount: amount,
      pin: pin,
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop();
      FeedbackService.showSuccess(context,
          message: 'Transferência realizada com sucesso!');
      return;
    }
    setState(() {
      _loading = false;
      _error = provider.error ?? 'Erro ao realizar transferência.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetWrapper(
      title: 'TRANSFERIR',
      subtitle: 'Envie saldo para outra conta Troco Seguro.',
      icon: Icons.send_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) _ErrorBanner(_error!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _driverId != null
                    ? const TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Destinatário',
                          hintText: 'Motorista identificado por QR',
                          border: OutlineInputBorder(),
                        ),
                      )
                    : TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        enabled: !_verified,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(9),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Nº de telefone',
                          hintText: '9XX XXX XXX',
                          prefixText: '+244 ',
                          border: OutlineInputBorder(),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              if (!_verified) ...[
                SizedBox(
                  height: 56,
                  child: IconButton.outlined(
                    onPressed: _loading ? null : _scanQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    tooltip: 'Ler QR do destinatário',
                  ),
                ),
                const SizedBox(width: 4),
              ],
              SizedBox(
                height: 56,
                child: _verified
                    ? IconButton.filled(
                        onPressed: () => setState(() {
                          _verified = false;
                          _recipientName = null;
                          _driverId = null;
                          _pinCtrl.clear();
                        }),
                        icon: const Icon(Icons.edit),
                        tooltip: 'Alterar',
                      )
                    : ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Verificar'),
                      ),
              ),
            ],
          ),
          if (_recipientName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _recipientName!,
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            enabled: _verified,
            decoration: const InputDecoration(
                labelText: 'Montante (Kz)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            enabled: _verified,
            decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                border: OutlineInputBorder()),
          ),
          if (_driverId != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'PIN de conta',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
          const SizedBox(height: 18),
          _ActionRow(
            loading: _loading && _verified,
            onConfirm: _verified ? _submit : null,
            confirmLabel: 'Transferir',
          ),
        ],
      ),
    );
  }
}

// ── Helpers partilhados ──────────────────────────────────────────────────────

class _QrBalanceSheet extends StatefulWidget {
  final String qrData;
  const _QrBalanceSheet({required this.qrData});
  @override
  State<_QrBalanceSheet> createState() => _QrBalanceSheetState();
}

class _QrBalanceSheetState extends State<_QrBalanceSheet> {
  bool _loading = true;
  String? _error;
  CardBalanceResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String qrId = widget.qrData;
    try {
      final decoded = jsonDecode(widget.qrData);
      qrId = decoded['qrId'] ?? decoded['id'] ?? decoded['cardId'] ?? widget.qrData;
    } catch (_) {}

    final result = await ApiService().getWalletBalanceByQr(qrId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _result = result.data;
      } else {
        _error = result.error ?? 'Não foi possível obter o saldo.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _BottomSheetWrapper(
      title: 'SALDO DO CARTÃO',
      subtitle: 'Consulta via QR code.',
      icon: Icons.qr_code_scanner_rounded,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          : _error != null
              ? _ErrorBanner(_error!)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_result!.ownerName != null)
                      Text(
                        _result!.ownerName!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    if (_result!.cardName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _result!.cardName!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      '${_result!.balance} Kz',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saldo disponível',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _BottomSheetWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _BottomSheetWrapper({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).cardColor
                : AppColors.lightCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).round()),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withAlpha((0.3 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(icon,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.6 * 255).round()),
                  ),
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(message,
          style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool loading;
  final VoidCallback? onConfirm;
  final String confirmLabel;

  const _ActionRow({
    required this.loading,
    required this.onConfirm,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: loading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: (loading || onConfirm == null) ? null : onConfirm,
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}

// ── Withdrawal Sheet (IBAN) ──────────────────────────────────────────────────
class _WithdrawalSheet extends StatefulWidget {
  const _WithdrawalSheet();

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  final _amountCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  bool _busy = false;
  String _method = 'bank';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  bool _validIban(String v) => v.isNotEmpty && v.toUpperCase().startsWith('AO06');

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final account = _ibanCtrl.text.trim();

    if (amount <= 0) {
      FeedbackService.showError(context, message: 'Valor deve ser maior que 0');
      return;
    }
    if (_method == 'bank' && !_validIban(account)) {
      FeedbackService.showError(context, message: 'IBAN inválido (deve começar por AO06)');
      return;
    }
    if (_method == 'mcx_express' && account.length != 9) {
      FeedbackService.showError(context, message: 'Informe os 9 dígitos do número');
      return;
    }
    final iban = _method == 'mcx_express' ? '+244$account' : account;

    setState(() => _busy = true);
    final provider = context.read<AppProvider>();
    final ok = await provider.requestWithdrawal(amount: amount, iban: iban);
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      Navigator.pop(context);
      FeedbackService.showSuccess(context,
          message: 'Pedido de levantamento submetido. Prazo: 1-3 dias úteis.');
    } else {
      FeedbackService.showError(context, message: 'Erro ao solicitar levantamento');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final onSurface = isDark ? Colors.white : AppColors.textDark;
    final subtle = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Solicitar Levantamento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface)),
            const SizedBox(height: 4),
            Text('Escolha o método de levantamento',
                style: TextStyle(fontSize: 12, color: subtle)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _WithdrawalMethodOption(
                    label: 'Banco',
                    sublabel: 'Transferência bancária',
                    icon: Icons.account_balance_rounded,
                    isSelected: _method == 'bank',
                    isDark: isDark,
                    onTap: () => setState(() {
                      _method = 'bank';
                      _ibanCtrl.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WithdrawalMethodOption(
                    label: 'MCX Express',
                    sublabel: 'Receba em minutos',
                    icon: Icons.flash_on_rounded,
                    isSelected: false,
                    isDark: isDark,
                    disabled: true,
                    // Backend ainda não suporta levantamento por MCX
                    // Express (só aceita IBAN) — ver BACKEND_PENDING_CHANGES.md.
                    onTap: () => FeedbackService.showInfo(context,
                        message:
                            'Levantamento por Multicaixa Express em desenvolvimento. Por agora, use o levantamento por IBAN.'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valor a levantar',
                suffixText: 'Kz',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.accentOf(context), width: 1.5),
                ),
                filled: true,
                fillColor: fillColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ibanCtrl,
              keyboardType: _method == 'bank' ? TextInputType.text : TextInputType.phone,
              inputFormatters: _method == 'bank'
                  ? null
                  : [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
              decoration: InputDecoration(
                labelText: _method == 'bank' ? 'IBAN (AO06...)' : 'Número de telefone',
                hintText: _method == 'bank' ? null : '9XX XXX XXX',
                prefixText: _method == 'bank' ? null : '+244 ',
                prefixIcon: _method == 'bank'
                    ? const Icon(Icons.credit_score_rounded)
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.accentOf(context), width: 1.5),
                ),
                filled: true,
                fillColor: fillColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _method == 'bank'
                          ? 'O valor será transferido para a sua conta bancária em 1-3 dias úteis'
                          : 'O valor será transferido via Multicaixa Express em poucos minutos',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOf(context),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 0,
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Solicitar Levantamento',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalMethodOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final bool disabled;

  const _WithdrawalMethodOption({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final unselectedBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03);
    final unselectedBorder = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.12) : unselectedBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? accent : unselectedBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? accent : textColor.withValues(alpha: 0.6), size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? accent : textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                disabled ? 'Em desenvolvimento' : sublabel,
                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
