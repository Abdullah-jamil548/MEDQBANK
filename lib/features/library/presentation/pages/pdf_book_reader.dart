import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../domain/entities/study_book.dart';
import '../providers/library_provider.dart';

class PdfBookReaderPage extends StatefulWidget {
  const PdfBookReaderPage({super.key});

  @override
  State<PdfBookReaderPage> createState() => _PdfBookReaderPageState();
}

class _PdfBookReaderPageState extends State<PdfBookReaderPage> {
  final PdfViewerController _controller = PdfViewerController();
  final TextEditingController _noteController = TextEditingController();
  late final List<PdfViewerPagePaintCallback> _paints = [_paintHighlights];
  bool _hasSelection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LibraryProvider>().ensureRemoteDocument();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Color _fill(HighlightTint tint) {
    switch (tint) {
      case HighlightTint.amber:
        return const Color(0x99FFE08A);
      case HighlightTint.mint:
        return const Color(0x999DE6C8);
      case HighlightTint.rose:
        return const Color(0x99F4B6D2);
    }
  }

  void _paintHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    if (!mounted) return;
    final library = context.read<LibraryProvider>();
    final paint = Paint()..style = PaintingStyle.fill;
    for (final mark in library.pdfHighlightsOn(page.pageNumber)) {
      paint.color = _fill(mark.tint);
      for (final box in mark.boxes) {
        if (box.right <= box.left || box.top <= box.bottom) continue;
        final pdfRect = PdfRect(box.left, box.top, box.right, box.bottom);
        final rect = pdfRect
            .toRect(page: page, scaledPageSize: pageRect.size)
            .translate(pageRect.left, pageRect.top);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(2)),
          paint,
        );
      }
    }
  }

  Future<void> _highlightSelection(
    PdfTextSelection selection, {
    String note = '',
  }) async {
    final library = context.read<LibraryProvider>();
    final ranges = await selection.getSelectedTextRanges();
    for (final range in ranges) {
      final boxes = range.enumerateFragmentBoundingRects().map((item) {
        final bounds = item.bounds;
        return PdfBox(
          left: bounds.left,
          top: bounds.top,
          right: bounds.right,
          bottom: bounds.bottom,
        );
      }).toList();
      if (boxes.isEmpty) {
        final bounds = range.bounds;
        boxes.add(
          PdfBox(
            left: bounds.left,
            top: bounds.top,
            right: bounds.right,
            bottom: bounds.bottom,
          ),
        );
      }
      library.addPdfHighlight(
        page: range.pageNumber,
        start: range.start,
        end: range.end,
        excerpt: range.text,
        boxes: boxes,
        note: note,
      );
    }
    if (_controller.isReady) _controller.invalidate();
    await _controller.textSelectionDelegate.clearTextSelection();
    if (mounted) setState(() => _hasSelection = false);
  }

  void _onPageChanged(int? page) {
    if (!mounted || page == null) return;
    final library = context.read<LibraryProvider>();
    final count = _controller.isReady ? _controller.pageCount : library.pdfPageCount;
    library.setPdfPage(page, pageCount: count);
  }

  void _onReady(PdfDocument document, PdfViewerController controller) {
    final library = context.read<LibraryProvider>();
    final savedPage = library.pdfPage < 1 ? 1 : library.pdfPage;
    library.setPdfPage(savedPage, pageCount: controller.pageCount);
    if (savedPage > 1) {
      controller.goToPage(pageNumber: savedPage);
    }
    controller.invalidate();
  }

  void _customizeMenu(
    PdfViewerContextMenuBuilderParams params,
    List<ContextMenuButtonItem> items,
  ) {
    if (!params.isTextSelectionEnabled || !params.textSelectionDelegate.hasSelectedText) {
      return;
    }
    items.insertAll(0, [
      ContextMenuButtonItem(
        label: 'Highlight',
        onPressed: () async {
          params.dismissContextMenu();
          await _highlightSelection(params.textSelectionDelegate);
        },
      ),
      ContextMenuButtonItem(
        label: 'Note',
        onPressed: () async {
          params.dismissContextMenu();
          final text = await params.textSelectionDelegate.getSelectedText();
          if (!mounted) return;
          await _openNoteSheet(
            context.read<LibraryProvider>(),
            excerpt: text,
            selection: params.textSelectionDelegate,
          );
        },
      ),
    ]);
  }

  String _statusLine(LibraryProvider library) {
    if (library.hasPdfDocument) {
      return 'Page ${library.pdfPage} of ${library.pdfPageCount}';
    }
    if (library.isOpeningRemote) return 'Opening streamed copy…';
    if (library.pdfOpenError != null) return 'Could not open this book';
    return 'Preparing a short-lived reading link';
  }

  PdfViewerParams _viewerParams() {
    return PdfViewerParams(
      backgroundColor: AppColors.background,
      margin: 10,
      textSelectionParams: PdfTextSelectionParams(
        enabled: true,
        showContextMenuAutomatically: true,
        onTextSelectionChange: (selection) {
          if (!mounted) return;
          final selected = selection.hasSelectedText;
          if (selected == _hasSelection) return;
          setState(() => _hasSelection = selected);
        },
      ),
      pagePaintCallbacks: _paints,
      customizeContextMenuItems: _customizeMenu,
      onPageChanged: _onPageChanged,
      onViewerReady: _onReady,
      loadingBannerBuilder: (context, downloaded, total) {
        final progress = total != null && total > 0 ? downloaded / total : null;
        return _ReaderMessage(
          loading: true,
          progress: progress,
          title: 'Opening book',
          body: total == null
              ? 'Preparing a secure reading session…'
              : '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB',
        );
      },
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
        return _ReaderMessage(
          icon: Icons.refresh_rounded,
          title: 'Reading link expired',
          body: 'Ask MedQBank for a new session and try again.',
          actionLabel: 'Retry',
          onAction: () => context.read<LibraryProvider>().retryRemoteDocument(),
        );
      },
    );
  }

  Widget _buildBody(LibraryProvider library) {
    if (library.hasRemotePdfUrl) {
      return PdfViewer.uri(
        Uri.parse(library.remotePdfUrl!),
        key: ValueKey(library.remotePdfUrl),
        controller: _controller,
        initialPageNumber: library.pdfPage < 1 ? 1 : library.pdfPage,
        useProgressiveLoading: true,
        preferRangeAccess: true,
        timeout: const Duration(minutes: 3),
        params: _viewerParams(),
      );
    }
    if (library.isOpeningRemote) {
      return const _ReaderMessage(
        loading: true,
        title: 'Opening book',
        body: 'Preparing a secure reading session…',
      );
    }
    if (library.isRemotePdf) {
      return _ReaderMessage(
        icon: library.pdfOpenError == null ? Icons.menu_book_rounded : Icons.error_outline_rounded,
        title: library.pdfOpenError == null ? 'Ready to read' : 'Could not open this book',
        body: library.pdfOpenError ?? 'The PDF streams in the reader and is not saved to Downloads.',
        actionLabel: 'Open book',
        onAction: library.ensureRemoteDocument,
      );
    }
    return const _ReaderMessage(
      icon: Icons.local_library_outlined,
      title: 'Choose a book',
      body: 'Open a textbook from the library to start reading.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final book = library.selectedBook;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book?.title ?? 'Reader',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusLine(library),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (library.hasPdfDocument) ...[
                    _HeaderIcon(
                      tooltip: 'Highlights, bookmarks, notes',
                      onPressed: () => _openMarks(library),
                      icon: Icons.auto_stories_outlined,
                    ),
                    const SizedBox(width: 4),
                    _HeaderIcon(
                      tooltip: library.isCurrentBookmarked ? 'Remove bookmark' : 'Bookmark page',
                      onPressed: library.toggleBookmark,
                      icon: library.isCurrentBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      active: library.isCurrentBookmarked,
                    ),
                  ],
                ],
              ),
            ),
            if (library.hasPdfDocument)
              LinearProgressIndicator(
                value: library.progress,
                minHeight: 3,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.secondary,
              ),
            if (library.hasPdfDocument)
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    ...HighlightTint.values.map(
                      (tint) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => library.setTint(tint),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _fill(tint).withValues(alpha: 1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: library.activeTint == tint
                                    ? AppColors.textPrimary
                                    : Colors.white,
                                width: library.activeTint == tint ? 2 : 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openNoteSheet(library),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Note'),
                    ),
                  ],
                ),
              ),
            if (library.hasPdfDocument && _hasSelection)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Text selected',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _highlightSelection(_controller.textSelectionDelegate),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text('Highlight'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final current = context.read<LibraryProvider>();
                            final selection = _controller.textSelectionDelegate;
                            final text = await selection.getSelectedText();
                            if (!mounted) return;
                            await _openNoteSheet(
                              current,
                              excerpt: text,
                              selection: selection,
                            );
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          child: const Text('Note'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: _buildBody(library)),
          ],
        ),
      ),
    );
  }

  Future<void> _goToPage(int page) async {
    context.read<LibraryProvider>().goToPdfPage(page);
    if (_controller.isReady) {
      await _controller.goToPage(pageNumber: page);
      _controller.invalidate();
    }
  }

  Future<void> _openMarks(LibraryProvider library) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: Consumer<LibraryProvider>(
            builder: (context, library, _) {
              final highlights = library.allPdfHighlights;
              final bookmarks = library.allPdfBookmarkPages;
              final notes = library.allPdfNotes;
              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your notes',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${highlights.length} highlights · ${bookmarks.length} bookmarks · ${notes.length} notes',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textMuted,
                        indicatorColor: AppColors.primary,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: [
                          Tab(text: 'Highlights'),
                          Tab(text: 'Bookmarks'),
                          Tab(text: 'Notes'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _marksList(
                              empty: 'Select text in the book, then tap Highlight.',
                              children: highlights
                                  .map(
                                    (mark) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        radius: 8,
                                        backgroundColor: _fill(mark.tint).withValues(alpha: 1),
                                      ),
                                      title: Text(mark.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(
                                        mark.note.isEmpty ? 'Page ${mark.page}' : 'Page ${mark.page} · ${mark.note}',
                                      ),
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                        await _goToPage(mark.page);
                                      },
                                      trailing: IconButton(
                                        onPressed: () {
                                          library.removePdfHighlight(mark);
                                          if (_controller.isReady) _controller.invalidate();
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            _marksList(
                              empty: 'Bookmark a page from the header to come back later.',
                              children: bookmarks
                                  .map(
                                    (page) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.bookmark_rounded, color: AppColors.primary),
                                      title: Text('Page $page'),
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                        await _goToPage(page);
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                            _marksList(
                              empty: 'Add a page note, or select text and choose Note.',
                              children: notes
                                  .map(
                                    (note) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.note_alt_outlined),
                                      title: Text(note.text),
                                      subtitle: Text('Page ${note.page}'),
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                        await _goToPage(note.page);
                                      },
                                      trailing: IconButton(
                                        onPressed: () => library.removePdfNote(note),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ),
                                  )
                                  .toList(),
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
        );
      },
    );
  }

  Widget _marksList({required String empty, required List<Widget> children}) {
    if (children.isEmpty) {
      return Center(
        child: Text(
          empty,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      );
    }
    return ListView(children: children);
  }

  Future<void> _openNoteSheet(
    LibraryProvider library, {
    String? excerpt,
    PdfTextSelection? selection,
  }) async {
    _noteController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                excerpt == null ? 'Page note' : 'Note on selected text',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.2),
              ),
              if (excerpt != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Clinical point, viva tip, or reminder…',
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Save note',
                onPressed: () async {
                  final text = _noteController.text;
                  Navigator.of(context).pop();
                  if (selection != null) {
                    await _highlightSelection(selection, note: text);
                  } else {
                    library.addPdfNote(text);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.active = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active ? AppColors.primarySoft : AppColors.surfaceMuted,
        foregroundColor: active ? AppColors.primary : AppColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({
    this.loading = false,
    this.progress,
    this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final bool loading;
  final double? progress;
  final IconData? icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                value: progress,
                color: AppColors.primary,
              ),
            )
          else
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon ?? Icons.menu_book_rounded, color: AppColors.primary),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.2),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PrimaryButton(label: actionLabel!, onPressed: onAction),
            ),
          ],
        ],
      ),
    );
  }
}
