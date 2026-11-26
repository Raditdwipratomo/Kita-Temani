import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/features/curhai/data/repositories/curhai_repository_impl.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_conversation.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';
import 'package:kitatemani/features/curhai/presentation/controllers/curhai_controller.dart';
import 'package:kitatemani/features/curhai/presentation/widgets/curhai_history_sidebar.dart';
import 'package:kitatemani/features/curhai/presentation/widgets/markdown_chat_text.dart';
import 'package:kitatemani/l10n/l10n.dart';

class CurhaiScreen extends ConsumerStatefulWidget {
  const CurhaiScreen({super.key});

  @override
  ConsumerState<CurhaiScreen> createState() => _CurhaiScreenState();
}

class _CurhaiScreenState extends ConsumerState<CurhaiScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _localCrisisTriggered = false;
  bool _crisisDismissed = false;
  bool _isDesktopSidebarOpen = true;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _handleStartNewChat({bool closeDrawer = false}) {
    setState(() {
      _localCrisisTriggered = false;
      _crisisDismissed = false;
    });
    if (closeDrawer) {
      _scaffoldKey.currentState?.closeDrawer();
    }
    unawaited(ref.read(curhaiControllerProvider.notifier).startNewChat());
  }

  void _handleSelectConversation(String conversationId, {bool closeDrawer = false}) {
    setState(() {
      _localCrisisTriggered = false;
      _crisisDismissed = false;
    });
    if (closeDrawer) {
      _scaffoldKey.currentState?.closeDrawer();
    }
    unawaited(
      ref
          .read(curhaiControllerProvider.notifier)
          .selectConversation(conversationId),
    );
    _scrollToBottomAfterFrame();
  }

  Future<void> _handleRenameConversation(ChatConversation conversation) async {
    final newTitle =
        await showRenameConversationDialog(context, conversation.title);
    if (!mounted || newTitle == null || newTitle.trim().isEmpty) return;
    await ref
        .read(curhaiControllerProvider.notifier)
        .renameConversation(conversation.id, newTitle);
  }

  Future<void> _handleDeleteConversation(ChatConversation conversation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus obrolan?', style: AppTextStyles.heading2),
        content: Text(
          'Obrolan "${conversation.title}" akan dihapus dari riwayat di perangkat ini.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darurat,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final wasActive =
        ref.read(curhaiControllerProvider).activeConversationId ==
            conversation.id;
    if (wasActive) {
      setState(() {
        _localCrisisTriggered = false;
        _crisisDismissed = false;
      });
    }
    await ref
        .read(curhaiControllerProvider.notifier)
        .deleteConversation(conversation.id);
  }

  Future<void> _handleClearAllConversations({bool closeDrawer = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus semua riwayat?', style: AppTextStyles.heading2),
        content: Text(
          'Semua riwayat obrolan CurhAI di perangkat ini akan dihapus.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darurat,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
            ),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _localCrisisTriggered = false;
      _crisisDismissed = false;
    });
    if (closeDrawer) {
      _scaffoldKey.currentState?.closeDrawer();
    }
    await ref.read(curhaiControllerProvider.notifier).clearAllConversations();
  }

  bool _isUrgentCrisisText(String text) {
    if (detectCrisisRiskLevel(text) == CrisisRiskLevel.crisis) {
      return true;
    }
    final lower = text.toLowerCase();
    return lower.contains('bunuh') ||
        lower.contains('mati') ||
        lower.contains('takut sekali') ||
        lower.contains('dipukuli') ||
        lower.contains('darurat');
  }

  OwlMood _resolveHeaderMood(CurhaiState state, bool showCrisisCard) {
    if (state.isActiveTyping) return OwlMood.thinking;
    if (showCrisisCard || state.errorMessage != null) {
      return OwlMood.reassuring;
    }
    if (state.messages.isNotEmpty &&
        state.messages.last.riskLevel == CrisisRiskLevel.elevated) {
      return OwlMood.listening;
    }
    return OwlMood.warm;
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _inputController.text;
    if (text.trim().isEmpty) return;
    if (preset == null) _inputController.clear();

    if (_isUrgentCrisisText(text)) {
      setState(() {
        _localCrisisTriggered = true;
        _crisisDismissed = false;
      });
    }

    await ref.read(curhaiControllerProvider.notifier).sendUserMessage(text);
    if (!mounted) return;

    if (ref.read(curhaiControllerProvider).hasCrisisAlert) {
      setState(() => _crisisDismissed = false);
    }

    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildSidebar(
    CurhaiState state,
    List<ChatConversation> sortedConversations, {
    required bool isDrawer,
  }) {
    return CurhaiHistorySidebar(
      conversations: sortedConversations,
      activeConversationId: state.activeConversationId,
      isTyping: state.isTyping,
      typingConversationId: state.typingConversationId,
      isDrawer: isDrawer,
      onClose: () {
        if (isDrawer) {
          _scaffoldKey.currentState?.closeDrawer();
        } else {
          setState(() => _isDesktopSidebarOpen = false);
        }
      },
      onNewChat: () => _handleStartNewChat(closeDrawer: isDrawer),
      onSelectConversation: (id) =>
          _handleSelectConversation(id, closeDrawer: isDrawer),
      onTogglePin: (conv) {
        unawaited(
          ref
              .read(curhaiControllerProvider.notifier)
              .togglePinConversation(conv.id),
        );
      },
      onRenameConversation: _handleRenameConversation,
      onDeleteConversation: _handleDeleteConversation,
      onClearAll: () => unawaited(
        _handleClearAllConversations(closeDrawer: isDrawer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(curhaiControllerProvider);
    final sortedConversations = state.sortedConversations;
    final bool showCrisisCard =
        !_crisisDismissed && (_localCrisisTriggered || state.hasCrisisAlert);
    final activeConv = state.activeConversation;

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final bool isDesktop = outerConstraints.maxWidth >= 900;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.canvas,
          drawer: isDesktop
              ? null
              : Drawer(
                  width: math.min(outerConstraints.maxWidth * 0.84, 300),
                  backgroundColor: AppColors.cardWhite,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.horizontal(right: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    child: _buildSidebar(
                      state,
                      sortedConversations,
                      isDrawer: true,
                    ),
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (isDesktop && _isDesktopSidebarOpen)
                  Container(
                    width: 276,
                    decoration: const BoxDecoration(
                      color: AppColors.cardWhite,
                      border: Border(
                        right: BorderSide(
                          color: AppColors.borderHairline,
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildSidebar(
                      state,
                      sortedConversations,
                      isDrawer: false,
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double contentWidth = math.max(
                        0,
                        math.min(constraints.maxWidth, 720),
                      );
                      final double bubbleMaxWidth = math.max(
                        0,
                        math.min((contentWidth - 32) * 0.74, 520),
                      );

                      return Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            children: [
                              // Header
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 10),
                                child: Row(
                                  children: [
                                    if (Navigator.of(context).canPop()) ...[
                                      CircleActionButton(
                                        icon: Icons.arrow_back_rounded,
                                        size: 38,
                                        iconSize: 19,
                                        onTap: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    CircleActionButton(
                                      icon: (isDesktop && _isDesktopSidebarOpen)
                                          ? Icons.menu_open_rounded
                                          : Icons.menu_rounded,
                                      size: 38,
                                      iconSize: 19,
                                      tooltip: 'Riwayat obrolan',
                                      onTap: () {
                                        if (isDesktop) {
                                          setState(
                                            () => _isDesktopSidebarOpen =
                                                !_isDesktopSidebarOpen,
                                          );
                                        } else {
                                          _scaffoldKey.currentState
                                              ?.openDrawer();
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    OwlMascot(
                                      mood: _resolveHeaderMood(
                                        state,
                                        showCrisisCard,
                                      ),
                                      size: 38,
                                      backgroundColor: AppColors.indigoSoft,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            L10n.curhaiTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.heading2,
                                          ),
                                          Text(
                                            state.isActiveTyping
                                                ? 'Sedang merangkai balasan empatik…'
                                                : (activeConv != null
                                                    ? activeConv.title
                                                    : L10n.curhaiStatus),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.inter(
                                              fontSize: 12,
                                              color: AppColors.mintText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    CircleActionButton(
                                      icon: Icons.add_comment_outlined,
                                      size: 38,
                                      iconSize: 19,
                                      tooltip: 'Mulai obrolan baru',
                                      onTap: _handleStartNewChat,
                                    ),
                                    const SizedBox(width: 8),
                                    CircleActionButton(
                                      icon: Icons.emergency_share_outlined,
                                      size: 38,
                                      iconSize: 19,
                                      iconColor: AppColors.darurat,
                                      backgroundColor: AppColors.sosSoft,
                                      tooltip: 'Tombol Darurat',
                                      onTap: () => Navigator.of(context)
                                          .pushNamed(AppRoutes.panic),
                                    ),
                                  ],
                                ),
                              ),

                    // Privacy pill banner
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: KtInfoBanner(
                        icon: Icons.lock_outline_rounded,
                        message: L10n.curhaiPrivacyPill,
                      ),
                    ),

                    if (showCrisisCard)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: KtCard(
                          color: AppColors.sosSoft,
                          borderColor:
                              AppColors.darurat.withValues(alpha: 0.45),
                          borderWidth: 1.4,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.health_and_safety_outlined,
                                    color: AppColors.darurat,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Bicara dengan orang sekarang',
                                      style: AppTextStyles.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.crimsonContrast,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _crisisDismissed = true,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.inkSlate,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Jika kamu merasa terancam atau butuh pendampingan langsung, hubungi orang tua / Guru BK lewat Tombol SOS atau buat laporan bullying sekarang.',
                                style: AppTextStyles.inter(
                                  fontSize: 12,
                                  color: AppColors.crimsonContrast,
                                  height: 1.38,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => Navigator.of(context)
                                          .pushNamed(AppRoutes.panic),
                                      icon: const Icon(
                                        Icons.emergency_share_outlined,
                                        size: 15,
                                        color: AppColors.darurat,
                                      ),
                                      label: const Text('Tombol SOS'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.darurat,
                                        side: BorderSide(
                                          color: AppColors.darurat
                                              .withValues(alpha: 0.45),
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.of(context)
                                          .pushNamed(AppRoutes.reportType),
                                      icon: const Icon(
                                        Icons.school_outlined,
                                        size: 15,
                                      ),
                                      label: const Text('Lapor Guru BK'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: KtCard(
                          color: AppColors.sosSoft,
                          borderColor: AppColors.darurat.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: AppColors.darurat,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.errorMessage!,
                                  style: AppTextStyles.inter(
                                    fontSize: 12,
                                    color: AppColors.crimsonContrast,
                                    height: 1.38,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => ref
                                    .read(curhaiControllerProvider.notifier)
                                    .clearError(),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.inkSlate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Chat list
                    Expanded(
                      child: state.messages.isEmpty && !state.isActiveTyping
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const OwlMascot(
                                      mood: OwlMood.warm,
                                      size: 96,
                                      backgroundColor: AppColors.indigoSoft,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Mulai bercerita dengan CurhAI',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.heading2,
                                    ),
                                    const SizedBox(height: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 420,
                                      ),
                                      child: Text(
                                        'Ceritakan pelan-pelan apa yang kamu rasakan. Aku siap mendengarkan tanpa menghakimi, dan obrolanmu tetap privat.',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _ChatActionPill(
                                          label: 'Aku merasa cemas di sekolah',
                                          onTap: () => _send(
                                            'Aku merasa cemas di sekolah hari ini.',
                                          ),
                                        ),
                                        _ChatActionPill(
                                          label:
                                              'Bagaimana cara hadapi ejekan?',
                                          onTap: () => _send(
                                            'Bagaimana cara tenang saat menghadapi ejekan teman?',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              itemCount: state.messages.length +
                                  (state.isActiveTyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= state.messages.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const OwlMascot(
                                          mood: OwlMood.thinking,
                                          size: 28,
                                          backgroundColor: AppColors.indigoSoft,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.cardWhite,
                                              borderRadius:
                                                  BorderRadius.circular(18)
                                                      .copyWith(
                                                bottomLeft:
                                                    const Radius.circular(4),
                                              ),
                                              border: Border.all(
                                                color: AppColors.borderHairline,
                                                width: 1.1,
                                              ),
                                            ),
                                            child: Text(
                                              'CurhAI sedang mengetik…',
                                              style: AppTextStyles.inter(
                                                fontSize: 12.5,
                                                color: AppColors.inkSlate,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final msg = state.messages[index];
                                final isUser = msg.sender == ChatSender.user;
                                if (isUser) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxWidth: bubbleMaxWidth,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          gradient:
                                              AppColors.primaryButtonGradient,
                                          borderRadius:
                                              BorderRadius.circular(18)
                                                  .copyWith(
                                            bottomRight:
                                                const Radius.circular(4),
                                          ),
                                          boxShadow: AppColors.buttonShadow,
                                        ),
                                        child: Text(
                                          msg.content,
                                          style: AppTextStyles.inter(
                                            fontSize: 13.5,
                                            color: Colors.white,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final bool isOutOfScope = msg.isOutOfScope;
                                final Widget markdownBody = MarkdownChatText(
                                  data: msg.content,
                                  style: AppTextStyles.inter(
                                    fontSize: 13.5,
                                    color: AppColors.inkNavy,
                                    height: 1.45,
                                  ),
                                  resolveStyle: (s) => AppTextStyles.inter(
                                    fontSize: s.fontSize ?? 13.5,
                                    fontWeight: s.fontWeight ?? FontWeight.w400,
                                    fontStyle: s.fontStyle,
                                    color: s.color ?? AppColors.inkNavy,
                                    height: s.height,
                                    letterSpacing: s.letterSpacing,
                                    decoration: s.decoration,
                                    decorationColor: s.decorationColor,
                                  ),
                                  codeStyle: AppTextStyles.code(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.inkNavy,
                                    letterSpacing: 0,
                                  ).copyWith(
                                    backgroundColor: AppColors.tintIndigo,
                                  ),
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      OwlMascot(
                                        mood: isOutOfScope
                                            ? OwlMood.reassuring
                                            : OwlMood.listening,
                                        size: 28,
                                        backgroundColor: AppColors.indigoSoft,
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth: bubbleMaxWidth,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardWhite,
                                          borderRadius:
                                              BorderRadius.circular(18)
                                                  .copyWith(
                                            bottomLeft:
                                                const Radius.circular(4),
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderHairline,
                                            width: 1.1,
                                          ),
                                        ),
                                        child: markdownBody,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Permanent disclaimer (FR-CH-05)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        L10n.curhaiDisclaimer,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.inter(
                          fontSize: 11,
                          color: AppColors.inkSlate,
                        ),
                      ),
                    ),

                    // Floating pill composer (clean single border, no inner box artifacts)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      padding: const EdgeInsets.fromLTRB(16, 5, 6, 5),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.borderHairline,
                          width: 1.1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              style: AppTextStyles.inter(
                                fontSize: 13.5,
                                color: AppColors.inkNavy,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                isDense: true,
                                hintText: 'Ketik ceritamu dengan aman...',
                                hintStyle: AppTextStyles.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              gradient: AppColors.primaryButtonGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppColors.buttonShadow,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () => _send(),
                            ),
                          ),
                        ],
                      ),
                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatActionPill extends StatelessWidget {
  const _ChatActionPill({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = AppTextStyles.inter(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: AppColors.inkNavy,
    );

    return Material(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderHairline, width: 1.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
