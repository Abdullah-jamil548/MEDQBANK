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
  static const _pdfStorageKey = 'medqbank.library.pdf.v1';

  final LibraryRepository _repository;

  List<StudyBook> remoteBooks = const [];
  List<BookChapter> chapters = const [];
  StudyBook? selectedBook;
  String? remotePdfUrl;
  bool remoteCatalogLoading = false;
  String? remoteCatalogError;
  bool isOpeningRemote = false;
  String? pdfOpenError;
  String? _savedBookId;
  int chapterIndex = 0;
  HighlightTint activeTint = HighlightTint.amber;
  final Set<String> bookmarkedChapterIds = {};
  final List<TextHighlight> highlights = [];
  final List<ChapterNote> notes = [];

  int pdfPage = 1;
  int pdfPageCount = 1;
  final Set<int> pdfBookmarks = {};
  final List<PdfHighlight> pdfHighlights = [];
  final List<PdfPageNote> pdfNotes = [];

  List<StudyBook> get books => remoteBooks;

  BookChapter? get currentChapter =>
      chapters.isEmpty ? null : chapters[chapterIndex.clamp(0, chapters.length - 1)];

  bool get isPdfSelected => selectedBook?.kind == BookKind.pdf;
  bool get isRemotePdf => selectedBook?.isRemote == true;
  bool get hasRemotePdfUrl => remotePdfUrl != null && remotePdfUrl!.isNotEmpty;
  bool get hasPdfDocument => hasRemotePdfUrl;
  String? get pdfFileName => selectedBook?.fileName;
  String? get marksKey => selectedBook?.id;

  List<PdfHighlight> get allPdfHighlights {
    final items = [...pdfHighlights]..sort((a, b) {
        final byPage = a.page.compareTo(b.page);
        return byPage != 0 ? byPage : a.start.compareTo(b.start);
      });
    return items;
  }

  List<int> get allPdfBookmarkPages {
    final pages = pdfBookmarks.toList()..sort();
    return pages;
  }

  List<PdfPageNote> get allPdfNotes {
    final items = [...pdfNotes]..sort((a, b) => a.page.compareTo(b.page));
    return items;
  }

  Map<String, dynamic>? _cachedMarksFor(StudyBook book) {
    if (selectedBook?.id == book.id) return _liveMarksJson();
    return _pdfMarksCache[book.id] ??
        (book.fileName == null || book.fileName!.isEmpty ? null : _pdfMarksCache[book.fileName!]);
  }

  double progressFor(StudyBook book) {
    final json = _cachedMarksFor(book);
    final page = _asInt(json?['page']) ?? 0;
    final count = _asInt(json?['pageCount']) ?? 0;
    if (count <= 1) return 0;
    return (page / count).clamp(0, 1);
  }

  int highlightCountFor(StudyBook book) {
    if (selectedBook?.id == book.id) return pdfHighlights.length;
    return ((_cachedMarksFor(book)?['highlights'] as List?) ?? const []).length;
  }

  String progressLabelFor(StudyBook book) {
    final json = _cachedMarksFor(book);
    final page = _asInt(json?['page']) ?? 0;
    final count = _asInt(json?['pageCount']) ?? 0;
    if (count > 1) return 'Page $page of $count';
    if (highlightCountFor(book) == 0) return 'Not started';
    return 'In progress';
  }

  bool get hasBook => isPdfSelected ? true : currentChapter != null;

  double get progress {
    if (isPdfSelected) {
      return pdfPageCount <= 1 ? 0 : (pdfPage / pdfPageCount).clamp(0, 1);
    }
    if (chapters.isEmpty) return 0;
    return ((chapterIndex + 1) / chapters.length).clamp(0, 1);
  }

  bool get isCurrentBookmarked {
    if (isPdfSelected) return pdfBookmarks.contains(pdfPage);
    return currentChapter != null && bookmarkedChapterIds.contains(currentChapter!.id);
  }

  Future<void> load() async {
    await _restore();
    await _restorePdf();
    notifyListeners();
    await refreshRemoteBooks();
  }

  Future<void> refreshRemoteBooks() async {
    remoteCatalogLoading = true;
    remoteCatalogError = null;
    notifyListeners();
    try {
      remoteBooks = await _repository.getRemoteBooks();
      _restoreSavedSelection();
    } catch (error) {
      remoteCatalogError = error.toString();
    } finally {
      remoteCatalogLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectBook(StudyBook book) async {
    _stashCurrentPdfMarks();
    selectedBook = book;
    pdfOpenError = null;
    remotePdfUrl = null;
    if (book.kind == BookKind.pdf) {
      chapters = const [];
      _applyPdfMarks(book);
      await _requestRemoteAccess(book);
    } else {
      chapters = await _repository.getChapters(book.id);
      chapterIndex = chapterIndex.clamp(0, chapters.isEmpty ? 0 : chapters.length - 1);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> ensureRemoteDocument() async {
    final book = selectedBook;
    if (book == null || !book.isRemote || hasRemotePdfUrl || isOpeningRemote) return;
    await _requestRemoteAccess(book);
  }

  Future<void> retryRemoteDocument() async {
    final book = selectedBook;
    if (book == null || !book.isRemote) return;
    remotePdfUrl = null;
    await _requestRemoteAccess(book);
  }

  Future<void> _requestRemoteAccess(StudyBook book) async {
    isOpeningRemote = true;
    pdfOpenError = null;
    notifyListeners();
    try {
      final access = await _repository.getBookAccess(book.id, filename: book.fileName);
      if (access.url.isEmpty) {
        throw const FormatException('The book link was empty.');
      }
      remotePdfUrl = access.url;
      if (selectedBook?.id == book.id && (selectedBook?.fileName == null || selectedBook!.fileName!.isEmpty)) {
        selectedBook = StudyBook(
          id: book.id,
          title: book.title,
          author: book.author,
          subject: book.subject,
          yearLabel: book.yearLabel,
          blurb: book.blurb,
          kind: book.kind,
          fileName: access.filename,
          isRemote: true,
          sizeBytes: access.size,
        );
      }
    } catch (_) {
      pdfOpenError = 'Could not open this book. Check your connection and try again.';
      remotePdfUrl = null;
    } finally {
      isOpeningRemote = false;
      notifyListeners();
    }
  }

  void setPdfPage(int page, {int? pageCount}) {
    if (pageCount != null && pageCount > 0) pdfPageCount = pageCount;
    pdfPage = page.clamp(1, pdfPageCount < 1 ? 1 : pdfPageCount);
    notifyListeners();
    _persistPdf();
  }

  void goToPdfPage(int page) {
    setPdfPage(page);
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
    if (isPdfSelected) {
      if (pdfBookmarks.contains(pdfPage)) {
        pdfBookmarks.remove(pdfPage);
      } else {
        pdfBookmarks.add(pdfPage);
      }
      notifyListeners();
      _persistPdf();
      return;
    }
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

  void addPdfHighlight({
    required int page,
    required int start,
    required int end,
    required String excerpt,
    required List<PdfBox> boxes,
    String note = '',
  }) {
    if (end <= start || boxes.isEmpty) return;
    pdfHighlights.removeWhere(
      (item) => item.page == page && item.start < end && item.end > start,
    );
    pdfHighlights.add(
      PdfHighlight(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: page,
        start: start,
        end: end,
        excerpt: excerpt.trim(),
        tint: activeTint,
        createdAt: DateTime.now(),
        boxes: boxes,
        note: note.trim(),
      ),
    );
    notifyListeners();
    _persistPdf();
  }

  void removeHighlight(TextHighlight highlight) {
    highlights.removeWhere((item) => item.id == highlight.id);
    notifyListeners();
    _persist();
  }

  void removePdfHighlight(PdfHighlight highlight) {
    pdfHighlights.removeWhere((item) => item.id == highlight.id);
    notifyListeners();
    _persistPdf();
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

  void addPdfNote(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    pdfNotes.insert(
      0,
      PdfPageNote(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        page: pdfPage,
        text: trimmed,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    _persistPdf();
  }

  void removeNote(ChapterNote note) {
    notes.removeWhere((item) => item.id == note.id);
    notifyListeners();
    _persist();
  }

  void removePdfNote(PdfPageNote note) {
    pdfNotes.removeWhere((item) => item.id == note.id);
    notifyListeners();
    _persistPdf();
  }

  List<TextHighlight> highlightsFor(String chapterId) {
    final items = highlights.where((item) => item.chapterId == chapterId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  List<ChapterNote> notesFor(String chapterId) {
    return notes.where((item) => item.chapterId == chapterId).toList();
  }

  List<PdfHighlight> pdfHighlightsOn(int page) {
    return pdfHighlights.where((item) => item.page == page).toList();
  }

  List<PdfPageNote> pdfNotesOn(int page) {
    return pdfNotes.where((item) => item.page == page).toList();
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

  Map<String, dynamic> _pdfToJson() {
    final live = _liveMarksJson();
    return {
      'selectedId': selectedBook?.id,
      'files': {
        ..._pdfMarksCache,
        ?marksKey: live,
        ?pdfFileName: live,
      },
    };
  }

  Map<String, dynamic> _liveMarksJson() {
    return {
      'page': pdfPage,
      'pageCount': pdfPageCount,
      'bookmarks': pdfBookmarks.toList(),
      'highlights': pdfHighlights.map(_pdfHighlightJson).toList(),
      'notes': pdfNotes.map(_pdfNoteJson).toList(),
    };
  }

  Map<String, dynamic> _pdfHighlightJson(PdfHighlight item) {
    return {
      'id': item.id,
      'page': item.page,
      'start': item.start,
      'end': item.end,
      'excerpt': item.excerpt,
      'tint': item.tint.name,
      'createdAt': item.createdAt.toIso8601String(),
      'note': item.note,
      'boxes': item.boxes
          .map(
            (box) => {
              'l': box.left,
              't': box.top,
              'r': box.right,
              'b': box.bottom,
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> _pdfNoteJson(PdfPageNote item) {
    return {
      'id': item.id,
      'page': item.page,
      'text': item.text,
      'createdAt': item.createdAt.toIso8601String(),
    };
  }

  final Map<String, Map<String, dynamic>> _pdfMarksCache = {};

  void _applyPdfMarks(StudyBook book) {
    final json = _pdfMarksCache[book.id] ??
        (book.fileName == null || book.fileName!.isEmpty ? null : _pdfMarksCache[book.fileName!]);
    pdfBookmarks.clear();
    pdfHighlights.clear();
    pdfNotes.clear();
    if (json == null) {
      pdfPage = 1;
      pdfPageCount = 1;
      return;
    }
    pdfPage = _asInt(json['page']) ?? 1;
    pdfPageCount = _asInt(json['pageCount']) ?? 1;
    pdfBookmarks.addAll(
      ((json['bookmarks'] as List?) ?? const []).map((item) => _asInt(item) ?? 0).where((page) => page > 0),
    );
    pdfHighlights.addAll(
      ((json['highlights'] as List?) ?? const []).map(_highlightFromJson),
    );
    pdfNotes.addAll(
      ((json['notes'] as List?) ?? const []).map(_noteFromJson),
    );
  }

  void _stashCurrentPdfMarks() {
    final book = selectedBook;
    if (book == null) return;
    final payload = _liveMarksJson();
    _pdfMarksCache[book.id] = payload;
    final fileName = book.fileName;
    if (fileName != null && fileName.isNotEmpty) {
      _pdfMarksCache[fileName] = Map<String, dynamic>.from(payload);
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  PdfHighlight _highlightFromJson(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return PdfHighlight(
      id: map['id'] as String,
      page: _asInt(map['page']) ?? 1,
      start: _asInt(map['start']) ?? 0,
      end: _asInt(map['end']) ?? 0,
      excerpt: map['excerpt'] as String? ?? '',
      tint: HighlightTint.values.firstWhere(
        (value) => value.name == map['tint'],
        orElse: () => HighlightTint.amber,
      ),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String? ?? '',
      boxes: ((map['boxes'] as List?) ?? const []).map((item) {
        final box = item as Map<String, dynamic>;
        return PdfBox(
          left: (box['l'] as num).toDouble(),
          top: (box['t'] as num).toDouble(),
          right: (box['r'] as num).toDouble(),
          bottom: (box['b'] as num).toDouble(),
        );
      }).toList(),
    );
  }

  PdfPageNote _noteFromJson(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return PdfPageNote(
      id: map['id'] as String,
      page: _asInt(map['page']) ?? 1,
      text: map['text'] as String,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedIndex = json['chapterIndex'] as int? ?? 0;
      chapterIndex = savedIndex;
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
      final savedId = json['bookId'] as String?;
      _savedBookId = savedId;
      if (savedId != null) {
        final match = books.where((book) => book.id == savedId);
        if (match.isNotEmpty) selectedBook = match.first;
      }
    } catch (_) {}
  }

  Future<void> _restorePdf() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pdfStorageKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final files = (json['files'] as Map?)?.cast<String, dynamic>() ?? {};
      _pdfMarksCache
        ..clear()
        ..addAll(files.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map))));
      final selectedId = json['selectedId'] as String?;
      if (selectedId != null) {
        _savedBookId ??= selectedId;
      }
    } catch (_) {}
  }

  void _restoreSavedSelection() {
    final savedId = _savedBookId;
    if (savedId == null) return;
    final match = books.where((book) => book.id == savedId);
    if (match.isEmpty) return;
    selectedBook = match.first;
    if (match.first.kind == BookKind.pdf) {
      _applyPdfMarks(match.first);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_toJson()));
    } catch (_) {}
  }

  Future<void> _persistPdf() async {
    _stashCurrentPdfMarks();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pdfStorageKey, jsonEncode(_pdfToJson()));
    } catch (_) {}
  }
}
