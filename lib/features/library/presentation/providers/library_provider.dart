import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../domain/entities/study_book.dart';
import '../../../../domain/repositories/library_repository.dart';

class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._repository) {
    load();
  }

  static const _storageKey = 'medqbank.library.v1';

  final LibraryRepository _repository;

  List<StudyBook> books = const [];
  List<BookChapter> chapters = const [];
  StudyBook? selectedBook;
  int chapterIndex = 0;
  HighlightTint activeTint = HighlightTint.amber;
  final Set<String> bookmarkedChapterIds = {};
  final List<TextHighlight> highlights = [];
  final List<ChapterNote> notes = [];

  BookChapter? get currentChapter =>
      chapters.isEmpty ? null : chapters[chapterIndex.clamp(0, chapters.length - 1)];

  bool get hasBook => currentChapter != null;

  double get progress {
    if (chapters.isEmpty) return 0;
    return ((chapterIndex + 1) / chapters.length).clamp(0, 1);
  }

  bool get isCurrentBookmarked =>
      currentChapter != null && bookmarkedChapterIds.contains(currentChapter!.id);

  Future<void> load() async {
    books = await _repository.getBooks();
    selectedBook ??= books.isEmpty ? null : books.first;
    if (selectedBook != null) {
      chapters = await _repository.getChapters(selectedBook!.id);
    }
    await _restore();
    notifyListeners();
  }

  Future<void> selectBook(StudyBook book) async {
    selectedBook = book;
    chapters = await _repository.getChapters(book.id);
    chapterIndex = chapterIndex.clamp(0, chapters.isEmpty ? 0 : chapters.length - 1);
    notifyListeners();
    await _persist();
  }

  void openChapter(int index) {
    if (chapters.isEmpty) return;
    chapterIndex = index.clamp(0, chapters.length - 1);
    notifyListeners();
    _persist();
  }

  void nextChapter() {
    if (chapterIndex < chapters.length - 1) openChapter(chapterIndex + 1);
  }

  void previousChapter() {
    if (chapterIndex > 0) openChapter(chapterIndex - 1);
  }

  void setTint(HighlightTint tint) {
    activeTint = tint;
    notifyListeners();
  }

  void toggleBookmark() {
    final chapter = currentChapter;
    if (chapter == null) return;
    if (bookmarkedChapterIds.contains(chapter.id)) {
      bookmarkedChapterIds.remove(chapter.id);
    } else {
      bookmarkedChapterIds.add(chapter.id);
    }
    notifyListeners();
    _persist();
  }

  void addHighlight({
    required int start,
    required int end,
    String note = '',
    HighlightTint? tint,
  }) {
    final chapter = currentChapter;
    if (chapter == null) return;
    final lo = start < end ? start : end;
    final hi = start < end ? end : start;
    if (hi <= lo) return;
    if (lo < 0 || hi > chapter.body.length) return;

    highlights.removeWhere(
      (item) => item.chapterId == chapter.id && item.start < hi && item.end > lo,
    );
    highlights.add(
      TextHighlight(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        chapterId: chapter.id,
        start: lo,
        end: hi,
        tint: tint ?? activeTint,
        createdAt: DateTime.now(),
        note: note.trim(),
      ),
    );
    notifyListeners();
    _persist();
  }

  void removeHighlight(TextHighlight highlight) {
    highlights.removeWhere((item) => item.id == highlight.id);
    notifyListeners();
    _persist();
  }

  void addNote(String text, {int? start, int? end}) {
    final chapter = currentChapter;
    if (chapter == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (start != null && end != null && end > start) {
      addHighlight(start: start, end: end, note: trimmed);
      return;
    }

    notes.insert(
      0,
      ChapterNote(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        chapterId: chapter.id,
        text: trimmed,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _persist();
  }

  void removeNote(ChapterNote note) {
    notes.removeWhere((item) => item.id == note.id);
    notifyListeners();
    _persist();
  }

  List<TextHighlight> highlightsFor(String chapterId) {
    final items = highlights.where((item) => item.chapterId == chapterId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  List<ChapterNote> notesFor(String chapterId) {
    return notes.where((item) => item.chapterId == chapterId).toList();
  }

  String excerpt(TextHighlight highlight) {
    final matches = chapters.where((item) => item.id == highlight.chapterId);
    if (matches.isEmpty) return '';
    final chapter = matches.first;
    final end = highlight.end.clamp(0, chapter.body.length);
    final start = highlight.start.clamp(0, end);
    return chapter.body.substring(start, end).replaceAll('\n', ' ').trim();
  }

  Map<String, dynamic> _toJson() {
    return {
      'bookId': selectedBook?.id,
      'chapterIndex': chapterIndex,
      'bookmarks': bookmarkedChapterIds.toList(),
      'highlights': highlights
          .map(
            (item) => {
              'id': item.id,
              'chapterId': item.chapterId,
              'start': item.start,
              'end': item.end,
              'tint': item.tint.name,
              'createdAt': item.createdAt.toIso8601String(),
              'note': item.note,
            },
          )
          .toList(),
      'notes': notes
          .map(
            (item) => {
              'id': item.id,
              'chapterId': item.chapterId,
              'text': item.text,
              'createdAt': item.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedIndex = json['chapterIndex'] as int? ?? 0;
      chapterIndex = chapters.isEmpty ? 0 : savedIndex.clamp(0, chapters.length - 1);
      bookmarkedChapterIds
        ..clear()
        ..addAll(((json['bookmarks'] as List?) ?? const []).cast<String>());
      highlights
        ..clear()
        ..addAll(
          ((json['highlights'] as List?) ?? const []).map((item) {
            final map = item as Map<String, dynamic>;
            return TextHighlight(
              id: map['id'] as String,
              chapterId: map['chapterId'] as String,
              start: map['start'] as int,
              end: map['end'] as int,
              tint: HighlightTint.values.firstWhere(
                (value) => value.name == map['tint'],
                orElse: () => HighlightTint.amber,
              ),
              createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
              note: map['note'] as String? ?? '',
            );
          }),
        );
      notes
        ..clear()
        ..addAll(
          ((json['notes'] as List?) ?? const []).map((item) {
            final map = item as Map<String, dynamic>;
            return ChapterNote(
              id: map['id'] as String,
              chapterId: map['chapterId'] as String,
              text: map['text'] as String,
              createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
            );
          }),
        );
    } catch (_) {
      // Tests and first launch have no plugin store.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_toJson()));
    } catch (_) {}
  }
}
