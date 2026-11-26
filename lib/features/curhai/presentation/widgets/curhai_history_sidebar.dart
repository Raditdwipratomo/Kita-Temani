import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_conversation.dart';

enum _ConversationMenuAction { pin, rename, delete }

class CurhaiHistorySidebar extends StatelessWidget {
  const CurhaiHistorySidebar({
    required this.conversations,
    required this.activeConversationId,
    required this.isTyping,
    required this.typingConversationId,
    required this.isDrawer,
    required this.onClose,
    required this.onNewChat,
    required this.onSelectConversation,
    required this.onTogglePin,
    required this.onRenameConversation,
    required this.onDeleteConversation,
    required this.onClearAll,
    super.key,
  });

  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final bool isTyping;
  final String? typingConversationId;
  final bool isDrawer;
  final VoidCallback onClose;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectConversation;
  final ValueChanged<ChatConversation> onTogglePin;
  final ValueChanged<ChatConversation> onRenameConversation;
  final ValueChanged<ChatConversation> onDeleteConversation;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final pinned = conversations.where((c) => c.isPinned).toList();
    final recent = conversations.where((c) => !c.isPinned).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Riwayat CurhAI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkNavy,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tutup riwayat',
                onPressed: onClose,
                icon: Icon(
                  isDrawer ? Icons.close_rounded : Icons.menu_open_rounded,
                  size: 20,
                  color: AppColors.inkSlate,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Material(
            color: AppColors.tintIndigo,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onNewChat,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.biruTinta.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_comment_outlined,
                      size: 18,
                      color: AppColors.biruTinta,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Obrolan baru',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.biruTinta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.tintIndigo,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            size: 22,
                            color: AppColors.inkSlate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada riwayat obrolan',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cerita yang kamu kirim akan otomatis tersimpan di perangkat ini.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                  itemCount: (pinned.isNotEmpty
                          ? 1 + pinned.length + (recent.isNotEmpty ? 1 : 0)
                          : 0) +
                      (recent.isNotEmpty ? 1 + recent.length : 0),
                  itemBuilder: (context, index) {
                    final hasPinned = pinned.isNotEmpty;
                    final hasRecent = recent.isNotEmpty;
                    final pinnedBlockCount = hasPinned
                        ? 1 + pinned.length + (hasRecent ? 1 : 0)
                        : 0;
                    if (hasPinned && index < pinnedBlockCount) {
                      if (index == 0) {
                        return const _SidebarSectionHeader(label: 'DISEMATKAN');
                      }
                      if (hasRecent && index == pinnedBlockCount - 1) {
                        return const SizedBox(height: 10);
                      }
                      final conv = pinned[index - 1];
                      return _ConversationHistoryTile(
                        conversation: conv,
                        isSelected: conv.id == activeConversationId,
                        isStreaming:
                            isTyping && typingConversationId == conv.id,
                        onSelect: () => onSelectConversation(conv.id),
                        onTogglePin: () => onTogglePin(conv),
                        onRename: () => onRenameConversation(conv),
                        onDelete: () => onDeleteConversation(conv),
                      );
                    }
                    final recentIndex = index - pinnedBlockCount;
                    if (recentIndex == 0) {
                      return const _SidebarSectionHeader(label: 'TERBARU');
                    }
                    final conv = recent[recentIndex - 1];
                    return _ConversationHistoryTile(
                      conversation: conv,
                      isSelected: conv.id == activeConversationId,
                      isStreaming: isTyping && typingConversationId == conv.id,
                      onSelect: () => onSelectConversation(conv.id),
                      onTogglePin: () => onTogglePin(conv),
                      onRename: () => onRenameConversation(conv),
                      onDelete: () => onDeleteConversation(conv),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.borderHairline, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.inkSlate,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tersimpan lokal di perangkatmu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.inter(
                    fontSize: 11.5,
                    color: AppColors.inkSlate,
                  ),
                ),
              ),
              if (conversations.length > 1)
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.darurat,
                  ),
                  child: Text(
                    'Hapus semua',
                    style: AppTextStyles.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darurat,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Text(
        label,
        style: AppTextStyles.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppColors.inkSlate,
        ),
      ),
    );
  }
}

class _ConversationHistoryTile extends StatelessWidget {
  const _ConversationHistoryTile({
    required this.conversation,
    required this.isSelected,
    required this.isStreaming,
    required this.onSelect,
    required this.onTogglePin,
    required this.onRename,
    required this.onDelete,
  });

  final ChatConversation conversation;
  final bool isSelected;
  final bool isStreaming;
  final VoidCallback onSelect;
  final VoidCallback onTogglePin;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? AppColors.indigoSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          hoverColor: AppColors.tintIndigo,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.biruTinta.withValues(alpha: 0.22)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: AppColors.inkNavy,
                      ),
                    ),
                  ),
                ),
                if (isStreaming)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.biruTinta,
                      shape: BoxShape.circle,
                    ),
                  )
                else if (conversation.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: AppColors.biruTinta,
                    ),
                  ),
                PopupMenuButton<_ConversationMenuAction>(
                  tooltip: 'Opsi obrolan',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 168,
                  ),
                  color: AppColors.cardWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(
                      color: AppColors.borderHairline,
                      width: 1,
                    ),
                  ),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isSelected ? AppColors.inkNavy : AppColors.inkSlate,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _ConversationMenuAction.pin:
                        onTogglePin();
                      case _ConversationMenuAction.rename:
                        onRename();
                      case _ConversationMenuAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<_ConversationMenuAction>(
                      value: _ConversationMenuAction.pin,
                      child: Row(
                        children: [
                          Icon(
                            conversation.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            size: 17,
                            color: AppColors.inkNavy,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            conversation.isPinned
                                ? 'Lepas sematan'
                                : 'Sematkan',
                            style: AppTextStyles.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ConversationMenuAction>(
                      value: _ConversationMenuAction.rename,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 17,
                            color: AppColors.inkNavy,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Ubah judul',
                            style: AppTextStyles.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ConversationMenuAction>(
                      value: _ConversationMenuAction.delete,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                            color: AppColors.darurat,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Hapus',
                            style: AppTextStyles.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.darurat,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> showRenameConversationDialog(
  BuildContext context,
  String initialTitle,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameConversationDialog(initialTitle: initialTitle),
  );
}

class _RenameConversationDialog extends StatefulWidget {
  const _RenameConversationDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<_RenameConversationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Ubah judul obrolan', style: AppTextStyles.heading2),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        style: AppTextStyles.inter(
          fontSize: 14,
          color: AppColors.inkNavy,
        ),
        decoration: const InputDecoration(
          hintText: 'Judul obrolan',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
