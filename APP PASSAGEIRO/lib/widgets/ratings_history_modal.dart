import 'package:flutter/material.dart';
import 'package:troco_seguro/models/rating.dart';
import 'package:troco_seguro/providers/app_provider.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';
import 'package:provider/provider.dart';

class RatingsHistoryModal extends StatefulWidget {
  final String userId;

  const RatingsHistoryModal({super.key, required this.userId});

  static Future<void> show(BuildContext context, {required String userId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingsHistoryModal(userId: userId),
    );
  }

  @override
  State<RatingsHistoryModal> createState() => _RatingsHistoryModalState();
}

class _RatingsHistoryModalState extends State<RatingsHistoryModal> {
  List<Rating> _ratings = [];
  bool _isLoading = true;
  int? _expandedIndex;
  String? _error;
  int _lastSeenRevision = -1;
  bool _autoReloadQueued = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    final revision = context.read<AppProvider>().ratingsRevision;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await ApiService().getRatings(widget.userId);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _ratings = result.data ?? [];
        _isLoading = false;
        _error = null;
        _lastSeenRevision = revision;
        _expandedIndex = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = result.error ?? 'Não foi possível carregar as avaliações.';
        _lastSeenRevision = revision;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxH = MediaQuery.of(context).size.height * 0.85;
    final ratingsRevision = context.watch<AppProvider>().ratingsRevision;

    if (!_isLoading && _lastSeenRevision != ratingsRevision && !_autoReloadQueued) {
      _autoReloadQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _autoReloadQueued = false;
        await _load(showLoading: false);
      });
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withAlpha((0.08 * 255).round()),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: EdgeInsets.only(top: responsive.scaledHeight(12)),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withAlpha((0.3 * 255).round()),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.responsivePadding(),
              vertical: responsive.scaledHeight(16),
            ),
            child: Row(
              children: [
                Icon(Icons.star_rounded,
                    color: AppColors.accentOf(context),
                    size: responsive.scaledWidth(22)),
                SizedBox(width: responsive.scaledWidth(8)),
                Text(
                  'MINHAS AVALIAÇÕES',
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(16),
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                const Spacer(),
                if (!_isLoading)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.scaledWidth(10),
                      vertical: responsive.scaledHeight(4),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentOf(context).withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      '${_ratings.length}',
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(12),
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Flexible(
            child: RefreshIndicator(
              onRefresh: () => _load(showLoading: false),
              color: AppColors.accentOf(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  responsive.responsivePadding(),
                  responsive.scaledHeight(8),
                  responsive.responsivePadding(),
                  responsive.scaledHeight(32),
                ),
                children: [
                  if (_error != null) ...[
                    _buildErrorBanner(isDark, responsive),
                    SizedBox(height: responsive.scaledHeight(12)),
                  ],
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.all(responsive.scaledHeight(40)),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentOf(context),
                        ),
                      ),
                    )
                  else if (_ratings.isEmpty)
                    _buildEmpty(isDark, responsive)
                  else
                    ..._ratings.asMap().entries.expand((entry) {
                      final itemWidgets = <Widget>[
                        _buildItem(
                          context,
                          isDark,
                          responsive,
                          entry.value,
                          entry.key,
                        ),
                      ];
                      if (entry.key != _ratings.length - 1) {
                        itemWidgets.add(
                          SizedBox(height: responsive.scaledHeight(10)),
                        );
                      }
                      return itemWidgets;
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark, ResponsiveHelper responsive) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(responsive.scaledWidth(14)),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400),
          SizedBox(width: responsive.scaledWidth(10)),
          Expanded(
            child: Text(
              _error ?? 'Não foi possível carregar as avaliações.',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textDark,
                fontSize: responsive.responsiveFontSize(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _load(),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark, ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: responsive.scaledHeight(60),
        horizontal: responsive.responsivePadding(),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                Icons.star_outline_rounded,
                size: responsive.scaledWidth(32),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: responsive.scaledHeight(16)),
            Text(
              'Sem avaliações',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(16),
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            SizedBox(height: responsive.scaledHeight(6)),
            Text(
              _error == null
                  ? 'Você ainda não avaliou nenhuma viagem.'
                  : 'Deslize para baixo para tentar novamente.',
              style: TextStyle(
                fontSize: responsive.responsiveFontSize(12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.38),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    bool isDark,
    ResponsiveHelper responsive,
    Rating rating,
    int index,
  ) {
    final isExpanded = _expandedIndex == index;
    final textPrimary = isDark ? Colors.white : AppColors.textDark;
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.5);
    final displayName = rating.displayName;

    return GestureDetector(
      onTap: () => setState(
        () => _expandedIndex = isExpanded ? null : index,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(responsive.scaledWidth(14)),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row principal
            Row(
              children: [
                CircleAvatar(
                  radius: responsive.scaledWidth(14),
                  backgroundColor: AppColors.accentOf(context).withValues(alpha: 0.12),
                  backgroundImage: rating.avatarUrl != null && rating.avatarUrl!.isNotEmpty
                      ? NetworkImage(rating.avatarUrl!)
                      : null,
                  child: rating.avatarUrl == null || rating.avatarUrl!.isEmpty
                      ? Icon(
                          Icons.person_outline_rounded,
                          size: responsive.scaledWidth(15),
                          color: AppColors.accentOf(context),
                        )
                      : null,
                ),
                SizedBox(width: responsive.scaledWidth(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(12),
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: responsive.scaledHeight(2)),
                      Text(
                        rating.ratedName != null || rating.raterName != null
                            ? 'Avaliação concluída'
                            : 'Histórico de avaliação',
                        style: TextStyle(
                          fontSize: responsive.responsiveFontSize(10),
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: responsive.scaledWidth(10)),
                // Estrelas
                _buildStars(rating.stars, responsive),
                SizedBox(width: responsive.scaledWidth(10)),
                Text(
                  rating.formattedDate,
                  style: TextStyle(
                    fontSize: responsive.responsiveFontSize(10),
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Motorista (se disponível)
            if (rating.ratedName != null) ...[
              SizedBox(height: responsive.scaledHeight(7)),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: responsive.scaledWidth(13),
                      color: textSecondary),
                  SizedBox(width: responsive.scaledWidth(5)),
                  Expanded(
                    child: Text(
                      rating.ratedName!,
                      style: TextStyle(
                        fontSize: responsive.responsiveFontSize(11),
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: isExpanded ? null : 1,
                      overflow:
                          isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Comentário (colapsado: 1 linha; expandido: completo)
            if (rating.comment != null && rating.comment!.isNotEmpty) ...[
              SizedBox(height: responsive.scaledHeight(7)),
              Text(
                rating.comment!,
                style: TextStyle(
                  fontSize: responsive.responsiveFontSize(12),
                  color: textPrimary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
              ),
            ],
            // Indicador expand/collapse
            if (!isExpanded &&
                ((rating.comment?.length ?? 0) > 60 ||
                    rating.ratedName != null)) ...[
              SizedBox(height: responsive.scaledHeight(4)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.expand_more_rounded,
                    size: responsive.scaledWidth(16),
                    color: textSecondary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStars(int stars, ResponsiveHelper responsive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: responsive.scaledWidth(16),
          color: i < stars ? AppColors.accentOf(context) : Colors.grey,
        );
      }),
    );
  }
}
