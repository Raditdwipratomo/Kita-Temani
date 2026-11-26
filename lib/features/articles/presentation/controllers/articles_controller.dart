import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/features/articles/domain/entities/article.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:uuid/uuid.dart';

class ArticlesState {
  const ArticlesState({
    required this.articles,
    this.readerFontScale = 1.0,
    this.isSyncingRemote = false,
  });

  final List<ArticleItem> articles;
  final double readerFontScale;
  final bool isSyncingRemote;

  List<ArticleItem> get bookmarkedArticles =>
      articles.where((a) => a.isBookmarked).toList();

  ArticleItem? findById(String id) {
    for (final item in articles) {
      if (item.id == id) return item;
    }
    return null;
  }

  ArticlesState copyWith({
    List<ArticleItem>? articles,
    double? readerFontScale,
    bool? isSyncingRemote,
  }) {
    return ArticlesState(
      articles: articles ?? this.articles,
      readerFontScale: readerFontScale ?? this.readerFontScale,
      isSyncingRemote: isSyncingRemote ?? this.isSyncingRemote,
    );
  }
}

class ArticlesNotifier extends Notifier<ArticlesState> {
  static const String _prefsKey = 'kt_articles_state_v2';
  static const int maxClapsPerArticle = 50;
  static const _uuid = Uuid();

  bool _remoteLoaded = false;
  final Set<String> _deletedArticleIds = <String>{};
  final Map<String, Map<String, dynamic>> _editedArticles =
      <String, Map<String, dynamic>>{};

  @override
  ArticlesState build() {
    final initial = _restoreInitialState();
    if (!_remoteLoaded) {
      _remoteLoaded = true;
      Future.microtask(_syncRemoteArticles);
    }
    return initial;
  }

  ArticlesState _restoreInitialState() {
    _deletedArticleIds.clear();
    _editedArticles.clear();

    final prefs = ref.read(localPreferencesServiceProvider);
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return ArticlesState(articles: defaultEditorialArticles);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return ArticlesState(articles: defaultEditorialArticles);
      }
      final map = Map<String, dynamic>.from(decoded);
      final fontScale =
          ((map['fontScale'] as num?)?.toDouble() ?? 1.0).clamp(0.85, 1.3);

      final deletedRaw = map['deletedArticleIds'];
      if (deletedRaw is List) {
        for (final id in deletedRaw) {
          final clean = id?.toString().trim() ?? '';
          if (clean.isNotEmpty) {
            _deletedArticleIds.add(clean);
          }
        }
      }

