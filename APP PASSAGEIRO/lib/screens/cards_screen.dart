import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/services/virtual_card_service.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/widgets/card_transfer_modal.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _fmt(int amount) => NumberFormat('#,##0', 'pt_AO').format(amount);

  String _virtualCardNumber(String source) {
    final digits = source.codeUnits
        .map((code) => (code % 10).toString())
        .join()
        .padRight(16, '0');
    final n = digits.substring(0, 16);
    return '${n.substring(0, 4)} ${n.substring(4, 8)} ${n.substring(8, 12)} ${n.substring(12, 16)}';
  }

  String _virtualExpiry(String createdAt) {
    final created = DateTime.tryParse(createdAt) ?? DateTime.now();
    final expiry = DateTime(created.year + 3, created.month);
    return '${expiry.month.toString().padLeft(2, '0')}/${(expiry.year % 100).toString().padLeft(2, '0')}';
  }

  // ── Topup modal ────────────────────────────────────────────────────────────
  void _showTopupModal(VirtualCard card) {
    final provider = context.read<AppProvider>();
    final walletBalance = provider.user?.balance ?? 0;
    final amountController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.25 * 255).round()),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Recarregar "${card.name}"',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saldo disponível na carteira: ${_fmt(walletBalance)} Kz',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.6 * 255).round()),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor a recarregar',
                    suffixText: 'Kz',
                    prefixIcon: const Icon(Icons.add_card_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withAlpha((0.2 * 255).round()),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Theme.of(ctx).colorScheme.surface
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final amount =
                                int.tryParse(amountController.text.trim()) ?? 0;
                            if (amount <= 0) {
                              FeedbackService.showError(ctx,
                                  message: 'Valor deve ser maior que 0');
                              return;
                            }
                            if (amount > walletBalance) {
                              FeedbackService.showError(ctx,
                                  message: 'Saldo insuficiente na carteira');
                              return;
                            }
                            setSheet(() => isLoading = true);
                            final err = await provider.topupVirtualCard(
                              cardId: card.id,
                              amount: amount,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (err != null) {
                              FeedbackService.showError(context,
                                  message: err);
                            } else {
                              FeedbackService.showSuccess(context,
                                  message:
                                      '${_fmt(amount)} Kz adicionados ao cartão');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.primary,
                      foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Recarregar',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Withdraw modal ─────────────────────────────────────────────────────────
  void _showWithdrawModal(VirtualCard card) {
    final provider = context.read<AppProvider>();
    final amountController = TextEditingController();
    final pinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
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
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.25 * 255).round()),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Levantar de "${card.name}"',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saldo disponível: ${_fmt(card.balance)} Kz',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.6 * 255).round()),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor a levantar',
                    suffixText: 'Kz',
                    prefixIcon: const Icon(Icons.arrow_upward_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.onSurface.withAlpha((0.2 * 255).round()),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(ctx).colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? Theme.of(ctx).colorScheme.surface : Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'PIN do cartão (4 dígitos)',
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.onSurface.withAlpha((0.2 * 255).round()),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(ctx).colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? Theme.of(ctx).colorScheme.surface : Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final amount = int.tryParse(amountController.text.trim()) ?? 0;
                            final pin = pinController.text.trim();
                            if (amount <= 0) {
                              FeedbackService.showError(ctx, message: 'Valor deve ser maior que 0');
                              return;
                            }
                            if (amount > card.balance) {
                              FeedbackService.showError(ctx, message: 'Saldo insuficiente no cartão');
                              return;
                            }
                            if (pin.length != 4) {
                              FeedbackService.showError(ctx, message: 'PIN do cartão deve ter 4 dígitos');
                              return;
                            }
                            setSheet(() => isLoading = true);
                            final ok = await provider.withdrawFromCard(
                              cardId: card.id,
                              amount: amount,
                              cardPin: pin,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (ok) {
                              FeedbackService.showSuccess(context,
                                  message: '${_fmt(amount)} Kz devolvidos à carteira');
                            } else {
                              FeedbackService.showError(context, message: 'Erro ao levantar do cartão');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Levantar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Freeze/Unfreeze ────────────────────────────────────────────────────────
  Future<void> _toggleFreeze(VirtualCard card) async {
    final provider = context.read<AppProvider>();
    final willFreeze = !card.isFrozen;
    final newStatus = willFreeze ? 'frozen' : 'active';
    final label = willFreeze ? 'congelado' : 'activado';

    final err = await provider.updateVirtualCardStatus(
      cardId: card.id,
      status: newStatus,
    );
    if (!mounted) return;
    if (err != null) {
      FeedbackService.showError(context, message: err);
    } else {
      FeedbackService.showSuccess(context,
          message: 'Cartão ${card.name} $label');
    }
  }

  // ── Limit modal ────────────────────────────────────────────────────────────
  void _showLimitModal(VirtualCard card) {
    final provider = context.read<AppProvider>();
    final controller =
        TextEditingController(text: card.dailyLimit > 0 ? '${card.dailyLimit}' : '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.25 * 255).round()),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Limite diário — "${card.name}"',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Limite actual: ${card.dailyLimit > 0 ? '${_fmt(card.dailyLimit)} Kz' : 'Sem limite'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.6 * 255).round()),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Novo limite diário',
                    hintText: '0 = sem limite',
                    suffixText: 'Kz',
                    prefixIcon: const Icon(Icons.speed_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withAlpha((0.2 * 255).round()),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(ctx).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Theme.of(ctx).colorScheme.surface
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final limit =
                                int.tryParse(controller.text.trim()) ?? 0;
                            if (limit < 0) {
                              FeedbackService.showError(ctx,
                                  message: 'Limite inválido');
                              return;
                            }
                            setSheet(() => isLoading = true);
                            final err = await provider.updateVirtualCardLimit(
                              cardId: card.id,
                              dailyLimit: limit,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (err != null) {
                              FeedbackService.showError(context, message: err);
                            } else {
                              FeedbackService.showSuccess(context,
                                  message: limit == 0
                                      ? 'Limite removido'
                                      : 'Limite definido: ${_fmt(limit)} Kz/dia');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.primary,
                      foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(VirtualCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Apagar cartão',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Deseja apagar "${card.name}"?\nO saldo será devolvido à sua carteira.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final provider = context.read<AppProvider>();
    final ok = await provider.deleteVirtualCard(card.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        if (_currentPage > 0) _currentPage--;
      });
      FeedbackService.showSuccess(context,
          message: 'Cartão "${card.name}" apagado');
    } else {
      FeedbackService.showError(context, message: 'Erro ao apagar cartão');
    }
  }

  // ── Transfer between cards modal ───────────────────────────────────────────
  void _showTransferBetweenCardsModal(VirtualCard fromCard) {
    final provider = context.read<AppProvider>();
    final cards = provider.virtualCards;

    if (cards.length < 2) {
      FeedbackService.showError(
        context,
        message: 'É necessário ter pelo menos dois cartões para transferir',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CardTransferModal(
        cards: cards,
        onTransfer: (fromCardId, toCardId, amount, pin) =>
            provider.transferBetweenVirtualCards(
          fromCardId: fromCardId,
          toCardId: toCardId,
          amount: amount,
          pin: pin,
        ),
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  // ── More actions modal ─────────────────────────────────────────────────────
  void _showMoreCardActionsModal(VirtualCard card, bool isDark) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, _) {
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mais opções',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: dark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _ActionChip(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Transferir',
                          color: Colors.purple,
                          onTap: (card.isBlocked || card.isFrozen)
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _showTransferBetweenCardsModal(card);
                                },
                        ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          icon: Icons.speed_rounded,
                          label: 'Limite',
                          onTap: card.isBlocked
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _showLimitModal(card);
                                },
                        ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          icon: Icons.delete_outline_rounded,
                          label: 'Apagar',
                          color: Colors.red,
                          onTap: () {
                            Navigator.pop(ctx);
                            _confirmDelete(card);
                          },
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Card share/download ────────────────────────────────────────────────────
  Future<Uint8List?> _captureImage(GlobalKey key) async {
    try {
      final ro = key.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return null;
      final image = await ro.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareCard(GlobalKey key, VirtualCard card) async {
    final bytes = await _captureImage(key);
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/card_${card.id}.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Cartão ${card.name}');
  }

  Future<void> _downloadCard(GlobalKey key, VirtualCard card) async {
    final bytes = await _captureImage(key);
    if (bytes == null || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final cardsDir = Directory('${dir.path}/virtual_cards');
    if (!await cardsDir.exists()) await cardsDir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${cardsDir.path}/card_${card.id}_$ts.png');
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    FeedbackService.showSuccess(context,
        message: 'Cartão guardado em: ${file.path}');
  }

  // ── QR details sheet ───────────────────────────────────────────────────────
  Future<void> _showCardDetails(VirtualCard card) async {
    // Busca o QR oficial do servidor — a geração local não é válida para pagamento.
    final qrResult = await ApiService().getVirtualCardQr(card.id);
    if (!mounted) return;

    if (!qrResult.isSuccess || qrResult.data == null || qrResult.data!.isEmpty) {
      FeedbackService.showError(
        context,
        message: qrResult.error ?? 'Não foi possível gerar o QR code. Tente novamente.',
      );
      return;
    }

    final payload = qrResult.data!;
    final service = VirtualCardService();
    final remaining =
        card.dailyLimit > 0 ? service.getRemainingDailyLimit(card) : null;
    final previewKey = GlobalKey();
    final virtualNumber = _virtualCardNumber(card.id);
    final expiry = _virtualExpiry(card.createdAt);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: isDark
          ? Theme.of(context).cardColor
          : AppColors.lightCard,
      builder: (ctx) {
        bool isSharing = false;
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(card.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                RepaintBoundary(
                  key: previewKey,
                  child: _CardVisual(
                    card: card,
                    cardHolderName: context
                            .read<AppProvider>()
                            .user
                            ?.fullName ??
                        '',
                    virtualNumber: virtualNumber,
                    expiry: expiry,
                    payload: payload,
                  ),
                ),
                const SizedBox(height: 14),
                Text('Saldo: ${_fmt(card.balance)} Kz',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  remaining == null
                      ? 'Sem limite diário'
                      : 'Limite restante hoje: ${_fmt(remaining)} Kz',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheet(() => isSaving = true);
                                await _downloadCard(previewKey, card);
                                if (!ctx.mounted) return;
                                setSheet(() => isSaving = false);
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.download_rounded),
                        label: const Text('Baixar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isSharing
                            ? null
                            : () async {
                                setSheet(() => isSharing = true);
                                await _shareCard(previewKey, card);
                                if (!ctx.mounted) return;
                                setSheet(() => isSharing = false);
                              },
                        icon: isSharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.share_rounded),
                        label: const Text('Partilhar'),
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

  // ── Create card sheet ──────────────────────────────────────────────────────
  void _showCreateCardSheet() {
    final provider = context.read<AppProvider>();
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    final userPinCtrl = TextEditingController();
    final cardPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;
    bool showUserPin = false;
    bool showCardPin = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Theme.of(ctx).cardColor : AppColors.lightCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.25 * 255).round()),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Criar Cartão Virtual',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildField(
                      ctx,
                      controller: nameCtrl,
                      label: 'Nome do cartão',
                      hint: 'Ex: Cartão Netflix',
                      icon: Icons.badge_outlined,
                      isDark: isDark,
                      validator: (v) => v?.trim().isEmpty == true
                          ? 'Informe um nome'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      ctx,
                      controller: balanceCtrl,
                      label: 'Saldo inicial',
                      hint: 'Valor em Kz',
                      icon: Icons.account_balance_wallet_outlined,
                      isDark: isDark,
                      suffix: 'Kz',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return (n == null || n <= 0)
                            ? 'Saldo deve ser maior que 0'
                            : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      ctx,
                      controller: limitCtrl,
                      label: 'Limite diário (opcional)',
                      hint: '0 = sem limite',
                      icon: Icons.speed_outlined,
                      isDark: isDark,
                      suffix: 'Kz',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        return (n == null || n < 0) ? 'Limite inválido' : null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .primary
                            .withAlpha((0.08 * 255).round()),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Precisas de dois PINs: o PIN da tua conta (6 dígitos) para confirmar identidade, e um PIN do cartão (4 dígitos) para pagamentos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPinField(
                      ctx,
                      controller: userPinCtrl,
                      label: 'PIN da conta (6 dígitos)',
                      isDark: isDark,
                      maxLen: 6,
                      obscure: !showUserPin,
                      trailing: IconButton(
                        icon: Icon(showUserPin
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setSheet(() => showUserPin = !showUserPin),
                      ),
                      validator: (v) {
                        final p = (v ?? '').trim();
                        if (p.length != 6) return 'PIN deve ter 6 dígitos';
                        if (int.tryParse(p) == null) {
                          return 'Apenas dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildPinField(
                      ctx,
                      controller: cardPinCtrl,
                      label: 'PIN do cartão (4 dígitos)',
                      isDark: isDark,
                      maxLen: 4,
                      obscure: !showCardPin,
                      trailing: IconButton(
                        icon: Icon(showCardPin
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setSheet(() => showCardPin = !showCardPin),
                      ),
                      validator: (v) {
                        final p = (v ?? '').trim();
                        if (p.length != 4) return 'PIN deve ter 4 dígitos';
                        if (int.tryParse(p) == null) {
                          return 'Apenas dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isCreating
                            ? null
                            : () async {
                                FocusScope.of(ctx).unfocus();
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => isCreating = true);

                                final balance = int.parse(
                                    balanceCtrl.text.trim());
                                final limitTxt = limitCtrl.text.trim();
                                final limit = limitTxt.isEmpty
                                    ? 0
                                    : int.parse(limitTxt);

                                try {
                                  await provider.createVirtualCard(
                                    name: nameCtrl.text.trim(),
                                    initialBalance: balance,
                                    dailyLimit: limit,
                                    userPin: userPinCtrl.text.trim(),
                                    cardPin: cardPinCtrl.text.trim(),
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  FeedbackService.showSuccess(context,
                                      message: 'Cartão criado com sucesso!');
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  setSheet(() => isCreating = false);
                                  FeedbackService.showError(context,
                                      message: e.toString());
                                }
                              },
                        icon: isCreating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_card_outlined),
                        label: Text(isCreating ? 'A criar...' : 'Criar cartão',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(ctx).colorScheme.primary,
                          foregroundColor:
                              Theme.of(ctx).colorScheme.onPrimary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext ctx, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(ctx)
                .colorScheme
                .onSurface
                .withAlpha((0.2 * 255).round()),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Theme.of(ctx).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor:
            isDark ? Theme.of(ctx).colorScheme.surface : Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _buildPinField(
    BuildContext ctx, {
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required int maxLen,
    required bool obscure,
    required Widget trailing,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: maxLen,
      obscureText: obscure,
      obscuringCharacter: '●',
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: trailing,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(ctx)
                .colorScheme
                .onSurface
                .withAlpha((0.2 * 255).round()),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Theme.of(ctx).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor:
            isDark ? Theme.of(ctx).colorScheme.surface : Colors.white,
      ),
      validator: validator,
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, ResponsiveHelper responsive) {
    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(10),
      ),
      child: Row(
        children: [
          Text(
            'Cartões',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(22),
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textDark,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showCreateCardSheet,
            child: Container(
              width: responsive.scaledWidth(38),
              height: responsive.scaledWidth(38),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                border: Border.all(
                  color: Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.add_card_rounded,
                size: responsive.scaledWidth(18),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppColors.textDark.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cards = provider.virtualCards;
    final isLoading = provider.isLoadingCards;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark, responsive),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.refreshVirtualCards(),
                child: CustomScrollView(
                  slivers: [
                    if (isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                        ),
                      ),

                // ── Empty state ────────────────────────────────────────────────
                if (cards.isEmpty && !isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                border: Border.all(
                                  color: AppColors.accentOf(context)
                                      .withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.credit_card_off_rounded,
                                size: 34,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Colors.black.withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Nenhum cartão virtual',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Crie o seu primeiro cartão virtual para pagamentos seguros.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Colors.black.withValues(alpha: 0.4),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: _showCreateCardSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.accentOf(context)
                                        .withValues(alpha: 0.6),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_card_rounded,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.85)
                                          : AppColors.textDark
                                              .withValues(alpha: 0.75),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Criar cartão virtual',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.85)
                                            : AppColors.textDark
                                                .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Card carousel ──────────────────────────────────────────────
                if (cards.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 210,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: cards.length,
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        itemBuilder: (ctx, i) {
                          final card = cards[i];
                          final isActive = i == _currentPage;
                          return AnimatedScale(
                            scale: isActive ? 1.0 : 0.93,
                            duration: const Duration(milliseconds: 250),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: _CardCarouselItem(
                                card: card,
                                virtualNumber: _virtualCardNumber(card.id),
                                expiry: _virtualExpiry(card.createdAt),
                                cardHolderName:
                                    provider.user?.fullName ?? '',
                                onTap: () => _showCardDetails(card),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Page dots
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(cards.length, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: active ? 20 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.accentOf(context)
                                  : AppColors.accentOf(context)
                                      .withAlpha((0.25 * 255).round()),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // ── Action buttons for selected card ─────────────────────────
                  SliverToBoxAdapter(
                    child: Builder(builder: (ctx) {
                      if (_currentPage >= cards.length) {
                        return const SizedBox.shrink();
                      }
                      final card = cards[_currentPage];
                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acções rápidas',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Colors.black.withValues(alpha: 0.4),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _ActionChip(
                                  icon: Icons.add_card_rounded,
                                  label: 'Recarregar',
                                  onTap: card.isBlocked
                                      ? null
                                      : () => _showTopupModal(card),
                                ),
                                const SizedBox(width: 8),
                                _ActionChip(
                                  icon: Icons.arrow_upward_rounded,
                                  label: 'Levantar',
                                  color: Colors.orange,
                                  onTap: (card.isBlocked || card.isFrozen)
                                      ? null
                                      : () => _showWithdrawModal(card),
                                ),
                                const SizedBox(width: 8),
                                _ActionChip(
                                  icon: card.isFrozen
                                      ? Icons.play_arrow_rounded
                                      : Icons.ac_unit_rounded,
                                  label: card.isFrozen
                                      ? 'Activar'
                                      : 'Congelar',
                                  color: card.isFrozen
                                      ? Colors.green
                                      : Colors.blue,
                                  onTap: card.isBlocked
                                      ? null
                                      : () => _toggleFreeze(card),
                                ),
                                const SizedBox(width: 8),
                                _ActionChip(
                                  icon: Icons.grid_view_rounded,
                                  label: 'Mais',
                                  onTap: () =>
                                      _showMoreCardActionsModal(card, isDark),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ),

                  // ── Card details info ─────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Builder(builder: (ctx) {
                      if (_currentPage >= cards.length) {
                        return const SizedBox.shrink();
                      }
                      final card = cards[_currentPage];
                      final service = VirtualCardService();
                      final remaining = card.dailyLimit > 0
                          ? service.getRemainingDailyLimit(card)
                          : null;

                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.07),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Saldo',
                                value: '${_fmt(card.balance)} Kz',
                                valueColor: AppColors.accentOf(context),
                              ),
                              _Divider(),
                              _InfoRow(
                                icon: Icons.speed_rounded,
                                label: 'Limite diário',
                                value: card.dailyLimit > 0
                                    ? '${_fmt(card.dailyLimit)} Kz'
                                    : 'Sem limite',
                              ),
                              if (card.dailyLimit > 0) ...[
                                _Divider(),
                                _InfoRow(
                                  icon: Icons.today_rounded,
                                  label: 'Gasto hoje',
                                  value: '${_fmt(card.spentToday)} Kz',
                                ),
                                _Divider(),
                                _InfoRow(
                                  icon: Icons.check_circle_outline_rounded,
                                  label: 'Disponível hoje',
                                  value: remaining != null
                                      ? '${_fmt(remaining)} Kz'
                                      : '—',
                                  valueColor: Colors.green.shade700,
                                ),
                              ],
                              _Divider(),
                              _InfoRow(
                                icon: card.isBlocked
                                    ? Icons.block_rounded
                                    : card.isFrozen
                                        ? Icons.ac_unit_rounded
                                        : Icons.check_circle_rounded,
                                label: 'Estado',
                                value: card.isBlocked
                                    ? 'Bloqueado'
                                    : card.isFrozen
                                        ? 'Congelado'
                                        : 'Activo',
                                valueColor: card.isBlocked
                                    ? Colors.red
                                    : card.isFrozen
                                        ? Colors.orange
                                        : Colors.green.shade700,
                              ),
                              _Divider(),
                              _InfoRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Criado em',
                                value: _formatDate(card.createdAt),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy', 'pt_AO').format(dt);
  }
}

// ── Card carousel item ────────────────────────────────────────────────────────
class _CardCarouselItem extends StatelessWidget {
  final VirtualCard card;
  final String virtualNumber;
  final String expiry;
  final String cardHolderName;
  final VoidCallback onTap;

  const _CardCarouselItem({
    required this.card,
    required this.virtualNumber,
    required this.expiry,
    required this.cardHolderName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/card_fundo.jpg'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentOf(context).withAlpha((0.9 * 255).round()),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.28 * 255).round()),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withAlpha((0.22 * 255).round()),
                Colors.black.withAlpha((0.60 * 255).round()),
              ],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/images/logo.png',
                      height: 38, width: 38, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      card.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (card.isBlocked)
                    _StatusBadge('BLOQUEADO', Colors.red)
                  else if (card.isFrozen)
                    _StatusBadge('CONGELADO', Colors.orange)
                  else
                    const Icon(Icons.wifi_rounded,
                        color: Colors.white70, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE7C97A), Color(0xFFC39A45)]),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Spacer(),
              Text(
                virtualNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TITULAR',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 8,
                              letterSpacing: 1)),
                      Text(
                        cardHolderName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('VALIDADE',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 8,
                              letterSpacing: 1)),
                      Text(expiry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('SALDO',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 8,
                              letterSpacing: 1)),
                      Text(
                        '${NumberFormat('#,##0', 'pt_AO').format(card.balance)} Kz',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha((0.85 * 255).round()),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}

// ── Card visual for QR details ─────────────────────────────────────────────────
class _CardVisual extends StatelessWidget {
  final VirtualCard card;
  final String cardHolderName;
  final String virtualNumber;
  final String expiry;
  final String payload;

  const _CardVisual({
    required this.card,
    required this.cardHolderName,
    required this.virtualNumber,
    required this.expiry,
    required this.payload,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.58,
      child: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/card_fundo.jpg'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.accentOf(context).withAlpha((0.9 * 255).round()),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.24 * 255).round()),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withAlpha((0.28 * 255).round()),
                Colors.black.withAlpha((0.58 * 255).round()),
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final scale = (constraints.maxWidth / 410).clamp(0.72, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/logo.png',
                          height: 42 * scale,
                          width: 42 * scale,
                          fit: BoxFit.contain),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: Text(
                          card.name.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * scale,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.wifi_rounded,
                          color: Colors.white70, size: 18 * scale),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  Container(
                    width: 44 * scale,
                    height: 32 * scale,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8 * scale),
                      gradient: const LinearGradient(
                          colors: [Color(0xFFE7C97A), Color(0xFFC39A45)]),
                    ),
                  ),
                  const Spacer(),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(virtualNumber,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22 * scale,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TITULAR',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9 * scale,
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              cardHolderName.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12 * scale,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4 * scale),
                            Text('Validade $expiry',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10 * scale,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      SizedBox(width: 6 * scale),
                      Container(
                        padding: EdgeInsets.all(4 * scale),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                        child: payload.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(payload.split(',').last),
                                width: 100 * scale,
                                height: 100 * scale,
                                fit: BoxFit.contain,
                              )
                            : QrImageView(
                                data: payload,
                                size: 100 * scale,
                                backgroundColor: Colors.white,
                              ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Action chip ───────────────────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: disabled ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentOf(context),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textDark.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon,
              size: 17,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.38)
                  : Colors.black.withValues(alpha: 0.3)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.55)
                    : Colors.black.withValues(alpha: 0.5),
              )),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ??
                    (isDark ? Colors.white : AppColors.textDark),
              )),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outline.withAlpha((0.1 * 255).round()),
    );
  }
}
