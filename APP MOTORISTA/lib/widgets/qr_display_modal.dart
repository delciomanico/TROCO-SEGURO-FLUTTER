import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/widgets/custom_widgets.dart'
    show CustomButton;
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class QrDisplayModal extends StatefulWidget {
  final String qrData;
  final String? qrCodeImage;
  final int? amount;
  final String currency;
  final String driverName;
  final String? tripId;
  final String? routeName;
  final VoidCallback? onClose;
  final VoidCallback? onPaymentReceived;

  const QrDisplayModal({
    super.key,
    required this.qrData,
    this.qrCodeImage,
    this.amount,
    this.currency = 'AOA',
    required this.driverName,
    this.tripId,
    this.routeName,
    this.onClose,
    this.onPaymentReceived,
  });

  static Future<void> show(
    BuildContext context, {
    required String qrData,
    String? qrCodeImage,
    int? amount,
    String currency = 'AOA',
    required String driverName,
    String? tripId,
    String? routeName,
    VoidCallback? onClose,
    VoidCallback? onPaymentReceived,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QrDisplayModal(
        qrData: qrData,
        qrCodeImage: qrCodeImage,
        amount: amount,
        currency: currency,
        driverName: driverName,
        tripId: tripId,
        routeName: routeName,
        onClose: onClose,
        onPaymentReceived: onPaymentReceived,
      ),
    );
  }

  @override
  State<QrDisplayModal> createState() => _QrDisplayModalState();
}

class _QrDisplayModalState extends State<QrDisplayModal>
    with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isWaitingPayment = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    final suffix = widget.currency.toUpperCase() == 'AOA' ? 'Kz' : widget.currency;
    return '${format.format(amount)} $suffix';
  }

  Uint8List? _decodeQrImage() {
    final raw = widget.qrCodeImage;
    if (raw == null || raw.isEmpty) return null;

    try {
      final commaIndex = raw.indexOf(',');
      final base64Data = commaIndex >= 0 ? raw.substring(commaIndex + 1) : raw;
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareQrCode() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/qr_code_troco_seguro.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath)],
        text: widget.amount != null
            ? 'Pagamento de ${_formatCurrency(widget.amount!)} via Troco Seguro'
            : 'QR Code de pagamento - Troco Seguro',
      );
    } catch (e) {
      debugPrint('Erro ao compartilhar: $e');
    }
  }

  void _startWaitingPayment() {
    setState(() => _isWaitingPayment = true);
    // Simular recebimento após 5 segundos (em produção, seria via WebSocket)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isWaitingPayment) {
        setState(() => _isWaitingPayment = false);
        widget.onPaymentReceived?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final qrImageBytes = _decodeQrImage();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(responsive.responsivePadding()),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(responsive.scaledWidth(8)),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.qr_code_rounded,
                        color: AppColors.accent,
                        size: responsive.scaledWidth(20),
                      ),
                    ),
                    SizedBox(width: responsive.scaledWidth(12)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR Code de Pagamento',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(16),
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Mostre ao passageiro',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(12),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Route display (if specified)
          if (widget.routeName != null)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: responsive.responsivePadding(),
              ),
              padding: EdgeInsets.all(responsive.responsivePadding()),
              decoration: BoxDecoration(
                color: AppColors.darkBlue,
                borderRadius:
                    BorderRadius.circular(responsive.responsiveBorderRadius()),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(responsive.scaledWidth(10)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.route_rounded,
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
                          'Rota',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(10),
                            color: Colors.white60,
                          ),
                        ),
                        Text(
                          widget.routeName!,
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(14),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (widget.routeName != null)
            SizedBox(height: responsive.scaledHeight(12)),

          // Amount display (if specified)
          if (widget.amount != null)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: responsive.responsivePadding(),
              ),
              padding: EdgeInsets.all(responsive.responsivePadding()),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF6B415), Color(0xFFF9C846)],
                ),
                borderRadius:
                    BorderRadius.circular(responsive.responsiveBorderRadius()),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: responsive.scaledWidth(24),
                  ),
                  SizedBox(width: responsive.scaledWidth(12)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor a receber',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(11),
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _formatCurrency(widget.amount!),
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(28),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          SizedBox(height: responsive.scaledHeight(24)),

          // QR Code
          Screenshot(
            controller: _screenshotController,
            child: Container(
              padding: EdgeInsets.all(responsive.responsivePadding()),
              margin: EdgeInsets.symmetric(
                horizontal: responsive.responsivePadding(),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(responsive.responsiveBorderRadius()),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.accent.withOpacity(0.3),
                              width: 3,
                            ),
                          ),
                          child: qrImageBytes != null
                              ? Image.memory(
                                  qrImageBytes,
                                  width: responsive.scaledWidth(200),
                                  height: responsive.scaledWidth(200),
                                  fit: BoxFit.contain,
                                )
                              : QrImageView(
                                  data: widget.qrData,
                                  version: QrVersions.auto,
                                  size: responsive.scaledWidth(200),
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: AppColors.darkBlue,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: AppColors.darkBlue,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: responsive.scaledHeight(16)),
                  Text(
                    widget.driverName,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (widget.tripId != null)
                    Text(
                      'ID: ${widget.tripId}',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(10),
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: responsive.scaledHeight(24)),

          // Status indicator
          if (_isWaitingPayment)
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: responsive.responsivePadding(),
              ),
              padding: EdgeInsets.all(responsive.responsivePadding()),
              decoration: BoxDecoration(
                color: AppColors.statusPending.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(responsive.responsiveBorderRadius()),
                border: Border.all(
                  color: AppColors.statusPending.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.statusPending,
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(12)),
                  Text(
                    'Aguardando pagamento...',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusPending,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: responsive.scaledHeight(16)),

          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.responsivePadding(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomButton(
                    label: 'COMPARTILHAR',
                    icon: Icons.share_rounded,
                    isOutlined: true,
                    onPressed: _shareQrCode,
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: CustomButton(
                    label: _isWaitingPayment ? 'AGUARDANDO...' : 'CONFIRMAR',
                    icon: _isWaitingPayment
                        ? Icons.hourglass_empty_rounded
                        : Icons.check_circle_outline,
                    isLoading: _isWaitingPayment,
                    onPressed: _isWaitingPayment ? null : _startWaitingPayment,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: responsive.scaledHeight(16)),

          // Instructions
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: responsive.responsivePadding(),
            ),
            padding: EdgeInsets.all(responsive.responsivePadding()),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius:
                  BorderRadius.circular(responsive.responsiveBorderRadius()),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: responsive.scaledWidth(20),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: Text(
                    'O passageiro deve escanear este código no app Troco Seguro para realizar o pagamento.',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(12),
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: responsive.scaledHeight(32)),
        ],
      ),
    );
  }
}
