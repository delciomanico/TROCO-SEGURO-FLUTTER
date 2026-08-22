import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/models/trip.dart';
import 'package:troco_seguro_pro/utils/constants.dart';
import 'package:troco_seguro_pro/utils/responsive_helper.dart';
import 'package:troco_seguro_pro/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:troco_seguro_pro/widgets/driver_bottom_dock.dart';

/// Valores monetários vêm da API como string decimal (ex. "0.00") — ver
/// BACKEND_PENDING_CHANGES.md, item "valores monetários como string".
int _statInt(dynamic value) =>
    value == null ? 0 : (num.tryParse(value.toString())?.toInt() ?? 0);

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


  @override
  void initState() {
    super.initState();
    _loadTrips();
    _loadStats();
  }

  Future<void> _loadTrips() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
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

      // Fallback: cache local
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

      // Sem dados: exibe lista vazia
      if (mounted) {
        setState(() => trips = []);
      }
    } catch (e) {
      debugPrint('Erro ao carregar viagens: $e');
      // Mantém o estado atual em caso de erro (evita apagar dados em cache)
      if (mounted && trips.isEmpty) {
        setState(() => trips = []);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<Trip> get filteredTrips {
    return trips.where((trip) {
      return trip.passengerName.toLowerCase().contains(searchQuery.toLowerCase());
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

  bool _searchActive = false;
  final _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Map<String, dynamic>? _stats;

  Future<void> _loadStats() async {
    final result = await _api.getTripStats();
    if (result.isSuccess && result.data != null && mounted) {
      setState(() => _stats = result.data);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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
              selectedTab: DriverDockTab.wallet,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadTrips();
            await _loadStats();
          },
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGold,
                  ),
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildFlatHeader(responsive, isDark),
                    ),
                    if (_stats != null)
                      SliverToBoxAdapter(
                        child: _buildStatsRow(responsive, isDark),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          responsive.scaledWidth(20),
                          responsive.scaledHeight(4),
                          responsive.scaledWidth(20),
                          responsive.scaledHeight(110),
                        ),
                        child: _buildTripsList(responsive),
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-0.04, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _searchActive
                ? GestureDetector(
                    key: const ValueKey('close'),
                    onTap: () {
                      _searchFocus.unfocus();
                      setState(() {
                        _searchActive = false;
                        searchQuery = '';
                        _searchController.clear();
                      });
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
                        size: responsive.scaledWidth(20),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.textDark.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('spacer'),
                    width: responsive.scaledWidth(38),
                    height: responsive.scaledWidth(38),
                  ),
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
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
                child: _searchActive
                    ? TextField(
                        key: const ValueKey('search'),
                        controller: _searchController,
                        focusNode: _searchFocus,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(15),
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Pesquisar viagens...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => searchQuery = v),
                      )
                    : Text(
                        key: const ValueKey('title'),
                        'Viagens',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(17),
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textDark,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _searchActive = !_searchActive),
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
                _searchActive
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
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

  Widget _buildStatsRow(ResponsiveHelper responsive, bool isDark) {
    final total = _statInt(_stats?['total'] ?? _stats?['totalTrips']);
    // `monthSpent` em GET trips/stats é, pelo nome, o valor GASTO por um
    // passageiro — não o valor RECEBIDO por um motorista. Para o motorista
    // este campo fica sempre a 0/errado, por isso "recebido" nunca
    // aparecia. Somamos antes o valor das próprias viagens já carregadas
    // (mesma abordagem já usada em Earnings.fromTrips na tela inicial),
    // com o campo antigo só como recurso se ainda não houver viagens.
    final earned = trips.isNotEmpty
        ? trips.fold<int>(0, (sum, t) => sum + t.amount)
        : _statInt(_stats?['monthSpent'] ??
            _stats?['totalEarned'] ??
            _stats?['earned'] ??
            _stats?['revenue']);
    final fmt = NumberFormat('#,##0', 'pt_AO');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.scaledWidth(20),
        responsive.scaledHeight(4),
        responsive.scaledWidth(20),
        responsive.scaledHeight(4),
      ),
      child: Row(
        children: [
          _statChip(
            isDark,
            Icons.route_rounded,
            '$total',
            'viagens',
            responsive,
          ),
          SizedBox(width: responsive.scaledWidth(10)),
          _statChip(
            isDark,
            Icons.account_balance_wallet_outlined,
            '${fmt.format(earned)} Kz',
            'recebido',
            responsive,
          ),
        ],
      ),
    );
  }

  Widget _statChip(bool isDark, IconData icon, String value, String label, ResponsiveHelper responsive) {
    final accent = isDark ? AppColors.primaryGold : AppColors.primaryOrange;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scaledWidth(14),
          vertical: responsive.scaledHeight(12),
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            SizedBox(width: responsive.scaledWidth(10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(11),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(vertical: responsive.scaledHeight(60)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_taxi_outlined,
            size: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.15),
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          Text(
            'Nenhuma viagem encontrada',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.35),
            ),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          Text(
            'As suas viagens aparecerão aqui',
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(12),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  void _showTripDetail(Trip trip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;
    final statusColor = _getStatusColor(trip.status);
    final statusLabel = _getStatusLabel(trip.status);

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    _detailRow(ctx, isDark, Icons.person, 'Passageiro',
                        trip.passengerName),
                    if (trip.passengerPhone != null)
                      _detailRow(ctx, isDark, Icons.phone_outlined, 'Telefone',
                          trip.passengerPhone!),
                    _detailRow(ctx, isDark, Icons.calendar_today_outlined,
                        'Data', '${trip.date} às ${trip.time}'),
                    _detailRow(ctx, isDark, Icons.payments_outlined, 'Valor',
                        _formatCurrency(trip.amount)),
                    if (trip.distance != null)
                      _detailRow(
                          ctx,
                          isDark,
                          Icons.straighten_outlined,
                          'Distância',
                          '${trip.distance!.toStringAsFixed(1)} km'),
                    if (trip.duration != null)
                      _detailRow(ctx, isDark, Icons.timer_outlined, 'Duração',
                          '${trip.duration} min'),
                    if (trip.rating != null)
                      _detailRow(
                          ctx,
                          isDark,
                          Icons.star_outline_rounded,
                          'Avaliação',
                          '${trip.rating!.toStringAsFixed(1)} estrelas'),
                    if (trip.comment != null && trip.comment!.isNotEmpty)
                      _detailRow(ctx, isDark, Icons.comment_outlined,
                          'Comentário', trip.comment!),
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

  Widget _detailRow(BuildContext ctx, bool isDark, IconData icon, String label,
      String value) {
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

  Widget _buildTripCard(ResponsiveHelper responsive, Trip trip) {
    final statusColor = _getStatusColor(trip.status);
    final statusLabel = _getStatusLabel(trip.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return GestureDetector(
      onTap: () => _showTripDetail(trip),
      child: Container(
      margin: EdgeInsets.only(bottom: responsive.scaledHeight(12)),
      padding: EdgeInsets.all(responsive.scaledWidth(16)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
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
                  color: AppColors.primaryGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.primaryGold,
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
                        color: Colors.grey,
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
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (trip.rating != null)
                Row(
                  children: [
                    Icon(Icons.star,
                        color: AppColors.primaryGold, size: 16),
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
    ),
    );
  }
}
