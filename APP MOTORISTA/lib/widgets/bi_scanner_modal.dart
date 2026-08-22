import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/widgets/custom_widgets.dart'
    show CustomInput, CustomButton;

/// Modal para escanear o QR code do verso do Bilhete de Identidade angolano,
/// usado para verificar automaticamente a identidade do motorista.
class BiScannerModal extends StatefulWidget {
  final Function(String qrData) onScanned;
  final VoidCallback onCancel;

  const BiScannerModal({
    super.key,
    required this.onScanned,
    required this.onCancel,
  });

  @override
  State<BiScannerModal> createState() => _BiScannerModalState();
}

class _BiScannerModalState extends State<BiScannerModal> {
  late MobileScannerController scannerController;
  final TextEditingController manualController = TextEditingController();
  String? error;
  String? scanHint;
  bool showManualInput = false;
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    try {
      scannerController.dispose();
    } catch (e) {
      // Camera might be already disposed
    }
    manualController.dispose();
    super.dispose();
  }

  void _processManual() {
    final qrData = manualController.text.trim();
    if (qrData.isEmpty) {
      setState(() => error = 'Cole o texto do QR do BI');
      return;
    }
    widget.onScanned(qrData);
  }

  void _handleBarcodeDetect(BarcodeCapture barcodes) {
    if (!isScanning || barcodes.barcodes.isEmpty) return;

    final barcode = barcodes.barcodes.first;
    var qrData = barcode.rawValue;

    // O QR no verso de alguns BI codifica dados binários (não texto) — o
    // MLKit não preenche rawValue nesse caso, e o scanner ficava a "ler"
    // indefinidamente sem nunca disparar onScanned. Como último recurso,
    // enviamos os bytes em bruto (base64) e deixamos o backend validar.
    if (qrData == null || qrData.isEmpty) {
      final bytes = switch (barcode.rawDecodedBytes) {
        DecodedBarcodeBytes(:final bytes) => bytes,
        DecodedVisionBarcodeBytes(:final bytes, :final rawBytes) =>
          bytes ?? rawBytes,
        null => null,
      };
      if (bytes != null && bytes.isNotEmpty) {
        qrData = base64Encode(bytes);
      }
    }

    if (qrData != null && qrData.isNotEmpty) {
      setState(() => isScanning = false);
      widget.onScanned(qrData);
    } else if (scanHint == null) {
      // Barcode detectado mas sem qualquer dado extraível — avisar em vez
      // de deixar o utilizador a apontar a câmera sem nenhum feedback.
      setState(() => scanHint =
          'QR detectado mas ilegível. Aproxime mais e mantenha o BI estável e bem iluminado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      height: screenHeight * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(responsive.responsivePadding()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
                Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(12)),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    size: responsive.scaledWidth(32),
                    color: AppColors.accent,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(12)),
                Text(
                  'VERIFICAR IDENTIDADE',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(16),
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(8)),
                Text(
                  'Aponte a câmera para o QR code no verso do seu Bilhete de Identidade',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (!showManualInput)
            Expanded(child: _buildScannerSection(responsive))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(responsive.responsivePadding()),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Container(
                        margin:
                            EdgeInsets.only(bottom: responsive.scaledHeight(12)),
                        padding: EdgeInsets.all(responsive.responsiveSpacing()),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: responsive.responsiveFontSize(12),
                          ),
                        ),
                      ),
                    CustomInput(
                      label: '',
                      hint: 'Cole o texto lido do QR do BI',
                      controller: manualController,
                      onChanged: (val) {
                        if (error != null) setState(() => error = null);
                      },
                    ),
                    SizedBox(height: responsive.scaledHeight(24)),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            label: 'VOLTAR',
                            onPressed: () =>
                                setState(() => showManualInput = false),
                            isOutlined: true,
                          ),
                        ),
                        SizedBox(width: responsive.responsiveSpacing()),
                        Expanded(
                          child: CustomButton(
                            label: 'CONFIRMAR',
                            onPressed: _processManual,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerSection(ResponsiveHelper responsive) {
    return Stack(
      children: [
        MobileScanner(
          controller: scannerController,
          onDetect: _handleBarcodeDetect,
          errorBuilder: (context, error) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(responsive.responsivePadding()),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red, size: responsive.scaledWidth(48)),
                    SizedBox(height: responsive.scaledHeight(16)),
                    Text(
                      'Erro ao acessar câmera',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Center(
          child: Container(
            width: responsive.scaledWidth(280),
            height: responsive.scaledHeight(180),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 3),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        if (scanHint != null)
          Positioned(
            top: responsive.scaledHeight(16),
            left: responsive.scaledWidth(16),
            right: responsive.scaledWidth(16),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.responsiveSpacing(),
                vertical: responsive.scaledHeight(10),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                scanHint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: responsive.responsiveFontSize(12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: responsive.scaledHeight(16),
          left: responsive.scaledWidth(16),
          right: responsive.scaledWidth(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'bi_flash',
                onPressed: () => scannerController.toggleTorch(),
                tooltip: 'Flash',
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                child: const Icon(Icons.flash_on, color: Colors.white),
              ),
              FloatingActionButton(
                heroTag: 'bi_keyboard',
                onPressed: () => setState(() => showManualInput = true),
                tooltip: 'Colar texto do QR',
                backgroundColor: Colors.black.withValues(alpha: 0.6),
                child: const Icon(Icons.keyboard, color: Colors.white),
              ),
              FloatingActionButton(
                heroTag: 'bi_close',
                onPressed: () {
                  widget.onCancel();
                  Navigator.pop(context);
                },
                tooltip: 'Cancelar',
                backgroundColor: Colors.red.withValues(alpha: 0.7),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
