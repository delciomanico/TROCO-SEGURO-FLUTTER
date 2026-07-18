import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:troco_seguro_pro/utils/constants.dart';

/// Modal de solicitação de saque — visual e estrutura alinhados com o
/// _WithdrawalSheet do APP PASSAGEIRO, mantendo o passo de cotação
/// (Valor/Tarifa/Total) já confirmado a funcionar com o backend.
class WithdrawalModal extends StatefulWidget {
  final int availableBalance;
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const WithdrawalModal({
    super.key,
    required this.availableBalance,
    this.onSuccess,
    this.onError,
  });

  static Future<void> show(
    BuildContext context, {
    required int availableBalance,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawalModal(
        availableBalance: availableBalance,
        onSuccess: onSuccess,
        onError: onError,
      ),
    );
  }

  @override
  State<WithdrawalModal> createState() => _WithdrawalModalState();
}

class _WithdrawalModalState extends State<WithdrawalModal> {
  final _amountCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final ApiService _api = ApiService();

  String _method = 'bank';
  bool _busy = false;
  bool _loadingQuote = false;
  String? _errorMessage;
  QuoteResult? _quote;

  @override
  void initState() {
    super.initState();
    _api.loadTokens();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  bool _validIban(String v) => v.isNotEmpty && v.toUpperCase().startsWith('AO06');

  void _resetQuote() {
    if (_errorMessage != null || _quote != null) {
      setState(() {
        _errorMessage = null;
        _quote = null;
      });
    }
  }

  /// Primeiro toque: valida e mostra a cotação (Valor/Tarifa/Total). Segundo
  /// toque (com `_quote` já carregado): submete o pedido de saque.
  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final account = _ibanCtrl.text.trim();

    if (amount <= 0) {
      setState(() => _errorMessage = 'Valor deve ser maior que 0');
      return;
    }
    if (amount > widget.availableBalance) {
      setState(() => _errorMessage = 'Saldo insuficiente');
      return;
    }
    if (amount < 1000) {
      setState(() => _errorMessage = 'Valor mínimo: 1.000 Kz');
      return;
    }
    if (_method == 'bank' && !_validIban(account)) {
      setState(() => _errorMessage = 'IBAN inválido (deve começar por AO06)');
      return;
    }
    if (_method == 'mcx_express' && account.isEmpty) {
      setState(() => _errorMessage = 'Informe o número de telefone');
      return;
    }

    if (_quote == null) {
      setState(() {
        _loadingQuote = true;
        _errorMessage = null;
      });
      final quoteResult =
          await _api.getTransactionQuote(type: 'withdrawal', amount: amount);
      if (!mounted) return;
      setState(() {
        _loadingQuote = false;
        _quote = quoteResult.isSuccess
            ? quoteResult.data
            : QuoteResult(
                type: 'withdrawal',
                amount: amount,
                feePercent: 0,
                feeAmount: 0,
                totalDebited: amount,
                netReceived: amount,
              );
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final result = await _api.requestWithdrawal(amount: amount, iban: account);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isSuccess) {
      Navigator.pop(context);
      widget.onSuccess?.call();
    } else {
      setState(() => _errorMessage = result.error ?? 'Erro ao processar saque');
      widget.onError?.call(result.error ?? 'Erro ao processar saque');
    }
  }

  Widget _quoteLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: AppColors.textLight,
              )),
          Text(value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.textLight,
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0x1FFFFFFF);
    const fillColor = Color(0x0FFFFFFF);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Solicitar Saque',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight)),
              const SizedBox(height: 4),
              Text('Escolha o método de saque',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MethodOption(
                      label: 'Banco',
                      sublabel: 'Transferência bancária',
                      icon: Icons.account_balance_rounded,
                      isSelected: _method == 'bank',
                      onTap: () {
                        setState(() => _method = 'bank');
                        _resetQuote();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MethodOption(
                      label: 'MCX Express',
                      sublabel: 'Receba em minutos',
                      icon: Icons.flash_on_rounded,
                      isSelected: _method == 'mcx_express',
                      onTap: () {
                        setState(() => _method = 'mcx_express');
                        _resetQuote();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Valor a levantar',
                  suffixText: 'Kz',
                  prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.primaryGold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                  ),
                  filled: true,
                  fillColor: fillColor,
                ),
                onChanged: (_) => _resetQuote(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ibanCtrl,
                keyboardType:
                    _method == 'bank' ? TextInputType.text : TextInputType.phone,
                decoration: InputDecoration(
                  labelText: _method == 'bank' ? 'IBAN (AO06...)' : 'Número de telefone',
                  hintText: _method == 'bank' ? null : '9XX XXX XXX',
                  prefixIcon: Icon(
                    _method == 'bank'
                        ? Icons.credit_score_rounded
                        : Icons.phone_android_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                  ),
                  filled: true,
                  fillColor: fillColor,
                ),
                onChanged: (_) => _resetQuote(),
              ),

              // Cotação (Valor / Tarifa / Total)
              if (_quote != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _quoteLine('Valor', '${_quote!.amount} Kz'),
                      _quoteLine('Tarifa', '${_quote!.feeAmount} Kz'),
                      _quoteLine('Total a debitar', '${_quote!.totalDebited} Kz', bold: true),
                    ],
                  ),
                ),
              ],

              // Erro
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange.shade300),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _method == 'bank'
                            ? 'O valor será transferido para a sua conta bancária em 1-3 dias úteis'
                            : 'O valor será transferido via Multicaixa Express em poucos minutos',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade200),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_busy || _loadingQuote) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: (_busy || _loadingQuote)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _quote == null ? 'VER TARIFA E CONTINUAR' : 'CONFIRMAR SAQUE',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodOption({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primaryGold
                  : AppColors.textLight.withValues(alpha: 0.6),
              size: 22,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primaryGold : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(fontSize: 10, color: AppColors.textLight.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
