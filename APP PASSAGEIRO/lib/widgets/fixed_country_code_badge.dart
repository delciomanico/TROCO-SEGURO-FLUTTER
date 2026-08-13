import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/constants.dart';

/// Indicativo do país fixo (+244, Angola) mostrado ao lado de um campo de
/// telefone. Todos os números nesta app são angolanos (9 dígitos depois
/// do indicativo), por isso não há selector de país — o utilizador só
/// introduz os 9 dígitos.
class FixedCountryCodeBadge extends StatelessWidget {
  final bool isDark;

  const FixedCountryCodeBadge({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇦🇴', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            '+244',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
