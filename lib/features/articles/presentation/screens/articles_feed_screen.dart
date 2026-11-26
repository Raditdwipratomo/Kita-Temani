import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/articles/domain/entities/article.dart';
import 'package:kitatemani/features/articles/presentation/controllers/articles_controller.dart';
import 'package:kitatemani/features/articles/presentation/widgets/article_feed_card.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';

enum _FeedTab {
  untukmu('Untukmu'),
  populer('Populer'),
  disimpan('Disimpan');

  const _FeedTab(this.label);
  final String label;
}

class ArticlesFeedScreen extends ConsumerStatefulWidget {
  const ArticlesFeedScreen({
    this.isTabView = false,
    super.key,
  });

  final bool isTabView;

  @override
  ConsumerState<ArticlesFeedScreen> createState() => _ArticlesFeedScreenState();
}

class _ArticlesFeedScreenState extends ConsumerState<ArticlesFeedScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  _FeedTab _selectedTab = _FeedTab.untukmu;
  String _selectedTopic = 'Semua';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openArticle(String articleId, {bool scrollToComments = false}) {
    Navigator.of(context).pushNamed(
      AppRoutes.articleDetail,
      arguments: <String, dynamic>{
        'articleId': articleId,
        'scrollToComments': scrollToComments,
      },
    );
  }

  void _editArticle(ArticleItem article) {
    Navigator.of(context).pushNamed(
      AppRoutes.articleCompose,
      arguments: article,
    );
  }

  Future<void> _confirmDeleteArticle(ArticleItem article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Artikel?'),
          content: Text(
            'Artikel "${article.cleanTitle}" akan dihapus dari Ruang Baca.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.darurat),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    ref.read(articlesControllerProvider.notifier).deleteArticle(article.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Artikel dihapus dari Ruang Baca.')),
    );
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedTab = _FeedTab.untukmu;
      _selectedTopic = 'Semua';
      _searchQuery = '';
    });
  }

  List<ArticleItem> _filteredArticles(List<ArticleItem> all) {
    final query = _searchQuery.trim().toLowerCase();
    var list = List<ArticleItem>.from(all);

    if (_selectedTab == _FeedTab.disimpan) {
      list = list.where((a) => a.isBookmarked).toList();
    } else if (_selectedTab == _FeedTab.populer) {
      list.sort(
        (a, b) => (b.clapCount + b.comments.length * 3)
            .compareTo(a.clapCount + a.comments.length * 3),
      );
    }

    if (_selectedTopic != 'Semua') {
      list = list.where((a) => a.tag == _selectedTopic).toList();
    }

    if (query.isNotEmpty) {
      list = list.where((a) {
        return a.cleanTitle.toLowerCase().contains(query) ||
            a.subtitle.toLowerCase().contains(query) ||
            a.tag.toLowerCase().contains(query) ||
            a.authorName.toLowerCase().contains(query);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isStaff =
        ref.watch(studentProfileProvider.select((p) => p.role.isStaff));
    final articlesData = ref.watch(
      articlesControllerProvider.select(
        (s) => (
          articles: s.articles,
          bookmarkedCount: s.bookmarkedArticles.length,
        ),
      ),
    );
    final notifier = ref.read(articlesControllerProvider.notifier);
    final bookmarkedCount = articlesData.bookmarkedCount;
    final items = _filteredArticles(articlesData.articles);
    final showFeaturedLead = _selectedTab == _FeedTab.untukmu &&
        _selectedTopic == 'Semua' &&
        _searchQuery.trim().isEmpty &&
        items.isNotEmpty;

    final topics = ['Semua', ...kArticleTopics];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                KtPageHeader(
                  title: 'Ruang Baca',
                  showBack: !widget.isTabView,
                  subtitle: isStaff
                      ? 'Kelola artikel edukasi & diskusi siswa'
                      : 'Artikel, cerita aman, & tanya jawab',
                  trailing: isStaff
                      ? InkWell(
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.articleCompose),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.indigoSoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    AppColors.biruTinta.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppColors.biruTinta,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tulis',
                                  style: AppTextStyles.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.biruTinta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                ),

                // Search bar + Segmented Feed Tabs + Topic Filter Pills
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KtCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        borderRadius: 16,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.inkSlate,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                key: const Key('articles_search_input'),
                                controller: _searchCtrl,
                                style: AppTextStyles.inter(
                                  fontSize: 13.5,
                                  color: AppColors.inkNavy,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Cari judul, topik, atau penulis...',
                                  hintStyle: AppTextStyles.inter(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.inkSlate,
                                ),
                                tooltip: 'Hapus pencarian',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Feed tabs: Untukmu, Populer, Disimpan
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.indigoSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: _FeedTab.values.map((tab) {
                            final selected = _selectedTab == tab;
                            final label =
                                tab == _FeedTab.disimpan && bookmarkedCount > 0
                                    ? '${tab.label} ($bookmarkedCount)'
                                    : tab.label;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedTab = tab),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.cardWhite
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: selected
                                        ? AppColors.circleControlShadow
                                        : null,
                                  ),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.poppins(
                                      fontSize: 12.5,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: selected
                                          ? AppColors.biruTinta
                                          : AppColors.inkSlate,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Topic filter chips
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topics.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final topic = topics[idx];
                            final selected = _selectedTopic == topic;
                            return ChoiceChip(
                              label: Text(topic),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: AppColors.indigoSoft,
                              backgroundColor: AppColors.cardWhite,
                              visualDensity: VisualDensity.compact,
                              labelStyle: AppTextStyles.inter(
                                fontSize: 12.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.biruTinta
                                    : AppColors.inkNavy,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.biruTinta
                                      : AppColors.borderHairline,
                                ),
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedTopic = topic),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // Feed list
                Expanded(
                  child: items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          children: [
                            KtCard(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      color: AppColors.indigoSoft,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _selectedTab == _FeedTab.disimpan
                                          ? Icons.bookmark_border_rounded
                                          : Icons.menu_book_outlined,
                                      size: 26,
                                      color: AppColors.biruTinta,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _selectedTab == _FeedTab.disimpan
                                        ? 'Belum ada artikel tersimpan'
                                        : 'Artikel tidak ditemukan',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.heading3,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _selectedTab == _FeedTab.disimpan
                                        ? 'Ketuk ikon simpan pada artikel mana pun untuk membacanya lagi nanti.'
                                        : 'Coba ubah kata kunci pencarian atau tampilkan semua topik.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    label: _selectedTab == _FeedTab.disimpan
                                        ? 'Jelajahi artikel'
                                        : 'Reset filter',
                                    isOutlined: true,
                                    onPressed: _resetFilters,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final article = items[index];
                            if (showFeaturedLead && index == 0) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: items.length > 1 ? 14 : 0,
                                ),
                                child: KtCard(
                                  padding: EdgeInsets.zero,
                                  borderRadius: 20,
                                  borderColor: article.borderColor,
                                  child: ArticleFeedCard(
                                    article: article,
                                    featured: true,
                                    onTap: () => _openArticle(article.id),
                                    onCommentTap: () => _openArticle(
                                      article.id,
                                      scrollToComments: true,
                                    ),
                                    onClap: () =>
                                        notifier.clapArticle(article.id),
                                    onBookmark: () =>
                                        notifier.toggleBookmark(article.id),
                                    onEdit: isStaff
                                        ? () => _editArticle(article)
                                        : null,
                                    onDelete: isStaff
                                        ? () => _confirmDeleteArticle(article)
                                        : null,
                                  ),
                                ),
                              );
                            }

                            final streamIndex =
                                showFeaturedLead ? index - 1 : index;
                            final streamCount = showFeaturedLead
                                ? items.length - 1
                                : items.length;
                            return _GroupedStreamArticleItem(
                              article: article,
                              isFirst: streamIndex == 0,
                              isLast: streamIndex == streamCount - 1,
                              onTap: () => _openArticle(article.id),
                              onCommentTap: () => _openArticle(
                                article.id,
                                scrollToComments: true,
                              ),
                              onClap: () => notifier.clapArticle(article.id),
                              onBookmark: () =>
                                  notifier.toggleBookmark(article.id),
                              onEdit:
                                  isStaff ? () => _editArticle(article) : null,
                              onDelete: isStaff
                                  ? () => _confirmDeleteArticle(article)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupedStreamArticleItem extends StatelessWidget {
  const _GroupedStreamArticleItem({
    required this.article,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onCommentTap,
    required this.onClap,
    required this.onBookmark,
    this.onEdit,
    this.onDelete,
  });

  final ArticleItem article;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onCommentTap;
  final VoidCallback onClap;
  final VoidCallback onBookmark;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final card = ArticleFeedCard(
      article: article,
      onTap: onTap,
      onCommentTap: onCommentTap,
      onClap: onClap,
      onBookmark: onBookmark,
      onEdit: onEdit,
      onDelete: onDelete,
    );

    if (isFirst && isLast) {
      return KtCard(
        padding: EdgeInsets.zero,
        borderRadius: 20,
        child: card,
      );
    }

    final content = isFirst
        ? card
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderHairline,
              ),
              card,
            ],
          );

    if (!isFirst && !isLast) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          border: Border.symmetric(
            vertical: BorderSide(color: AppColors.borderHairline, width: 1.1),
          ),
        ),
        child: content,
      );
    }

    return CustomPaint(
      painter: _GroupedCardEdgePainter(isTop: isFirst),
      child: content,
    );
  }
}

