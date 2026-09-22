import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../domain/entities/catalog_book.dart';
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

  String get _selectedText {
    final parts = _selections
        .where((s) => s.isNotEmpty)
        .map((s) => s.text.trim())
        .where((t) => t.isNotEmpty);
    return parts.join(' ').trim();
  }

  bool get _hasSelection => _selectedText.isNotEmpty;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final book = library.selectedBook;
    final path = library.localPdfPath;
    final bytes = library.pdfBytes;

    final hasSource = book != null &&
        ((path != null && !kIsWeb && File(path).existsSync()) ||
            (bytes != null && bytes.isNotEmpty));

    if (!hasSource) {
      return Scaffold(
        appBar: AppBar(leading: const AppBackButton()),
        body: const Center(child: Text('No local PDF. Download the book first.')),
      );
    }

    final viewerParams = PdfViewerParams(
      enableTextSelection: true,
      onPageChanged: (pageNumber) {
        if (pageNumber != null) {
          context.read<LibraryProvider>().setPage(pageNumber);
        }
      },
      onTextSelectionChange: (selections) {
        setState(() => _selections = List<PdfTextRanges>.from(selections));
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
                          'Page ${library.currentPage} • Long-press to select text',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: bytes != null
                        ? PdfViewer.data(
                            bytes,
                            sourceName: book.id,
                            controller: _controller ??= PdfViewerController(),
                            params: viewerParams,
                          )
                        : PdfViewer.file(
                            path!,
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
                        tint: _tint,
                        onTint: (c) => setState(() => _tint = c),
                        onHighlight: () => _saveHighlight(library),
                        onNote: () => _noteFromSelection(library),
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
        final pdfRect = PdfRect(
          (map['left'] as num).toDouble(),
          (map['top'] as num).toDouble(),
          (map['right'] as num).toDouble(),
          (map['bottom'] as num).toDouble(),
        );
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
    setState(() => _selections = const []);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Highlight saved'), duration: Duration(seconds: 1)),
    );
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

    // Store as highlight+note when there is a selection, else page note.
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
          builder: (_, controller) {
            final pageNotes = library.notes;
            final pageHighlights = library.highlights;
            final pageBookmarks = library.bookmarks;
            return ListView(
              controller: controller,
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
    required this.tint,
    required this.onTint,
    required this.onHighlight,
    required this.onNote,
    required this.onClear,
  });

  final String tint;
  final ValueChanged<String> onTint;
  final VoidCallback onHighlight;
  final VoidCallback onNote;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Text selected',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
          ],
        ),
      ),
    );
  }
}
