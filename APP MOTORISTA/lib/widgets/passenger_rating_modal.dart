import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/widgets/custom_widgets.dart';

/// Modal de avaliação do passageiro, mostrado ao motorista após um pagamento
/// concluído com sucesso (Fluxo 2).
class PassengerRatingModal extends StatefulWidget {
  final String tripId;
  final String passengerName;
  final Future<bool> Function(String tripId, int stars, String? comment)
      onSubmitRating;

  const PassengerRatingModal({
    super.key,
    required this.tripId,
    required this.passengerName,
    required this.onSubmitRating,
  });

  @override
  State<PassengerRatingModal> createState() => _PassengerRatingModalState();

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required String passengerName,
    required Future<bool> Function(String tripId, int stars, String? comment)
        onSubmitRating,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PassengerRatingModal(
        tripId: tripId,
        passengerName: passengerName,
        onSubmitRating: onSubmitRating,
      ),
    );
  }
}

class _PassengerRatingModalState extends State<PassengerRatingModal> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma avaliação')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await widget.onSubmitRating(
      widget.tripId,
      _selectedRating,
      _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação enviada com sucesso!')),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao enviar avaliação. Tente novamente.')),
      );
    }
  }

  void _skipRating() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentOf(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Icon(Icons.star_rounded, size: responsive.scaledWidth(64), color: accent),
              SizedBox(height: responsive.scaledHeight(16)),
              Text(
                'AVALIE O PASSAGEIRO',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                'Como foi a viagem com ${widget.passengerName}?',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(13),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textDark.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.scaledHeight(32)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _selectedRating = index + 1),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: responsive.scaledWidth(4)),
                      child: Icon(
                        index < _selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: responsive.scaledWidth(48),
                        color: index < _selectedRating ? accent : Colors.grey,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'COMENTÁRIO (OPCIONAL)',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(13),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Conte-nos mais sobre a viagem...',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.03),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      label: 'PULAR',
                      onPressed: _isSubmitting ? null : _skipRating,
                      isOutlined: true,
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(12)),
                  Expanded(
                    child: CustomButton(
                      label: _isSubmitting ? 'ENVIANDO...' : 'ENVIAR',
                      onPressed: _isSubmitting ? null : _submitRating,
                      isLoading: _isSubmitting,
                    ),
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
