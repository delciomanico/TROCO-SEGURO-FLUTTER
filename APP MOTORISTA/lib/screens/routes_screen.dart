import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/models/route.dart';
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
  // ========== API INTEGRATION ==========
  static const bool useMockData = false; // ✅ INTEGRADO COM API REAL
  // ===============================

  List<TaxiRoute> routes = [];
  TaxiRoute? selectedRoute;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => isLoading = true);

    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 500));
      routes = _getMockRoutes();
    } else {
      // TODO: Implementar chamada à API
      routes = [];
    }

    setState(() => isLoading = false);
  }

  List<TaxiRoute> _getMockRoutes() {
    return [
      TaxiRoute(
        id: '1',
        name: 'Aeroporto → Centro',
        origin: 'Aeroporto 4 de Fevereiro',
        destination: 'Largo do Kinaxixi',
        trafficStatus: TrafficStatus.moderate,
        trafficReason: 'Obras na via principal',
        activeTaxis: 23,
        distance: 12.5,
        estimatedTime: 25,
        currentTime: 35,
        basePrice: 3500,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      TaxiRoute(
        id: '2',
        name: 'Viana → Maianga',
        origin: 'Viana (Estalagem)',
        destination: 'Maianga',
        trafficStatus: TrafficStatus.heavy,
        trafficReason: 'Acidente na Estrada de Catete',
        activeTaxis: 15,
        distance: 18.2,
        estimatedTime: 30,
        currentTime: 55,
        basePrice: 4000,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      TaxiRoute(
        id: '3',
        name: 'Talatona → Mutamba',
        origin: 'Talatona (Xyami)',
        destination: 'Mutamba',
        trafficStatus: TrafficStatus.normal,
        trafficReason: null,
        activeTaxis: 31,
        distance: 15.0,
        estimatedTime: 28,
        currentTime: 30,
        basePrice: 3800,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
      TaxiRoute(
        id: '4',
        name: 'Cacuaco → Porto de Luanda',
        origin: 'Cacuaco (Vidrul)',
        destination: 'Porto de Luanda',
        trafficStatus: TrafficStatus.blocked,
        trafficReason: 'Manifestação na Avenida Deolinda Rodrigues',
        activeTaxis: 5,
        distance: 22.0,
        estimatedTime: 35,
        currentTime: 90,
        basePrice: 5000,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      TaxiRoute(
        id: '5',
        name: 'Miramar → Ilha de Luanda',
        origin: 'Miramar',
        destination: 'Ilha de Luanda',
        trafficStatus: TrafficStatus.normal,
        trafficReason: null,
        activeTaxis: 42,
        distance: 8.5,
        estimatedTime: 15,
        currentTime: 17,
        basePrice: 2500,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      TaxiRoute(
        id: '6',
        name: 'Benfica → Alvalade',
        origin: 'Benfica',
        destination: 'Alvalade',
        trafficStatus: TrafficStatus.moderate,
        trafficReason: 'Trânsito intenso no horário de pico',
        activeTaxis: 28,
        distance: 10.0,
        estimatedTime: 20,
        currentTime: 28,
        basePrice: 3000,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      TaxiRoute(
        id: '7',
        name: 'Camama → Rangel',
        origin: 'Camama',
        destination: 'Rangel',
        trafficStatus: TrafficStatus.heavy,
        trafficReason: 'Semáforo avariado no cruzamento principal',
        activeTaxis: 12,
        distance: 14.0,
        estimatedTime: 25,
        currentTime: 45,
        basePrice: 3200,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 6)),
      ),
      TaxiRoute(
        id: '8',
        name: 'Kilamba → Belas Shopping',
        origin: 'Centralidade do Kilamba',
        destination: 'Belas Shopping',
        trafficStatus: TrafficStatus.normal,
        trafficReason: null,
        activeTaxis: 35,
        distance: 6.0,
        estimatedTime: 12,
        currentTime: 14,
        basePrice: 2000,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 7)),
      ),
      TaxiRoute(
        id: '9',
        name: 'Golfe → Ingombota',
        origin: 'Golfe II',
        destination: 'Ingombota',
        trafficStatus: TrafficStatus.normal,
        trafficReason: null,
        activeTaxis: 18,
        distance: 9.0,
        estimatedTime: 18,
        currentTime: 20,
        basePrice: 2800,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      TaxiRoute(
        id: '10',
        name: 'Cazenga → Maianga',
        origin: 'Cazenga (Terra Nova)',
        destination: 'Maianga',
        trafficStatus: TrafficStatus.moderate,
        trafficReason: 'Trânsito lento devido ao mercado informal',
        activeTaxis: 20,
        distance: 11.0,
        estimatedTime: 22,
        currentTime: 32,
        basePrice: 3000,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      TaxiRoute(
        id: '11',
        name: 'Zango → Viana',
        origin: 'Zango 0',
        destination: 'Viana Centro',
        trafficStatus: TrafficStatus.heavy,
        trafficReason: 'Congestionamento na entrada de Viana',
        activeTaxis: 8,
        distance: 16.0,
        estimatedTime: 28,
        currentTime: 50,
        basePrice: 3500,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      TaxiRoute(
        id: '12',
        name: 'Sambizanga → Porto',
        origin: 'Sambizanga',
        destination: 'Porto de Luanda',
        trafficStatus: TrafficStatus.normal,
        trafficReason: null,
        activeTaxis: 25,
        distance: 7.0,
        estimatedTime: 14,
        currentTime: 16,
        basePrice: 2200,
        lastUpdate: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
    ];
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
    final pageGradient = isDark
        ? AppColors.darkScreenGradient
        : const LinearGradient(
            colors: [AppColors.lightBackground, AppColors.lightSurface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Rotas'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightBackground,
        foregroundColor: isDark ? Colors.white : AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadRoutes,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomDock
          ? const DriverBottomDock(
              selectedTab: DriverDockTab.menu,
            )
          : null,
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.adaptiveAccent(context)),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(responsive.responsivePadding()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown de seleção de rota
                    _buildRouteSelector(responsive),
                    SizedBox(height: responsive.scaledHeight(24)),

                    // Detalhes da rota selecionada
                    if (selectedRoute != null) ...[
                      _buildRouteDetails(responsive),
                    ] else ...[
                      _buildEmptyState(responsive),
                    ],
                  ],
                ),
              ),
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
            color: Colors.black.withOpacity(0.05),
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
              color: AppColors.cardBorder.withOpacity(0.3),
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
                              color: statusColor.withOpacity(0.1),
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
          colors: [statusColor, statusColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
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
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding()),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsive.scaledWidth(16)),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
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
                  color: const Color(0xFF2ECC71).withOpacity(0.1),
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
                  color: const Color(0xFFE74C3C).withOpacity(0.1),
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
        color: statusColor.withOpacity(0.1),
        borderRadius:
            BorderRadius.circular(responsive.responsiveBorderRadius()),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(responsive.scaledWidth(12)),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
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

  Widget _buildEmptyState(ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding() * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: responsive.scaledWidth(80),
            color: AppColors.textSecondary.withOpacity(0.3),
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
              color: AppColors.textSecondary.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

