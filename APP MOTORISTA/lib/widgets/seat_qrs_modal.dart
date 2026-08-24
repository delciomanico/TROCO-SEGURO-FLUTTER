import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/services/feedback_service.dart';

/// Modal completo de gestão dos QR Codes dos assentos individuais.
/// Permite visualizar, baixar e partilhar o QR de cada assento.
class SeatQrsModal extends StatefulWidget {
  final List<Map<String, dynamic>> childQrs;
  final int currentFare;
  final String driverName;

  const SeatQrsModal({
    super.key,
    required this.childQrs,
    required this.currentFare,
    required this.driverName,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> childQrs,
    required int currentFare,
    required String driverName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SeatQrsModal(
        childQrs: childQrs,
        currentFare: currentFare,
        driverName: driverName,
      ),
    );
  }

  @override
  State<SeatQrsModal> createState() => _SeatQrsModalState();
}

class _SeatQrsModalState extends State<SeatQrsModal> {
  final Map<int, bool> _savingIndex = {};
  bool _savingAll = false;

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  Uint8List? _decodeImage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final commaIndex = raw.indexOf(',');
      final b64 = commaIndex >= 0 ? raw.substring(commaIndex + 1) : raw;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  String _seatLabel(Map<String, dynamic> seat, int fallbackIndex) {
    final label = seat['label']?.toString();
    if (label != null && label.isNotEmpty) return label;
    return 'Assento ${fallbackIndex + 1}';
  }

