import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:intl/intl.dart';

class DepositModal extends StatefulWidget {
  final int currentBalance;
  final VoidCallback? onSuccess;

  const DepositModal({
    super.key,
    required this.currentBalance,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentBalance,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DepositModal(
        currentBalance: currentBalance,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<DepositModal> createState() => _DepositModalState();
}

class _DepositModalState extends State<DepositModal> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _reference;

  final List<int> _quickAmounts = [1000, 2000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    _api.loadTokens();
  }

  @override
  void dispose() {
    _amountController.dispose();
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

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount < 500) {
      setState(() => _errorMessage = 'Valor mínimo: 500 Kz');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _api.initiateDeposit(amount: amount);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess && result.data != null) {
      setState(() => _reference = result.data!['reference']?.toString());
      widget.onSuccess?.call();
    } else {
      setState(() =>
          _errorMessage = result.error ?? 'Erro ao gerar referência de carregamento');
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
                                color: AppColors.primaryGold.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: responsive.scaledWidth(20),
                          ),
                        ),
                        SizedBox(width: responsive.scaledWidth(12)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carregar Saldo',
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(18),
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Via Multicaixa Express',
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
                      color: AppColors.darkBackground.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo actual',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(12),
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: responsive.scaledHeight(4)),
                    Text(
                      _formatCurrency(widget.currentBalance),
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(24),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: responsive.scaledHeight(24)),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.responsivePadding(),
                ),
                child: _reference != null
                    ? _buildReferenceResult(responsive)
                    : _buildForm(responsive),
              ),

              SizedBox(height: responsive.scaledHeight(24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ResponsiveHelper responsive) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Valor a carregar',
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
                margin: EdgeInsets.only(right: responsive.scaledWidth(8)),
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
                borderSide:
                    const BorderSide(color: AppColors.primaryGold, width: 2),
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

          SizedBox(height: responsive.scaledHeight(12)),
          Wrap(
            spacing: responsive.scaledWidth(8),
            runSpacing: responsive.scaledHeight(8),
            children: _quickAmounts
                .map((amount) => GestureDetector(
                      onTap: () => _setQuickAmount(amount),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.scaledWidth(14),
                          vertical: responsive.scaledHeight(8),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _formatCurrency(amount),
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(12),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

          if (_errorMessage != null) ...[
            SizedBox(height: responsive.scaledHeight(16)),
            Container(
              padding: EdgeInsets.all(responsive.responsivePadding() * 0.8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitDeposit,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_downward_rounded, color: Colors.white),
                        SizedBox(width: responsive.scaledWidth(8)),
                        Text(
                          'GERAR REFERÊNCIA',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(14),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceResult(ResponsiveHelper responsive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(responsive.responsivePadding()),
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryGold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Referência de pagamento',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(4)),
              Text(
                _reference!,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(20),
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryGold,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(8)),
              Text(
                'Pague este valor num Multicaixa Express ou ATM usando esta referência. O saldo é creditado após a confirmação do pagamento.',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(11),
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: responsive.scaledHeight(20)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(16)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: AppColors.primaryGold),
            ),
            child: Text(
              'FECHAR',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(14),
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