class _GroupedCardEdgePainter extends CustomPainter {
  const _GroupedCardEdgePainter({required this.isTop});

  final bool isTop;

  static const double _radius = 20;
  static const double _strokeWidth = 1.1;
  static final Paint _fillPaint = Paint()..color = AppColors.cardWhite;
  static final Paint _strokePaint = Paint()
    ..color = AppColors.borderHairline
    ..style = PaintingStyle.stroke
    ..strokeWidth = _strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    const hw = _strokeWidth / 2;
    const cornerRadius = Radius.circular(_radius);
    final fillRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillRRect = isTop
        ? RRect.fromRectAndCorners(
            fillRect,
            topLeft: cornerRadius,
            topRight: cornerRadius,
          )
        : RRect.fromRectAndCorners(
            fillRect,
            bottomLeft: cornerRadius,
            bottomRight: cornerRadius,
          );
    canvas.drawRRect(fillRRect, _fillPaint);

    const innerRadius = Radius.circular(_radius - hw);
    final path = Path();
    if (isTop) {
      path
        ..moveTo(hw, size.height)
        ..lineTo(hw, _radius)
        ..arcToPoint(const Offset(_radius, hw), radius: innerRadius)
        ..lineTo(size.width - _radius, hw)
        ..arcToPoint(Offset(size.width - hw, _radius), radius: innerRadius)
        ..lineTo(size.width - hw, size.height);
    } else {
      path
        ..moveTo(hw, 0)
        ..lineTo(hw, size.height - _radius)
        ..arcToPoint(
          Offset(_radius, size.height - hw),
          radius: innerRadius,
          clockwise: false,
        )
        ..lineTo(size.width - _radius, size.height - hw)
        ..arcToPoint(
          Offset(size.width - hw, size.height - _radius),
          radius: innerRadius,
          clockwise: false,
        )
        ..lineTo(size.width - hw, 0);
    }
    canvas.drawPath(path, _strokePaint);
  }

  @override
  bool shouldRepaint(covariant _GroupedCardEdgePainter oldDelegate) =>
      oldDelegate.isTop != isTop;
}
