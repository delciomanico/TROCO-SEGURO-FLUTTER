import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';

/// Modal de avaliação pós-pagamento
class RatingModal extends StatefulWidget {
  final String tripId;
  final String driverName;
  final Future<bool> Function(String tripId, int rating, String? comment) onSubmitRating;

  const RatingModal({
    super.key,
    required this.tripId,
    required this.driverName,
    required this.onSubmitRating,
  });

  @override
  State<RatingModal> createState() => _RatingModalState();

  static Future<void> show(
    BuildContext context, {
    required String tripId,
    required String driverName,
    required Future<bool> Function(String tripId, int rating, String? comment) onSubmitRating,
  }) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => RatingModal(
        tripId: tripId,
        driverName: driverName,
        onSubmitRating: onSubmitRating,
      ),
    );
  }
}

class _RatingModalState extends State<RatingModal> {
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

    try {
      final success = await widget.onSubmitRating(
        widget.tripId,
        _selectedRating,
        _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
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
          const SnackBar(content: Text('Erro ao enviar avaliação. Tente novamente.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  void _skipRating() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withAlpha((0.08 * 255).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.07 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: responsive.responsivePadding(),
            right: responsive.responsivePadding(),
            top: responsive.responsivePadding(),
            bottom: MediaQuery.of(context).viewInsets.bottom + responsive.responsivePadding(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Icon(
                Icons.star_rounded,
                size: responsive.scaledWidth(64),
                color: AppColors.primaryGold,
              ),
              SizedBox(height: responsive.scaledHeight(16)),
              Text(
                'AVALIE SUA VIAGEM',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                'Como foi sua experiência com ${widget.driverName}?',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(13),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textDark.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.scaledHeight(32)),
              // Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: _isSubmitting ? null : () {
                      setState(() => _selectedRating = index + 1);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(4)),
                      child: Icon(
                        index < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: responsive.scaledWidth(48),
                        color: index < _selectedRating ? AppColors.primaryGold : Colors.grey,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              // Comment (optional)
              CustomInput(
                label: 'COMENTÁRIO (OPCIONAL)',
                placeholder: 'Conte-nos mais sobre sua experiência...',
                controller: _commentController,
                maxLines: 3,
                enabled: !_isSubmitting,
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'PULAR',
                      onPressed: _isSubmitting ? null : _skipRating,
                      isOutline: true,
                    ),
                  ),
                  SizedBox(width: responsive.responsiveSpacing()),
                  Expanded(
                    child: CustomButton(
                      text: _isSubmitting ? 'ENVIANDO...' : 'ENVIAR',
                      onPressed: _isSubmitting ? null : _submitRating,
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsive.scaledHeight(16)),
            ],
          ),
        ),
      ),
    );
  }
}
