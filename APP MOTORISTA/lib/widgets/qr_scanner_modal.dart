import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/widgets/custom_widgets.dart'
    show CustomInput, CustomButton;

/// Modal para escanear QR Code do cartão virtual do passageiro
class QRScannerModal extends StatefulWidget {
  final Function(String scannedData) onQRScanned;
  final VoidCallback onCancel;

  const QRScannerModal({
    super.key,
    required this.onQRScanned,
    required this.onCancel,
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
    manualQRController.dispose();
    super.dispose();
  }

  void _processQRCode() {
    final qrData = manualQRController.text.trim();

    if (qrData.isEmpty) {
      setState(() => error = 'Digite o código do cartão virtual');
      return;
    }

    if (qrData.length < 5) {
      setState(() => error = 'Código muito curto ou inválido');
      return;
    }

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

    return Container(
      color: Theme.of(context).colorScheme.surface,
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
                        Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(16)),
                Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(12)),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.qr_code_scanner,
                    size: responsive.scaledWidth(32),
                    color: AppColors.accent,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(12)),
                Text(
                  'ESCANEAR CARTÃO VIRTUAL',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(16),
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(8)),
                Text(
                  'Aponte a câmera para o QR code do passageiro',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: responsive.responsiveFontSize(12),
                            ),
                          ),
                        ),
                      Icon(
                        Icons.credit_card,
                        size: responsive.scaledWidth(64),
                        color: AppColors.accent.withOpacity(0.3),
                      ),
                      SizedBox(height: responsive.scaledHeight(16)),
                      Text(
                        'Digite o código do cartão virtual',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(12)),
                      CustomInput(
                        label: '',
                        hint: 'Cole ou digite o código do cartão',
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
        // Camera Scanner
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
                            .withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: responsive.scaledHeight(24)),
                  ElevatedButton(
                    onPressed: () {
                      scannerController
                          .stop()
                          .then((_) => scannerController.start());
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
            width: responsive.scaledWidth(280),
            height: responsive.scaledHeight(280),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.accent,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.credit_card,
                  size: responsive.scaledWidth(64),
                  color: Colors.white,
                ),
                SizedBox(height: responsive.scaledHeight(12)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scaledWidth(16),
                    vertical: responsive.scaledHeight(8),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Alinhe o QR do passageiro aqui',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.responsiveFontSize(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Corners decoration
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          left: MediaQuery.of(context).size.width * 0.12,
          child: _buildCorner(responsive, true, true),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          right: MediaQuery.of(context).size.width * 0.12,
          child: _buildCorner(responsive, true, false),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.2,
          left: MediaQuery.of(context).size.width * 0.12,
          child: _buildCorner(responsive, false, true),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.2,
          right: MediaQuery.of(context).size.width * 0.12,
          child: _buildCorner(responsive, false, false),
        ),
        // Botões flutuantes
        Positioned(
          bottom: responsive.scaledHeight(16),
          left: responsive.scaledWidth(16),
          right: responsive.scaledWidth(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'flash',
                onPressed: () {
                  scannerController.toggleTorch();
                },
                tooltip: 'Flash',
                backgroundColor: Colors.black.withOpacity(0.6),
                child: const Icon(Icons.flash_on, color: Colors.white),
              ),
              FloatingActionButton(
                heroTag: 'keyboard',
                onPressed: () => setState(() => showManualInput = true),
                tooltip: 'Digite Manualmente',
                backgroundColor: Colors.black.withOpacity(0.6),
                child: const Icon(Icons.keyboard, color: Colors.white),
              ),
              FloatingActionButton(
                heroTag: 'close',
                onPressed: () {
                  widget.onCancel();
                  Navigator.pop(context);
                },
                tooltip: 'Cancelar',
                backgroundColor: Colors.red.withOpacity(0.7),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(ResponsiveHelper responsive, bool isTop, bool isLeft) {
    return Container(
      width: responsive.scaledWidth(30),
      height: responsive.scaledHeight(30),
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: AppColors.accent, width: 4)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: AppColors.accent, width: 4)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: AppColors.accent, width: 4)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: AppColors.accent, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }
}
