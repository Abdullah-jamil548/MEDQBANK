import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../../domain/entities/friend.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../providers/library_provider.dart';

class BookReaderPage extends StatefulWidget {
  const BookReaderPage({super.key});

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final _noteController = TextEditingController();
  PdfViewerController? _controller;
  List<PdfTextRanges> _selections = const [];
  String _tint = 'amber';

  /// When true, pan/zoom drag is disabled so text selection can capture gestures.
  bool _selectMode = false;
  bool _didJumpInitialPage = false;

  String get _selectedText {
    final parts = _selections
        .where((s) => s.isNotEmpty)
        .map((s) => s.text.trim())
        .where((t) => t.isNotEmpty);
    return parts.join(' ').trim();
  }

  bool get _hasSelection => _selectedText.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToPendingPage());
  }

  void _jumpToPendingPage() {
    if (_didJumpInitialPage || !mounted) return;
    final page = context.read<LibraryProvider>().consumePendingInitialPage();
    if (page == null) return;
    _didJumpInitialPage = true;
    // Viewer may still be attaching; retry shortly.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _controller?.goToPage(pageNumber: page);
      context.read<LibraryProvider>().setPage(page);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) {
        _selections = const [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final book = library.selectedBook;
    final path = library.localPdfPath;
    final bytes = library.pdfBytes;

    final hasSource = book != null &&
        (bytes != null && bytes.isNotEmpty ||
            (!kIsWeb && path != null && path.isNotEmpty));

    if (!hasSource) {
      return Scaffold(
        appBar: AppBar(leading: const AppBackButton()),
        body: const Center(child: Text('No local PDF. Download the book first.')),
      );
    }

    // Key forces viewer rebuild when select/pan mode flips (panEnabled alone is sticky).
    final viewerParams = PdfViewerParams(
      enableTextSelection: true,
      panEnabled: !_selectMode,
      onPageChanged: (pageNumber) {
        if (pageNumber != null) {
          context.read<LibraryProvider>().setPage(pageNumber);
        }
      },
      onTextSelectionChange: (selections) {
        final next = List<PdfTextRanges>.from(selections);
        final text = next
            .where((s) => s.isNotEmpty)
            .map((s) => s.text.trim())
            .where((t) => t.isNotEmpty)
            .join(' ');
        setState(() {
          _selections = next;
          if (text.isNotEmpty && !_selectMode) {
            _selectMode = true;
          }
        });
      },
      pagePaintCallbacks: [_paintSavedHighlights],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          _selectMode
                              ? 'Select mode: drag over text, then Highlight'
                              : 'Page ${library.currentPage} • Tap highlighter to select text',
                          style: TextStyle(
                            color: _selectMode ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _selectMode ? 'Exit select mode' : 'Select text to highlight',
                    onPressed: _toggleSelectMode,
                    style: IconButton.styleFrom(
                      backgroundColor: _selectMode ? AppColors.primarySoft : null,
                    ),
                    icon: Icon(
                      Icons.highlight_alt_rounded,
                      color: _selectMode ? AppColors.primary : null,
                    ),
                  ),
                  IconButton(
                    tooltip: library.isPageBookmarked() ? 'Remove bookmark' : 'Bookmark page',
                    onPressed: library.toggleBookmark,
                    icon: Icon(
                      library.isPageBookmarked()
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Page note',
                    onPressed: () => _addPageNoteDialog(library),
                    icon: const Icon(Icons.note_add_outlined),
                  ),
                  IconButton(
                    tooltip: 'Highlights & notes',
                    onPressed: () => _openMarks(library),
                    icon: const Icon(Icons.list_alt_rounded),
                  ),
                ],
              ),
            ),
            if (_selectMode)
              Material(
                color: AppColors.primarySoft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          kIsWeb
                              ? 'Click and drag across words to select them.'
                              : 'Long-press a word, then drag to select.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _toggleSelectMode,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: bytes != null
                        ? PdfViewer.data(
                            bytes,
                            key: ValueKey('pdf-data-${book.id}-$_selectMode'),
                            sourceName: book.id,
                            controller: _controller ??= PdfViewerController(),
                            params: viewerParams,
                          )
                        : PdfViewer.file(
                            path!,
                            key: ValueKey('pdf-file-${book.id}-$_selectMode'),
                            controller: _controller ??= PdfViewerController(),
                            params: viewerParams,
                          ),
                  ),
                  if (_hasSelection)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 16,
                      child: _SelectionActionBar(
                        preview: _selectedText,
                        tint: _tint,
                        onTint: (c) => setState(() => _tint = c),
                        onHighlight: () => _saveHighlight(library),
                        onNote: () => _noteFromSelection(library),
                        onSend: () => _sendSelectionToFriend(library),
                        onClear: () => setState(() => _selections = const []),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _paintSavedHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final library = context.read<LibraryProvider>();
    for (final h in library.highlights) {
      if (h.pageNo != page.pageNumber) continue;
      final paint = Paint()
        ..color = _tintColor(h.textColor).withValues(alpha: 0.38)
        ..style = PaintingStyle.fill;

      final rectMaps = _rectsFromHighlight(h);
      if (rectMaps.isEmpty) continue;
      for (final map in rectMaps) {
        final left = (map['left'] as num?)?.toDouble();
        final top = (map['top'] as num?)?.toDouble();
        final right = (map['right'] as num?)?.toDouble();
        final bottom = (map['bottom'] as num?)?.toDouble();
        if (left == null || top == null || right == null || bottom == null) continue;
        final pdfRect = PdfRect(left, top, right, bottom);
        canvas.drawRect(
          pdfRect.toRectInPageRect(page: page, pageRect: pageRect),
          paint,
        );
      }
    }
  }

  List<Map<String, dynamic>> _rectsFromHighlight(PageHighlight h) {
    final raw = h.rects;
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Color _tintColor(String tint) {
    switch (tint) {
      case 'mint':
        return const Color(0xFF34D399);
      case 'rose':
        return const Color(0xFFFB7185);
      case 'amber':
      default:
        return const Color(0xFFFBBF24);
    }
  }

  List<Map<String, dynamic>> _selectionRects() {
    final out = <Map<String, dynamic>>[];
    for (final selection in _selections) {
      if (selection.isEmpty) continue;
      for (final range in selection.ranges) {
        final frag = range.toTextRangeWithFragments(selection.pageText);
        if (frag == null) continue;
        out.add({
          'left': frag.bounds.left,
          'top': frag.bounds.top,
          'right': frag.bounds.right,
          'bottom': frag.bounds.bottom,
          'page': selection.pageNumber,
        });
      }
    }
    return out;
  }

  int _selectionPage() {
    for (final s in _selections) {
      if (s.isNotEmpty) return s.pageNumber;
    }
    return context.read<LibraryProvider>().currentPage;
  }

  Future<void> _saveHighlight(LibraryProvider library) async {
    final text = _selectedText;
    if (text.isEmpty) return;
    await library.addHighlight(
      selectedText: text,
      pageNo: _selectionPage(),
      rects: _selectionRects(),
      color: _tint,
    );
    if (!mounted) return;
    setState(() {
      _selections = const [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Highlight saved'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _sendSelectionToFriend(LibraryProvider library) async {
    final text = _selectedText.trim();
    final book = library.selectedBook;
    if (text.isEmpty || book == null) return;

    final friends = context.read<FriendsProvider>();
    if (friends.friends.isEmpty) {
      await friends.refresh(silent: true);
    }
    if (!mounted) return;
    if (friends.friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a friend first to share passages')),
      );
      return;
    }

    final pageNo = _selectionPage();
    final friend = await showModalBottomSheet<Friend>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final list = ctx.watch<FriendsProvider>().friends;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text(
                'Send passage to…',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Page $pageNo · ${book.title}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...list.map(
                (f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      f.initials,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(f.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(f.email),
                  onTap: () => Navigator.pop(ctx, f),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (friend == null || !mounted) return;

    final ok = await context.read<ChatProvider>().sendBookShare(
          friendUserId: friend.userId,
          bookId: book.id,
          bookTitle: book.title,
          pageNo: pageNo,
          selectedText: text,
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _selections = const []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${friend.fullName}')),
      );
    } else {
      final err = context.read<ChatProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Could not send')),
      );
    }
  }

  Future<void> _noteFromSelection(LibraryProvider library) async {
    final selected = _selectedText;
    _noteController.text = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note on selection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selected.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selected,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            TextField(
              controller: _noteController,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Write your note…'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final noteText = _noteController.text.trim();
    if (noteText.isEmpty) return;

    if (selected.isNotEmpty) {
      await library.addHighlight(
        selectedText: selected,
        pageNo: _selectionPage(),
        rects: _selectionRects(),
        color: _tint,
        note: noteText,
      );
    } else {
      await library.addNote(noteText);
    }
    if (!mounted) return;
    setState(() => _selections = const []);
  }

  Future<void> _addPageNoteDialog(LibraryProvider library) async {
    _noteController.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note on page ${library.currentPage}'),
        content: TextField(
          controller: _noteController,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Write your note…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await library.addNote(_noteController.text);
    }
  }

  void _openMarks(LibraryProvider library) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, scrollController) {
            final pageNotes = library.notes;
            final pageHighlights = library.highlights;
            final pageBookmarks = library.bookmarks;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${library.selectedBook?.title}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pageHighlights.length} highlights • ${pageNotes.length} notes • ${pageBookmarks.length} bookmarks',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text('Bookmarks', style: TextStyle(fontWeight: FontWeight.w800)),
                if (pageBookmarks.isEmpty)
                  const ListTile(dense: true, title: Text('None yet'))
                else
                  ...pageBookmarks.map(
                    (b) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.bookmark),
                      title: Text('Page ${b.pageNo}'),
                      onTap: () {
                        _controller?.goToPage(pageNumber: b.pageNo);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                const Divider(),
                const Text('Highlights', style: TextStyle(fontWeight: FontWeight.w800)),
                if (pageHighlights.isEmpty)
                  const ListTile(dense: true, title: Text('None yet'))
                else
                  ...pageHighlights.map(
                    (h) => ListTile(
                      dense: true,
                      leading: Icon(Icons.highlight, color: _tintColor(h.textColor)),
                      title: Text(
                        h.selectedText ?? '(no text)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        h.note.isEmpty
                            ? 'Page ${h.pageNo} • ${h.textColor}'
                            : 'Page ${h.pageNo} • ${h.note}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => library.deleteHighlight(h),
                      ),
                      onTap: () {
                        _controller?.goToPage(pageNumber: h.pageNo);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                const Divider(),
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.w800)),
                if (pageNotes.isEmpty)
                  const ListTile(dense: true, title: Text('None yet'))
                else
                  ...pageNotes.map(
                    (n) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.notes),
                      title: Text(n.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Page ${n.pageNo}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => library.deleteNote(n),
                      ),
                      onTap: () {
                        _controller?.goToPage(pageNumber: n.pageNo);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.preview,
    required this.tint,
    required this.onTint,
    required this.onHighlight,
    required this.onNote,
    required this.onSend,
    required this.onClear,
  });

  final String preview;
  final String tint;
  final ValueChanged<String> onTint;
  final VoidCallback onHighlight;
  final VoidCallback onNote;
  final VoidCallback onSend;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final c in const ['amber', 'mint', 'rose'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: tint == c,
                      onSelected: (_) => onTint(c),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onHighlight,
                    icon: const Icon(Icons.highlight_rounded, size: 18),
                    label: const Text('Highlight'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNote,
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('Note'),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Send to friend'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
