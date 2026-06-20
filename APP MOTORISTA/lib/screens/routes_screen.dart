import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/models/route.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/widgets/driver_bottom_dock.dart';
import 'package:intl/intl.dart';

class RoutesScreen extends StatefulWidget {
  final bool showBottomDock;

  const RoutesScreen({
    super.key,
    this.showBottomDock = true,
  });

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final ApiService _api = ApiService();

  List<TaxiRoute> routes = [];
  TaxiRoute? selectedRoute;
  bool isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    try {
      await _api.loadTokens();
      final result = await _api.getRoutes();
      if (result.isSuccess && result.data != null) {
        setState(() {
          routes = result.data!;
          isLoading = false;
        });
      } else {
        setState(() {
          routes = [];
          _errorMessage = result.error ?? 'Não foi possível carregar as rotas.';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar rotas: $e');
      setState(() {
        routes = [];
        _errorMessage = 'Erro inesperado ao carregar rotas.';
        isLoading = false;
      });
    }
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    return 'Há ${diff.inDays} dias';
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

  IconData _getStatusIcon(TrafficStatus status) {
    switch (status) {
      case TrafficStatus.normal:
        return Icons.check_circle_rounded;
      case TrafficStatus.moderate:
        return Icons.warning_rounded;
      case TrafficStatus.heavy:
        return Icons.traffic_rounded;
      case TrafficStatus.blocked:
        return Icons.block_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      bottomNavigationBar: widget.showBottomDock
          ? const DriverBottomDock(
              selectedTab: DriverDockTab.menu,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryGold,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadRoutes,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildFlatHeader(responsive, isDark),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(responsive.responsivePadding()),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              _buildErrorBanner(responsive),
                              SizedBox(height: responsive.scaledHeight(16)),
                            ],
                            _buildRouteSelector(responsive),
                            SizedBox(height: responsive.scaledHeight(24)),
                            if (selectedRoute != null)
                              _buildRouteDetails(responsive)
                            else
                              _buildEmptyState(responsive),
                            SizedBox(height: responsive.scaledHeight(110)),
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

  Widget _buildFlatHeader(ResponsiveHelper responsive, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(14),
      ),
      child: Row(
        children: [
          SizedBox(width: responsive.scaledWidth(38)),
          Expanded(
            child: Center(
              child: Text(
                'Rotas',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(17),
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadRoutes,
            child: Container(
              width: responsive.scaledWidth(38),
              height: responsive.scaledWidth(38),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: responsive.scaledWidth(20),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSelector(ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding()),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                color: AppColors.accent,
                size: responsive.scaledWidth(24),
              ),
              SizedBox(width: responsive.scaledWidth(12)),
              Text(
                'Selecione uma Rota',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(16),
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBorder.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TaxiRoute>(
                value: selectedRoute,
                isExpanded: true,
                hint: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scaledWidth(16),
                  ),
                  child: Text(
                    'Escolha uma rota para ver os detalhes',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: responsive.responsiveFontSize(14),
                    ),
                  ),
                ),
                icon: Padding(
                  padding: EdgeInsets.only(right: responsive.scaledWidth(12)),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
                dropdownColor: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                items: routes.map((route) {
                  final statusColor = _getStatusColor(route.trafficStatus);
                  return DropdownMenuItem<TaxiRoute>(
                    value: route,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.scaledWidth(16),
                        vertical: responsive.scaledHeight(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: responsive.scaledWidth(12)),
                          Flexible(
                            child: Text(
                              route.name,
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(14),
                                fontWeight: FontWeight.w500,
                                color: AppColors.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: responsive.scaledWidth(8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.scaledWidth(8),
                              vertical: responsive.scaledHeight(2),
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              route.trafficStatus.label,
                              style: TextStyle(
                                fontSize: responsive.responsiveFontSize(10),
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (route) {
                  setState(() => selectedRoute = route);
                },
              ),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          Text(
            '${routes.length} rotas disponíveis',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(12),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetails(ResponsiveHelper responsive) {
    final route = selectedRoute!;
    final statusColor = _getStatusColor(route.trafficStatus);

    return Column(
      children: [
        // Card de Status Principal
        _buildStatusCard(responsive, route, statusColor),
        SizedBox(height: responsive.scaledHeight(16)),

        // Card de Táxis Ativos
        _buildTaxisCard(responsive, route),
        SizedBox(height: responsive.scaledHeight(16)),

        // Card de Percurso
        _buildRouteInfoCard(responsive, route),
        SizedBox(height: responsive.scaledHeight(16)),

        // Card de Tempo e Distância
        _buildTimeDistanceCard(responsive, route, statusColor),

        // Card de Motivo (se houver)
        if (route.trafficReason != null && route.trafficReason!.isNotEmpty) ...[
          SizedBox(height: responsive.scaledHeight(16)),
          _buildReasonCard(responsive, route, statusColor),
        ],
      ],
    );
  }

  Widget _buildStatusCard(
      ResponsiveHelper responsive, TaxiRoute route, Color statusColor) {
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding() * 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(route.trafficStatus),
            color: Colors.white,
            size: responsive.scaledWidth(56),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          Text(
            route.trafficStatus.label.toUpperCase(),
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(24),
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          Text(
            'Atualizado ${_getTimeAgo(route.lastUpdate)}',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(12),
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxisCard(ResponsiveHelper responsive, TaxiRoute route) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding()),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.textDark,
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsive.scaledWidth(16)),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_taxi_rounded,
              color: AppColors.accent,
              size: responsive.scaledWidth(32),
            ),
          ),
          SizedBox(width: responsive.scaledWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Táxis Trabalhando',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(4)),
                Text(
                  '${route.activeTaxis}',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(36),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'nesta rota',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: responsive.scaledHeight(4)),
              Text(
                'agora',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(14),
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard(ResponsiveHelper responsive, TaxiRoute route) {
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding()),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Origem
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scaledWidth(8)),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  color: const Color(0xFF2ECC71),
                  size: responsive.scaledWidth(20),
                ),
              ),
              SizedBox(width: responsive.scaledWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORIGEM',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(10),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: responsive.scaledHeight(2)),
                    Text(
                      route.origin,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Linha conectora
          Padding(
            padding: EdgeInsets.only(
              left: responsive.scaledWidth(18),
              top: responsive.scaledHeight(4),
              bottom: responsive.scaledHeight(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: responsive.scaledHeight(30),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2ECC71),
                        Color(0xFFE74C3C),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Destino
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scaledWidth(8)),
                decoration: BoxDecoration(
                  color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: const Color(0xFFE74C3C),
                  size: responsive.scaledWidth(20),
                ),
              ),
              SizedBox(width: responsive.scaledWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DESTINO',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(10),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: responsive.scaledHeight(2)),
                    Text(
                      route.destination,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDistanceCard(
      ResponsiveHelper responsive, TaxiRoute route, Color statusColor) {
    return Row(
      children: [
        // Distância
        Expanded(
          child: Container(
            padding: EdgeInsets.all(responsive.responsivePadding()),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  BorderRadius.circular(responsive.responsiveBorderRadius()),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.straighten_rounded,
                  color: AppColors.accent,
                  size: responsive.scaledWidth(28),
                ),
                SizedBox(height: responsive.scaledHeight(8)),
                Text(
                  '${route.distance.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(20),
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  'Distância',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: responsive.scaledWidth(12)),

        // Tempo atual
        Expanded(
          child: Container(
            padding: EdgeInsets.all(responsive.responsivePadding()),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  BorderRadius.circular(responsive.responsiveBorderRadius()),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: route.delay > 5 ? statusColor : AppColors.accent,
                  size: responsive.scaledWidth(28),
                ),
                SizedBox(height: responsive.scaledHeight(8)),
                Text(
                  '${route.currentTime} min',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(20),
                    fontWeight: FontWeight.w800,
                    color: route.delay > 5 ? statusColor : AppColors.text,
                  ),
                ),
                Text(
                  route.delay > 5 ? '+${route.delay} min' : 'Tempo atual',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color:
                        route.delay > 5 ? statusColor : AppColors.textSecondary,
                    fontWeight:
                        route.delay > 5 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: responsive.scaledWidth(12)),

        // Preço
        Expanded(
          child: Container(
            padding: EdgeInsets.all(responsive.responsivePadding()),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  BorderRadius.circular(responsive.responsiveBorderRadius()),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.payments_rounded,
                  color: AppColors.accent,
                  size: responsive.scaledWidth(28),
                ),
                SizedBox(height: responsive.scaledHeight(8)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatCurrency(route.basePrice),
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(16),
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  'Preço base',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonCard(
      ResponsiveHelper responsive, TaxiRoute route, Color statusColor) {
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding()),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsive.scaledWidth(12)),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.info_rounded,
              color: statusColor,
              size: responsive.scaledWidth(24),
            ),
          ),
          SizedBox(width: responsive.scaledWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOTIVO DO TRÂNSITO',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(10),
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(4)),
                Text(
                  route.trafficReason!,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ResponsiveHelper responsive) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.responsivePadding()),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded,
              color: Colors.red.shade600, size: responsive.scaledWidth(20)),
          SizedBox(width: responsive.scaledWidth(10)),
          Expanded(
            child: Text(
              _errorMessage ?? 'Não foi possível carregar as rotas.',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(13),
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadRoutes,
            child: Text(
              'Tentar\nnovamente',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(11),
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding() * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: responsive.scaledWidth(80),
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          SizedBox(height: responsive.scaledHeight(24)),
          Text(
            'Selecione uma rota',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(18),
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          Text(
            'Escolha uma rota no menu acima para ver\nos detalhes do trânsito e táxis ativos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
