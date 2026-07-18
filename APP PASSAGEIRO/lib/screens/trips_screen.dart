import 'package:flutter/material.dart';
import 'package:troco_seguro/models/trip.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:intl/intl.dart';
import 'package:troco_seguro/utils/constants.dart';

import 'package:provider/provider.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/services/api_service.dart' show ApiService, TripStats;
import 'package:troco_seguro/widgets/ratings_history_modal.dart';
import 'package:troco_seguro/widgets/rating_modal.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  TripStats? _apiStats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final result = await ApiService().getTripStats();
    if (result.isSuccess && result.data != null && mounted) {
      setState(() => _apiStats = result.data);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Trip> _filtered(List<Trip> trips) {
    if (_searchQuery.isEmpty) return trips;
    final q = _searchQuery.toLowerCase();
    return trips.where((t) {
      return t.origin.toLowerCase().contains(q) ||
          t.destination.toLowerCase().contains(q) ||
          t.driverName.toLowerCase().contains(q);
    }).toList();
  }

  String _fmt(int amount) =>
      '${NumberFormat('#,##0', 'pt_AO').format(amount)} Kz';

  Color _statusColor(String status) {
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

  String _statusLabel(String status) {
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

    final filtered = _filtered(trips);
    final completed = _apiStats?.totalTrips ?? trips.where((t) => t.status == 'completed').length;
    final totalSpent = _apiStats?.totalSpentMonth ?? trips.fold<int>(0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark, responsive),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentOf(context)))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await context.read<AppProvider>().refreshTrips();
                        await _loadStats();
                      },
                      color: AppColors.accentOf(context),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          responsive.scaledWidth(20),
                          responsive.scaledHeight(4),
                          responsive.scaledWidth(20),
                          responsive.scaledHeight(100),
                        ),
                        children: [
                          _buildStatsRow(isDark, responsive, completed,
                              totalSpent),
                          SizedBox(height: responsive.scaledHeight(24)),
                          _buildSectionLabel(isDark, responsive),
                          SizedBox(height: responsive.scaledHeight(12)),
                          filtered.isEmpty
                              ? _buildEmptyState(isDark, responsive)
                              : _buildTripsList(isDark, responsive, filtered),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fixed header ────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, ResponsiveHelper responsive) {
    return Container(
      color: isDark ? AppColors.darkBackground : Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(10),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: _showSearch
            ? Row(
                key: const ValueKey('search'),
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      autofocus: true,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textDark,
                        fontSize: responsive.responsiveFontSize(14),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar viagens...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.38)
                              : Colors.black.withValues(alpha: 0.32),
                          fontSize: responsive.responsiveFontSize(14),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.accentOf(context),
                          size: responsive.scaledWidth(20),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.04),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 11),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                            color:
                                AppColors.accentOf(context).withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(8)),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSearch = false;
                        _searchQuery = '';
                      });
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                    },
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
                        Icons.close_rounded,
                        size: responsive.scaledWidth(18),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.textDark.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('title'),
                children: [
                  Text(
                    'Viagens',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(22),
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  // Botão: histórico de avaliações
                  GestureDetector(
                    onTap: () {
                      final userId =
                          context.read<AppProvider>().user?.id;
                      if (userId != null) {
                        RatingsHistoryModal.show(context, userId: userId);
                      }
                    },
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
                        Icons.star_outline_rounded,
                        size: responsive.scaledWidth(20),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scaledWidth(8)),
                  GestureDetector(
                    onTap: () => setState(() => _showSearch = true),
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
                        Icons.search_rounded,
                        size: responsive.scaledWidth(20),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Stats ───────────────────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isDark, ResponsiveHelper responsive, int completed,
      int totalSpent) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(4),
        vertical: responsive.scaledHeight(16),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              isDark,
              responsive,
              Icons.check_circle_outline_rounded,
              _apiStats != null ? 'Total viagens' : 'Concluídas',
              '$completed',
              Colors.green,
            ),
          ),
          Container(
            width: 1,
            height: responsive.scaledHeight(36),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
          ),
          Expanded(
            child: _buildStatItem(
              isDark,
              responsive,
              Icons.payments_outlined,
              _apiStats != null ? 'Kz este mês' : 'Total gasto',
              _fmt(totalSpent),
              AppColors.accentOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    bool isDark,
    ResponsiveHelper responsive,
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: iconColor, size: responsive.scaledWidth(22)),
        SizedBox(height: responsive.scaledHeight(6)),
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(11),
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.45),
          ),
        ),
        SizedBox(height: responsive.scaledHeight(3)),
        Text(
          value,
          style: TextStyle(
            fontSize: responsive.responsiveFontSize(15),
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  // ── Section label ───────────────────────────────────────────────────────────
  Widget _buildSectionLabel(bool isDark, ResponsiveHelper responsive) {
    return Text(
      'RECENTES',
      style: TextStyle(
        fontSize: responsive.responsiveFontSize(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.35),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark, ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(60)),
      child: Center(
        child: Column(
          children: [
            Container(
              width: responsive.scaledWidth(72),
              height: responsive.scaledWidth(72),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                border: Border.all(
                  color: AppColors.accentOf(context).withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.route_outlined,
                size: responsive.scaledWidth(32),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            Text(
              'Nenhuma viagem',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(16),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(6)),
            Text(
              'As suas viagens aparecerão aqui',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trips list ──────────────────────────────────────────────────────────────
  Widget _buildTripsList(
      bool isDark, ResponsiveHelper responsive, List<Trip> trips) {
    return Column(
      children: trips.asMap().entries.map((e) {
        return _buildTripItem(isDark, responsive, e.value,
            isLast: e.key == trips.length - 1);
      }).toList(),
    );
  }

  Widget _buildTripItem(
    bool isDark,
    ResponsiveHelper responsive,
    Trip trip, {
    required bool isLast,
  }) {
    final statusColor = _statusColor(trip.status);
    final textPrimary = isDark ? Colors.white : AppColors.textDark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        Column(
          children: [
            Container(
              width: responsive.scaledWidth(9),
              height: responsive.scaledWidth(9),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: responsive.scaledHeight(74),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
          ],
        ),
        SizedBox(width: responsive.scaledWidth(12)),
        // Card
        Expanded(
          child: GestureDetector(
          onTap: () => _showTripDetail(trip, isDark),
          child: Container(
            margin:
                EdgeInsets.only(bottom: responsive.scaledHeight(12)),
            padding: EdgeInsets.all(responsive.scaledWidth(14)),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: responsive.scaledWidth(14),
                      color: textPrimary,
                    ),
                    SizedBox(width: responsive.scaledWidth(5)),
                    Expanded(
                      child: Text(
                        trip.driverName,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(13),
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: responsive.scaledWidth(8)),
                    Text(
                      _fmt(trip.amount),
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(13),
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: responsive.scaledHeight(7)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scaledWidth(8),
                    vertical: responsive.scaledHeight(3),
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _statusLabel(trip.status),
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(10),
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: responsive.scaledHeight(5)),
                Row(
                  children: [
                    Text(
                      '${trip.date} • ${trip.time}',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(10),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (trip.rating != null) ...[
                      SizedBox(width: responsive.scaledWidth(10)),
                      Icon(
                        Icons.star_rounded,
                        size: responsive.scaledWidth(12),
                        color: AppColors.accentOf(context),
                      ),
                      SizedBox(width: responsive.scaledWidth(2)),
                      Text(
                        trip.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(10),
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }

  void _showTripDetail(Trip trip, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final statusColor = _statusColor(trip.status);
    final statusLabel = _statusLabel(trip.status);
    final vehicleParts = [trip.vehicleModel, trip.vehicleColor]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalhes da Viagem',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(isDark, Icons.person_outline_rounded,
                        'Motorista', trip.driverName),
                    if (trip.licensePlate.isNotEmpty)
                      _detailRow(isDark, Icons.directions_car_outlined,
                          'Matrícula', trip.licensePlate),
                    if (vehicleParts.isNotEmpty)
                      _detailRow(isDark, Icons.local_taxi_outlined,
                          'Viatura', vehicleParts.join(' • ')),
                    _detailRow(isDark, Icons.calendar_today_outlined, 'Data',
                        '${trip.date} às ${trip.time}'),
                    _detailRow(isDark, Icons.payments_outlined, 'Valor',
                        _fmt(trip.amount)),
                    if (trip.distance != null)
                      _detailRow(isDark, Icons.straighten_outlined,
                          'Distância', '${trip.distance!.toStringAsFixed(1)} km'),
                    if (trip.duration != null)
                      _detailRow(isDark, Icons.timer_outlined, 'Duração',
                          '${trip.duration} min'),
                    if (trip.rating != null) ...[
                      _detailRow(
                          isDark,
                          Icons.star_outline_rounded,
                          'Avaliação',
                          '${trip.rating!.toStringAsFixed(1)} estrelas'),
                      if (trip.comment != null && trip.comment!.isNotEmpty)
                        _detailRow(isDark, Icons.comment_outlined,
                            'Comentário', trip.comment!),
                    ] else if (trip.status == 'completed') ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _rateTrip(ctx, trip),
                          icon: Icon(Icons.star_outline_rounded,
                              color: AppColors.accentOf(context)),
                          label: Text(
                            'Avaliar viagem',
                            style: TextStyle(
                              color: AppColors.accentOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.accentOf(context)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rateTrip(BuildContext sheetContext, Trip trip) {
    RatingModal.show(
      sheetContext,
      tripId: trip.id,
      driverName: trip.driverName,
      onSubmitRating: (tripId, stars, comment) async {
        final response = await ApiService()
            .rateTrip(tripId: tripId, stars: stars, comment: comment);
        if (response.isSuccess && sheetContext.mounted) {
          await sheetContext.read<AppProvider>().refreshTrips();
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        }
        return response.isSuccess;
      },
    );
  }

  Widget _detailRow(
      bool isDark, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
