import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:intl/intl.dart';

class WithdrawalModal extends StatefulWidget {
  final int availableBalance;
  final String? bankAccount;
  final String? bankName;
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const WithdrawalModal({
    super.key,
    required this.availableBalance,
    this.bankAccount,
    this.bankName,
    this.onSuccess,
    this.onError,
  });

  static Future<void> show(
    BuildContext context, {
    required int availableBalance,
    String? bankAccount,
    String? bankName,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawalModal(
        availableBalance: availableBalance,
        bankAccount: bankAccount,
        bankName: bankName,
        onSuccess: onSuccess,
        onError: onError,
      ),
    );
  }

  @override
  State<WithdrawalModal> createState() => _WithdrawalModalState();
}

class _WithdrawalModalState extends State<WithdrawalModal> {
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  String _withdrawalMethod = 'bank';
  bool _isLoading = false;
  String? _errorMessage;

  final List<int> _quickAmounts = [5000, 10000, 25000, 50000];

  @override
  void initState() {
    super.initState();
    _accountController.text = widget.bankAccount ?? '';
    _api.loadTokens();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  int? _parseAmount(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned);
  }

  void _setQuickAmount(int amount) {
    _amountController.text = _formatCurrency(amount);
    setState(() => _errorMessage = null);
  }

  void _withdrawAll() {
    _amountController.text = _formatCurrency(widget.availableBalance);
    setState(() => _errorMessage = null);
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Valor inválido');
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _api.requestWithdrawal(
      amount: amount,
      iban: _accountController.text,
    );

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      Navigator.pop(context);
      widget.onSuccess?.call();
    } else {
      setState(() => _errorMessage = result.error ?? 'Erro ao processar saque');
      widget.onError?.call(result.error ?? 'Erro ao processar saque');
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
              // Handle bar
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

              // Header
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
                              colors: [
                                AppColors.primaryGold,
                                AppColors.secondaryGold
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGold.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: responsive.scaledWidth(20),
                          ),
                        ),
                        SizedBox(width: responsive.scaledWidth(12)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solicitar Saque',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(18),
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Transferir para sua conta',
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
                        child: Icon(
                          Icons.close,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Balance display
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: responsive.responsivePadding(),
                ),
                padding: EdgeInsets.all(responsive.responsivePadding()),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.darkBackground, AppColors.darkSurface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkBackground.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo disponível',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(12),
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(height: responsive.scaledHeight(4)),
                        Text(
                          _formatCurrency(widget.availableBalance),
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(24),
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

              // Form
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.responsivePadding(),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Withdrawal method
                      Text(
                        'Método de saque',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(12)),
                      Row(
                        children: [
                          Expanded(
                            child: _MethodOption(
                              label: 'Banco',
                              sublabel: 'Transferência bancária',
                              icon: Icons.account_balance_rounded,
                              isSelected: _withdrawalMethod == 'bank',
                              onTap: () =>
                                  setState(() => _withdrawalMethod = 'bank'),
                            ),
                          ),
                          SizedBox(width: responsive.scaledWidth(12)),
                          Expanded(
                            child: _MethodOption(
                              label: 'MCX Express',
                              sublabel: 'Receba em minutos',
                              icon: Icons.flash_on_rounded,
                              isSelected: _withdrawalMethod == 'mcx_express',
                              onTap: () => setState(
                                  () => _withdrawalMethod = 'mcx_express'),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: responsive.scaledHeight(20)),

                      // Amount field
                      Text(
                        'Valor do saque',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(10)),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(22),
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: '0 Kz',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: Container(
                            padding: EdgeInsets.all(responsive.scaledWidth(12)),
                            margin: EdgeInsets.only(
                                right: responsive.scaledWidth(8)),
                            child: const Icon(
                              Icons.payments_outlined,
                              color: AppColors.primaryGold,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.primaryGold, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe o valor';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                      ),

                      SizedBox(height: responsive.scaledHeight(20)),

                      // Account field
                      Text(
                        _withdrawalMethod == 'bank'
                            ? 'Número da conta (IBAN)'
                            : 'Número de telefone',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(10)),
                      TextFormField(
                        controller: _accountController,
                        keyboardType: _withdrawalMethod == 'bank'
                            ? TextInputType.text
                            : TextInputType.phone,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(14),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: _withdrawalMethod == 'bank'
                              ? 'AO06 0000 0000 0000 0000 0000 0'
                              : '9XX XXX XXX',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Icon(
                            _withdrawalMethod == 'bank'
                                ? Icons.account_balance_outlined
                                : Icons.phone_android_rounded,
                            color: Colors.grey.shade500,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: AppColors.primaryGold, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _withdrawalMethod == 'bank'
                                ? 'Informe o número da conta'
                                : 'Informe o número de telefone';
                          }
                          return null;
                        },
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        SizedBox(height: responsive.scaledHeight(16)),
                        Container(
                          padding: EdgeInsets.all(
                              responsive.responsivePadding() * 0.8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: responsive.scaledWidth(10)),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: responsive.responsiveFontSize(13),
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: responsive.scaledHeight(28)),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitWithdrawal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            padding: EdgeInsets.symmetric(
                              vertical: responsive.scaledHeight(16),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.arrow_upward_rounded,
                                        color: Colors.white),
                                    SizedBox(width: responsive.scaledWidth(8)),
                                    Text(
                                      'SOLICITAR SAQUE',
                                      style: TextStyle(
                                        fontSize:
                                            responsive.responsiveFontSize(14),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      SizedBox(height: responsive.scaledHeight(16)),

                      // Info
                      Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.scaledWidth(16),
                            vertical: responsive.scaledHeight(8),
                          ),
                          decoration: BoxDecoration(
                            color: _withdrawalMethod == 'mcx_express'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _withdrawalMethod == 'mcx_express'
                                    ? Icons.flash_on_rounded
                                    : Icons.schedule_rounded,
                                size: 16,
                                color: _withdrawalMethod == 'mcx_express'
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                              SizedBox(width: responsive.scaledWidth(6)),
                              Text(
                                _withdrawalMethod == 'bank'
                                    ? 'Processamento em até 24h úteis'
                                    : 'Processamento instantâneo',
                                style: TextStyle(
                                  fontSize: responsive.responsiveFontSize(11),
                                  fontWeight: FontWeight.w600,
                                  color: _withdrawalMethod == 'mcx_express'
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: responsive.scaledHeight(32)),
                    ],
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
    final responsive = ResponsiveHelper(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(responsive.responsivePadding()),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withOpacity(0.1)
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(10)),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGold.withOpacity(0.15)
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color:
                    isSelected ? AppColors.primaryGold : Colors.grey.shade500,
                size: responsive.scaledWidth(24),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(10)),
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(13),
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primaryGold : AppColors.textDark,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(2)),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(10),
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