  Future<File?> _writeTempFile(Uint8List bytes, String name) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Compõe o QR do assento com o número do assento desenhado na própria
  /// imagem — sem isto, o ficheiro partilhado/impresso é só o QR em bruto
  /// e o número só existe na legenda de texto do share, que muitos fluxos
  /// de impressão/gravação descartam (ver relato do cliente: folha
  /// impressa com QRs sem nenhum número visível).
  Future<Uint8List> _composeSeatQrImage(Uint8List qrBytes, String label) async {
    try {
      final controller = ScreenshotController();
      final composed = await controller.captureFromWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            width: 640,
            height: 760,
            color: Colors.white,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.memory(qrBytes, width: 560, height: 560, fit: BoxFit.contain),
                const SizedBox(height: 24),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        pixelRatio: 2.0,
        targetSize: const Size(640, 760),
      );
      return composed;
    } catch (_) {
      return qrBytes;
    }
  }

  Future<void> _shareOne(int index) async {
    setState(() => _savingIndex[index] = true);
    try {
      final seat = widget.childQrs[index];
      final bytes = _decodeImage(seat['image']?.toString());
      if (bytes == null) {
        _showError('Imagem do QR não disponível.');
        return;
      }
      final label = _seatLabel(seat, index);
      final composed = await _composeSeatQrImage(bytes, label);
      final safeName = label.toLowerCase().replaceAll(' ', '_');
      final file = await _writeTempFile(composed, 'qr_${safeName}_troco_seguro.png');
      if (file == null) {
        _showError('Não foi possível preparar o ficheiro.');
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$label — ${widget.driverName}\n'
            'Valor: ${_formatCurrency(widget.currentFare)} por assento\n'
            'Troco Seguro',
        subject: 'QR Code $label',
      );
    } finally {
      if (mounted) setState(() => _savingIndex.remove(index));
    }
  }

  Future<void> _shareAll() async {
    setState(() => _savingAll = true);
    try {
      final files = <XFile>[];
      for (int i = 0; i < widget.childQrs.length; i++) {
        final seat = widget.childQrs[i];
        final bytes = _decodeImage(seat['image']?.toString());
        if (bytes == null) continue;
        final label = _seatLabel(seat, i);
        final composed = await _composeSeatQrImage(bytes, label);
        final safeName = label.toLowerCase().replaceAll(' ', '_');
        final file = await _writeTempFile(composed, 'qr_${safeName}_troco_seguro.png');
        if (file != null) files.add(XFile(file.path));
      }
      if (files.isEmpty) {
        _showError('Nenhum QR disponível para partilhar.');
        return;
      }
      await Share.shareXFiles(
        files,
        text: 'QR Codes dos assentos — ${widget.driverName}\n'
            'Valor: ${_formatCurrency(widget.currentFare)} por assento\n'
            'Troco Seguro',
        subject: 'QR Codes dos Assentos',
      );
    } finally {
      if (mounted) setState(() => _savingAll = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    FeedbackService.showError(context, message: msg);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final subtleColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.45);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: responsive.scaledHeight(12)),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.scaledWidth(20),
              responsive.scaledHeight(16),
              responsive.scaledWidth(12),
              responsive.scaledHeight(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(10)),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.event_seat_rounded,
                    color: AppColors.accent,
                    size: responsive.scaledWidth(22),
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR dos Assentos',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(18),
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${widget.childQrs.length} assento${widget.childQrs.length != 1 ? 's' : ''} · ${_formatCurrency(widget.currentFare)} cada',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(12),
                          color: subtleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: subtleColor),
                ),
              ],
            ),
          ),

          // Info banner
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scaledWidth(20),
            ),
            child: Container(
              padding: EdgeInsets.all(responsive.responsivePadding()),
              decoration: BoxDecoration(
                color: AppColors.darkBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.darkBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.darkBlue,
                    size: responsive.scaledWidth(20),
                  ),
                  SizedBox(width: responsive.scaledWidth(10)),
                  Expanded(
                    child: Text(
                      'Cole cada QR no lugar correspondente. O passageiro escaneia o QR do seu assento para pagar.',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(12),
                        color: AppColors.darkBlue,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: responsive.scaledHeight(16)),

          // Seat list
          Expanded(
            child: widget.childQrs.isEmpty
                ? _buildEmpty(responsive, textColor, subtleColor)
                : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.scaledWidth(20),
                    ),
                    itemCount: widget.childQrs.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: responsive.scaledHeight(16)),
                    itemBuilder: (context, index) => _buildSeatCard(
                      context,
                      responsive,
                      isDark,
                      cardBg,
                      textColor,
                      subtleColor,
                      index,
                    ),
                  ),
          ),

          // Bottom action
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.scaledWidth(20),
                responsive.scaledHeight(12),
                responsive.scaledWidth(20),
                responsive.scaledHeight(16),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (_savingAll || widget.childQrs.isEmpty) ? null : _shareAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor:
                        isDark ? Colors.black : Colors.white,
                    disabledBackgroundColor:
                        AppColors.accent.withValues(alpha: 0.4),
                    padding: EdgeInsets.symmetric(
                        vertical: responsive.scaledHeight(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                  ),
                  icon: _savingAll
                      ? SizedBox(
                          width: responsive.scaledWidth(18),
                          height: responsive.scaledWidth(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        )
                      : Icon(Icons.share_rounded,
                          size: responsive.scaledWidth(20)),
                  label: Text(
                    _savingAll
                        ? 'A preparar...'
                        : 'PARTILHAR TODOS (${widget.childQrs.length})',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatCard(
    BuildContext context,
    ResponsiveHelper responsive,
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtleColor,
    int index,
  ) {
    final seat = widget.childQrs[index];
    final label = _seatLabel(seat, index);
    final imageBytes = _decodeImage(seat['image']?.toString());
    final isSaving = _savingIndex[index] == true;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Seat header
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.scaledWidth(16),
              responsive.scaledHeight(14),
              responsive.scaledWidth(16),
              responsive.scaledHeight(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scaledWidth(12),
                    vertical: responsive.scaledHeight(6),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_seat_rounded,
                        color: AppColors.accent,
                        size: responsive.scaledWidth(14),
                      ),
                      SizedBox(width: responsive.scaledWidth(6)),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatCurrency(widget.currentFare),
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(15),
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // QR image
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: responsive.scaledWidth(16),
              vertical: responsive.scaledHeight(8),
            ),
            padding: EdgeInsets.all(responsive.scaledWidth(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: imageBytes != null
                ? Image.memory(
                    imageBytes,
                    width: responsive.scaledWidth(180),
                    height: responsive.scaledWidth(180),
                    fit: BoxFit.contain,
                  )
                : SizedBox(
                    width: responsive.scaledWidth(180),
                    height: responsive.scaledWidth(180),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_rounded,
                            size: responsive.scaledWidth(64),
                            color: Colors.grey.shade300,
                          ),
                          SizedBox(height: responsive.scaledHeight(8)),
                          Text(
                            'QR não disponível',
                            style: TextStyle(
                              fontSize: responsive.responsiveFontSize(12),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Instruction chip
          Padding(
            padding: EdgeInsets.only(bottom: responsive.scaledHeight(8)),
            child: Text(
              'Mostre ou cole este QR no $label',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(11),
                color: subtleColor,
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.scaledWidth(16),
              0,
              responsive.scaledWidth(16),
              responsive.scaledHeight(16),
            ),
            child: Row(
              children: [
                // Share button
                Expanded(
                  child: _buildActionButton(
                    responsive: responsive,
                    isDark: isDark,
                    icon: Icons.share_rounded,
                    label: 'Partilhar',
                    isLoading: isSaving,
                    onTap: isSaving ? null : () => _shareOne(index),
                    isPrimary: true,
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(10)),
                // Screenshot/save button
                Expanded(
                  child: _buildScreenshotSaveButton(
                    responsive: responsive,
                    isDark: isDark,
                    imageBytes: imageBytes,
                    label: label,
                    index: index,
                    subtleColor: subtleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotSaveButton({
    required ResponsiveHelper responsive,
    required bool isDark,
    required Uint8List? imageBytes,
    required String label,
    required int index,
    required Color subtleColor,
  }) {
    return _buildActionButton(
      responsive: responsive,
      isDark: isDark,
      icon: Icons.download_rounded,
      label: 'Guardar',
      isLoading: false,
      onTap: imageBytes == null
          ? null
          : () async {
              setState(() => _savingIndex[index] = true);
              try {
                final composed = await _composeSeatQrImage(imageBytes, label);
                final safeName = label.toLowerCase().replaceAll(' ', '_');
                final file = await _writeTempFile(
                  composed,
                  'qr_${safeName}_troco_seguro.png',
                );
                if (file == null) {
                  _showError('Não foi possível guardar o ficheiro.');
                  return;
                }
                await Share.shareXFiles(
                  [XFile(file.path)],
                  text: '$label · ${widget.driverName} · Troco Seguro',
                  subject: 'QR Code $label',
                );
              } finally {
                if (mounted) setState(() => _savingIndex.remove(index));
              }
            },
      isPrimary: false,
    );
  }

  Widget _buildActionButton({
    required ResponsiveHelper responsive,
    required bool isDark,
    required IconData icon,
    required String label,
    required bool isLoading,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    final bg = isPrimary
        ? AppColors.accent
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05));
    final fg = isPrimary
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : AppColors.textDark);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: responsive.scaledHeight(12),
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: responsive.scaledWidth(16),
                    height: responsive.scaledWidth(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: fg, size: responsive.scaledWidth(16)),
                    SizedBox(width: responsive.scaledWidth(6)),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(13),
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmpty(
    ResponsiveHelper responsive,
    Color textColor,
    Color subtleColor,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_seat_outlined,
            size: responsive.scaledWidth(80),
            color: subtleColor.withValues(alpha: 0.4),
          ),
          SizedBox(height: responsive.scaledHeight(20)),
          Text(
            'Sem QR de assentos',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(18),
              fontWeight: FontWeight.w700,
              color: subtleColor,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          Text(
            'Configure uma sessão de QR primeiro.',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              color: subtleColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
