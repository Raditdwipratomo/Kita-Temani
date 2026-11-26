import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/articles/domain/entities/article.dart';
import 'package:kitatemani/features/articles/presentation/controllers/articles_controller.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';

class ArticleDetailScreen extends ConsumerStatefulWidget {
  const ArticleDetailScreen({
    required this.articleId,
    this.scrollToComments = false,
    super.key,
  });

  final String articleId;
  final bool scrollToComments;

  @override
  ConsumerState<ArticleDetailScreen> createState() =>
      _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _commentCtrl = TextEditingController();
  final GlobalKey _commentsKey = GlobalKey();
  final ValueNotifier<double> _readProgress = ValueNotifier<double>(0.0);
  bool _commentAnonymous = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    if (widget.scrollToComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToComments());
    }
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    _readProgress.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final maxExtent = _scrollCtrl.position.maxScrollExtent;
    final next =
        maxExtent <= 0 ? 1.0 : (_scrollCtrl.offset / maxExtent).clamp(0.0, 1.0);
    if ((next - _readProgress.value).abs() >= 0.02) {
      _readProgress.value = next;
    }
  }

  void _scrollToComments() {
    final targetContext = _commentsKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  void _handleClap(ArticleItem article) {
    final ok =
        ref.read(articlesControllerProvider.notifier).clapArticle(article.id);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamu sudah memberi batas maksimal 50 tepuk tangan.'),
        ),
      );
    }
  }

  void _submitComment(ArticleItem article) {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tuliskan tanggapanmu terlebih dahulu.')),
      );
      return;
    }
    ref.read(articlesControllerProvider.notifier).addComment(
          articleId: article.id,
          body: text,
          isAnonymous: _commentAnonymous,
        );
    _commentCtrl.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tanggapanmu ditambahkan ke diskusi.')),
    );
  }

  String _fontScaleLabel(double scale) {
    if (scale < 0.95) return 'A-';
    if (scale > 1.05) return 'A+';
    return 'A';
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
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      await Navigator.of(context).pushReplacementNamed(AppRoutes.articles);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff =
        ref.watch(studentProfileProvider.select((p) => p.role.isStaff));
    final readerData = ref.watch(
      articlesControllerProvider.select(
        (s) => (
          article: s.findById(widget.articleId),
          fontScale: s.readerFontScale,
        ),
      ),
    );
    final notifier = ref.read(articlesControllerProvider.notifier);
    final article = readerData.article;
    final readerFontScale = readerData.fontScale;

    if (article == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              const KtPageHeader(title: 'Ruang Baca'),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: KtCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Artikel tidak ditemukan',
                            style: AppTextStyles.heading2,
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Kembali ke Ruang Baca',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final scene = article.scene;

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky 3px Reading Progress Bar
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _readProgress,
                builder: (_, progress, __) => LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: AppColors.borderHairline,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(article.accentColor),
                ),
              ),
            ),

            // Minimal Editorial Reader Top Bar
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      CircleActionButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Kembali',
                        onTap: () {
                          final nav = Navigator.of(context);
                          if (nav.canPop()) {
                            nav.pop();
                          } else {
                            nav.pushNamedAndRemoveUntil(
                              AppRoutes.articles,
                              (r) => false,
                            );
                          }
                        },
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Ukuran huruf',
                        child: InkWell(
                          onTap: notifier.cycleFontScale,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.indigoSoft,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.borderHairline),
                            ),
                            child: Text(
                              _fontScaleLabel(readerFontScale),
                              style: AppTextStyles.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.biruTinta,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleActionButton(
                        icon: article.isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        iconColor: article.isBookmarked
                            ? AppColors.biruTinta
                            : AppColors.inkNavy,
                        tooltip: article.isBookmarked
                            ? 'Hapus dari disimpan'
                            : 'Simpan artikel',
                        onTap: () => notifier.toggleBookmark(article.id),
                      ),
                      if (isStaff) ...[
                        const SizedBox(width: 8),
                        CircleActionButton(
                          icon: Icons.edit_outlined,
                          iconColor: AppColors.biruTinta,
                          tooltip: 'Edit artikel',
                          onTap: () => _editArticle(article),
                        ),
                        const SizedBox(width: 8),
                        CircleActionButton(
                          icon: Icons.delete_outline_rounded,
                          iconColor: AppColors.darurat,
                          tooltip: 'Hapus artikel',
                          onTap: () => _confirmDeleteArticle(article),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable Long-Form Article Content + Comments
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Topic pill & read time
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: article.cardBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: article.borderColor),
                              ),
                              child: Text(
                                article.tag,
                                style: AppTextStyles.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: article.tagTextColor,
                                ),
                              ),
                            ),
                            Text(
                              '${article.readMinutes} menit baca · ${article.relativeTimeLabel}',
                              style: AppTextStyles.inter(
                                fontSize: 12.5,
                                color: AppColors.inkSlate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Display Headline
                        Text(
                          article.cleanTitle,
                          style: AppTextStyles.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkNavy,
                            height: 1.24,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtitle / Dek
                        Text(
                          article.subtitle,
                          style: AppTextStyles.inter(
                            fontSize: 15,
                            color: AppColors.inkSlate,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Author Byline Strip
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderHairline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: article.cardBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: article.borderColor,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    article.authorInitials,
                                    style: AppTextStyles.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: article.tagTextColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            article.authorName,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.poppins(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (article.isVerifiedAuthor) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.verified_rounded,
                                            size: 15,
                                            color: AppColors.biruTinta,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      article.authorRole,
                                      style: AppTextStyles.inter(
                                        fontSize: 12,
                                        color: AppColors.inkSlate,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Editorial Illustration Banner
                        if (scene != null) ...[
                          Container(
                            width: double.infinity,
                            height: 176,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: article.cardBackground,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: article.borderColor),
                            ),
                            child: KitaIllustration(scene: scene),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Long-form editorial paragraphs
                        ..._buildArticleBlocks(
                          article: article,
                          fontScale: readerFontScale,
                        ),

                        const SizedBox(height: 18),

                        // Safe Support Action Callout
                        KtCard(
                          color: AppColors.tintIndigo,
                          borderColor: const Color(0xFFDCE0FC),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Butuh tempat cerita atau mau melapor?',
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kamu bisa mengobrol rahasia dengan Curhai atau langsung mengirim laporan ke Guru BK.',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context)
                                        .pushNamed(AppRoutes.curhai),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Cerita di Curhai'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.biruTinta,
                                      side: const BorderSide(
                                        color: AppColors.biruTinta,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => Navigator.of(context)
                                        .pushNamed(AppRoutes.reportType),
                                    icon: const Icon(
                                      Icons.shield_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Buat laporan privat'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.biruTinta,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),
                        const Divider(
                          height: 1,
                          color: AppColors.borderHairline,
                        ),
                        const SizedBox(height: 22),

                        // Diskusi & Tanggapan Section (Quora/Medium style)
                        Container(
                          key: _commentsKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diskusi & Tanggapan (${article.comments.length})',
                                style: AppTextStyles.heading2,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ruang diskusi dijaga ramah dan rahasia. Kamu bisa menanggapi tanpa mencantumkan nama.',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              KtCard(
                                color: AppColors.canvas,
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      key: const Key('article_comment_input'),
                                      controller: _commentCtrl,
                                      minLines: 2,
                                      maxLines: 5,
                                      style: AppTextStyles.inter(
                                        fontSize: 13.5,
                                        color: AppColors.inkNavy,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Tulis pendapat, dukungan, atau pertanyaanmu...',
                                        hintStyle: AppTextStyles.inter(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.cardWhite,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AppColors.borderHairline,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AppColors.borderHairline,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AppColors.biruTinta,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Switch.adaptive(
                                                value: _commentAnonymous,
                                                activeTrackColor:
                                                    AppColors.biruTinta,
                                                onChanged: (v) => setState(
                                                  () => _commentAnonymous = v,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Kirim sebagai Anonim',
                                                style: AppTextStyles.inter(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.inkNavy,
                                                ),
                                              ),
                                            ],
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                _submitComment(article),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.biruTinta,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child:
                                                const Text('Kirim tanggapan'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (article.comments.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'Belum ada tanggapan. Jadilah yang pertama berbagi pikiran dengan ramah.',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                )
                              else
                                ...article.comments.map(
                                  (comment) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _CommentCard(
                                      comment: comment,
                                      onToggleHelpful: () =>
                                          notifier.toggleCommentHelpful(
                                        article.id,
                                        comment.id,
                                      ),
                                      onDelete: isStaff
                                          ? () {
                                              notifier.deleteComment(
                                                articleId: article.id,
                                                commentId: comment.id,
                                              );
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Tanggapan dihapus oleh Guru BK.',
                                                  ),
                                                ),
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Sticky Bottom Engagement Bar
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(
                  top: BorderSide(color: AppColors.borderHairline, width: 1),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _handleClap(article),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: article.myClapCount > 0
                                  ? AppColors.indigoSoft
                                  : AppColors.canvas,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: article.myClapCount > 0
                                    ? AppColors.biruTinta
                                    : AppColors.borderHairline,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  article.myClapCount > 0
                                      ? Icons.pan_tool_alt_rounded
                                      : Icons.pan_tool_alt_outlined,
                                  size: 17,
                                  color: article.myClapCount > 0
                                      ? AppColors.biruTinta
                                      : AppColors.inkNavy,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${article.clapCount}',
                                  style: AppTextStyles.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: article.myClapCount > 0
                                        ? AppColors.biruTinta
                                        : AppColors.inkNavy,
                                  ),
                                ),
                                if (article.myClapCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.biruTinta,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '+${article.myClapCount}',
                                      style: AppTextStyles.poppins(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: _scrollToComments,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.borderHairline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 17,
                                  color: AppColors.inkNavy,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${article.comments.length}',
                                  style: AppTextStyles.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            article.isBookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: article.isBookmarked
                                ? AppColors.biruTinta
                                : AppColors.inkNavy,
                          ),
                          tooltip: article.isBookmarked
                              ? 'Hapus dari disimpan'
                              : 'Simpan artikel',
                          onPressed: () => notifier.toggleBookmark(article.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildArticleBlocks({
    required ArticleItem article,
    required double fontScale,
  }) {
    final blocks = article.body
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    final widgets = <Widget>[];
    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;

      if (lines.first.startsWith('## ')) {
        final heading = lines.first.substring(3).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              heading,
              style: AppTextStyles.poppins(
                fontSize: 18 * fontScale,
                fontWeight: FontWeight.w700,
                color: AppColors.inkNavy,
                height: 1.32,
              ),
            ),
          ),
        );
        final rest = lines.skip(1).toList();
        if (rest.isNotEmpty) {
          widgets.addAll(_renderLineGroup(rest, article, fontScale));
        }
      } else {
        widgets.addAll(_renderLineGroup(lines, article, fontScale));
      }
    }
    return widgets;
  }

  List<Widget> _renderLineGroup(
    List<String> lines,
    ArticleItem article,
    double fontScale,
  ) {
    final widgets = <Widget>[];
    for (final line in lines) {
      if (line.startsWith('> ')) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: article.cardBackground,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
              border: Border(
                left: BorderSide(color: article.accentColor, width: 4),
              ),
            ),
            child: Text(
              line.substring(2).trim(),
              style: AppTextStyles.editorialBody(
                fontSize: 16 * fontScale,
                fontStyle: FontStyle.italic,
                color: AppColors.inkNavy,
                height: 1.65,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 11, right: 12),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: article.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(2).trim(),
                    style: AppTextStyles.editorialBody(
                      fontSize: 16 * fontScale,
                      height: 1.72,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              line,
              style: AppTextStyles.editorialBody(
                fontSize: 16.5 * fontScale,
                height: 1.75,
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.onToggleHelpful,
    this.onDelete,
  });

  final ArticleComment comment;
  final VoidCallback onToggleHelpful;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        comment.isVerifiedStaff ? AppColors.tintIndigo : AppColors.canvas;
    final fgColor =
        comment.isVerifiedStaff ? AppColors.biruTinta : AppColors.inkNavy;

    return KtCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderHairline),
                ),
                child: Center(
                  child: Text(
                    comment.authorInitials,
                    style: AppTextStyles.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      comment.displayAuthor,
                      style: AppTextStyles.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (comment.isVerifiedStaff)
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.biruTinta,
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: comment.isVerifiedStaff
                            ? AppColors.indigoSoft
                            : AppColors.canvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        comment.displayRole,
                        style: AppTextStyles.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: comment.isVerifiedStaff
                              ? AppColors.biruTinta
                              : AppColors.inkSlate,
                        ),
                      ),
                    ),
                    Text(
                      '· ${comment.relativeTimeLabel}',
                      style: AppTextStyles.inter(
                        fontSize: 11,
                        color: AppColors.inkSlate,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: AppColors.darurat,
                  ),
                  tooltip: 'Hapus tanggapan',
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                    fixedSize: const Size(28, 28),
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.body,
            style: AppTextStyles.inter(
              fontSize: 13.5,
              color: AppColors.inkNavy,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onToggleHelpful,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: comment.isHelpfulByMe
                    ? AppColors.indigoSoft
                    : AppColors.canvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: comment.isHelpfulByMe
                      ? AppColors.biruTinta
                      : AppColors.borderHairline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    comment.isHelpfulByMe
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                    size: 14,
                    color: comment.isHelpfulByMe
                        ? AppColors.biruTinta
                        : AppColors.inkSlate,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Bermanfaat (${comment.helpfulCount})',
                    style: AppTextStyles.inter(
                      fontSize: 11.5,
                      fontWeight: comment.isHelpfulByMe
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: comment.isHelpfulByMe
                          ? AppColors.biruTinta
                          : AppColors.inkSlate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