      final editedRaw = map['editedArticles'];
      if (editedRaw is Map) {
        editedRaw.forEach((key, value) {
          if (value is Map) {
            _editedArticles[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
      }

      final userArticlesRaw = map['userArticles'];
      final userArticles = userArticlesRaw is List
          ? userArticlesRaw
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => ArticleItem.fromJson(Map<String, dynamic>.from(e)))
              .where(
                (a) =>
                    !_deletedArticleIds.contains(a.id) &&
                    !_deletedArticleIds.contains(a.slug),
              )
              .toList()
          : <ArticleItem>[];

      final interactionsRaw = map['interactions'];
      final interactions = interactionsRaw is Map
          ? Map<String, dynamic>.from(interactionsRaw)
          : const <String, dynamic>{};

      final mergedDefaults = defaultEditorialArticles
          .where(
            (item) =>
                !_deletedArticleIds.contains(item.id) &&
                !_deletedArticleIds.contains(item.slug),
          )
          .map((item) => _applyEdits(item, _editedArticles[item.id]))
          .map((item) => _applyInteractions(item, interactions[item.id]))
          .toList();
      final mergedUser = userArticles
          .map((item) => _applyEdits(item, _editedArticles[item.id]))
          .map((item) => _applyInteractions(item, interactions[item.id]))
          .toList();

      return ArticlesState(
        articles: [...mergedUser, ...mergedDefaults],
        readerFontScale: fontScale,
      );
    } on Object {
      return ArticlesState(articles: defaultEditorialArticles);
    }
  }

  ArticleItem _applyEdits(ArticleItem item, Map<String, dynamic>? editMap) {
    if (editMap == null || editMap.isEmpty) return item;
    final tag = (editMap['tag'] as String?) ?? item.tag;
    final theme = topicThemeFor(tag);
    final hasExplicitSceneKey = editMap.containsKey('sceneName');
    final editedSceneName =
        hasExplicitSceneKey ? editMap['sceneName'] as String? : item.sceneName;

    return ArticleItem(
      id: item.id,
      slug: item.slug,
      tag: tag,
      title: (editMap['title'] as String?) ?? item.title,
      subtitle: (editMap['subtitle'] as String?) ?? item.subtitle,
      body: (editMap['body'] as String?) ?? item.body,
      readMinutes:
          (editMap['readMinutes'] as num?)?.toInt() ?? item.readMinutes,
      authorName: (editMap['authorName'] as String?) ?? item.authorName,
      authorRole: (editMap['authorRole'] as String?) ?? item.authorRole,
      isVerifiedAuthor: editMap['isVerifiedAuthor'] is bool
          ? editMap['isVerifiedAuthor'] as bool
          : item.isVerifiedAuthor,
      publishedAt: item.publishedAt,
      accentColorValue: (editMap['accentColorValue'] as num?)?.toInt() ??
          theme.accent.toARGB32(),
      cardBackgroundValue: (editMap['cardBackgroundValue'] as num?)?.toInt() ??
          theme.background.toARGB32(),
      borderColorValue: (editMap['borderColorValue'] as num?)?.toInt() ??
          theme.border.toARGB32(),
      tagTextColorValue: (editMap['tagTextColorValue'] as num?)?.toInt() ??
          theme.tagText.toARGB32(),
      sceneName: editedSceneName,
      clapCount: item.clapCount,
      myClapCount: item.myClapCount,
      isBookmarked: item.isBookmarked,
      isUserCreated: item.isUserCreated,
      comments: item.comments,
    );
  }

  ArticleItem _applyInteractions(ArticleItem item, dynamic rawEntry) {
    if (rawEntry is! Map) return item;
    final entry = Map<String, dynamic>.from(rawEntry);
    final commentsRaw = entry['comments'];
    final persistedComments = commentsRaw is List
        ? commentsRaw
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ArticleComment.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : null;

    return item.copyWith(
      clapCount: (entry['clapCount'] as num?)?.toInt() ?? item.clapCount,
      myClapCount: (entry['myClapCount'] as num?)?.toInt() ?? item.myClapCount,
      isBookmarked: entry['isBookmarked'] is bool
          ? entry['isBookmarked'] as bool
          : item.isBookmarked,
      comments: persistedComments ?? item.comments,
    );
  }

  Future<void> _persistState() async {
    final prefs = ref.read(localPreferencesServiceProvider);
    final userArticles = state.articles
        .where((a) => a.isUserCreated)
        .map((a) => a.toJson())
        .toList();

    final interactions = <String, Map<String, dynamic>>{};
    for (final article in state.articles) {
      interactions[article.id] = {
        'clapCount': article.clapCount,
        'myClapCount': article.myClapCount,
        'isBookmarked': article.isBookmarked,
        'comments': article.comments.map((c) => c.toJson()).toList(),
      };
    }

    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'fontScale': state.readerFontScale,
        'userArticles': userArticles,
        'interactions': interactions,
        'editedArticles': _editedArticles,
        'deletedArticleIds': _deletedArticleIds.toList(),
      }),
    );
  }

  Future<void> _syncRemoteArticles() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    try {
      state = state.copyWith(isSyncingRemote: true);
      List<dynamic> rows;
      try {
        rows = await client
            .from('education_articles')
            .select(
              'slug, title, subtitle, tag, body, read_minutes, accent_color, '
              'author_name, author_role, is_verified_author, scene_name, sort_order',
            )
            .order('sort_order', ascending: true) as List<dynamic>;
      } on Object {
        rows = await client
            .from('education_articles')
            .select('slug, title, body, read_minutes, accent_color, sort_order')
            .order('sort_order', ascending: true) as List<dynamic>;
      }
      final currentList = List<ArticleItem>.from(state.articles);
      final existingBySlug = {for (final a in currentList) a.slug: a};
      final extras = <ArticleItem>[];

      for (final raw in rows.whereType<Map<String, dynamic>>()) {
        final slug = (raw['slug'] ?? '').toString().trim();
        final title = (raw['title'] ?? '').toString().trim();
        final body = (raw['body'] ?? '').toString().trim();
        if (title.isEmpty || slug.isEmpty) continue;
        if (_deletedArticleIds.contains(slug) ||
            _deletedArticleIds.contains('remote-$slug')) {
          continue;
        }
        final rawTag = (raw['tag'] ?? '').toString().trim();
        final rawSubtitle = (raw['subtitle'] ?? '').toString().trim();
        final rawAuthorName = (raw['author_name'] ?? '').toString().trim();
        final rawAuthorRole = (raw['author_role'] ?? '').toString().trim();
        final rawSceneName = (raw['scene_name'] ?? '').toString().trim();
        final verified = raw['is_verified_author'] is bool
            ? raw['is_verified_author'] as bool
            : true;

        final existing = existingBySlug[slug];
        if (existing != null) {
          if (_editedArticles.containsKey(existing.id)) {
            continue;
          }
          final idx = currentList.indexWhere((a) => a.id == existing.id);
          if (idx >= 0) {
            currentList[idx] = existing.copyWith(
              tag: rawTag.isNotEmpty ? rawTag : existing.tag,
              title: title.replaceAll('\n', ' '),
              subtitle:
                  rawSubtitle.isNotEmpty ? rawSubtitle : existing.subtitle,
              body: body.isNotEmpty ? body : existing.body,
              readMinutes: (raw['read_minutes'] as num?)?.toInt() ??
                  existing.readMinutes,
              authorName:
                  rawAuthorName.isNotEmpty ? rawAuthorName : existing.authorName,
              authorRole:
                  rawAuthorRole.isNotEmpty ? rawAuthorRole : existing.authorRole,
              isVerifiedAuthor: verified,
              sceneName:
                  rawSceneName.isNotEmpty ? rawSceneName : existing.sceneName,
            );
          }
        } else {
          final topic = rawTag.isNotEmpty
              ? rawTag
              : kArticleTopics[extras.length % kArticleTopics.length];
          final theme = topicThemeFor(topic);
          final remoteItem = ArticleItem(
            id: 'remote-$slug',
            slug: slug,
            tag: topic,
            title: title.replaceAll('\n', ' '),
            subtitle: rawSubtitle.isNotEmpty
                ? rawSubtitle
                : body.split('\n').first,
            body: body,
            readMinutes: (raw['read_minutes'] as num?)?.toInt() ??
                estimateReadMinutes(body),
            authorName: rawAuthorName.isNotEmpty
                ? rawAuthorName
                : '$defaultCounselorName (Guru BK)',
            authorRole: rawAuthorRole.isNotEmpty
                ? rawAuthorRole
                : 'Guru BK · SMAN 1 Nusantara',
            isVerifiedAuthor: verified,
            publishedAt: DateTime.now(),
            accentColorValue: theme.accent.toARGB32(),
            cardBackgroundValue: theme.background.toARGB32(),
            borderColorValue: theme.border.toARGB32(),
            tagTextColorValue: theme.tagText.toARGB32(),
            sceneName: rawSceneName.isNotEmpty
                ? rawSceneName
                : theme.defaultScene?.name,
            clapCount: 0,
          );
          extras.add(
            _applyEdits(remoteItem, _editedArticles[remoteItem.id]),
          );
        }
      }

      state = state.copyWith(
        articles: [...currentList, ...extras],
        isSyncingRemote: false,
      );
    } on Object {
      state = state.copyWith(isSyncingRemote: false);
    }
  }

  Future<void> _upsertRemoteArticle(ArticleItem article) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null || client.auth.currentSession == null) return;
    final accentHex =
        '#${article.accentColorValue.toRadixString(16).padLeft(8, '0').substring(2)}';
    try {
      await client.from('education_articles').upsert(
        {
          'slug': article.slug,
          'tag': article.tag,
          'title': article.title,
          'subtitle': article.subtitle,
          'body': article.body,
          'read_minutes': article.readMinutes,
          'accent_color': accentHex,
          'author_name': article.authorName,
          'author_role': article.authorRole,
          'is_verified_author': article.isVerifiedAuthor,
          'scene_name': article.sceneName,
        },
        onConflict: 'slug',
      );
    } on Object {
      try {
        await client.from('education_articles').upsert(
          {
            'slug': article.slug,
            'title': article.title,
            'body': article.body,
            'read_minutes': article.readMinutes,
            'accent_color': accentHex,
          },
          onConflict: 'slug',
        );
      } on Object {
        // Best-effort remote sync; local state is already persisted.
      }
    }
  }

  Future<void> _deleteRemoteArticle(String slug) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null || client.auth.currentSession == null) return;
    try {
      await client.from('education_articles').delete().eq('slug', slug);
    } on Object {
      // Best-effort remote sync; local deletion is already persisted.
    }
  }

  void toggleBookmark(String articleId) {
    state = state.copyWith(
      articles: [
        for (final article in state.articles)
          if (article.id == articleId)
            article.copyWith(isBookmarked: !article.isBookmarked)
          else
            article,
      ],
    );
    unawaited(_persistState());
  }

  bool clapArticle(String articleId) {
    final target = state.findById(articleId);
    if (target == null || target.myClapCount >= maxClapsPerArticle) {
      return false;
    }
    state = state.copyWith(
      articles: [
        for (final article in state.articles)
          if (article.id == articleId)
            article.copyWith(
              clapCount: article.clapCount + 1,
              myClapCount: article.myClapCount + 1,
            )
          else
            article,
      ],
    );
    unawaited(_persistState());
    return true;
  }

  void addComment({
    required String articleId,
    required String body,
    required bool isAnonymous,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final student = ref.read(studentProfileProvider);
    final resolvedName = isAnonymous
        ? 'Siswa Anonim'
        : (student.name.trim().isNotEmpty
            ? student.name.trim()
            : (student.shortName.trim().isNotEmpty
                ? student.shortName.trim()
                : 'Siswa KitaTemani'));
    final resolvedRole = isAnonymous
        ? 'Anonim'
        : (student.role.isStaff
            ? 'Guru BK'
            : (student.className.trim().isNotEmpty
                ? 'Siswa · ${student.className.trim()}'
                : 'Siswa'));

    final comment = ArticleComment(
      id: 'cmt-${_uuid.v4()}',
      authorName: resolvedName,
      authorRole: resolvedRole,
      isVerifiedStaff: !isAnonymous && student.role.isStaff,
      isAnonymous: isAnonymous,
      body: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      articles: [
        for (final article in state.articles)
          if (article.id == articleId)
            article.copyWith(comments: [comment, ...article.comments])
          else
            article,
      ],
    );
    unawaited(_persistState());
  }

  void deleteComment({
    required String articleId,
    required String commentId,
  }) {
    state = state.copyWith(
      articles: [
        for (final article in state.articles)
          if (article.id == articleId)
            article.copyWith(
              comments: article.comments
                  .where((c) => c.id != commentId)
                  .toList(growable: false),
            )
          else
            article,
      ],
    );
    unawaited(_persistState());
  }

  void toggleCommentHelpful(String articleId, String commentId) {
    state = state.copyWith(
      articles: [
        for (final article in state.articles)
          if (article.id == articleId)
            article.copyWith(
              comments: [
                for (final c in article.comments)
                  if (c.id == commentId)
                    c.copyWith(
                      isHelpfulByMe: !c.isHelpfulByMe,
                      helpfulCount: c.isHelpfulByMe
                          ? (c.helpfulCount > 0 ? c.helpfulCount - 1 : 0)
                          : c.helpfulCount + 1,
                    )
                  else
                    c,
              ],
            )
          else
            article,
      ],
    );
    unawaited(_persistState());
  }

  ArticleItem publishArticle({
    required String title,
    required String subtitle,
    required String body,
    required String tag,
    required bool isAnonymous,
    IllustrationScene? scene,
  }) {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    final cleanSubtitle = subtitle.trim().isNotEmpty
        ? subtitle.trim()
        : cleanBody
            .replaceAll(RegExp(r'^#{1,3}\s*|^>\s*|-\s*', multiLine: true), '')
            .split('\n')
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => cleanTitle);

    final theme = topicThemeFor(tag);
    final student = ref.read(studentProfileProvider);
    final resolvedAuthor = isAnonymous
        ? 'Tim Guru BK'
        : (student.name.trim().isNotEmpty
            ? student.name.trim()
            : '$defaultCounselorName (Guru BK)');
    const resolvedRole = 'Guru BK';

    final id = 'user-${_uuid.v4()}';
    final created = ArticleItem(
      id: id,
      slug: id,
      tag: tag,
      title: cleanTitle,
      subtitle: cleanSubtitle,
      body: cleanBody,
      readMinutes: estimateReadMinutes(cleanBody),
      authorName: resolvedAuthor,
      authorRole: resolvedRole,
      isVerifiedAuthor: !isAnonymous && student.role.isStaff,
      publishedAt: DateTime.now(),
      accentColorValue: theme.accent.toARGB32(),
      cardBackgroundValue: theme.background.toARGB32(),
      borderColorValue: theme.border.toARGB32(),
      tagTextColorValue: theme.tagText.toARGB32(),
      sceneName: scene?.name,
      clapCount: 1,
      myClapCount: 1,
      isUserCreated: true,
    );

    state = state.copyWith(articles: [created, ...state.articles]);
    unawaited(_persistState());
    unawaited(_upsertRemoteArticle(created));
    return created;
  }

  ArticleItem? updateArticle({
    required String articleId,
    required String title,
    required String subtitle,
    required String body,
    required String tag,
    IllustrationScene? scene,
    bool clearScene = false,
  }) {
    final existing = state.findById(articleId);
    if (existing == null) return null;

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    final cleanSubtitle = subtitle.trim().isNotEmpty
        ? subtitle.trim()
        : cleanBody
            .replaceAll(RegExp(r'^#{1,3}\s*|^>\s*|-\s*', multiLine: true), '')
            .split('\n')
            .firstWhere((l) => l.trim().isNotEmpty, orElse: () => cleanTitle);

    final theme = topicThemeFor(tag);
    final resolvedSceneName =
        clearScene ? null : (scene?.name ?? existing.sceneName);
    final updated = ArticleItem(
      id: existing.id,
      slug: existing.slug,
      tag: tag,
      title: cleanTitle,
      subtitle: cleanSubtitle,
      body: cleanBody,
      readMinutes: estimateReadMinutes(cleanBody),
      authorName: existing.authorName,
      authorRole: existing.authorRole,
      isVerifiedAuthor: existing.isVerifiedAuthor,
      publishedAt: existing.publishedAt,
      accentColorValue: theme.accent.toARGB32(),
      cardBackgroundValue: theme.background.toARGB32(),
      borderColorValue: theme.border.toARGB32(),
      tagTextColorValue: theme.tagText.toARGB32(),
      sceneName: resolvedSceneName,
      clapCount: existing.clapCount,
      myClapCount: existing.myClapCount,
      isBookmarked: existing.isBookmarked,
      isUserCreated: existing.isUserCreated,
      comments: existing.comments,
    );

    _editedArticles[articleId] = {
      'tag': updated.tag,
      'title': updated.title,
      'subtitle': updated.subtitle,
      'body': updated.body,
      'readMinutes': updated.readMinutes,
      'accentColorValue': updated.accentColorValue,
      'cardBackgroundValue': updated.cardBackgroundValue,
      'borderColorValue': updated.borderColorValue,
      'tagTextColorValue': updated.tagTextColorValue,
      'sceneName': updated.sceneName,
    };

    state = state.copyWith(
      articles: [
        for (final article in state.articles)
          if (article.id == articleId) updated else article,
      ],
    );
    unawaited(_persistState());
    unawaited(_upsertRemoteArticle(updated));
    return updated;
  }

  void deleteArticle(String articleId) {
    final target = state.findById(articleId);
    _deletedArticleIds.add(articleId);
    if (target != null) {
      _deletedArticleIds.add(target.slug);
    }
    _editedArticles.remove(articleId);
    state = state.copyWith(
      articles: state.articles
          .where((article) => article.id != articleId)
          .toList(growable: false),
    );
    unawaited(_persistState());
    if (target != null) {
      unawaited(_deleteRemoteArticle(target.slug));
    }
  }

  void setFontScale(double scale) {
    state = state.copyWith(readerFontScale: scale.clamp(0.85, 1.3));
    unawaited(_persistState());
  }

  void cycleFontScale() {
    final current = state.readerFontScale;
    final next = current < 0.95 ? 1.0 : (current < 1.1 ? 1.15 : 0.9);
    setFontScale(next);
  }
}

final articlesControllerProvider =
    NotifierProvider<ArticlesNotifier, ArticlesState>(
  ArticlesNotifier.new,
);
