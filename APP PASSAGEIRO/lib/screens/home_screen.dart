import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:troco_seguro/models/user.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/widgets/qr_scanner_modal.dart';
import 'package:troco_seguro/widgets/card_transfer_modal.dart';
import 'package:troco_seguro/services/payment_service.dart';
import 'package:troco_seguro/widgets/payment_confirmation_modal.dart';
import 'package:troco_seguro/security/pin_guard.dart';
import 'package:troco_seguro/services/secure_storage_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenVirtualCards;
  final VoidCallback? onOpenTopup;
  final Future<bool> Function(double latitude, double longitude)? onPanic;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onTerminateSession;

  const HomeScreen({
    super.key,
    required this.onOpenScanner,
    required this.onOpenVirtualCards,
    this.onOpenTopup,
    this.onPanic,
    this.onOpenProfile,
    this.onTerminateSession,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showBalance = false;
  bool _isPanicLoading = false;

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)}kzs';
  }

  String _getFirstName(String fullName) {
    final normalized = fullName.trim();
    if (normalized.isEmpty) {
      return 'Usuário';
    }
    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1]}';
    }
    return parts.first;
  }

  Future<void> _confirmTerminateSession() async {
    final responsive = ResponsiveHelper(context);
    final shouldTerminate = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: responsive.scaledWidth(24),
            right: responsive.scaledWidth(24),
            top: responsive.scaledHeight(16),
            bottom: MediaQuery.of(context).viewInsets.bottom +
                responsive.scaledHeight(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Center(
                child: Text(
                  'Terminar sessão?',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(18),
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(12)),
              Center(
                child: Text(
                  'Tem certeza que deseja terminar a sessão nesta conta?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.72 * 255).round()),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(28)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.18 * 255).round()),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.textLight : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Terminar sessão',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (shouldTerminate == true) {
      widget.onTerminateSession?.call();
    }
  }

  Future<void> _confirmPanicAction() async {
    final responsive = ResponsiveHelper(context);
    final shouldTrigger = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.08 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: responsive.scaledWidth(24),
            right: responsive.scaledWidth(24),
            top: responsive.scaledHeight(16),
            bottom: MediaQuery.of(context).viewInsets.bottom +
                responsive.scaledHeight(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(24)),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Center(
                child: Text(
                  'Acionar pânico?',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(18),
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(12)),
              Center(
                child: Text(
                  'Esta ação vai notificar as autoridades e os seus contatos de emergência.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.72 * 255).round()),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(28)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.18 * 255).round()),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppColors.textLight : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: responsive.scaledHeight(14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Acionar pânico',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (shouldTrigger == true) {
      await _triggerPanic();
    }
  }

  /// Acionar botão de pânico com localização
  Future<void> _triggerPanic() async {
    setState(() => _isPanicLoading = true);

    try {
      // Use default location (Luanda) for now
      // In production, this should get real location via geolocator
      const double latitude = -8.839988;
      const double longitude = 13.289437;

      final success = widget.onPanic != null
          ? await widget.onPanic!(latitude, longitude)
          : false;

      if (mounted) {
        setState(() => _isPanicLoading = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 Alerta de pânico registrado com sucesso!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Erro ao registrar alerta de pânico'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPanicLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AppProvider>();
    final user = provider.user;

    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F1115),
                    Color(0xFF1A1D24),
                    Color(0xFF2A2416),
                    Color(0xFF13151A),
                  ],
                  stops: [0.0, 0.42, 0.72, 1.0],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Color(0xFFFFFCF6),
                    Colors.white,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
          color: isDark ? null : Colors.white,
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              await provider.refreshUserData();
            },
            child: ListView(
              padding: EdgeInsets.only(top: responsive.scaledHeight(0)),
              children: [
                _buildHeader(responsive, user),
                // Corpo principal: usar único container escuro sem divisão
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        responsive.scaledHeight(200),
                  ),
                  child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.only(top: responsive.scaledHeight(6)),
                    child: Column(
                      children: [
                        SizedBox(height: responsive.scaledHeight(12)),
                        _buildQuickActions(responsive),
                        SizedBox(height: responsive.scaledHeight(24)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveHelper responsive, User? user) {
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(20),
          vertical: responsive.scaledHeight(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row centered
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bem vindo, ${_getFirstName(user?.fullName ?? 'Usuário')}',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(18),
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                InkWell(
                  onTap: () => widget.onOpenProfile?.call(),
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: responsive.scaledWidth(42),
                    height: responsive.scaledWidth(42),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: responsive.scaledWidth(22),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(18)),
            _buildBalanceCard(responsive, user),
            SizedBox(height: responsive.scaledHeight(18)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ResponsiveHelper responsive, User? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(40),
      ),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : null,
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7F8FA), Color(0xFFEFEFF2)],
              ),
        image: const DecorationImage(
          image: AssetImage('assets/images/card_fundo.jpg'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((0.9 * 255).round()),
            width: 1.2),
        boxShadow: [
          // Sombra inferior (profundidade)
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha((0.6 * 255).round())
                : Colors.black.withAlpha((0.2 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          // Sombra superior (destaque 3D)
          BoxShadow(
            color: isDark
                ? Colors.white.withAlpha((0.05 * 255).round())
                : Colors.white.withAlpha((0.9 * 255).round()),
            blurRadius: 6,
            offset: const Offset(0, -3),
            spreadRadius: 0,
          ),
          // Sombra lateral para profundidade
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha((0.4 * 255).round())
                : Colors.black.withAlpha((0.12 * 255).round()),
            blurRadius: 8,
            offset: const Offset(3, 3),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Current saldo',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: isDark
                    ? Colors.white.withAlpha((0.9 * 255).round())
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withAlpha((0.78 * 255).round()),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          GestureDetector(
            onTap: () => setState(() => showBalance = !showBalance),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showBalance ? _formatCurrency(user?.balance ?? 0) : '••••••',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(30),
                    color: isDark
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Icon(
                  Icons.credit_card,
                  color: isDark
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.85 * 255).round())
                      : Theme.of(context).colorScheme.primary,
                  size: responsive.scaledWidth(28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ResponsiveHelper responsive) {
    final actions = [
      (
        icon: Icons.qr_code,
        label: 'Pagar com QR',
        onTap: _handlePayWithQr,
      ),
      (
        icon: Icons.qr_code_scanner,
        label: 'Identificar QR',
        onTap: _handleIdentifyQr,
      ),
      (
        icon: Icons.credit_card,
        label: 'Cartões',
        onTap: widget.onOpenVirtualCards,
      ),
      (
        icon: Icons.sync_alt_rounded,
        label: 'Entre cartões',
        onTap: _showCardTransferModal,
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        label: 'Recarregar',
        onTap: _handleTopup,
      ),
      (
        icon: Icons.warning_amber_rounded,
        label: 'Pânico',
        onTap: _isPanicLoading ? () {} : _confirmPanicAction,
      ),
      (
        icon: Icons.qr_code_2_rounded,
        label: 'Meu QR',
        onTap: _handleShowMyQrCode,
      ),
      (
        icon: Icons.more_horiz_rounded,
        label: 'Outros',
        onTap: () {},
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: responsive.scaledHeight(12),
          crossAxisSpacing: responsive.scaledWidth(8),
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _buildCircularActionButton(
            responsive,
            icon: action.icon,
            label: action.label,
            onTap: action.onTap,
          );
        },
      ),
    );
  }

  void _handleTopup() {
    if (widget.onOpenTopup != null) {
      widget.onOpenTopup!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recarga indisponível no momento.')),
    );
  }

  Widget _buildQrCodePreview(String qrCode) {
    final normalized = qrCode.trim();

    if (normalized.startsWith('data:image')) {
      final base64Data = normalized.split(',').last;
      return Image.memory(
        base64Decode(base64Data),
        fit: BoxFit.contain,
      );
    }

    if (normalized.startsWith('http')) {
      return Image.network(
        normalized,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.qr_code_2_rounded,
          size: 140,
        ),
      );
    }

    return SelectableText(
      normalized,
      textAlign: TextAlign.center,
    );
  }

  Future<void> _handleShowMyQrCode() async {
    final apiService = context.read<AppProvider>().apiService;
    final response = await apiService.getMyQrCode();

    if (!mounted) return;

    if (!response.isSuccess ||
        response.data == null ||
        response.data!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.error ?? 'Não foi possível carregar o seu QR Code.',
          ),
        ),
      );
      return;
    }

    final qrCode = response.data!;
    final responsive = ResponsiveHelper(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withAlpha((0.08 * 255).round()),
            ),
          ),
          padding: EdgeInsets.only(
            left: responsive.scaledWidth(24),
            right: responsive.scaledWidth(24),
            top: responsive.scaledHeight(16),
            bottom: MediaQuery.of(context).viewInsets.bottom +
                responsive.scaledHeight(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              Text(
                'Seu QR Code',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(18),
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(12)),
              Container(
                width: responsive.scaledWidth(240),
                height: responsive.scaledWidth(240),
                padding: EdgeInsets.all(responsive.scaledWidth(16)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: _buildQrCodePreview(qrCode),
                  ),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(16)),
              Text(
                'Mostre este QR code quando precisar identificar a sua conta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.72 * 255).round()),
                ),
              ),
              SizedBox(height: responsive.scaledHeight(20)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCardTransferModal() async {
    final provider = context.read<AppProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardTransferModal(
        cards: provider.virtualCards,
        onTransfer: (fromCardId, toCardId, amount) async {
          return await provider.transferBetweenVirtualCards(
            fromCardId: fromCardId,
            toCardId: toCardId,
            amount: amount,
          );
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _handleIdentifyQr() async {
    final qrData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QRScannerModal(
        onCancel: () {},
        onQRScanned: (data) => Navigator.pop(context, data),
      ),
    );

    if (qrData == null) return;
    if (!mounted) return;

    final paymentService = PaymentService();
    final validation = await paymentService.validateQrCode(context, qrData);
    if (!mounted) return;
    if (validation == null) return;

    // Show identification info (without triggering payment)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informações do QR',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('Motorista: ${validation.driverName ?? 'Desconhecido'}'),
            Text('Veículo: ${validation.licensePlate ?? 'Desconhecido'}'),
            Text(
                'Valor: ${validation.amount != null ? '${validation.amount} Kz' : 'N/A'}'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayWithQr() async {
    // Open scanner modal and get scanned data
    final qrData = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QRScannerModal(
        onCancel: () {},
        onQRScanned: (data) => Navigator.pop(context, data),
      ),
    );

    if (qrData == null) return;
    if (!mounted) return;

    // Validate QR via PaymentService
    final paymentService = PaymentService();
    final validation = await paymentService.validateQrCode(context, qrData);
    if (!mounted) return;
    if (validation == null || !validation.valid) {
      // Errors are shown by PaymentService/FeedbackService
      return;
    }

    // Determine amount/origin/destination
    int amount = validation.amount ?? 0;
    String origin = 'Origem';
    String destination = 'Destino';

    // If amount not provided by QR, ask user
    if (amount == 0) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          final amountController = TextEditingController();
          final originController = TextEditingController();
          final destinationController = TextEditingController();
          return AlertDialog(
            title: const Text('Detalhes do Pagamento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor (Kz)'),
                ),
                TextField(
                  controller: originController,
                  decoration: const InputDecoration(labelText: 'Origem'),
                ),
                TextField(
                  controller: destinationController,
                  decoration: const InputDecoration(labelText: 'Destino'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  final a = int.tryParse(amountController.text) ?? 0;
                  Navigator.pop(context, {
                    'amount': a,
                    'origin': originController.text.trim(),
                    'destination': destinationController.text.trim(),
                  });
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (result == null) return;
      amount = (result['amount'] as int?) ?? 0;
      origin = (result['origin'] as String?)?.isNotEmpty == true
          ? result['origin'] as String
          : origin;
      destination = (result['destination'] as String?)?.isNotEmpty == true
          ? result['destination'] as String
          : destination;
    }

    // Show confirmation modal with driver info and amount
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentConfirmationModal(
        driverInfo: validation,
        amount: amount,
        origin: origin,
        destination: destination,
        pinValidator: (pin) async {
          return await PinGuard.validatePin(
            scope: 'payment',
            enteredPin: pin,
            readExpectedPin: () => SecureStorageService().readPin(),
          );
        },
        onSuccess: (_) {
          // Dados já foram invalidados dentro do PaymentConfirmationModal.
        },
        onCancel: () {},
      ),
    );
  }

  Widget _buildCircularActionButton(
    ResponsiveHelper responsive, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: responsive.scaledWidth(64),
            height: responsive.scaledWidth(64),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha((0.1 * 255).round())
                    : Colors.black.withAlpha((0.05 * 255).round()),
                width: 1.5,
              ),
              boxShadow: [
                // Sombra inferior (profundidade)
                BoxShadow(
                  color: isDark
                      ? Colors.black.withAlpha((0.5 * 255).round())
                      : Colors.black.withAlpha((0.15 * 255).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                // Sombra superior (destaque 3D)
                BoxShadow(
                  color: isDark
                      ? Colors.white.withAlpha((0.05 * 255).round())
                      : Colors.white.withAlpha((0.8 * 255).round()),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                  spreadRadius: 0,
                ),
                // Sombra lateral para profundidade
                BoxShadow(
                  color: isDark
                      ? Colors.black.withAlpha((0.3 * 255).round())
                      : Colors.black.withAlpha((0.08 * 255).round()),
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.textDark,
              size: responsive.scaledWidth(28),
            ),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(11),
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withAlpha((0.78 * 255).round()),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
