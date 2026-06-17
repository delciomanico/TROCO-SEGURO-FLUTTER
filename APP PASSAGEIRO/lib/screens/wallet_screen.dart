import 'package:flutter/material.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

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

  List<Transaction> getFilteredTransactions(List<Transaction> transactions) {
    return transactions.where((tx) {
      final type = tx.type.toLowerCase();
      final matchesType = activeFilter == 'all' ||
          type == activeFilter ||
          (activeFilter == 'topup' && type == 'deposit');
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryGold))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await Future.wait([
                          provider.refreshUserData(),
                          provider.refreshTransactions(),
                        ]);
                      },
                      color: AppColors.primaryGold,
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
                          color: AppColors.primaryGold,
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primaryGold.withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Saldo disponível',
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
                      ? NumberFormat('#,##0', 'pt_AO')
                          .format(user?.balance ?? 0)
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
                  padding:
                      EdgeInsets.only(bottom: responsive.scaledHeight(5)),
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

  Widget _buildQuickActions(bool isDark, ResponsiveHelper responsive) {
    final actions = [
      (icon: Icons.add_circle_outline_rounded, label: 'Recarregar',
          onTap: () => widget.onOpenTopup?.call()),
      (icon: Icons.send_rounded, label: 'Transferir',
          onTap: _showTransferModal),
      (icon: Icons.credit_card_rounded, label: 'P/ Cartão',
          onTap: _showDepositToCardModal),
      (icon: Icons.swap_horiz_rounded, label: 'Cartão Ext.',
          onTap: _showExternalCardModal),
    ];

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Icon(
              icon,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppColors.textDark.withValues(alpha: 0.75),
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
              ? AppColors.primaryGold
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primaryGold
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
        borderRadius: BorderRadius.circular(14),
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
                color: AppColors.primaryGold.withValues(alpha: 0.3),
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
          TextField(
            controller: _cardCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Número do cartão',
                border: OutlineInputBorder()),
          ),
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
  String? _error;
  String? _recipientName;
  bool _loading = false;
  bool _verified = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Informe o número de telefone.');
      return;
    }
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
    setState(() {
      _error = null;
      _loading = true;
    });
    final provider = context.read<AppProvider>();
    final ok = await provider.transfer(
      amount: amount,
      receiverPhone: _phoneCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      FeedbackService.showSuccess(context,
          message: 'Transferência realizada com sucesso!');
      return;
    }
    final errMsg = provider.error;
    setState(() {
      _loading = false;
      _error = errMsg ?? 'Erro ao realizar transferência.';
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
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  enabled: !_verified,
                  decoration: const InputDecoration(
                    labelText: 'Nº de telefone',
                    hintText: '+244 9XX XXX XXX',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: _verified
                    ? IconButton.filled(
                        onPressed: () =>
                            setState(() {
                              _verified = false;
                              _recipientName = null;
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
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
                borderRadius: BorderRadius.circular(10),
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
                const BorderRadius.vertical(top: Radius.circular(24)),
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
                      borderRadius: BorderRadius.circular(2),
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
        borderRadius: BorderRadius.circular(10),
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
