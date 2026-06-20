import 'package:flutter/material.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/utils/constants.dart';

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
    ('TRANSACTION', 'Transacao'),
    ('TRIP', 'Viagem'),
    ('OTHER', 'Outro'),
  ];

  String _category = 'TRANSACTION';
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null) {
      _category = 'TRANSACTION';
      _refCtrl.text = widget.transactionId!;
    } else if (widget.tripId != null) {
      _category = 'TRIP';
      _refCtrl.text = widget.tripId!;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.length < 20) {
      FeedbackService.showError(context, message: 'Descrição deve ter pelo menos 20 caracteres');
      return;
    }

    setState(() => _busy = true);

    final ref = _refCtrl.text.trim();
    final result = await ApiService().createComplaint(
      category: _category,
      reasonCode: _category.toLowerCase(),
      description: desc,
      transactionId: _category == 'TRANSACTION' && ref.isNotEmpty ? ref : null,
      tripId: _category == 'TRIP' && ref.isNotEmpty ? ref : null,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isSuccess) {
      Navigator.pop(context);
      FeedbackService.showSuccess(context, message: 'Reclamacao submetida com sucesso');
    } else {
      FeedbackService.showError(context, message: result.error ?? 'Erro ao submeter reclamacao');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final onSurface = isDark ? Colors.white : AppColors.textDark;
    final subtle = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.45);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Submeter Reclamacao',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Descreva o problema com o maior detalhe possivel',
                style: TextStyle(fontSize: 12, color: subtle),
              ),
              const SizedBox(height: 20),
              Text('Categoria', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
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
                              ? AppColors.primaryGold.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? AppColors.primaryGold : borderColor,
                            width: selected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          c.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppColors.primaryGold : subtle,
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
                    labelText: _category == 'TRANSACTION' ? 'ID da transacao (opcional)' : 'ID da viagem (opcional)',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
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
                  labelText: 'Descricao (min. 20 caracteres)',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 52),
                    child: Icon(Icons.description_outlined),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Submeter Reclamacao', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
