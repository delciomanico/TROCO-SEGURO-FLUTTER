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
  final Future<bool> Function(int amount)? onUpdateAmount;

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
    this.onUpdateAmount,
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
    Future<bool> Function(int amount)? onUpdateAmount,
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
        onUpdateAmount: onUpdateAmount,
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
  bool _isEditingAmount = false;
  late TextEditingController _amountController;
  late int _currentAmount;
  bool _isUpdatingAmount = false;

  @override
  void initState() {
    super.initState();
    _currentAmount = widget.amount ?? 0;
    _amountController = TextEditingController(text: _currentAmount.toString());
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
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateAmount() async {
    final newAmount = int.tryParse(_amountController.text) ?? 0;
    if (newAmount <= 0) return;

    if (widget.onUpdateAmount != null) {
      setState(() => _isUpdatingAmount = true);
      final success = await widget.onUpdateAmount!(newAmount);
      if (mounted) {
        setState(() {
          _isUpdatingAmount = false;
          if (success) {
            _currentAmount = newAmount;
            _isEditingAmount = false;
          }
        });
      }
    } else {
      setState(() {
        _currentAmount = newAmount;
        _isEditingAmount = false;
      });
    }
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

  // Método de simulação removido conforme solicitado

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final qrImageBytes = _decodeQrImage();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
                          'QR Code (Configurável)',
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

          // Amount display
          if (true) // Always show to allow editing
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: responsive.responsivePadding(),
              ),
              padding: EdgeInsets.all(responsive.responsivePadding()),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isEditingAmount
                      ? [AppColors.darkBlue, AppColors.darkBlue.withOpacity(0.8)]
                      : [const Color(0xFFF6B415), const Color(0xFFF9C846)],
                ),
                borderRadius:
                    BorderRadius.circular(responsive.responsiveBorderRadius()),
              ),
              child: _isEditingAmount
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(color: Colors.white70),
                              suffixText: 'Kz',
                              suffixStyle: TextStyle(color: Colors.white),
                              border: InputBorder.none,
                            ),
                            autofocus: true,
                          ),
                        ),
                        if (_isUpdatingAmount)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.white),
                            onPressed: _handleUpdateAmount,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () =>
                                setState(() => _isEditingAmount = false),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          color: Colors.white,
                          size: responsive.scaledWidth(24),
                        ),
                        SizedBox(width: responsive.scaledWidth(12)),
                        Expanded(
                          child: Column(
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
                                _currentAmount > 0
                                    ? _formatCurrency(_currentAmount)
                                    : 'Definir Valor',
                                style: TextStyle(
                                  fontSize: responsive.responsiveFontSize(
                                      _currentAmount > 0 ? 28 : 20),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded,
                              color: Colors.white),
                          onPressed: () =>
                              setState(() => _isEditingAmount = true),
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
          // Indicador de status removido

          SizedBox(height: responsive.scaledHeight(16)),

          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.responsivePadding(),
            ),
            child: CustomButton(
              label: 'COMPARTILHAR QR CODE',
              icon: Icons.share_rounded,
              isOutlined: false,
              onPressed: _shareQrCode,
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
        ),
      ),
    );
  }
}
