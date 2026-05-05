import 'package:flutter/material.dart';
import 'package:troco_seguro/models/trip.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:intl/intl.dart';
import 'package:troco_seguro/utils/constants.dart';

import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshTrips();
    });
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)}kzs';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      case 'pending':
        return 'Pendente';
      default:
        return 'Desconhecido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final provider = context.watch<AppProvider>();
    final trips = provider.trips;
    final isLoading = provider.isLoadingTrips;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statsCompleted = trips.where((t) => t.status == 'completed').length;
    final statsTotal = trips.fold<int>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).cardColor : AppColors.lightCard,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async =>
                  await context.read<AppProvider>().refreshTrips(),
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scaledWidth(20),
                    vertical: responsive.scaledHeight(20),
                  ),
                  children: [
                    _buildHeader(responsive, statsCompleted, statsTotal),
                    SizedBox(height: responsive.scaledHeight(20)),
                    _buildTimelineHeader(responsive),
                    SizedBox(height: responsive.scaledHeight(12)),
                    _buildTripsList(responsive, trips),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(
      ResponsiveHelper responsive, int completed, int totalSpent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(responsive.scaledWidth(20)),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withAlpha((0.10 * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.06 * 255).round()),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scaledWidth(12)),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: AppColors.primaryGold,
                  size: responsive.scaledWidth(28),
                ),
              ),
              SizedBox(width: responsive.scaledWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histórico de Viagens',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(20),
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: responsive.scaledHeight(4)),
                    Text(
                      'Suas jornadas registradas',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(12),
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textDark.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          Divider(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withAlpha((0.10 * 255).round()),
            thickness: 1,
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  responsive,
                  Icons.check_circle_rounded,
                  'Concluídas',
                  '$completed',
                  Colors.green,
                ),
              ),
              Container(
                width: 1,
                height: responsive.scaledHeight(40),
                color: AppColors.primaryGold.withOpacity(0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  responsive,
                  Icons.payments_rounded,
                  'Total Gasto',
                  _formatCurrency(totalSpent),
                  AppColors.primaryGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ResponsiveHelper responsive,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: color, size: responsive.scaledWidth(24)),
        SizedBox(height: responsive.scaledHeight(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(11),
            color: isDark
                ? Colors.white.withOpacity(0.6)
                : AppColors.textDark.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: responsive.scaledHeight(4)),
        Text(
          value,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(16),
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineHeader(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withAlpha((0.45 * 255).round()),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: responsive.scaledWidth(12)),
        Text(
          'Viagens recentes',
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(16),
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTripsList(ResponsiveHelper responsive, List<Trip> trips) {
    if (trips.isEmpty) return _buildEmptyState(responsive);
    return Column(
      children: trips.asMap().entries.map((entry) {
        final index = entry.key;
        final trip = entry.value;
        final isLast = index == trips.length - 1;
        return _buildTripItem(responsive, trip, isLast);
      }).toList(),
    );
  }

  Widget _buildEmptyState(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(60)),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scaledWidth(20)),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route_outlined,
                size: responsive.scaledWidth(48),
                color: AppColors.primaryGold.withOpacity(0.5),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            Text(
              'Nenhuma viagem registrada',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(16),
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(8)),
            Text(
              'Suas viagens aparecerão aqui',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripItem(ResponsiveHelper responsive, Trip trip, bool isLast) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textLight : AppColors.textDark;
    final statusColor = _getStatusColor(trip.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: responsive.scaledWidth(10),
              height: responsive.scaledWidth(10),
              decoration: BoxDecoration(
                color: statusColor.withAlpha((0.85 * 255).round()),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: responsive.scaledHeight(72),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.14 * 255).round()),
              ),
          ],
        ),
        SizedBox(width: responsive.scaledWidth(12)),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: responsive.scaledHeight(14)),
            padding: EdgeInsets.all(responsive.scaledWidth(14)),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.08 * 255).round()),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).round()),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${trip.origin} → ${trip.destination}',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(14),
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatCurrency(trip.amount),
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.scaledHeight(8)),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: responsive.scaledWidth(14),
                      color: primaryText.withAlpha((0.65 * 255).round()),
                    ),
                    SizedBox(width: responsive.scaledWidth(6)),
                    Expanded(
                      child: Text(
                        trip.driverName ?? 'Motorista',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(11),
                          color: primaryText.withAlpha((0.72 * 255).round()),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.scaledWidth(8),
                        vertical: responsive.scaledHeight(3),
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusLabel(trip.status),
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(10),
                          color: statusColor.withAlpha((0.9 * 255).round()),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.scaledHeight(6)),
                Text(
                  '${trip.date} • ${trip.time}',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(10),
                    color: primaryText.withAlpha((0.6 * 255).round()),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
