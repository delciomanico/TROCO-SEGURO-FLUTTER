import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:troco_seguro_pro/models/qr_config.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:intl/intl.dart';

class QrConfigModal extends StatefulWidget {
  final QrConfig currentConfig;
  final Future<String?> Function(QrConfig) onConfigSaved;

  const QrConfigModal({
    super.key,
    required this.currentConfig,
    required this.onConfigSaved,
  });

  static Future<QrConfig?> show(
    BuildContext context, {
    required QrConfig currentConfig,
    required Future<String?> Function(QrConfig) onConfigSaved,
  }) {
    return showModalBottomSheet<QrConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QrConfigModal(
        currentConfig: currentConfig,
        onConfigSaved: onConfigSaved,
      ),
    );
  }

  @override
  State<QrConfigModal> createState() => _QrConfigModalState();
}

class _QrConfigModalState extends State<QrConfigModal> {
  late TextEditingController _fareController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fareController = TextEditingController(
      text: widget.currentConfig.currentFare > 0
          ? widget.currentConfig.currentFare.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _fareController.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  Future<void> _saveConfig() async {
    final fare = int.tryParse(_fareController.text) ?? 0;
    if (fare <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Defina um valor maior que 0 Kz.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final newConfig = widget.currentConfig.copyWith(
      currentFare: fare,
      lastUpdate: DateTime.now(),
    );

    final error = await widget.onConfigSaved(newConfig);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.pop(context, newConfig);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;
    final textSecondaryColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.textSecondary;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.cardBorder;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: responsive.scaledHeight(12)),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(responsive.responsivePadding()),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(10)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent,
                        AppColors.accent.withValues(alpha: 0.7)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: responsive.scaledWidth(22),
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configurar QR Code',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(18),
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Defina o valor da corrida',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(12),
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          Divider(color: borderColor, height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(responsive.responsivePadding()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fare input
                  Text(
                    'VALOR DA CORRIDA',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(11),
                      fontWeight: FontWeight.w700,
                      color: textSecondaryColor,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(8)),
                  TextField(
                    controller: _fareController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(24),
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentOf(context),
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'Kz',
                      suffixStyle: TextStyle(
                        fontSize: responsive.responsiveFontSize(16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentOf(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide:
                            BorderSide(color: AppColors.accent, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: responsive.scaledWidth(16),
                        vertical: responsive.scaledHeight(16),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  // Quick fare buttons
                  SizedBox(height: responsive.scaledHeight(16)),
                  Text(
                    'VALORES RÁPIDOS',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(11),
                      fontWeight: FontWeight.w700,
                      color: textSecondaryColor,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(8)),
                  Wrap(
                    spacing: responsive.scaledWidth(8),
                    runSpacing: responsive.scaledHeight(8),
                    children: [
                      1000,
                      1500,
                      2000,
                      2500,
                      3000,
                      3500,
                      4000,
                      5000
                    ]
                        .map((value) =>
                            _buildQuickFareButton(responsive, value))
                        .toList(),
                  ),

                  SizedBox(height: responsive.scaledHeight(32)),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.7),
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_outline_rounded,
                                    size: responsive.scaledWidth(20)),
                                SizedBox(width: responsive.scaledWidth(8)),
                                Text(
                                  'INICIAR SESSÃO',
                                  style: TextStyle(
                                    fontSize: responsive.responsiveFontSize(14),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: responsive.scaledHeight(16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFareButton(ResponsiveHelper responsive, int value) {
    final isSelected = _fareController.text == value.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.cardBorder;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;
    return GestureDetector(
      onTap: () {
        _fareController.text = value.toString();
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(16),
          vertical: responsive.scaledHeight(10),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.accent : borderColor,
          ),
        ),
        child: Text(
          _formatCurrency(value),
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(12),
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}
