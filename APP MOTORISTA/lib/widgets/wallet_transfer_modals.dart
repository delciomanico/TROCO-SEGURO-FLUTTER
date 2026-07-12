import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:troco_seguro_pro/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro_pro/widgets/otp_box_input.dart';
import 'package:troco_seguro_pro/widgets/success_modal.dart';

/// Cabeçalho + moldura partilhados pelos modais de carteira desta ficha,
/// no mesmo estilo do WithdrawalModal (fundo branco, ícone com gradiente
/// dourado, botão de fechar circular).
class _WalletModalShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _WalletModalShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: responsive.scaledHeight(12)),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(responsive.responsivePadding()),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(responsive.scaledWidth(12)),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryGold, AppColors.secondaryGold],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGold.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: responsive.scaledWidth(20)),
                        ),
                        SizedBox(width: responsive.scaledWidth(12)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(18),
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(12),
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: EdgeInsets.all(responsive.scaledWidth(6)),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.grey.shade600, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  responsive.responsivePadding(),
                  0,
                  responsive.responsivePadding(),
                  responsive.responsivePadding(),
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label, {String? hint, Widget? prefixIcon, Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF5F7FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
    ),
  );
}

void _showSuccess(BuildContext context, {required String title, required String subtitle}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SuccessModal(
      title: title,
      subtitle: subtitle,
      primaryButtonLabel: 'OK',
      onPrimaryPressed: () => Navigator.pop(context),
    ),
  );
}

Future<String?> _scanQr(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => QRScannerModal(
      onCancel: () {},
      onQRScanned: (data) => Navigator.pop(context, data),
    ),
  );
}

// ─── Pagar ao lotador ───────────────────────────────────────────────────────

/// Transfere saldo da carteira do motorista para o cartão virtual de um
/// terceiro (ex.: o lotador), identificado por número do cartão.
class PayLoaderModal extends StatefulWidget {
  const PayLoaderModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PayLoaderModal(),
    );
  }

  @override
  State<PayLoaderModal> createState() => _PayLoaderModalState();
}

