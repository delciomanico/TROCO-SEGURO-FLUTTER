import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/models/trip.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:troco_seguro_motorista/widgets/driver_bottom_dock.dart';

class TripsScreen extends StatefulWidget {
  final bool showBottomDock;

  const TripsScreen({
    super.key,
    this.showBottomDock = true,
  });

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip> trips = [];
  String searchQuery = '';
  bool isLoading = true;
  final ApiService _api = ApiService();

  static const bool useMockData = false; // ✅ INTEGRADO COM API REAL

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      if (useMockData) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() => trips = Constants.mockTrips);
        return;
      }

      await _api.loadTokens();

      final tripsResult = await _api.getTrips();
      if (tripsResult.isSuccess && tripsResult.data != null) {
        if (mounted) {
          setState(() => trips = tripsResult.data!);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'ts_driver_trips',
            json.encode(
                (tripsResult.data ?? []).map((t) => t.toJson()).toList()));
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final tripsJson = prefs.getString('ts_driver_trips');
      if (tripsJson != null && tripsJson.trim().isNotEmpty) {
        try {
          final decoded = (json.decode(tripsJson) as List)
              .map((trip) => Trip.fromJson(trip))
              .toList();
          if (mounted) {
            setState(() => trips = decoded);
          }
          return;
        } catch (_) {
          await prefs.remove('ts_driver_trips');
        }
      }

      if (mounted) {
        setState(() => trips = Constants.mockTrips);
      }
    } catch (e) {
      debugPrint('Erro ao carregar viagens: $e');
      if (mounted && trips.isEmpty) {
        setState(() => trips = Constants.mockTrips);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<Trip> get filteredTrips {
    return trips.where((trip) {
      final matchesSearch = trip.destination
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          trip.passengerName.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'in_progress':
        return AppColors.pending;
      default:
        return AppColors.textMutedOnDark;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      case 'in_progress':
        return 'Em andamento';
      default:
        return 'Desconhecido';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Viagens'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightBackground,
        foregroundColor: isDark ? Colors.white : AppColors.textDark,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${trips.length} viagens',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      bottomNavigationBar: widget.showBottomDock
          ? const DriverBottomDock(
              selectedTab: DriverDockTab.wallet,
            )
          : null,
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadTrips,
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.adaptiveAccent(context),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: responsive.scaledHeight(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSearchAndFilters(responsive),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: responsive.scaledHeight(16),
                                  ),
                                  child: _buildTripsList(responsive),
                                ),
                                SizedBox(height: responsive.scaledHeight(12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(20),
          vertical: responsive.scaledHeight(16),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textColor,
                size: responsive.scaledWidth(20),
              ),
              tooltip: 'Voltar',
            ),
            Container(
              width: responsive.scaledWidth(44),
              height: responsive.scaledWidth(44),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppColors.textDark.withOpacity(0.1),
              ),
              child: Icon(
                Icons.local_taxi_rounded,
                color: isDark
                    ? AppColors.adaptiveAccent(context)
                    : AppColors.textDark,
                size: responsive.scaledWidth(24),
              ),
            ),
            SizedBox(width: responsive.scaledWidth(12)),
            Expanded(
              child: Text(
                'Viagens',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(20),
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.scaledWidth(12),
                vertical: responsive.scaledHeight(6),
              ),
              decoration: BoxDecoration(
                color: AppColors.adaptiveAccent(context)
                    .withOpacity(isDark ? 0.2 : 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${trips.length} viagens',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: isDark
                      ? AppColors.adaptiveAccent(context)
                      : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scaledWidth(16),
              vertical: responsive.scaledHeight(4),
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              style:
                  TextStyle(color: isDark ? Colors.white : AppColors.textDark),
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar passagem...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: responsive.responsiveFontSize(14),
                ),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.grey.shade400),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList(ResponsiveHelper responsive) {
    if (filteredTrips.isEmpty) {
      return _buildEmptyState(responsive);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Column(
        children: filteredTrips
            .map((trip) => _buildTripCard(responsive, trip))
            .toList(),
      ),
    );
  }

  Widget _buildEmptyState(ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(60)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_taxi_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          Text(
            'Nenhuma viagem encontrada',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(16),
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          Text(
            'Suas viagens aparecerão aqui',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(ResponsiveHelper responsive, Trip trip) {
    final statusColor = _getStatusColor(trip.status);
    final statusLabel = _getStatusLabel(trip.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return Container(
      margin: EdgeInsets.only(bottom: responsive.scaledHeight(12)),
      padding: EdgeInsets.all(responsive.scaledWidth(16)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: responsive.scaledWidth(44),
                height: responsive.scaledWidth(44),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveAccent(context).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.adaptiveAccent(context),
                  size: responsive.scaledWidth(24),
                ),
              ),
              SizedBox(width: responsive.scaledWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.passengerName,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: responsive.scaledHeight(2)),
                    Text(
                      '${trip.date} às ${trip.time}',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(11),
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.scaledWidth(10),
                  vertical: responsive.scaledHeight(4),
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(10),
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          // Route
          Container(
            padding: EdgeInsets.all(responsive.scaledWidth(12)),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            width: 2),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 20,
                      color: Colors.grey.shade300,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.adaptiveAccent(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            width: 2),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.origin,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(12),
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: responsive.scaledHeight(12)),
                      Text(
                        trip.destination,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(12),
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (trip.rating != null)
                Row(
                  children: [
                    Icon(Icons.star,
                        color: AppColors.adaptiveAccent(context), size: 16),
                    SizedBox(width: responsive.scaledWidth(4)),
                    Text(
                      trip.rating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(12),
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(),
              Text(
                '+${_formatCurrency(trip.amount)}',
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(16),
                  fontWeight: FontWeight.w800,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
