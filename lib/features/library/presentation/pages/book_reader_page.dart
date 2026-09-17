import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../domain/entities/study_book.dart';
import '../providers/library_provider.dart';
import 'pdf_book_reader.dart';

class BookReaderPage extends StatefulWidget {
  const BookReaderPage({super.key});

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    if (library.isPdfSelected) return const PdfBookReaderPage();
    final chapter = library.currentChapter;
    final book = library.selectedBook;

    return Scaffold(
      body: SafeArea(
        child: chapter == null
            ? const Center(child: Text('No chapter loaded.'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Chapter ${library.chapterIndex + 1} of ${library.chapters.length}',
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
                          tooltip: 'Contents',
                          onPressed: () => _openContents(library),
                          icon: const Icon(Icons.list_alt_rounded),
                        ),
                        IconButton(
                          tooltip: 'Highlights & notes',
                          onPressed: () => _openMarks(library),
                          icon: const Icon(Icons.highlight_rounded),
                        ),
                        IconButton(
                          tooltip: 'Bookmark',
                          onPressed: library.toggleBookmark,
                          icon: Icon(
                            library.isCurrentBookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: library.isCurrentBookmarked
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: library.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceMuted,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Highlight colour',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        ...HighlightTint.values.map(
                          (tint) => _TintDot(
                            tint: tint,
                            selected: library.activeTint == tint,
                            onTap: () => library.setTint(tint),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openNoteSheet(library),
                          child: const Text('Add note'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(
                          chapter.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          chapter.subtitle,
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select any line → Highlight or Note',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SelectableText.rich(
                          TextSpan(
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16.5,
                              height: 1.65,
                              fontWeight: FontWeight.w500,
                            ),
                            children: _spans(chapter.body, library.highlightsFor(chapter.id)),
                          ),
                          key: ValueKey(chapter.id),
                          contextMenuBuilder: (context, state) {
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: state.contextMenuAnchors,
                              buttonItems: [
                                ContextMenuButtonItem(
                                  label: 'Highlight',
                                  onPressed: () {
                                    final selection = state.textEditingValue.selection;
                                    state.hideToolbar();
                                    if (!selection.isValid || selection.isCollapsed) return;
                                    library.addHighlight(
                                      start: selection.start,
                                      end: selection.end,
                                    );
                                  },
                                ),
                                ContextMenuButtonItem(
                                  label: 'Note',
                                  onPressed: () {
                                    final selection = state.textEditingValue.selection;
                                    state.hideToolbar();
                                    if (!selection.isValid || selection.isCollapsed) return;
                                    _openNoteSheet(
                                      library,
                                      start: selection.start,
                                      end: selection.end,
                                      excerpt: selection.textInside(chapter.body),
                                    );
                                  },
                                ),
                                ...state.contextMenuButtonItems,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: library.chapterIndex == 0 ? null : library.previousChapter,
                            child: const Text('Previous'),
                          ),
                          Expanded(
                            child: Text(
                              chapter.title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: library.chapterIndex >= library.chapters.length - 1
                                ? null
                                : library.nextChapter,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<InlineSpan> _spans(String text, List<TextHighlight> highlights) {
    if (highlights.isEmpty) return [TextSpan(text: text)];
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final highlight in highlights) {
      final start = highlight.start.clamp(0, text.length);
      final end = highlight.end.clamp(0, text.length);
      if (end <= start || start < cursor) continue;
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            backgroundColor: _tintColor(highlight.tint),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  Future<void> _openContents(LibraryProvider library) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
          itemCount: library.chapters.length,
          itemBuilder: (context, index) {
            final chapter = library.chapters[index];
            final selected = index == library.chapterIndex;
            final marked = library.bookmarkedChapterIds.contains(chapter.id);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: selected ? AppColors.primary : AppColors.primarySoft,
                foregroundColor: selected ? Colors.white : AppColors.primary,
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text(chapter.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(chapter.subtitle),
              trailing: marked ? const Icon(Icons.bookmark_rounded, color: AppColors.primary) : null,
              onTap: () {
                library.openChapter(index);
                Navigator.of(context).pop();
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openMarks(LibraryProvider library) async {
    final chapter = library.currentChapter;
    if (chapter == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final marks = library.highlightsFor(chapter.id);
        final pageNotes = library.notesFor(chapter.id);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Highlights & notes',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (marks.isEmpty && pageNotes.isEmpty)
                const Text(
                  'Select text in the chapter to highlight or attach a note.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.45),
                ),
              ...marks.map(
                (mark) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: _tintColor(mark.tint)),
                  title: Text(
                    library.excerpt(mark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: mark.note.isEmpty ? null : Text(mark.note),
                  trailing: IconButton(
                    onPressed: () {
                      library.removeHighlight(mark);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
              ...pageNotes.map(
                (note) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.note_alt_outlined),
                  title: Text(note.text),
                  trailing: IconButton(
                    onPressed: () {
                      library.removeNote(note);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNoteSheet(
    LibraryProvider library, {
    int? start,
    int? end,
    String? excerpt,
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
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                excerpt == null ? 'Chapter note' : 'Note on selected text',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              if (excerpt != null) ...[
                const SizedBox(height: 8),
                Text(
                  excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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
                onPressed: () {
                  library.addNote(
                    _noteController.text,
                    start: start,
                    end: end,
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TintDot extends StatelessWidget {
  const _TintDot({
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final HighlightTint tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _tintColor(tint),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

Color _tintColor(HighlightTint tint) {
  switch (tint) {
    case HighlightTint.amber:
      return const Color(0xFFFFE08A);
    case HighlightTint.mint:
      return const Color(0xFF9DE6C8);
    case HighlightTint.rose:
      return const Color(0xFFF4B6D2);
  }
}
