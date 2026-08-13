import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:troco_seguro/models/virtual_card.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/services/virtual_card_export_service.dart';
import 'package:troco_seguro/services/virtual_card_service.dart';

class VirtualCardsFullscreen extends StatefulWidget {
  final List<VirtualCard> cards;

  /// Returns a [VirtualCardCreated] on success, throws a String error message on failure.
  final Future<VirtualCardCreated> Function({
    required String name,
    required int initialBalance,
    required int dailyLimit,
    required String userPin,
    required String cardPin,
  }) onCreateCard;
  final Function(String cardId) onDeleteCard;
  final VoidCallback onClose;
  final String cardHolderName;

  const VirtualCardsFullscreen({
    super.key,
    required this.cards,
    required this.onCreateCard,
    required this.onDeleteCard,
    required this.onClose,
    required this.cardHolderName,
  });

  @override
  State<VirtualCardsFullscreen> createState() => _VirtualCardsFullscreenState();
}

class _VirtualCardsFullscreenState extends State<VirtualCardsFullscreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _dailyLimitController = TextEditingController();
  final _userPinController = TextEditingController(); // 6-digit account PIN
  final _cardPinController = TextEditingController(); // 4-digit card PIN
  final _formKey = GlobalKey<FormState>();

  late final TabController _tabController;
  bool _isCreating = false;
  String _createError = '';
  VirtualCardCreated? _createdCard; // holds result shown after creation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _dailyLimitController.dispose();
    _userPinController.dispose();
    _cardPinController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  int get _totalBalance =>
      widget.cards.fold<int>(0, (sum, card) => sum + card.balance);

  int get _activeCards =>
      widget.cards.where((card) => !card.isBlocked && !card.isFrozen).length;

  int get _limitedCards =>
      widget.cards.where((card) => card.dailyLimit > 0).length;

  Color _statusColor(ThemeData theme, VirtualCard card) {
    if (card.isBlocked) return Colors.red.shade700;
    if (card.isFrozen) return Colors.orange.shade700;
    return theme.colorScheme.primary;
  }

  String _statusLabel(VirtualCard card) {
    if (card.isBlocked) return 'Bloqueado';
    if (card.isFrozen) return 'Congelado';
    return 'Ativo';
  }

  Future<void> _submitCreate() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
      _createError = '';
    });

    final balance = int.parse(_balanceController.text.trim());
    final dailyLimitTxt = _dailyLimitController.text.trim();
    final dailyLimit = dailyLimitTxt.isEmpty ? 0 : int.parse(dailyLimitTxt);

    try {
      final created = await widget.onCreateCard(
        name: _nameController.text.trim(),
        initialBalance: balance,
        dailyLimit: dailyLimit,
        userPin: _userPinController.text.trim(),
        cardPin: _cardPinController.text.trim(),
      );

      if (!mounted) return;

      // Clear form
      _nameController.clear();
      _balanceController.clear();
      _dailyLimitController.clear();
      _userPinController.clear();
      _cardPinController.clear();

      setState(() {
        _isCreating = false;
        _createError = '';
        _createdCard = created; // show the one-time card display
      });

      // Go to "Meus cartões" tab so the display is shown
      _tabController.animateTo(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createError = e.toString();
      });
    }
  }

  Future<void> _confirmDelete(VirtualCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apagar cartão'),
          content: Text('Deseja realmente apagar "${card.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await widget.onDeleteCard(card.id);
    if (!mounted) return;

    // Limpar _createdCard para evitar inconsistências de estado
    setState(() => _createdCard = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cartão "${card.name}" removido.')),
    );
  }

  Future<Uint8List?> _captureCardImage(GlobalKey previewKey) async {
    try {
      final renderObject = previewKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareCard(GlobalKey previewKey, VirtualCard card) async {
    final bytes = await _captureCardImage(previewKey);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível gerar a imagem do cartão.')),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/cartao_virtual_${card.id}.png';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Cartão virtual ${card.name}',
    );
  }

  Future<void> _downloadCard(GlobalKey previewKey, VirtualCard card) async {
    final bytes = await _captureCardImage(previewKey);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível guardar a imagem do cartão.')),
      );
      return;
    }

    final result = await VirtualCardExportService().saveImageBytes(
      bytes,
      suggestedName: 'cartao_virtual_${card.id}.png',
    );

    if (!mounted) return;
    if (result.cancelled) return;

    if (result.path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cartão guardado em: ${result.path}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Não foi possível guardar o cartão.'),
        ),
      );
    }
  }

  String _virtualCardNumber(String source) {
    final digits = source.codeUnits
        .map((code) => (code % 10).toString())
        .join()
        .padRight(16, '0');
    final number = digits.substring(0, 16);
    return '${number.substring(0, 4)} ${number.substring(4, 8)} ${number.substring(8, 12)} ${number.substring(12, 16)}';
  }

  String _virtualExpiry(String createdAt) {
    final created = DateTime.tryParse(createdAt) ?? DateTime.now();
    final expiry = DateTime(created.year + 3, created.month);
    final mm = expiry.month.toString().padLeft(2, '0');
    final yy = (expiry.year % 100).toString().padLeft(2, '0');
    return '$mm/$yy';
  }

  Future<void> _showCardDetails(VirtualCard card) async {
    // Busca o QR oficial do servidor — não usar geração local (inválida em produção)
    final qrResult = await ApiService().getVirtualCardQr(card.id);
    if (!mounted) return;

    if (!qrResult.isSuccess) {
      FeedbackService.showError(
        context,
        message: qrResult.error ?? 'Não foi possível gerar o QR code. Tente novamente.',
      );
      return;
    }

    final qrData = qrResult.data!;
    final service = VirtualCardService();
    final remainingLimit =
        card.dailyLimit > 0 ? service.getRemainingDailyLimit(card) : null;
    final previewKey = GlobalKey();
    final virtualNumber = _virtualCardNumber(card.id);
    final expiry = _virtualExpiry(card.createdAt);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        bool isSharing = false;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  RepaintBoundary(
                    key: previewKey,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 410),
                      child: AspectRatio(
                        aspectRatio: 1.58,
                        child: Container(
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage('assets/images/card_fundo.jpg'),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withAlpha((0.9 * 255).round()),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withAlpha((0.24 * 255).round()),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.white
                                    .withAlpha((0.35 * 255).round()),
                                blurRadius: 6,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final scale =
                                  (constraints.maxWidth / 410).clamp(0.72, 1.0);
                              final contentPadding = 12.0 * scale;
                              final qrSize = 110.0 * scale;
                              final qrPadding = 4.0 * scale;

                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.black
                                          .withAlpha((0.28 * 255).round()),
                                      Colors.black
                                          .withAlpha((0.58 * 255).round()),
                                    ],
                                  ),
                                ),
                                padding: EdgeInsets.all(contentPadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/logo.png',
                                          height: 42 * scale,
                                          width: 42 * scale,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(width: 12 * scale),
                                        Expanded(
                                          child: Text(
                                            card.name.toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14 * scale,
                                              letterSpacing: 1.2 * scale,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.wifi_rounded,
                                          color: Colors.white
                                              .withAlpha((0.9 * 255).round()),
                                          size: 18 * scale,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8 * scale),
                                    Container(
                                      width: 44 * scale,
                                      height: 32 * scale,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.sm * scale),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE7C97A),
                                            Color(0xFFC39A45)
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(flex: 1),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FittedBox(
                                        alignment: Alignment.centerLeft,
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          virtualNumber,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22 * scale,
                                            letterSpacing: 1.8 * scale,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(flex: 1),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'TITULAR',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 9 * scale,
                                                  letterSpacing: 1.0 * scale,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 2 * scale),
                                              Text(
                                                widget.cardHolderName
                                                    .toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12 * scale,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: 4 * scale),
                                              Text(
                                                'Validade $expiry',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10 * scale,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 6 * scale),
                                        Container(
                                          padding: EdgeInsets.all(qrPadding),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8 * scale,
                                            ),
                                          ),
                                          child: qrData.startsWith('data:image')
                                              ? Image.memory(
                                                  base64Decode(qrData.split(',').last),
                                                  width: qrSize,
                                                  height: qrSize,
                                                  fit: BoxFit.contain,
                                                )
                                              : QrImageView(
                                                  data: qrData,
                                                  size: qrSize,
                                                  backgroundColor: Colors.white,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Saldo: ${card.balance} Kz',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    remainingLimit == null
                        ? 'Sem limite diário'
                        : 'Limite restante hoje: $remainingLimit Kz',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setSheetState(() => isSaving = true);
                                  await _downloadCard(previewKey, card);
                                  if (!mounted) return;
                                  setSheetState(() => isSaving = false);
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded),
                          label: const Text('Baixar cartão'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isSharing
                              ? null
                              : () async {
                                  setSheetState(() => isSharing = true);
                                  await _shareCard(previewKey, card);
                                  if (!mounted) return;
                                  setSheetState(() => isSharing = false);
                                },
                          icon: isSharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.share_rounded),
                          label: const Text('Partilhar cartão'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {
        widget.onClose();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Cartões Virtuais'),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              onPressed: () {
                widget.onClose();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close_rounded),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Meus cartões'),
              Tab(text: 'Criar novo'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(color: Color(0xFF1C1B1B)),
          child: SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCardsTab(theme),
                _buildCreateTab(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardsTab(ThemeData theme) {
    return CustomScrollView(
      key: ValueKey(widget.cards.length),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── One-time card display shown right after creation ──────────────
        if (_createdCard != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _VirtualCardDisplay(
                created: _createdCard!,
                onDismiss: () => setState(() => _createdCard = null),
              ),
            ),
          ),

        if (widget.cards.isEmpty && _createdCard == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.credit_card_off_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nenhum cartão criado',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Abra a aba "Criar novo" para emitir seu primeiro cartão virtual.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            key: ValueKey('cards_list_${widget.cards.length}'),
            itemCount: widget.cards.length,
            itemBuilder: (context, index) {
              final card = widget.cards[index];
              final isFrozen = card.isFrozen;
              final isBlocked = card.isBlocked;

              return Stack(
                children: [
                  InkWell(
                    onTap: () => _showCardDetails(card),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: isBlocked
                              ? Colors.red.withAlpha(120)
                              : isFrozen
                                  ? Colors.orange.withAlpha(100)
                                  : theme.colorScheme.outline
                                      .withAlpha((0.12 * 255).round()),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${card.balance} Kz',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isFrozen || isBlocked)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isBlocked
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(
                                isBlocked ? 'BLOQUEADO' : 'CONGELADO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: () => _confirmDelete(card),
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Apagar',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Semi-transparent red overlay when FROZEN / BLOCKED
                  if (isFrozen || isBlocked)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(isBlocked ? 55 : 30),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildCreateTab(ThemeData theme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const SizedBox(height: 8),
          const Text(
            'Criar Cartão Virtual',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Nome do cartão
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nome do cartão',
              hintText: 'Ex: Cartão Netflix',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Informe um nome para o cartão.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Saldo inicial
          TextFormField(
            controller: _balanceController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Saldo inicial',
              hintText: 'Valor em AOA',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              suffixText: 'Kz',
            ),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n <= 0) {
                return 'Saldo deve ser maior que 0.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Limite diário
          TextFormField(
            controller: _dailyLimitController,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Limite diário (opcional)',
              hintText: '0 = sem limite',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              prefixIcon: const Icon(Icons.speed_outlined),
              suffixText: 'Kz',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(v.trim());
              if (n == null || n < 0) return 'Limite inválido.';
              return null;
            },
          ),
          const SizedBox(height: 28),

          // PIN da conta (6 dígitos)
          TextFormField(
            controller: _userPinController,
            maxLength: 6,
            keyboardType: TextInputType.number,
            obscureText: true,
            obscuringCharacter: '●',
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'PIN da conta (6 dígitos)',
              hintText: '●●●●●●',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              prefixIcon: const Icon(Icons.lock_person_outlined),
              counterText: '',
            ),
            validator: (v) {
              final p = (v ?? '').trim();
              if (p.length != 6) {
                return 'PIN da conta deve ter 6 dígitos.';
              }
              if (int.tryParse(p) == null) {
                return 'Apenas dígitos numéricos.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // PIN do cartão (4 dígitos)
          TextFormField(
            controller: _cardPinController,
            maxLength: 4,
            keyboardType: TextInputType.number,
            obscureText: true,
            obscuringCharacter: '●',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _isCreating ? null : _submitCreate(),
            decoration: InputDecoration(
              labelText: 'PIN do cartão (4 dígitos)',
              hintText: '●●●●',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              prefixIcon: const Icon(Icons.credit_card_outlined),
              counterText: '',
            ),
            validator: (v) {
              final p = (v ?? '').trim();
              if (p.length != 4) {
                return 'PIN do cartão deve ter 4 dígitos.';
              }
              if (int.tryParse(p) == null) {
                return 'Apenas dígitos numéricos.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Info message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(25),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Guarda bem os teus PINs. O PIN do cartão não será mostrado novamente.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_createError.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _createError,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isCreating ? null : _submitCreate,
              icon: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_card_outlined),
              label: Text(_isCreating ? 'A criar...' : 'Criar cartão'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.06 * 255).round()),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── VirtualCardDisplay ──────────────────────────────────────────────────────

/// Shown ONCE immediately after card creation.
/// Displays PAN, CVV, expiry and the PIN reminder.
class _VirtualCardDisplay extends StatefulWidget {
  final VirtualCardCreated created;
  final VoidCallback onDismiss;

  const _VirtualCardDisplay({
    required this.created,
    required this.onDismiss,
  });

  @override
  State<_VirtualCardDisplay> createState() => _VirtualCardDisplayState();
}

class _VirtualCardDisplayState extends State<_VirtualCardDisplay> {
  bool _copied = false;

  String get _formattedNumber {
    final n = widget.created.cardNumber.replaceAll(' ', '');
    if (n.length != 16) return n;
    return '${n.substring(0, 4)} ${n.substring(4, 8)} ${n.substring(8, 12)} ${n.substring(12, 16)}';
  }

  Future<void> _copyNumber() async {
    await _ClipboardHelper.copy(_formattedNumber);
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.created;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card visual ──────────────────────────────────────────────────
        AspectRatio(
          aspectRatio: 1.586,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A237E),
                  Color(0xFF283593),
                  Color(0xFF1565C0)
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A237E).withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card name top
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 34,
                      width: 34,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.card.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.wifi_rounded,
                        color: Colors.white70, size: 20),
                  ],
                ),
                const SizedBox(height: 10),
                // Chip
                Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE7C97A), Color(0xFFC39A45)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                const Spacer(),
                // PAN
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formattedNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VALIDADE',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 9,
                                letterSpacing: 1)),
                        Text(c.expiryDate,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CVV',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 9,
                                letterSpacing: 1)),
                        Text(c.cvv,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Spacer(),
                    // "VISA"-style branding placeholder
                    const Text('VIRTUAL',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Copy button ──────────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: _copyNumber,
          icon: Icon(_copied ? Icons.check_circle_rounded : Icons.copy_rounded,
              size: 18),
          label: Text(_copied ? 'Copiado!' : 'Copiar número'),
        ),

        const SizedBox(height: 10),

        // ── PIN reminder ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.red.withAlpha(80)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_rounded, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Guarda o teu PIN do cartão. Não o mostramos novamente.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Dismiss button ────────────────────────────────────────────────
        TextButton(
          onPressed: widget.onDismiss,
          child: const Text('Dispensar'),
        ),
      ],
    );
  }
}

// Helper to copy to clipboard without importing services package
class _ClipboardHelper {
  static Future<void> copy(String text) async {
    final data = ClipboardData(text: text);
    await Clipboard.setData(data);
  }
}

Future<void> showVirtualCardsFullscreen(
  BuildContext context, {
  required List<VirtualCard> cards,
  required String cardHolderName,
  required Future<VirtualCardCreated> Function({
    required String name,
    required int initialBalance,
    required int dailyLimit,
    required String userPin,
    required String cardPin,
  }) onCreateCard,
  required Function(String cardId) onDeleteCard,
  required VoidCallback onClose,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VirtualCardsFullscreen(
        cards: cards,
        cardHolderName: cardHolderName,
        onCreateCard: onCreateCard,
        onDeleteCard: onDeleteCard,
        onClose: onClose,
      ),
    ),
  );
}
