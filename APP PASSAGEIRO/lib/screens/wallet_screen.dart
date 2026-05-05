import 'package:flutter/material.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/models/transaction.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/utils/constants.dart';

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

  List<Transaction> getFilteredTransactions(List<Transaction> transactions) {
    return transactions.where((tx) {
      final matchesType = activeFilter == 'all' || tx.type == activeFilter;
      final matchesSearch =
          tx.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (tx.driver?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false);
      return matchesType && matchesSearch;
    }).toList();
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)}kzs';
  }

  Future<void> _showWalletToCardTransferModal() async {
    final provider = context.read<AppProvider>();

    final didTransfer = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletToCardTransferSheet(
        cards: provider.virtualCards,
        onTransfer: (cardId, amount) {
          return provider.transferFromWalletToVirtualCard(
            cardId: cardId,
            amount: amount,
          );
        },
      ),
    );

    if (!mounted) return;
    if (didTransfer == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transferência para cartão virtual concluída!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<AppProvider>();
    final user = provider.user;
    final transactions = provider.transactions;
    final filteredTxs = getFilteredTransactions(transactions);

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
      body: provider.isLoadingTransactions
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  provider.refreshUserData(),
                  provider.refreshTransactions(),
                ]);
              },
              child: SafeArea(
                top: true,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: isDark
                            ? Theme.of(context).colorScheme.surface
                            : Colors.white,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                          children: [
                            _buildBalanceCard(isDark, user),
                            const SizedBox(height: 24),
                            _buildQuickActions(isDark),
                            const SizedBox(height: 24),
                            _buildFilters(isDark),
                            const SizedBox(height: 16),
                            _buildSearchBar(isDark),
                            const SizedBox(height: 16),
                            if (filteredTxs.isEmpty)
                              _buildEmptyState(isDark)
                            else
                              ...filteredTxs.map(
                                  (tx) => _buildTransactionItem(tx, isDark)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard(bool isDark, User? user) {
    final isDarkLocal = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: isDarkLocal ? Theme.of(context).cardColor : null,
        gradient: isDarkLocal ? null : AppColors.silverGradient,
        image: const DecorationImage(
          image: AssetImage('assets/images/card_fundo.jpg'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.primaryGold.withAlpha((0.9 * 255).round()),
            width: 1.2),
        boxShadow: [
          // Sombra inferior (profundidade)
          BoxShadow(
            color: isDarkLocal
                ? Colors.black.withAlpha((0.6 * 255).round())
                : Colors.black.withAlpha((0.2 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          // Sombra superior (destaque 3D)
          BoxShadow(
            color: isDarkLocal
                ? Colors.white.withAlpha((0.05 * 255).round())
                : Colors.white.withAlpha((0.9 * 255).round()),
            blurRadius: 6,
            offset: const Offset(0, -3),
            spreadRadius: 0,
          ),
          // Sombra lateral para profundidade
          BoxShadow(
            color: isDarkLocal
                ? Colors.black.withAlpha((0.4 * 255).round())
                : Colors.black.withAlpha((0.12 * 255).round()),
            blurRadius: 8,
            offset: const Offset(3, 3),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Saldo disponível',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withAlpha((0.9 * 255).round())
                  : AppColors.primaryGold.withAlpha((0.9 * 255).round()),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => showBalance = !showBalance),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  showBalance ? _formatCurrency(user?.balance ?? 0) : '••••••',
                  style: TextStyle(
                    fontSize: 36,
                    color: isDark ? Colors.white : AppColors.primaryGold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  showBalance ? Icons.visibility : Icons.visibility_off,
                  color: isDark
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.8 * 255).round())
                      : AppColors.primaryGold,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 64,
            child: _buildActionButton(
              icon: Icons.person_outline_rounded,
              label: 'Outra conta',
              isPrimary: false,
              onTap: widget.onOpenTransfer ?? () {},
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 64,
            child: _buildActionButton(
              icon: Icons.credit_card,
              label: 'Cartão virtual',
              isPrimary: false,
              onTap: _showWalletToCardTransferModal,
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? Colors.transparent
              : (isDark ? Colors.transparent : Theme.of(context).cardColor),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary
                ? (isDark ? AppColors.primaryGold : AppColors.textDark)
                : (isDark
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.18 * 255).round())
                    : Colors.grey.withAlpha((0.3 * 255).round())),
            width: isPrimary ? 2 : 2,
          ),
          boxShadow: [
            // Sombra inferior (profundidade)
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha((0.5 * 255).round())
                  : Colors.black.withAlpha((0.15 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            // Sombra superior (destaque 3D)
            BoxShadow(
              color: isDark
                  ? Colors.white.withAlpha((0.05 * 255).round())
                  : Colors.white.withAlpha((0.8 * 255).round()),
              blurRadius: 4,
              offset: const Offset(0, -2),
              spreadRadius: 0,
            ),
            // Sombra lateral para profundidade
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha((0.3 * 255).round())
                  : Colors.black.withAlpha((0.08 * 255).round()),
              blurRadius: 6,
              offset: const Offset(2, 2),
              spreadRadius: -1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary
                  ? (isDark ? AppColors.primaryGold : AppColors.textDark)
                  : (isDark
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurface),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? (isDark ? AppColors.primaryGold : AppColors.textDark)
                    : (isDark
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
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
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isActive = activeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => activeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.darkBackground
              : (isDark
                  ? AppColors.darkCard.withOpacity(0.06)
                  : AppColors.lightBackground),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.darkBackground
                : (isDark
                    ? AppColors.textLight.withOpacity(0.18)
                    : Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive
                ? AppColors.textLight
                : (isDark
                    ? AppColors.textLight.withOpacity(0.9)
                    : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return TextField(
      onChanged: (value) => setState(() => searchQuery = value),
      style:
          TextStyle(color: isDark ? AppColors.textLight : AppColors.textDark),
      decoration: InputDecoration(
        hintText: 'Buscar transações...',
        hintStyle: TextStyle(
            color: isDark ? AppColors.textLight.withOpacity(0.6) : Colors.grey),
        prefixIcon: Icon(Icons.search,
            color: isDark ? AppColors.textLight.withOpacity(0.6) : Colors.grey),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: isDark
                  ? AppColors.textLight.withOpacity(0.38)
                  : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma transação',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textLight.withOpacity(0.6)
                    : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction tx, bool isDark) {
    // Use direction or displayAmount to determine if incoming/outgoing
    final isIncoming = tx.isIncoming;
    final displayValue = (tx.originalAmount ?? tx.amount).abs();
    final counterpartyName = tx.counterparty ?? tx.driver ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isIncoming
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isIncoming ? Colors.green : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (counterpartyName.isNotEmpty)
                  Text(
                    counterpartyName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textLight.withOpacity(0.6)
                          : Colors.grey[500],
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
                '${isIncoming ? '+' : '-'}${_formatCurrency(displayValue)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isIncoming ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tx.time ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textLight.withOpacity(0.6)
                      : Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletToCardTransferSheet extends StatefulWidget {
  final List<VirtualCard> cards;
  final Future<String?> Function(String cardId, int amount) onTransfer;

  const _WalletToCardTransferSheet({
    required this.cards,
    required this.onTransfer,
  });

  @override
  State<_WalletToCardTransferSheet> createState() =>
      _WalletToCardTransferSheetState();
}

class _WalletToCardTransferSheetState
    extends State<_WalletToCardTransferSheet> {
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCardId;
  String? _formError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());

    if (_selectedCardId == null || amount == null) {
      setState(() {
        _formError = 'Selecione o cartão de destino e informe o montante.';
      });
      return;
    }

    if (amount <= 0) {
      setState(() {
        _formError = 'O montante deve ser maior que zero.';
      });
      return;
    }

    setState(() {
      _formError = null;
      _isSubmitting = true;
    });

    final transferError = await widget.onTransfer(_selectedCardId!, amount);
    if (!mounted) return;

    if (transferError == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _formError = transferError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
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
                Container(
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
                const SizedBox(height: 20),
                Icon(
                  Icons.credit_card,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'TRANSFERIR PARA CARTÃO VIRTUAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Escolha o cartão de destino e o valor a sair da carteira principal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.7 * 255).round()),
                  ),
                ),
                const SizedBox(height: 18),
                if (_formError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha((0.08 * 255).round()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  value: _selectedCardId,
                  decoration: const InputDecoration(
                    labelText: 'Cartão de destino',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.cards
                      .map(
                        (card) => DropdownMenuItem<String>(
                          value: card.id,
                          child: Text('${card.name} - ${card.balance} Kz'),
                        ),
                      )
                      .toList(),
                  onChanged: widget.cards.isEmpty
                      ? null
                      : (value) {
                          setState(() => _selectedCardId = value);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montante (Kz)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Transferir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
