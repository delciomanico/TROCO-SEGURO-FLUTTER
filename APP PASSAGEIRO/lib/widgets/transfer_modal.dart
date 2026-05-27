import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/widgets/custom_widgets.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/security/pin_guard.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';
import 'dart:convert';

class TransferModal extends StatefulWidget {
  final int currentBalance;
  final Function(String receiverPhone, int amount, String description)? onTransfer;
  final VoidCallback onClose;

  const TransferModal({
    super.key,
    required this.currentBalance,
    this.onTransfer,
    required this.onClose,
  });

  @override
  State<TransferModal> createState() => _TransferModalState();
}

class _TransferModalState extends State<TransferModal> {
  final receiverPhoneController = TextEditingController();
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  String? error;
  bool isLoading = false;

  void _scanQrCode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QRScannerModal(
        onCancel: () {},
        onQRScanned: (qrData) {
          Navigator.pop(context, qrData);
        },
      ),
    );

    if (result != null && mounted) {
      try {
        final decoded = jsonDecode(result);
        final phone = decoded['receiverPhone'] ??
            decoded['phone'] ??
            decoded['userPhone'] ??
            decoded['phoneNumber'];

        if (phone != null) {
          setState(() {
            receiverPhoneController.text = phone.toString();
            error = null;
          });
        } else if (decoded['type'] == 'PROFILE' && phone != null) {
          setState(() {
            receiverPhoneController.text = phone.toString();
            error = null;
          });
        } else {
          setState(() => error = 'QR Code inválido');
        }
      } catch (e) {
        setState(() => error = 'Erro ao ler QR Code');
      }
    }
  }

  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    String enteredPin = '';

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar Transferência'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Digite seu PIN para confirmar'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      enteredPin = value;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (enteredPin.length != 6) {
                      return;
                    }

                    // Validar PIN
                    final isValid = await PinGuard.validatePin(
                      scope: 'transfer',
                      enteredPin: enteredPin,
                      readExpectedPin: () => SecureStorageService().readPin(),
                    );
                    if (!isValid) {
                      if (mounted) {
                        setState(() => error = 'PIN incorreto');
                        Navigator.pop(context);
                      }
                      return;
                    }

                    Navigator.pop(context);
                    await _processTransfer();
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processTransfer() async {
    setState(() => isLoading = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    final success = await appProvider.transfer(
      receiverPhone: receiverPhoneController.text.trim(),
      amount: int.parse(amountController.text),
      description: descriptionController.text.isNotEmpty 
          ? descriptionController.text 
          : 'Transferência P2P',
    );

    if (mounted) {
      setState(() => isLoading = false);
      
      if (success) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transferência realizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => error = appProvider.error ?? 'Erro ao realizar transferência');
      }
    }
  }

  void _validateAndTransfer() async {
    final receiverPhone = receiverPhoneController.text.trim();
    final amount = int.tryParse(amountController.text);

    if (receiverPhone.isEmpty || amount == null) {
      setState(() => error = 'Preencha todos os campos obrigatórios');
      return;
    }

    if (amount <= 0) {
      setState(() => error = 'Valor deve ser maior que zero');
      return;
    }

    if (amount > widget.currentBalance) {
      setState(() => error = 'Saldo insuficiente');
      return;
    }

    // Mostrar diálogo de PIN
    await _showPinDialog();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final screenHeight = MediaQuery.of(context).size.height;
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
      height: screenHeight * 0.85,
      padding: EdgeInsets.only(
        left: responsive.responsivePadding(),
        right: responsive.responsivePadding(),
        top: responsive.responsivePadding(),
        bottom: MediaQuery.of(context).viewInsets.bottom +
            responsive.responsivePadding(),
      ),
      child: SingleChildScrollView(
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
            Icon(Icons.swap_horiz,
              size: responsive.scaledWidth(48), color: Theme.of(context).colorScheme.primary),
            SizedBox(height: responsive.scaledHeight(16)),
            Text(
              'TRANSFERIR SALDO',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(18),
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            Text(
              'Saldo disponível: ${widget.currentBalance} Kz',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            if (error != null)
              Container(
                padding: EdgeInsets.all(responsive.responsiveSpacing()),
                margin: EdgeInsets.only(bottom: responsive.scaledHeight(16)),
                decoration: BoxDecoration(
                    color: Colors.red.withAlpha((0.08 * 255).round()),
                  borderRadius: BorderRadius.circular(
                      responsive.responsiveBorderRadius()),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: CustomInput(
                    label: 'TELEFONE DO DESTINATÁRIO',
                    placeholder: 'Ex: +244926283434',
                    controller: receiverPhoneController,
                  ),
                ),
                SizedBox(width: responsive.responsiveSpacing()),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    onPressed: _scanQrCode,
                    tooltip: 'Escanear QR Code',
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            CustomInput(
              label: 'VALOR (Kz)',
              placeholder: 'Digite o valor',
              keyboardType: TextInputType.number,
              controller: amountController,
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            CustomInput(
              label: 'DESCRIÇÃO (OPCIONAL)',
              placeholder: 'Ex: Pagamento Corrida',
              controller: descriptionController,
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'CANCELAR',
                      onPressed: widget.onClose,
                      isOutline: true,
                    ),
                  ),
                  SizedBox(width: responsive.responsiveSpacing()),
                  Expanded(
                    child: CustomButton(
                      text: 'TRANSFERIR',
                      onPressed: _validateAndTransfer,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
