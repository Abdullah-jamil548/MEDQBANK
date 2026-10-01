import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../../domain/entities/chat_message.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../providers/chat_provider.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.friendUserId,
    required this.friendName,
  });

  final String friendUserId;
  final String friendName;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  ChatProvider? _chat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chat ??= context.read<ChatProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().openThread(
            friendUserId: widget.friendUserId,
            friendName: widget.friendName,
          );
    });
  }

  @override
  void dispose() {
    _chat?.closeThread();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openBookShare(ChatMessage message) async {
    final bookId = message.bookId;
    final pageNo = message.pageNo;
    if (bookId == null || pageNo == null) return;

    final library = context.read<LibraryProvider>();
    if (library.books.isEmpty) {
      await library.load();
    }
    CatalogBook? book;
    for (final item in library.books) {
      if (item.id == bookId) {
        book = item;
        break;
      }
    }
    if (book == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book not found in your library')),
      );
      return;
    }

    if (!(library.downloaded[book.id] ?? false)) {
      if (!mounted) return;
      final download = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Download book?'),
          content: Text(
            '${book!.title} needs to be downloaded before opening page $pageNo.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download')),
          ],
        ),
      );
      if (download != true) return;
      await library.downloadBook(book);
      if (!(library.downloaded[book.id] ?? false)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(library.downloadError ?? 'Download failed')),
        );
        return;
      }
    }

    final ok = await library.openBook(book, initialPage: pageNo);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(library.downloadError ?? 'Could not open book')),
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.bookReader);
  }

  Future<void> _send() async {
    final text = _controller.text;
    final ok = await context.read<ChatProvider>().sendText(text);
    if (!ok) return;
    _controller.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
        actions: [
          IconButton(
            tooltip: chat.activeThreadMuted ? 'Unmute chat' : 'Mute chat',
            onPressed: () => chat.toggleMute(),
            icon: Icon(
              chat.activeThreadMuted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_none_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (chat.activeThreadMuted)
            Material(
              color: AppColors.surfaceMuted,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notifications muted for this chat',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (chat.error != null)
            Material(
              color: AppColors.errorSoft,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  chat.error!,
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Expanded(
            child: chat.loadingMessages && chat.messages.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final message = chat.messages[index];
                      return _MessageBubble(
                        message: message,
                        onOpenShare: message.isBookShare
                            ? () => _openBookShare(message)
                            : null,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.friendName.split(' ').first}…',
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: chat.sending ? null : _send,
                    icon: chat.sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onOpenShare});

  final ChatMessage message;
  final VoidCallback? onOpenShare;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = mine ? AppColors.primary : AppColors.surfaceMuted;
    final fg = mine ? Colors.white : AppColors.textPrimary;
    final timeLabel = ChatProvider.formatMessageTime(message.createdAt);
    final timeColor = mine ? Colors.white.withValues(alpha: 0.8) : AppColors.textMuted;

    Widget content = message.isBookShare
        ? InkWell(
            onTap: onOpenShare,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        message.bookTitle ?? 'Shared passage',
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Page ${message.pageNo ?? '?'} · Tap to open',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if ((message.selectedText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: mine
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '“${message.selectedText!.trim()}”',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                if ((message.body ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message.body!,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          )
        : Text(
            message.body ?? '',
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.35),
          );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              content,
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.pending) ...[
                    Text(
                      'Sending…',
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: timeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