class _PayLoaderModalState extends State<PayLoaderModal> {
  final _cardCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _cardCtrl.dispose();
    _amountCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanCard() async {
    final qrData = await _scanQr(context);
    if (qrData == null || !mounted) return;
    setState(() => _loading = true);
    final result = await ApiService().resolveVirtualCardQr(qrData);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.isSuccess && result.data?.cardNumber != null) {
      setState(() {
        _cardCtrl.text = result.data!.cardNumber!;
        _error = null;
      });
    } else {
      setState(() => _error = result.error ?? 'QR inválido ou não é um cartão virtual.');
    }
  }

  Future<void> _submit() async {
    final cardNumber = _cardCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.trim());
    final pin = _pinCtrl.text.trim();

    if (cardNumber.isEmpty || amount == null || amount <= 0 || pin.length < 6) {
      setState(() => _error = 'Preencha o número do cartão, o valor e o PIN (6 dígitos).');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final result = await ApiService().transferToExternalCard(
      cardNumber: cardNumber,
      amount: amount,
      pin: pin,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop();
      _showSuccess(context, title: 'Pagamento enviado!', subtitle: 'O valor foi creditado no cartão do lotador.');
      return;
    }

    setState(() {
      _loading = false;
      _error = result.error ?? 'Erro ao pagar ao lotador.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    return _WalletModalShell(
      title: 'Pagar ao Lotador',
      subtitle: 'Transferir para o cartão de um lotador',
      icon: Icons.storefront_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _ErrorBanner(_error!),
          TextField(
            controller: _cardCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textDark),
            decoration: _fieldDecoration(
              'Número do cartão',
              suffixIcon: IconButton(
                onPressed: _loading ? null : _scanCard,
                icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryGold),
                tooltip: 'Ler QR do cartão',
              ),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textDark),
            decoration: _fieldDecoration('Valor (Kz)'),
          ),
          SizedBox(height: responsive.scaledHeight(20)),
          Text(
            'PIN da sua conta',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(10)),
          OtpBoxInput(controller: _pinCtrl, accentColor: AppColors.primaryGold, isDark: false),
          SizedBox(height: responsive.scaledHeight(24)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(16)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('PAGAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transferir para outra carteira ─────────────────────────────────────────

/// Transfere saldo da carteira do motorista para outro utilizador por número
/// de telefone (ex.: devolver dinheiro a um passageiro).
class WalletTransferModal extends StatefulWidget {
  const WalletTransferModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WalletTransferModal(),
    );
  }

  @override
  State<WalletTransferModal> createState() => _WalletTransferModalState();
}

class _WalletTransferModalState extends State<WalletTransferModal> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _error;
  String? _recipientName;
  bool _loading = false;
  bool _verified = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanRecipient() async {
    final qrData = await _scanQr(context);
    if (qrData == null || !mounted) return;
    try {
      final decoded = jsonDecode(qrData) as Map<String, dynamic>;
      final phone = decoded['phoneNumber'] ?? decoded['phone'] ?? decoded['receiverPhone'];
      if (phone != null) {
        setState(() {
          _phoneCtrl.text = phone.toString();
          _verified = false;
          _recipientName = null;
          _error = null;
        });
      } else {
        setState(() => _error = 'QR não contém número de telefone.');
      }
    } catch (_) {
      setState(() => _error = 'QR inválido.');
    }
  }

  Future<void> _verify() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Informe o número de telefone.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final result = await ApiService().verifyTransferRecipient(phone);
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      final name = result.data!['name'] ?? result.data!['fullName'];
      setState(() {
        _recipientName = (name is String && name.isNotEmpty) ? name : 'Utilizador verificado';
        _verified = true;
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.error ?? 'Destinatário não encontrado.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe um montante válido.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final result = await ApiService().transfer(
      amount: amount,
      receiverPhone: _phoneCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop();
      _showSuccess(context, title: 'Transferência enviada!', subtitle: 'O valor foi transferido com sucesso.');
      return;
    }
    setState(() {
      _loading = false;
      _error = result.error ?? 'Erro ao realizar transferência.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    return _WalletModalShell(
      title: 'Transferir',
      subtitle: 'Enviar saldo para outra carteira Troco Seguro',
      icon: Icons.send_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _ErrorBanner(_error!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  enabled: !_verified,
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: _fieldDecoration('Nº de telefone', hint: '+244 9XX XXX XXX'),
                ),
              ),
              SizedBox(width: responsive.scaledWidth(8)),
              if (!_verified)
                SizedBox(
                  height: 56,
                  child: IconButton(
                    onPressed: _loading ? null : _scanRecipient,
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryGold),
                    tooltip: 'Ler QR do destinatário',
                  ),
                ),
              SizedBox(
                height: 56,
                child: _verified
                    ? IconButton(
                        onPressed: () => setState(() {
                          _verified = false;
                          _recipientName = null;
                        }),
                        icon: const Icon(Icons.edit, color: AppColors.primaryGold),
                        tooltip: 'Alterar',
                      )
                    : ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : const Text('Verificar', style: TextStyle(color: Colors.white)),
                      ),
              ),
            ],
          ),
          if (_recipientName != null) ...[
            SizedBox(height: responsive.scaledHeight(10)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_recipientName!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: responsive.scaledHeight(16)),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textDark),
            decoration: _fieldDecoration('Valor (Kz)'),
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: AppColors.textDark),
            decoration: _fieldDecoration('Descrição (opcional)', hint: 'Ex.: devolução de viagem'),
          ),
          SizedBox(height: responsive.scaledHeight(24)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_loading || !_verified) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(16)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('TRANSFERIR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Consultar saldo do cartão (só-leitura) ─────────────────────────────────

/// Escaneia o QR do cartão virtual de um terceiro e mostra o saldo, sem
/// nenhuma operação de débito/crédito.
class CardBalanceModal extends StatefulWidget {
  final String qrData;
  const CardBalanceModal({super.key, required this.qrData});

  static Future<void> show(BuildContext context) async {
    final qrData = await _scanQr(context);
    if (qrData == null || !context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardBalanceModal(qrData: qrData),
    );
  }

  @override
  State<CardBalanceModal> createState() => _CardBalanceModalState();
}

class _CardBalanceModalState extends State<CardBalanceModal> {
  bool _loading = true;
  String? _error;
  CardBalanceResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String qrId = widget.qrData;
    try {
      final decoded = jsonDecode(widget.qrData);
      qrId = decoded['qrId'] ?? decoded['id'] ?? decoded['cardId'] ?? widget.qrData;
    } catch (_) {}

    final result = await ApiService().getWalletBalanceByQr(qrId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _result = result.data;
      } else {
        _error = result.error ?? 'Não foi possível obter o saldo.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _WalletModalShell(
      title: 'Saldo do Cartão',
      subtitle: 'Consulta via QR code (só-leitura)',
      icon: Icons.qr_code_scanner_rounded,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: AppColors.primaryGold),
              ),
            )
          : _error != null
              ? _ErrorBanner(_error!)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_result!.ownerName != null)
                      Text(_result!.ownerName!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    if (_result!.cardName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _result!.cardName!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      '${_result!.balance} Kz',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primaryGold),
                    ),
                    const SizedBox(height: 8),
                    Text('Saldo disponível', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
