import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:troco_seguro_motorista/models/qr_config.dart';
import 'package:troco_seguro_motorista/models/route.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:intl/intl.dart';

class QrConfigModal extends StatefulWidget {
  final QrConfig currentConfig;
  final Function(QrConfig) onConfigSaved;

  const QrConfigModal({
    super.key,
    required this.currentConfig,
    required this.onConfigSaved,
  });

  static Future<QrConfig?> show(
    BuildContext context, {
    required QrConfig currentConfig,
    required Function(QrConfig) onConfigSaved,
  }) {
    return showModalBottomSheet<QrConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QrConfigModal(
        currentConfig: currentConfig,
        onConfigSaved: onConfigSaved,
      ),
    );
  }

  @override
  State<QrConfigModal> createState() => _QrConfigModalState();
}

class _QrConfigModalState extends State<QrConfigModal> {
  final ApiService _api = ApiService();

  late TextEditingController _fareController;
  TaxiRoute? _selectedRoute;
  List<TaxiRoute> _routes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fareController = TextEditingController(
      text: widget.currentConfig.currentFare > 0
          ? widget.currentConfig.currentFare.toString()
          : '',
    );
    _loadRoutes();
  }

  @override
  void dispose() {
    _fareController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _api.loadTokens();
      final result = await _api.getRoutes();
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        _routes = result.data!;
      } else {
        // Sem rotas na API — lista vazia (sem fallback de mock)
        _routes = [];
        if (result.error != null) {
          _errorMessage = result.error;
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar rotas: $e');
      _routes = [];
      _errorMessage = 'Não foi possível carregar as rotas.';
    }

    // Selecionar rota atual se existir
    if (widget.currentConfig.activeRouteId != null && _routes.isNotEmpty) {
      try {
        _selectedRoute = _routes.firstWhere(
          (r) => r.id == widget.currentConfig.activeRouteId,
        );
      } catch (_) {
        _selectedRoute = null;
      }
    }

    setState(() => _isLoading = false);
  }



  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  Color _getStatusColor(TrafficStatus status) {
    switch (status) {
      case TrafficStatus.normal:
        return const Color(0xFF2ECC71);
      case TrafficStatus.moderate:
        return AppColors.accent;
      case TrafficStatus.heavy:
        return const Color(0xFFE67E22);
      case TrafficStatus.blocked:
        return const Color(0xFFE74C3C);
    }
  }

  void _saveConfig() {
    final fare = int.tryParse(_fareController.text) ?? 0;

    final newConfig = widget.currentConfig.copyWith(
      activeRouteId: _selectedRoute?.id,
      activeRouteName: _selectedRoute?.name,
      currentFare: fare,
      lastUpdate: DateTime.now(),
    );

    widget.onConfigSaved(newConfig);
    Navigator.pop(context, newConfig);
  }

  void _useSuggestedFare() {
    if (_selectedRoute != null) {
      _fareController.text = _selectedRoute!.basePrice.toString();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              children: [
                Container(
                  padding: EdgeInsets.all(responsive.scaledWidth(10)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent,
                        AppColors.accent.withOpacity(0.7)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: responsive.scaledWidth(22),
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configurar QR Code',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(18),
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Defina a rota e valor atual',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(12),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          Divider(color: AppColors.cardBorder, height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(responsive.responsivePadding()),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info card
                        Container(
                          padding:
                              EdgeInsets.all(responsive.responsivePadding()),
                          decoration: BoxDecoration(
                            color: AppColors.darkBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.darkBlue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.darkBlue,
                                size: responsive.scaledWidth(24),
                              ),
                              SizedBox(width: responsive.scaledWidth(12)),
                              Expanded(
                                child: Text(
                                  'O QR Code é único e permanente. Apenas a rota e valor são atualizados quando o cliente escanear.',
                                  style: TextStyle(
                                    fontSize: responsive.responsiveFontSize(12),
                                    color: AppColors.darkBlue,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: responsive.scaledHeight(24)),

                        // Rota selection
                        Text(
                          'ROTA ATUAL',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(11),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: responsive.scaledHeight(8)),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TaxiRoute>(
                              value: _selectedRoute,
                              isExpanded: true,
                              hint: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: responsive.scaledWidth(16),
                                ),
                                child: Text(
                                  'Selecione a rota que está trabalhando',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: responsive.responsiveFontSize(14),
                                  ),
                                ),
                              ),
                              icon: Padding(
                                padding: EdgeInsets.only(
                                    right: responsive.scaledWidth(12)),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              dropdownColor: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              items: _routes.map((route) {
                                final statusColor =
                                    _getStatusColor(route.trafficStatus);
                                return DropdownMenuItem<TaxiRoute>(
                                  value: route,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: responsive.scaledWidth(16),
                                      vertical: responsive.scaledHeight(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(
                                            width: responsive.scaledWidth(10)),
                                        Flexible(
                                          child: Text(
                                            route.name,
                                            style: TextStyle(
                                              fontSize: responsive
                                                  .responsiveFontSize(14),
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.text,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                            width: responsive.scaledWidth(8)),
                                        Text(
                                          _formatCurrency(route.basePrice),
                                          style: TextStyle(
                                            fontSize: responsive
                                                .responsiveFontSize(12),
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (route) {
                                setState(() => _selectedRoute = route);
                              },
                            ),
                          ),
                        ),

                        // Route info card
                        if (_selectedRoute != null) ...[
                          SizedBox(height: responsive.scaledHeight(12)),
                          Container(
                            padding:
                                EdgeInsets.all(responsive.responsivePadding()),
                            decoration: BoxDecoration(
                              color:
                                  _getStatusColor(_selectedRoute!.trafficStatus)
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(
                                        _selectedRoute!.trafficStatus)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.route_rounded,
                                  color: _getStatusColor(
                                      _selectedRoute!.trafficStatus),
                                  size: responsive.scaledWidth(20),
                                ),
                                SizedBox(width: responsive.scaledWidth(10)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_selectedRoute!.origin} → ${_selectedRoute!.destination}',
                                        style: TextStyle(
                                          fontSize:
                                              responsive.responsiveFontSize(12),
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.text,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                      SizedBox(
                                          height: responsive.scaledHeight(2)),
                                      Text(
                                        '${_selectedRoute!.distance} km • ${_selectedRoute!.currentTime} min • ${_selectedRoute!.trafficStatus.label}',
                                        style: TextStyle(
                                          fontSize:
                                              responsive.responsiveFontSize(11),
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: responsive.scaledHeight(24)),

                        // Fare input
                        Text(
                          'VALOR DA CORRIDA',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(11),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: responsive.scaledHeight(8)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _fareController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: TextStyle(
                                  fontSize: responsive.responsiveFontSize(24),
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.darkBlue,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: 'Kz',
                                  suffixStyle: TextStyle(
                                    fontSize: responsive.responsiveFontSize(16),
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkBlue,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: AppColors.cardBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppColors.accent, width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: responsive.scaledWidth(16),
                                    vertical: responsive.scaledHeight(16),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            if (_selectedRoute != null) ...[
                              SizedBox(width: responsive.scaledWidth(12)),
                              ElevatedButton(
                                onPressed: _useSuggestedFare,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.accent.withOpacity(0.1),
                                  foregroundColor: AppColors.accent,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: responsive.scaledWidth(12),
                                    vertical: responsive.scaledHeight(16),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color:
                                            AppColors.accent.withOpacity(0.3)),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Sugerido',
                                      style: TextStyle(
                                        fontSize:
                                            responsive.responsiveFontSize(10),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(
                                          _selectedRoute!.basePrice),
                                      style: TextStyle(
                                        fontSize:
                                            responsive.responsiveFontSize(12),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Quick fare buttons
                        SizedBox(height: responsive.scaledHeight(16)),
                        Text(
                          'VALORES RÁPIDOS',
                          style: TextStyle(
                            fontSize: responsive.responsiveFontSize(11),
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: responsive.scaledHeight(8)),
                        Wrap(
                          spacing: responsive.scaledWidth(8),
                          runSpacing: responsive.scaledHeight(8),
                          children: [
                            1000,
                            1500,
                            2000,
                            2500,
                            3000,
                            3500,
                            4000,
                            5000
                          ]
                              .map((value) =>
                                  _buildQuickFareButton(responsive, value))
                              .toList(),
                        ),

                        SizedBox(height: responsive.scaledHeight(32)),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveConfig,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: responsive.scaledHeight(16),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded,
                                    size: responsive.scaledWidth(20)),
                                SizedBox(width: responsive.scaledWidth(8)),
                                Text(
                                  'SALVAR CONFIGURAÇÕES',
                                  style: TextStyle(
                                    fontSize: responsive.responsiveFontSize(14),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: responsive.scaledHeight(16)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFareButton(ResponsiveHelper responsive, int value) {
    final isSelected = _fareController.text == value.toString();
    return GestureDetector(
      onTap: () {
        _fareController.text = value.toString();
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(16),
          vertical: responsive.scaledHeight(10),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.cardBorder,
          ),
        ),
        child: Text(
          _formatCurrency(value),
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(12),
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}
