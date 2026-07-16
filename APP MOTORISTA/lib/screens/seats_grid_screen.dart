import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';

/// Grelha de lugares da sessão activa — mostra quais assentos já foram
/// pagos e quais continuam disponíveis, com a mesma disposição física do
/// veículo (frente/trás).
class SeatsGridScreen extends StatelessWidget {
  final List<SeatStatus> seats;

  const SeatsGridScreen({super.key, required this.seats});

  static Route<void> route(List<SeatStatus> seats) {
    return MaterialPageRoute(builder: (_) => SeatsGridScreen(seats: seats));
  }

  String _seatNumber(String label, int index) {
    final match = RegExp(r'(\d+)').firstMatch(label);
    return match != null ? int.parse(match.group(1)!).toString() : '${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = AppColors.primaryGold;
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final subtleText = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Assentos',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: responsive.responsiveFontSize(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsive.responsivePadding()),
        child: Column(
          children: [
            Text(
              'Selecione o assento para pagar',
              style: TextStyle(
                color: subtleText,
                fontSize: responsive.responsiveFontSize(13),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendSwatch(
                    label: 'Pago',
                    color: accent,
                    filled: true,
                    textColor: accent,
                    responsive: responsive),
                SizedBox(width: responsive.scaledWidth(24)),
                _legendSwatch(
                    label: 'Disponível',
                    color: isDark ? Colors.white24 : Colors.black26,
                    filled: false,
                    textColor: textColor,
                    responsive: responsive),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: responsive.scaledWidth(16),
                vertical: responsive.scaledHeight(20),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Icon(Icons.keyboard_arrow_up_rounded, color: accent),
                  Text(
                    'Frente do veículo',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: responsive.responsiveFontSize(13),
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(20)),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: seats.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: responsive.scaledWidth(16),
                      mainAxisSpacing: responsive.scaledHeight(16),
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final seat = seats[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: seat.paid
                              ? accent
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                          border: seat.paid
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.12),
                                ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _seatNumber(seat.label, index),
                          style: TextStyle(
                            color: seat.paid
                                ? Colors.black.withValues(alpha: 0.85)
                                : textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: responsive.responsiveFontSize(16),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: responsive.scaledHeight(20)),
                  Text(
                    'Traseira do veículo',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: responsive.responsiveFontSize(13),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                ],
              ),
            ),
            SizedBox(height: responsive.scaledHeight(20)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(responsive.responsivePadding()),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _legendInfo(
                      icon: Icons.person_rounded,
                      iconColor: accent,
                      title: 'Pago',
                      titleColor: accent,
                      description: 'Assentos já pagos e reservados.',
                      subtleText: subtleText,
                      responsive: responsive,
                    ),
                  ),
                  Expanded(
                    child: _legendInfo(
                      icon: Icons.person_rounded,
                      iconColor: isDark ? Colors.white38 : Colors.black38,
                      title: 'Disponível',
                      titleColor: textColor,
                      description: 'Assentos disponíveis para pagamento.',
                      subtleText: subtleText,
                      responsive: responsive,
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

  Widget _legendSwatch({
    required String label,
    required Color color,
    required bool filled,
    required Color textColor,
    required ResponsiveHelper responsive,
  }) {
    return Row(
      children: [
        Container(
          width: responsive.scaledWidth(20),
          height: responsive.scaledWidth(20),
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: filled ? null : Border.all(color: color, width: 1.5),
          ),
        ),
        SizedBox(width: responsive.scaledWidth(8)),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: responsive.responsiveFontSize(13),
          ),
        ),
      ],
    );
  }

  Widget _legendInfo({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String description,
    required Color subtleText,
    required ResponsiveHelper responsive,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: responsive.scaledWidth(22)),
        SizedBox(width: responsive.scaledWidth(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: responsive.responsiveFontSize(13),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(2)),
              Text(
                description,
                style: TextStyle(
                  color: subtleText,
                  fontSize: responsive.responsiveFontSize(11),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
