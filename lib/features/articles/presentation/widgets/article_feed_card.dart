import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/features/articles/domain/entities/article.dart';

class ArticleFeedCard extends StatelessWidget {
  const ArticleFeedCard({
    required this.article,
    required this.onTap,
    required this.onClap,
    required this.onBookmark,
    this.onCommentTap,
    this.onEdit,
    this.onDelete,
    this.featured = false,
    this.compact = false,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final ArticleItem article;
  final VoidCallback onTap;
  final VoidCallback onClap;
  final VoidCallback onBookmark;
  final VoidCallback? onCommentTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool featured;
  final bool compact;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scene = article.scene;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zone 1: Byline header (Author avatar, verified badge, role, time)
              Row(
                children: [
                  _AuthorCircleAvatar(
                    initials: article.authorInitials,
                    background: article.cardBackground,
                    foreground: article.tagTextColor,
                    borderColor: article.borderColor,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          article.authorName,
                          style: AppTextStyles.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkNavy,
                          ),
                        ),
                        if (article.isVerifiedAuthor)
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.biruTinta,
                          ),
                        Text(
                          '· ${article.relativeTimeLabel}',
                          style: AppTextStyles.inter(
                            fontSize: 11.5,
                            color: AppColors.inkSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: article.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      article.tag,
                      style: AppTextStyles.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: article.tagTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (featured && scene != null) ...[
                Container(
                  width: double.infinity,
                  height: 142,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: article.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: article.borderColor),
                  ),
                  child: KitaIllustration(scene: scene),
                ),
                const SizedBox(height: 12),
              ],

              // Zone 2: Headline & dek (+ compact right thumbnail when non-featured)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.cleanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.poppins(
                            fontSize: featured ? 18 : (compact ? 15 : 16),
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkNavy,
                            height: 1.3,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          article.subtitle,
                          maxLines: featured ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.inter(
                            fontSize: 13,
                            color: AppColors.inkSlate,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!featured && scene != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: compact ? 84 : 92,
                      height: compact ? 70 : 78,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: article.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: article.borderColor),
                      ),
                      child: KitaIllustration(scene: scene),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Zone 3 & 4: Read time & Medium x X engagement bar
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${article.readMinutes} menit baca',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkSlate,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _EngagementButton(
                    icon: article.myClapCount > 0
                        ? Icons.pan_tool_alt_rounded
                        : Icons.pan_tool_alt_outlined,
                    label: '${article.clapCount}',
                    active: article.myClapCount > 0,
                    activeColor: AppColors.biruTinta,
                    tooltip: 'Beri tepuk tangan',
                    onTap: onClap,
                  ),
                  const SizedBox(width: 4),
                  _EngagementButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${article.comments.length}',
                    active: false,
                    activeColor: AppColors.biruTinta,
                    tooltip: 'Lihat tanggapan',
                    onTap: onCommentTap ?? onTap,
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: Icon(
                      article.isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 19,
                      color: article.isBookmarked
                          ? AppColors.biruTinta
                          : AppColors.inkSlate,
                    ),
                    tooltip: article.isBookmarked
                        ? 'Hapus dari disimpan'
                        : 'Simpan artikel',
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(30, 30),
                      fixedSize: const Size(30, 30),
                    ),
                    onPressed: onBookmark,
                  ),
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.biruTinta,
                      ),
                      tooltip: 'Edit artikel',
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(30, 30),
                        fixedSize: const Size(30, 30),
                      ),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.darurat,
                      ),
                      tooltip: 'Hapus artikel',
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(30, 30),
                        fixedSize: const Size(30, 30),
                      ),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorCircleAvatar extends StatelessWidget {
  const _AuthorCircleAvatar({
    required this.initials,
    required this.background,
    required this.foreground,
    required this.borderColor,
    required this.size,
  });

  final String initials;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.poppins(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _EngagementButton extends StatelessWidget {
  const _EngagementButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.inkSlate;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.indigoSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.inter(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
