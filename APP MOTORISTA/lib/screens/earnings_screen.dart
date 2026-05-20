import 'package:flutter/material.dart';
import 'package:troco_seguro_motorista/models/driver_user.dart';
import 'package:troco_seguro_motorista/models/earnings.dart';
import 'package:troco_seguro_motorista/utils/constants.dart';
import 'package:troco_seguro_motorista/utils/responsive_helper.dart';
import 'package:troco_seguro_motorista/services/api_service.dart';
import 'package:troco_seguro_motorista/widgets/driver_bottom_dock.dart';
import 'package:intl/intl.dart';

class EarningsScreen extends StatefulWidget {
  final DriverUser driver;
  final bool showBottomDock;

  const EarningsScreen({
    super.key,
    required this.driver,
    this.showBottomDock = true,
  });

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  String selectedPeriod = 'today';
  Earnings earnings = Earnings.empty();
  bool isLoading = true;
  final ApiService _api = ApiService();


  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => isLoading = true);

    await _api.loadTokens();
    final result = await _api.getEarnings();

    if (result.isSuccess && result.data != null) {
      setState(() {
        earnings = result.data!;
        isLoading = false;
      });
    } else {
      setState(() {
        earnings = Earnings.empty();
        isLoading = false;
      });
      if (mounted && result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar ganhos: ${result.error}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat('#,##0', 'pt_AO');
    return '${format.format(amount)} Kz';
  }

  int get currentAmount {
    switch (selectedPeriod) {
      case 'today':
        return earnings.todayAmount;
      case 'week':
        return earnings.weekAmount;
      case 'month':
        return earnings.monthAmount;
      case 'total':
        return earnings.totalAmount;
      default:
        return 0;
    }
  }

  int get currentTrips {
    switch (selectedPeriod) {
      case 'today':
        return earnings.todayTrips;
      case 'week':
        return earnings.weekTrips;
      case 'month':
        return earnings.monthTrips;
      case 'total':
        return earnings.totalTrips;
      default:
        return 0;
    }
  }

  String _getPeriodLabel() {
    switch (selectedPeriod) {
      case 'today':
        return 'Ganhos de Hoje';
      case 'week':
        return 'Ganhos da Semana';
      case 'month':
        return 'Ganhos do Mês';
      case 'total':
        return 'Ganhos Totais';
      default:
        return 'Ganhos';
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
        title: const Text('Ganhos'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightBackground,
        foregroundColor: isDark ? Colors.white : AppColors.textDark,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(Icons.star, color: AppColors.adaptiveAccent(context), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    earnings.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
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
        backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      bottomNavigationBar: widget.showBottomDock
          ? DriverBottomDock(
              selectedTab: DriverDockTab.stats,
              driver: widget.driver,
            )
          : null,
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadEarnings,
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
                                Column(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: responsive.scaledWidth(20),
                                      ),
                                      child: _buildEarningsCard(responsive),
                                    ),
                                    SizedBox(
                                        height: responsive.scaledHeight(20)),
                                    _buildPeriodSelector(responsive),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: responsive.scaledHeight(24),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildStatsGrid(responsive),
                                      SizedBox(
                                          height: responsive.scaledHeight(24)),
                                      _buildWeeklyChart(responsive),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    _buildPerformanceTips(responsive),
                                    SizedBox(
                                        height: responsive.scaledHeight(16)),
                                  ],
                                ),
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
        child: Column(
          children: [
            Row(
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
                    Icons.trending_up_rounded,
                    color: isDark ? AppColors.adaptiveAccent(context) : AppColors.textDark,
                    size: responsive.scaledWidth(24),
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(12)),
                Expanded(
                  child: Text(
                    'Ganhos',
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(20),
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.star, color: AppColors.adaptiveAccent(context), size: 18),
                    SizedBox(width: responsive.scaledWidth(4)),
                    Text(
                      earnings.averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(14),
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(24)),
            // Main earnings card
            _buildEarningsCard(responsive),
            SizedBox(height: responsive.scaledHeight(24)),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scaledWidth(20),
        vertical: responsive.scaledHeight(28),
      ),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : null,
        gradient: isDark
            ? null
            : const LinearGradient(
                colors: [Color(0xFFF7F8FA), Color(0xFFEFEFF2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        // Removed texture image to reduce overdraw/jank on low-end devices.
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.primary.withAlpha((0.9 * 255).round()),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(153)
                : Colors.black.withAlpha(51),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withAlpha(13)
                : Colors.white.withAlpha(230),
            blurRadius: 6,
            offset: const Offset(0, -3),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(102)
                : Colors.black.withAlpha(31),
            blurRadius: 8,
            offset: const Offset(3, 3),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.monetization_on_rounded,
                color: isDark
                    ? Colors.white.withOpacity(0.8)
                    : colorScheme.primary.withOpacity(0.7),
                size: responsive.scaledWidth(20),
              ),
              SizedBox(width: responsive.scaledWidth(8)),
              Text(
                _getPeriodLabel(),
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(14),
                  color: isDark
                      ? Colors.white.withOpacity(0.85)
                      : colorScheme.onSurface.withAlpha(199),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scaledHeight(16)),
          Text(
            _formatCurrency(currentAmount),
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(40),
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : colorScheme.primary,
            ),
          ),
          SizedBox(height: responsive.scaledHeight(12)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scaledWidth(16),
              vertical: responsive.scaledHeight(8),
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : colorScheme.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_taxi,
                    color: isDark ? Colors.white : colorScheme.primary,
                    size: 16),
                SizedBox(width: responsive.scaledWidth(6)),
                Text(
                  '$currentTrips viagens',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(12),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = [
      {'key': 'today', 'label': 'Hoje'},
      {'key': 'week', 'label': 'Semana'},
      {'key': 'month', 'label': 'Mês'},
      {'key': 'total', 'label': 'Total'},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Container(
        padding: EdgeInsets.all(responsive.scaledWidth(4)),
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
        child: Row(
          children: periods.map((period) {
            final isSelected = selectedPeriod == period['key'];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => selectedPeriod = period['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    vertical: responsive.scaledHeight(12),
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppColors.adaptiveAccent(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    period['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(12),
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.textDark
                          : (isDark ? Colors.white70 : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              responsive,
              'Média/Viagem',
              currentTrips > 0
                  ? _formatCurrency(currentAmount ~/ currentTrips)
                  : '0 Kz',
              Icons.speed,
              AppColors.adaptiveAccent(context),
            ),
          ),
          SizedBox(width: responsive.scaledWidth(12)),
          Expanded(
            child: _buildStatCard(
              responsive,
              'Avaliação',
              widget.driver.rating?.toStringAsFixed(1) ?? '5.0',
              Icons.star_rounded,
              AppColors.adaptiveAccent(context),
            ),
          ),
          SizedBox(width: responsive.scaledWidth(12)),
          Expanded(
            child: _buildStatCard(
              responsive,
              'Total Viagens',
              earnings.totalTrips.toString(),
              Icons.local_taxi_rounded,
              AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ResponsiveHelper responsive,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(responsive.responsivePadding()),
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
        children: [
          Container(
            padding: EdgeInsets.all(responsive.scaledWidth(8)),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: responsive.scaledHeight(8)),
          Text(
            value,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(14),
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: responsive.scaledHeight(2)),
          Text(
            label,
            style: TextStyle(
              fontSize: responsive.responsiveFontSize(10),
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(ResponsiveHelper responsive) {
    if (earnings.dailyHistory.isEmpty) return const SizedBox();

    final maxAmount = earnings.dailyHistory
        .map((e) => e.amount)
        .reduce((a, b) => a > b ? a : b);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Container(
        padding: EdgeInsets.all(responsive.responsivePadding()),
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
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: isDark ? AppColors.adaptiveAccent(context) : AppColors.textDark,
                  size: responsive.scaledWidth(20),
                ),
                SizedBox(width: responsive.scaledWidth(8)),
                Text(
                  'Desempenho Semanal',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(20)),
            SizedBox(
              height: responsive.scaledHeight(120),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: earnings.dailyHistory.map((day) {
                  final heightPercent =
                      maxAmount > 0 ? day.amount / maxAmount : 0.0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: responsive.scaledWidth(28),
                        height: responsive.scaledHeight(80) * heightPercent,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.adaptiveAccent(context),
                              isDark
                                  ? AppColors.secondaryGold
                                  : AppColors.secondaryOrange
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(8)),
                      Text(
                        day.date,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(10),
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTips(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.scaledWidth(20)),
      child: Container(
        padding: EdgeInsets.all(responsive.responsivePadding()),
        decoration: BoxDecoration(
          color: AppColors.adaptiveAccent(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.adaptiveAccent(context).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.adaptiveAccent(context),
                  size: responsive.scaledWidth(20),
                ),
                SizedBox(width: responsive.scaledWidth(8)),
                Text(
                  'Dica para aumentar ganhos',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(14),
                    fontWeight: FontWeight.w700,
                    color: AppColors.adaptiveAccent(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scaledHeight(12)),
            Text(
              'Trabalhe em horários de pico (7h-9h e 17h-20h) para maximizar '
              'seus ganhos. Mantenha uma boa avaliação para receber mais passageiros!',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: isDark ? Colors.white70 : AppColors.textDark,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


