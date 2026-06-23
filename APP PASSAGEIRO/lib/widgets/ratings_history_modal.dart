import 'package:flutter/material.dart';
import 'package:troco_seguro/models/rating.dart';
import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:troco_seguro/utils/constants.dart';
import 'package:troco_seguro/utils/responsive_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiService().getRatings(widget.userId);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _ratings = result.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        FeedbackService.showError(
          context,
          message: result.error ?? 'Erro ao carregar avaliações.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                borderRadius: BorderRadius.circular(2),
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
                      borderRadius: BorderRadius.circular(20),
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
            child: _isLoading
                ? Padding(
                    padding:
                        EdgeInsets.all(responsive.scaledHeight(40)),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentOf(context)),
                    ),
                  )
                : _ratings.isEmpty
                    ? _buildEmpty(isDark, responsive)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          responsive.responsivePadding(),
                          responsive.scaledHeight(8),
                          responsive.responsivePadding(),
                          responsive.scaledHeight(32),
                        ),
                        itemCount: _ratings.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: responsive.scaledHeight(10)),
                        itemBuilder: (ctx, i) => _buildItem(
                          ctx,
                          isDark,
                          responsive,
                          _ratings[i],
                          i,
                        ),
                      ),
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
              'Você ainda não avaliou nenhuma viagem.',
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

    return GestureDetector(
      onTap: () => setState(
        () => _expandedIndex = isExpanded ? null : index,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(responsive.scaledWidth(14)),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
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
                // Estrelas
                _buildStars(rating.stars, responsive),
                SizedBox(width: responsive.scaledWidth(10)),
                // Label
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scaledWidth(8),
                    vertical: responsive.scaledHeight(3),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentOf(context).withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rating.scoreLabel,
                    style: TextStyle(
                      fontSize: responsive.responsiveFontSize(10),
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),
                const Spacer(),
                // Data
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
