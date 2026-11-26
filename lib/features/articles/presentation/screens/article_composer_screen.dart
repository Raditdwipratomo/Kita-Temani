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

class ArticleComposerScreen extends ConsumerStatefulWidget {
  const ArticleComposerScreen({this.editingArticle, super.key});

  final ArticleItem? editingArticle;

  @override
  ConsumerState<ArticleComposerScreen> createState() =>
      _ArticleComposerScreenState();
}

class _ArticleComposerScreenState extends ConsumerState<ArticleComposerScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _subtitleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();

  String _selectedTopic = kArticleTopics.first;
  IllustrationScene? _selectedScene;
  bool _publishAnonymous = false;
  String? _validationError;

  static const List<IllustrationScene> _coverScenes = [
    IllustrationScene.eduBoundary,
    IllustrationScene.eduAlly,
    IllustrationScene.eduCyber,
    IllustrationScene.eduSelfcare,
  ];

  bool get _isEditing => widget.editingArticle != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingArticle;
    if (editing != null) {
      _titleCtrl.text = editing.title;
      _subtitleCtrl.text = editing.subtitle;
      _bodyCtrl.text = editing.body;
      _selectedTopic = kArticleTopics.contains(editing.tag)
          ? editing.tag
          : kArticleTopics.first;
      _selectedScene = editing.scene;
      _publishAnonymous = false;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.length < 6) {
      setState(() {
        _validationError =
            'Judul artikel minimal 6 karakter agar mudah dipahami.';
      });
      return;
    }
    if (body.length < 20) {
      setState(() {
        _validationError =
            'Isi artikel minimal 20 karakter sebelum dipublikasikan.';
      });
      return;
    }

    setState(() => _validationError = null);

    final notifier = ref.read(articlesControllerProvider.notifier);
    final editing = widget.editingArticle;
    if (editing != null) {
      final updated = notifier.updateArticle(
        articleId: editing.id,
        title: title,
        subtitle: _subtitleCtrl.text,
        body: body,
        tag: _selectedTopic,
        scene: _selectedScene,
        clearScene: _selectedScene == null,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artikel berhasil diperbarui.')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else if (updated != null) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.articleDetail,
          arguments: updated.id,
        );
      }
      return;
    }

    final created = notifier.publishArticle(
      title: title,
      subtitle: _subtitleCtrl.text,
      body: body,
      tag: _selectedTopic,
      isAnonymous: _publishAnonymous,
      scene: _selectedScene,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Artikel berhasil dipublikasikan.')),
    );
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.articleDetail,
      arguments: created.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(studentProfileProvider);
    if (!student.role.isStaff) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: KtCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.tintIndigo,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.biruTinta,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Akses Khusus Guru BK',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hanya Guru BK yang dapat membuat atau mengelola artikel edukasi di Ruang Baca.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Kembali',
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.home);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final readMinutes = estimateReadMinutes(_bodyCtrl.text);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      KtPageHeader(
                        title: _isEditing ? 'Edit Artikel' : 'Tulis Artikel',
                        trailing:
                            KtStatusPill.indigo('$readMinutes menit baca'),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            Text(
                              'TOPIK',
                              style: AppTextStyles.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kArticleTopics.map((topic) {
                                final selected = _selectedTopic == topic;
                                return ChoiceChip(
                                  label: Text(topic),
                                  selected: selected,
                                  showCheckmark: false,
                                  selectedColor: AppColors.indigoSoft,
                                  backgroundColor: AppColors.cardWhite,
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
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'ILUSTRASI SAMPUL (OPSIONAL)',
                              style: AppTextStyles.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 76,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _CoverOptionCard(
                                    selected: _selectedScene == null,
                                    label: 'Tanpa gambar',
                                    onTap: () =>
                                        setState(() => _selectedScene = null),
                                  ),
                                  const SizedBox(width: 8),
                                  ..._coverScenes.map(
                                    (scene) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _CoverOptionCard(
                                        selected: _selectedScene == scene,
                                        scene: scene,
                                        onTap: () => setState(
                                          () => _selectedScene = scene,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            KtCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    key: const Key('composer_title_input'),
                                    controller: _titleCtrl,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    maxLines: 2,
                                    minLines: 1,
                                    style: AppTextStyles.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.inkNavy,
                                      height: 1.25,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Tulis judul artikelmu...',
                                      hintStyle: AppTextStyles.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const Divider(
                                    height: 20,
                                    color: AppColors.borderHairline,
                                  ),
                                  TextField(
                                    key: const Key('composer_subtitle_input'),
                                    controller: _subtitleCtrl,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    maxLines: 2,
                                    minLines: 1,
                                    style: AppTextStyles.inter(
                                      fontSize: 14,
                                      color: AppColors.inkSlate,
                                      height: 1.4,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Ringkasan singkat (opsional)...',
                                      hintStyle: AppTextStyles.inter(
                                        fontSize: 13.5,
                                        color: AppColors.textMuted,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const Divider(
                                    height: 20,
                                    color: AppColors.borderHairline,
                                  ),
                                  TextField(
                                    key: const Key('composer_body_input'),
                                    controller: _bodyCtrl,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    minLines: 7,
                                    maxLines: 14,
                                    onChanged: (_) => setState(() {}),
                                    style: AppTextStyles.editorialBody(
                                      fontSize: 15.5,
                                      height: 1.65,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Bagikan materi edukasi, panduan psikologis, atau tips pencegahan perundungan untuk siswa...',
                                      hintStyle: AppTextStyles.inter(
                                        fontSize: 13.5,
                                        color: AppColors.textMuted,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tips format: awali baris dengan ## untuk subjudul, > untuk kutipan, atau - untuk poin.',
                                    style: AppTextStyles.inter(
                                      fontSize: 11.5,
                                      color: AppColors.inkSlate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isEditing) ...[
                              const SizedBox(height: 14),
                              KtCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.tintIndigo,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.verified_user_outlined,
                                        size: 19,
                                        color: AppColors.biruTinta,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Publikasikan atas nama Guru BK',
                                            style: AppTextStyles.poppins(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _publishAnonymous
                                                ? 'Ditampilkan sebagai "Penulis Anonim"'
                                                : 'Menampilkan lencana terverifikasi Guru BK',
                                            style: AppTextStyles.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: !_publishAnonymous,
                                      activeTrackColor: AppColors.biruTinta,
                                      onChanged: (v) => setState(
                                        () => _publishAnonymous = !v,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_validationError != null) ...[
                          KtInfoBanner(
                            icon: Icons.info_outline_rounded,
                            backgroundColor: AppColors.sosSoft,
                            borderColor:
                                AppColors.darurat.withValues(alpha: 0.35),
                            iconColor: AppColors.darurat,
                            textColor: AppColors.crimsonContrast,
                            message: _validationError!,
                          ),
                          const SizedBox(height: 10),
                        ],
                        AppButton(
                          label: _isEditing
                              ? 'Simpan Perubahan Artikel'
                              : 'Publikasikan Artikel',
                          icon: _isEditing
                              ? Icons.save_outlined
                              : Icons.publish_rounded,
                          onPressed: _submit,
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
}

class _CoverOptionCard extends StatelessWidget {
  const _CoverOptionCard({
    required this.selected,
    required this.onTap,
    this.label,
    this.scene,
  });

  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final IllustrationScene? scene;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigoSoft : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.biruTinta : AppColors.borderHairline,
            width: selected ? 1.6 : 1.1,
          ),
        ),
        child: scene != null
            ? KitaIllustration(scene: scene!)
            : Center(
                child: Text(
                  label ?? '',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.inter(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.biruTinta : AppColors.inkSlate,
                  ),
                ),
              ),
      ),
    );
  }
}
