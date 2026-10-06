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
import '../../../home/presentation/providers/dashboard_provider.dart';
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
  DashboardProvider? _dashboard;

  /// When true, pan/zoom drag is disabled so text selection can capture gestures.
  bool _selectMode = false;
  bool _areaMode = false;
  bool _didJumpInitialPage = false;
  List<BookTocEntry> _outline = const [];
  bool _outlineReady = false;
  List<Map<String, dynamic>> _areaRects = const [];
  Offset? _areaStartLocal;
  Offset? _areaEndLocal;

  String get _selectedText {
    final parts = _selections
        .where((s) => s.isNotEmpty)
        .map((s) => s.text.trim())
        .where((t) => t.isNotEmpty);
    return parts.join(' ').trim();
  }

  bool get _hasSelection => _selectedText.isNotEmpty || _areaRects.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToPendingPage();
      context.read<DashboardProvider>().beginReading();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dashboard ??= context.read<DashboardProvider>();
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
    _dashboard?.endReading();
    _noteController.dispose();
    super.dispose();
  }

  PdfPageHitTestResult? _hitAtGlobal(Offset global) {
    final controller = _controller;
    if (controller == null) return null;
    final local = controller.globalToLocal(global);
    if (local == null) return null;
    return controller.getPdfPageHitTestResult(
      local,
      useDocumentLayoutCoordinates: false,
    );
  }

  void _onAreaPointerDown(PointerDownEvent event) {
    final hit = _hitAtGlobal(event.position);
    if (hit == null) return;
    final pt = hit.offset;
    setState(() {
      _areaStartLocal = event.localPosition;
      _areaEndLocal = event.localPosition;
      _areaRects = [
        {
          'left': pt.x,
          'top': pt.y,
          'right': pt.x,
          'bottom': pt.y,
          'page': hit.page.pageNumber,
        },
      ];
    });
  }

  void _onAreaPointerMove(PointerMoveEvent event) {
    if (_areaRects.isEmpty) return;
    final hit = _hitAtGlobal(event.position);
    if (hit == null) return;
    final start = _areaRects.first;
    final page = start['page'] as int?;
    if (page != hit.page.pageNumber) return;
    final x0 = (start['left'] as num).toDouble();
    final y0 = (start['top'] as num).toDouble();
    final x1 = hit.offset.x;
    final y1 = hit.offset.y;
    setState(() {
      _areaEndLocal = event.localPosition;
      _areaRects = [
        {
          'left': x0 < x1 ? x0 : x1,
          'top': y0 > y1 ? y0 : y1,
          'right': x0 > x1 ? x0 : x1,
          'bottom': y0 < y1 ? y0 : y1,
          'page': page,
        },
      ];
    });
  }

  void _onAreaPointerUp(PointerUpEvent event) {
    if (_areaRects.isEmpty) return;
    final r = _areaRects.first;
    final w = ((r['right'] as num) - (r['left'] as num)).abs();
    final h = ((r['top'] as num) - (r['bottom'] as num)).abs();
    if (w < 8 || h < 8) {
      setState(() {
        _areaRects = const [];
        _areaStartLocal = null;
        _areaEndLocal = null;
      });
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) {
        _selections = const [];
        _areaRects = const [];
        _areaStartLocal = null;
        _areaEndLocal = null;
        _areaMode = false;
      }
    });
  }

  Future<void> _jumpToOutline(BookTocEntry node) async {
    final page = node.pageNumber;
    if (page == null) return;
    final controller = _controller;
    if (controller == null) return;
    await controller.goToPage(pageNumber: page);
    if (!mounted) return;
    context.read<LibraryProvider>().setPage(page);
  }

  void _openContents() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Contents',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ),
                      Text(
                        _outlineReady ? '${_countOutline(_outline)} chapters' : 'Loading…',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: !_outlineReady
                      ? const Center(child: CircularProgressIndicator())
                      : _outline.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'This PDF has no table of contents.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                              children: _outline
                                  .map(
                                    (node) => _OutlineTile(
                                      node: node,
                                      depth: 0,
                                      onTap: (n) {
                                        Navigator.pop(ctx);
                                        _jumpToOutline(n);
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _countOutline(List<BookTocEntry> nodes) {
    var n = 0;
    for (final node in nodes) {
      n += 1 + _countOutline(node.children);
    }
    return n;
  }

  List<BookTocEntry> _fromPdfOutline(List<PdfOutlineNode> nodes) {
    return nodes
        .map(
          (n) => BookTocEntry(
            title: n.title,
            pageNumber: n.dest?.pageNumber,
            children: _fromPdfOutline(n.children),
          ),
        )
        .toList();
  }

  List<BookTocEntry> _fallbackOutlineFor(CatalogBook? book) {
    if (book == null) return const [];
    if (book.outline.isNotEmpty) return book.outline;
    return bundledOutlineFor(id: book.id, title: book.title);
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

    final viewerParams = PdfViewerParams(
      enableTextSelection: !_areaMode,
      panEnabled: !_selectMode,
      onViewerReady: (document, controller) async {
        final library = context.read<LibraryProvider>();
        final fallback = _fallbackOutlineFor(library.selectedBook);
        try {
          final nodes = await document.loadOutline();
          if (!mounted) return;
          final fromPdf = _fromPdfOutline(nodes);
          setState(() {
            _outline = fromPdf.isNotEmpty ? fromPdf : fallback;
            _outlineReady = true;
          });
          if (!mounted) return;
          final stayOn = library.currentPage;
          if (stayOn > 1) {
            await controller.goToPage(pageNumber: stayOn);
          }
          if (!mounted) return;
          if (library.consumePendingOpenContents()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openContents();
            });
          }
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _outline = fallback;
            _outlineReady = true;
          });
        }
      },
      onPageChanged: (pageNumber) {
        if (pageNumber != null) {
          final library = context.read<LibraryProvider>();
          library.setPage(pageNumber);
          final book = library.selectedBook;
          if (book != null) {
            context.read<DashboardProvider>().rememberReading(
                  bookId: book.id,
                  bookTitle: book.title,
                  pageNo: pageNumber,
                );
          }
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
      pagePaintCallbacks: [_paintSavedHighlights, _paintPendingArea],
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
                              ? (_areaMode
                                  ? 'Area mode: drag a box, then Highlight'
                                  : 'Text mode: drag over words, then Highlight')
                              : 'Page ${library.currentPage} • Tap highlighter to select',
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
                    tooltip: 'Contents',
                    onPressed: _openContents,
                    icon: const Icon(Icons.toc_rounded),
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
                        onPressed: () => setState(() {
                          _areaMode = false;
                          _areaRects = const [];
                          _areaStartLocal = null;
                          _areaEndLocal = null;
                        }),
                        child: Text(
                          'Text',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: !_areaMode ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _areaMode = true;
                          _selections = const [];
                        }),
                        child: Text(
                          'Area',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _areaMode ? AppColors.primary : AppColors.textSecondary,
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
                            key: ValueKey('pdf-data-${book.id}'),
                            sourceName: book.id,
                            controller: _controller ??= PdfViewerController(),
                            initialPageNumber: library.currentPage < 1 ? 1 : library.currentPage,
                            params: viewerParams,
                          )
                        : PdfViewer.file(
                            path!,
                            key: ValueKey('pdf-file-${book.id}'),
                            controller: _controller ??= PdfViewerController(),
                            initialPageNumber: library.currentPage < 1 ? 1 : library.currentPage,
                            params: viewerParams,
                          ),
                  ),
                  if (_selectMode && _areaMode)
                    Positioned.fill(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: _onAreaPointerDown,
                              onPointerMove: _onAreaPointerMove,
                              onPointerUp: _onAreaPointerUp,
                            ),
                          ),
                          if (_areaStartLocal != null && _areaEndLocal != null)
                            Positioned.fromRect(
                              rect: Rect.fromPoints(_areaStartLocal!, _areaEndLocal!),
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _tintColor(_tint).withValues(alpha: 0.32),
                                    border: Border.all(color: _tintColor(_tint), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_hasSelection)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 16,
                      child: _SelectionActionBar(
                        preview: _selectedText.isNotEmpty ? _selectedText : 'Marked area on this page',
                        tint: _tint,
                        onTint: (c) => setState(() => _tint = c),
                        onHighlight: () => _saveHighlight(library),
                        onNote: () => _noteFromSelection(library),
                        onSend: () => _sendSelectionToFriend(library),
                        onClear: () => setState(() {
                          _selections = const [];
                          _areaRects = const [];
                          _areaStartLocal = null;
                          _areaEndLocal = null;
                        }),
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
      final color = _tintColor(h.textColor).withValues(alpha: 0.38);
      final rectMaps = _rectsFromHighlight(h);
      if (rectMaps.isEmpty) continue;
      for (final map in rectMaps) {
        _drawPdfMapRect(canvas, pageRect, page, map, color);
      }
    }
  }

  void _paintPendingArea(Canvas canvas, Rect pageRect, PdfPage page) {
    for (final map in _areaRects) {
      if (map['page'] != page.pageNumber) continue;
      _drawPdfMapRect(canvas, pageRect, page, map, _tintColor(_tint).withValues(alpha: 0.28));
    }
  }

  void _drawPdfMapRect(
    Canvas canvas,
    Rect pageRect,
    PdfPage page,
    Map<String, dynamic> map,
    Color color,
  ) {
    final left = (map['left'] as num?)?.toDouble();
    final top = (map['top'] as num?)?.toDouble();
    final right = (map['right'] as num?)?.toDouble();
    final bottom = (map['bottom'] as num?)?.toDouble();
    if (left == null || top == null || right == null || bottom == null) return;
    canvas.drawRect(
      PdfRect(left, top, right, bottom).toRectInPageRect(page: page, pageRect: pageRect),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
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
    if (_areaRects.isNotEmpty) return List<Map<String, dynamic>>.from(_areaRects);
    final out = <Map<String, dynamic>>[];
    for (final selection in _selections) {
      if (selection.isEmpty) continue;
      for (final range in selection.ranges) {
        final frag = range.toTextRangeWithFragments(selection.pageText);
        if (frag == null) continue;
        for (final rect in frag.enumerateRectsForRange()) {
          out.add({
            'left': rect.left,
            'top': rect.top,
            'right': rect.right,
            'bottom': rect.bottom,
            'page': selection.pageNumber,
          });
        }
      }
    }
    return out;
  }

  int _selectionPage() {
    if (_areaRects.isNotEmpty) {
      final page = _areaRects.first['page'];
      if (page is int) return page;
    }
    for (final s in _selections) {
      if (s.isNotEmpty) return s.pageNumber;
    }
    return context.read<LibraryProvider>().currentPage;
  }

  Future<void> _saveHighlight(LibraryProvider library) async {
    final text = _selectedText.isNotEmpty ? _selectedText : 'Marked area';
    final rects = _selectionRects();
    if (text.isEmpty && rects.isEmpty) return;
    await library.addHighlight(
      selectedText: text,
      pageNo: _selectionPage(),
      rects: rects,
      color: _tint,
    );
    if (!mounted) return;
    setState(() {
      _selections = const [];
      _areaRects = const [];
      _areaStartLocal = null;
      _areaEndLocal = null;
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
                        h.note.isEmpty ? 'Page ${h.pageNo}' : 'Page ${h.pageNo} • ${h.note}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ColorDot(color: _tintColor(h.textColor), selected: true, size: 14),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => library.deleteHighlight(h),
                          ),
                        ],
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
                for (final c in const [
                  ('amber', Color(0xFFFBBF24)),
                  ('mint', Color(0xFF34D399)),
                  ('rose', Color(0xFFFB7185)),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _ColorDot(
                      color: c.$2,
                      selected: tint == c.$1,
                      onTap: () => onTint(c.$1),
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

class _OutlineTile extends StatelessWidget {
  const _OutlineTile({
    required this.node,
    required this.depth,
    required this.onTap,
  });

  final BookTocEntry node;
  final int depth;
  final void Function(BookTocEntry node) onTap;

  @override
  Widget build(BuildContext context) {
    final title = node.title.trim().isEmpty ? 'Untitled' : node.title.trim();
    final page = node.displayPage;
    final pageLabel = page == null
        ? null
        : Text(
            '$page',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          );

    if (node.children.isEmpty) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(left: 16 + depth * 14, right: 12),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: depth == 0 ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: pageLabel,
        onTap: node.pageNumber == null ? null : () => onTap(node),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: depth == 0,
        tilePadding: EdgeInsets.only(left: 8 + depth * 12, right: 8),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: depth == 0 ? FontWeight.w800 : FontWeight.w700,
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (page != null && node.pageNumber != null)
              TextButton(
                onPressed: () => onTap(node),
                child: pageLabel!,
              ),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
        children: node.children
            .map(
              (child) => _OutlineTile(
                node: child,
                depth: depth + 1,
                onTap: onTap,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    this.onTap,
    this.size = 28,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.textPrimary : Colors.white,
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
    if (onTap == null) return dot;
    return GestureDetector(onTap: onTap, child: dot);
  }
}
