import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

class QRScannerModal extends StatefulWidget {
  final Function(String scannedData)
      onQRScanned; // Callback with scanned QR data
  final VoidCallback onCancel;
  final String title;
  final String subtitle;

  const QRScannerModal({
    super.key,
    required this.onQRScanned,
    required this.onCancel,
    this.title = 'ESCANEAR QR DO TAXISTA',
    this.subtitle = 'Aponte a câmera para o QR code',
  });

  @override
  State<QRScannerModal> createState() => _QRScannerModalState();
}

class _QRScannerModalState extends State<QRScannerModal> {
  late MobileScannerController scannerController;
  final TextEditingController manualQRController = TextEditingController();
  String? error;
  bool showManualInput = false;
  bool isScanning = true;
  bool _isClosing = false;

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
    // Dispose direto evita callback assíncrono após desmontagem do widget.
    try {
      scannerController.dispose();
    } catch (_) {}

    manualQRController.dispose();
    super.dispose();
  }

  Future<void> _closeModalSafely() async {
    if (_isClosing) return;
    _isClosing = true;

    if (mounted) {
      setState(() => isScanning = false);
    }

    try {
      await scannerController.stop();
    } catch (_) {}

    if (!mounted) return;

    try {
      widget.onCancel();
    } catch (_) {}

    Navigator.of(context).maybePop();
  }

  void _processQRCode() {
    final qrData = manualQRController.text.trim();

    if (qrData.isEmpty) {
      setState(() => error = 'Digite o QR code do taxista');
      return;
    }

    // Validate QR format (expecting something with content)
    if (qrData.length < 5) {
      setState(() => error = 'QR code muito curto ou inválido');
      return;
    }

    // Success - pass scanned data to callback
    widget.onQRScanned(qrData);
  }

  void _handleBarcodeDetect(BarcodeCapture barcodes) {
    if (!isScanning || barcodes.barcodes.isEmpty) return;

    final barcode = barcodes.barcodes.first;
    final qrData = barcode.rawValue;

    if (qrData != null && qrData.isNotEmpty) {
      setState(() => isScanning = false);
      widget.onQRScanned(qrData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
      height: screenHeight * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(responsive.responsivePadding()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.outline.withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
                Icon(Icons.qr_code_2,
                    size: responsive.scaledWidth(40),
                  color: Theme.of(context).colorScheme.primary),
                SizedBox(height: responsive.scaledHeight(12)),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(16),
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(8)),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.6 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
          // Scanner or Manual Input
          if (!showManualInput)
            Expanded(
              child: _buildScannerSection(responsive),
            )
          else
            // Manual Input Section
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(responsive.responsivePadding()),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (error != null)
                        Container(
                          margin: EdgeInsets.only(
                              bottom: responsive.scaledHeight(12)),
                          padding:
                              EdgeInsets.all(responsive.responsiveSpacing()),
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
                      Text(
                        'Digite o código do QR',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.7 * 255).round()),
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(12)),
                      CustomInput(
                        label: '',
                        placeholder: 'Cole ou digite o código QR',
                        controller: manualQRController,
                        onChanged: (val) {
                          if (error != null) {
                            setState(() => error = null);
                          }
                        },
                      ),
                      SizedBox(height: responsive.scaledHeight(24)),
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'VOLTAR',
                              onPressed: () =>
                                  setState(() => showManualInput = false),
                              isOutline: true,
                            ),
                          ),
                          SizedBox(width: responsive.responsiveSpacing()),
                          Expanded(
                            child: CustomButton(
                              text: 'CONFIRMAR',
                              onPressed: _processQRCode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
        // Camera Scanner - Inicia automaticamente
        MobileScanner(
          controller: scannerController,
          onDetect: _handleBarcodeDetect,
          errorBuilder: (context, error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: responsive.scaledWidth(48),
                  ),
                  SizedBox(height: responsive.scaledHeight(16)),
                  Text(
                    'Erro ao acessar câmera',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(8)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: responsive.responsivePadding()),
                    child: Text(
                      'Verifique se você permitiu acesso à câmera nas configurações do app.',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(12),
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(24)),
                  ElevatedButton(
                    onPressed: () {
                      scannerController.stop().then(
                            (_) => scannerController.start(),
                          );
                    },
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          },
        ),
        // Overlay com frame para escanear
        Center(
          child: Container(
            width: responsive.scaledWidth(250),
            height: responsive.scaledHeight(250),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code,
                  size: responsive.scaledWidth(64),
                  color: Colors.white,
                ),
                SizedBox(height: responsive.scaledHeight(12)),
                Text(
                  'Alinhe o QR code aqui',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: responsive.responsiveFontSize(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Botões flutuantes
        Positioned(
          bottom: responsive.scaledHeight(16),
          left: responsive.scaledWidth(16),
          right: responsive.scaledWidth(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton.small(
                onPressed: () {
                  scannerController.toggleTorch();
                },
                tooltip: 'Flash',
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: const Icon(Icons.flash_on, color: Colors.white),
              ),
              FloatingActionButton.small(
                onPressed: () => setState(
                  () => showManualInput = true,
                ),
                tooltip: 'Digite Manualmente',
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: const Icon(Icons.keyboard, color: Colors.white),
              ),
              FloatingActionButton.small(
                onPressed: _closeModalSafely,
                tooltip: 'Cancelar',
                backgroundColor: Colors.red.withValues(alpha: 0.5),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
