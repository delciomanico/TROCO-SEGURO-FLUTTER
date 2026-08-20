import 'package:flutter/material.dart';
import 'package:troco_seguro/models/complaint.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/utils/constants.dart';

enum _ComplaintView { list, create, detail }

class ComplaintModal extends StatefulWidget {
  final String? transactionId;
  final String? tripId;

  const ComplaintModal({super.key, this.transactionId, this.tripId});

  static Future<void> show(
    BuildContext context, {
    String? transactionId,
    String? tripId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplaintModal(
        transactionId: transactionId,
        tripId: tripId,
      ),
    );
  }

  @override
  State<ComplaintModal> createState() => _ComplaintModalState();
}

class _ComplaintModalState extends State<ComplaintModal> {
  static const _categories = [
    ('TRANSACTION', 'Transação'),
    ('TRIP', 'Viagem'),
    ('OTHER', 'Outro'),
  ];

  _ComplaintView _view = _ComplaintView.list;

  // list state
  List<Complaint> _complaints = [];
  bool _loadingList = false;

  // detail state
  Complaint? _selected;

  // create state
  String _category = 'TRANSACTION';
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // If opened from a specific context (transaction/trip), go straight to create
    if (widget.transactionId != null || widget.tripId != null) {
      _prepareCreate();
      _view = _ComplaintView.create;
    } else {
      _loadComplaints();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  void _prepareCreate() {
    _category = widget.transactionId != null ? 'TRANSACTION' : 'TRIP';
    _refCtrl.text = widget.transactionId ?? widget.tripId ?? '';
    _descCtrl.clear();
  }

  Future<void> _loadComplaints() async {
    setState(() => _loadingList = true);
    final result = await ApiService().getComplaints();
    if (!mounted) return;
    if (result.isSuccess) {
      final sorted = List<Complaint>.from(result.data ?? [])
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _complaints = sorted;
        _loadingList = false;
      });
    } else {
      setState(() => _loadingList = false);
      if (mounted) {
        FeedbackService.showError(context,
            message: result.error ?? 'Erro ao carregar reclamações');
      }
    }
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.length < 20) {
      FeedbackService.showError(context,
          message: 'Descrição deve ter pelo menos 20 caracteres');
      return;
    }

    final ref = _refCtrl.text.trim();
    // O backend exige transactionId/tripId para estas duas categorias
    // (só "Outro" aceita reclamação sem referência) — validar aqui evita
    // que o motorista escreva a descrição toda e só depois leve com um
    // erro 400 genérico do servidor.
    if (_category == 'TRANSACTION' && ref.isEmpty) {
      FeedbackService.showError(context,
          message: 'Indique o ID da transação — obrigatório para esta categoria.');
      return;
    }
    if (_category == 'TRIP' && ref.isEmpty) {
      FeedbackService.showError(context,
          message: 'Indique o ID da viagem — obrigatório para esta categoria.');
      return;
    }

    setState(() => _busy = true);

    final result = await ApiService().createComplaint(
      category: _category,
      reasonCode: _category.toLowerCase(),
      description: desc,
      transactionId:
          _category == 'TRANSACTION' && ref.isNotEmpty ? ref : null,
      tripId: _category == 'TRIP' && ref.isNotEmpty ? ref : null,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isSuccess) {
      FeedbackService.showSuccess(context,
          message: 'Reclamação submetida com sucesso');
      // reload list and go back to it
      await _loadComplaints();
      if (mounted) setState(() => _view = _ComplaintView.list);
    } else {
      FeedbackService.showError(context,
          message: result.error ?? 'Erro ao submeter reclamação');
    }
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  Color _categoryColor(String category, bool isDark) {
    switch (category.toUpperCase()) {
      case 'TRANSACTION':
        return isDark
            ? Colors.blue.shade300
            : Colors.blue.shade700;
      case 'TRIP':
        return isDark
            ? Colors.purple.shade300
            : Colors.purple.shade700;
      default:
        return isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600;
    }
  }

  Color _statusColor(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'in-progress':
      case 'in_progress':
        return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
      case 'resolved':
      case 'closed':
        return isDark ? Colors.green.shade300 : Colors.green.shade700;
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: switch (_view) {
          _ComplaintView.list => _buildList(isDark, cardColor),
          _ComplaintView.create => _buildCreate(isDark),
          _ComplaintView.detail => _buildDetail(isDark),
        },
      ),
    );
  }

  // ─── view: lista ──────────────────────────────────────────────────────────

  Widget _buildList(bool isDark, Color cardColor) {
    final onSurface = isDark ? Colors.white : AppColors.textDark;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dragHandle(isDark),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Reclamações',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: onSurface),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _category = 'TRANSACTION';
                _refCtrl.clear();
                _descCtrl.clear();
                setState(() => _view = _ComplaintView.create);
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Nova'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentOf(context),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Histórico das suas reclamações',
          style: TextStyle(fontSize: 12, color: subtle),
        ),
        const SizedBox(height: 16),
        if (_loadingList)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.accentOf(context), strokeWidth: 2)),
          )
        else if (_complaints.isEmpty)
          _emptyState(isDark)
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _complaints.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              itemBuilder: (_, i) => _complaintTile(_complaints[i], isDark),
            ),
          ),
      ],
    );
  }

  Widget _complaintTile(Complaint c, bool isDark) {
    final onSurface = isDark ? Colors.white : AppColors.textDark;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);
    final catColor = _categoryColor(c.category, isDark);

    return InkWell(
      onTap: () => setState(() {
        _selected = c;
        _view = _ComplaintView.detail;
      }),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.reasonCode.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(
                        RegExp(r'^\w'),
                        (m) => m.group(0)!.toUpperCase()),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.description.length > 60
                        ? '${c.description.substring(0, 60)}...'
                        : c.description,
                    style: TextStyle(fontSize: 12, color: subtle),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.formattedDate,
                    style: TextStyle(fontSize: 11, color: subtle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text(
                    c.categoryLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: catColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(c.status, isDark)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: subtle),
            const SizedBox(height: 12),
            Text(
              'Nenhuma reclamação encontrada',
              style: TextStyle(fontSize: 14, color: subtle),
            ),
          ],
        ),
      ),
    );
  }

  // ─── view: detalhe ────────────────────────────────────────────────────────

  Widget _buildDetail(bool isDark) {
    final c = _selected!;
    final onSurface = isDark ? Colors.white : AppColors.textDark;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);
    final catColor = _categoryColor(c.category, isDark);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dragHandle(isDark),
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _view = _ComplaintView.list),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: onSurface),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Detalhe da Reclamação',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: onSurface),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  c.categoryLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: catColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow('Motivo',
              c.reasonCode.replaceAll('_', ' '), isDark),
          _detailRow('Data', c.formattedDate, isDark),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text('Estado',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.45))),
                ),
                Expanded(
                  child: Text(c.statusLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(c.status, isDark))),
                ),
              ],
            ),
          ),
          if (c.status.toLowerCase() != 'open')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentOf(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.accentOf(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A equipa de suporte já viu esta reclamação. A resposta '
                        'detalhada é enviada por outro canal — esta app ainda '
                        'não mostra o texto exacto da resposta.',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.55)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (c.transactionId != null && c.transactionId!.isNotEmpty)
            _detailRow('ID Transação', c.transactionId!, isDark),
          if (c.tripId != null && c.tripId!.isNotEmpty)
            _detailRow('ID Viagem', c.tripId!, isDark),
          const SizedBox(height: 16),
          Text('Descrição',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onSurface)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1)),
            ),
            child: Text(c.description,
                style: TextStyle(fontSize: 13, color: subtle)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    final onSurface = isDark ? Colors.white : AppColors.textDark;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtle)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: onSurface)),
          ),
        ],
      ),
    );
  }

  // ─── view: criar ──────────────────────────────────────────────────────────

  Widget _buildCreate(bool isDark) {
    final onSurface = isDark ? Colors.white : AppColors.textDark;
    final subtle = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.15);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dragHandle(isDark),
          const SizedBox(height: 20),
          Row(
            children: [
              // Back arrow only when there's no context (can go back to list)
              if (widget.transactionId == null && widget.tripId == null) ...[
                GestureDetector(
                  onTap: () => setState(() => _view = _ComplaintView.list),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: onSurface),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  'Submeter Reclamação',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Descreva o problema com o maior detalhe possível',
            style: TextStyle(fontSize: 12, color: subtle),
          ),
          const SizedBox(height: 20),
          Text('Categoria',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onSurface)),
          const SizedBox(height: 8),
          Row(
            children: _categories.map((c) {
              final selected = _category == c.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _category = c.$1;
                    _refCtrl.clear();
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentOf(context).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color:
                            selected ? AppColors.accentOf(context) : borderColor,
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      c.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color:
                            selected ? AppColors.accentOf(context) : subtle,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_category != 'OTHER') ...[
            TextField(
              controller: _refCtrl,
              decoration: InputDecoration(
                labelText: _category == 'TRANSACTION'
                    ? 'ID da transação'
                    : 'ID da viagem',
                prefixIcon: const Icon(Icons.tag_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: AppColors.accentOf(context), width: 1.5),
                ),
                filled: true,
                fillColor: fillColor,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _descCtrl,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Descrição (min. 20 caracteres)',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 52),
                child: Icon(Icons.description_outlined),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                    color: AppColors.accentOf(context), width: 1.5),
              ),
              filled: true,
              fillColor: fillColor,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                elevation: 0,
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Submeter Reclamação',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── shared ───────────────────────────────────────────────────────────────

  Widget _dragHandle(bool isDark) {
    return Center(
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
    );
  }
}
