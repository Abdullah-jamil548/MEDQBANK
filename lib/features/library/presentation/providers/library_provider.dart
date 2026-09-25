import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/book_cache.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../../domain/repositories/books_repository.dart';

class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._repository, this._api, this._cache);

  final BooksRepository _repository;
  final ApiClient _api;
  final BookCache _cache;
  final _uuid = const Uuid();

  List<CatalogBook> books = const [];
  final Map<String, bool> downloaded = {};
  final Map<String, double> downloadProgress = {};
  final Map<String, CancelToken> _cancelTokens = {};

  CatalogBook? selectedBook;
  String? localPdfPath;
  Uint8List? pdfBytes;
  int currentPage = 1;

  List<PageHighlight> highlights = [];
  List<PageNote> notes = [];
  List<PageBookmark> bookmarks = [];

  bool loading = false;
  String? error;
  String? downloadError;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      books = await _repository.listBooks();
      for (final book in books) {
        downloaded[book.id] = await _cache.isDownloaded(book.id);
      }
    } catch (e) {
      error = apiErrorMessage(e);
      books = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> downloadBook(CatalogBook book) async {
    if (downloadProgress.containsKey(book.id)) return;
    downloadError = null;
    downloadProgress[book.id] = 0.01;
    notifyListeners();

    final token = CancelToken();
    _cancelTokens[book.id] = token;
    try {
      // Web: stream via API (same-origin) to avoid R2 browser CORS blocks.
      // Native: direct R2 presigned URL for max speed.
      if (kIsWeb) {
        final res = await _api.dio.get<List<int>>(
          '/books/${book.id}/download',
          cancelToken: token,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 30),
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              downloadProgress[book.id] = (received / total).clamp(0.0, 1.0);
              notifyListeners();
            } else if (book.sizeBytes != null && book.sizeBytes! > 0) {
              downloadProgress[book.id] =
                  (received / book.sizeBytes!).clamp(0.0, 0.99);
              notifyListeners();
            }
          },
        );
        await _cache.saveBytes(book.id, Uint8List.fromList(res.data ?? const []));
      } else {
        final access = await _repository.getAccess(book.id, expiresIn: 3600);
        final path = await _cache.pathFor(book.id);
        if (path == null) {
          throw StateError('No local cache path available');
        }
        await _api.downloadUrl(
          access.url,
          path,
          cancelToken: token,
          onProgress: (received, total) {
            if (total > 0) {
              downloadProgress[book.id] = (received / total).clamp(0.0, 1.0);
              notifyListeners();
            }
          },
        );
      }
      downloaded[book.id] = true;
      downloadProgress.remove(book.id);
    } catch (e) {
      downloadProgress.remove(book.id);
      if (e is DioException && CancelToken.isCancel(e)) {
        downloadError = 'Download cancelled';
      } else if (e is DioException && e.type == DioExceptionType.connectionError) {
        downloadError =
            'Download failed (network). Check API is running and try again.';
      } else {
        downloadError = apiErrorMessage(e);
      }
    } finally {
      _cancelTokens.remove(book.id);
      notifyListeners();
    }
  }

  void cancelDownload(String bookId) {
    _cancelTokens[bookId]?.cancel('cancelled');
  }

  Future<bool> openBook(CatalogBook book) async {
    selectedBook = book;
    localPdfPath = null;
    pdfBytes = null;

    if (kIsWeb) {
      final bytes = await _cache.memoryBytes(book.id);
      if (bytes == null || bytes.isEmpty) {
        downloadError = 'Download the book first';
        notifyListeners();
        return false;
      }
      pdfBytes = bytes;
    } else {
      final file = await _cache.localFile(book.id);
      if (file == null) {
        downloadError = 'Download the book first';
        notifyListeners();
        return false;
      }
      localPdfPath = file.path;
    }
    currentPage = 1;
    await _loadAnnotations(book.id);
    notifyListeners();
    return true;
  }

  Future<void> _loadAnnotations(String bookId) async {
    try {
      highlights = await _repository.listHighlights(bookId: bookId);
      notes = await _repository.listNotes(bookId: bookId);
      bookmarks = await _repository.listBookmarks(bookId: bookId);
    } catch (_) {
      // keep empty; offline annotations can be added later
    }
  }

  void setPage(int page) {
    currentPage = page < 1 ? 1 : page;
    notifyListeners();
    final book = selectedBook;
    if (book != null) {
      _repository.upsertProgress(book.id, currentPage).ignore();
    }
  }

  bool isPageBookmarked([int? page]) {
    final p = page ?? currentPage;
    final book = selectedBook;
    if (book == null) return false;
    return bookmarks.any((b) => b.bookId == book.id && b.pageNo == p);
  }

  Future<void> toggleBookmark() async {
    final book = selectedBook;
    if (book == null) return;
    PageBookmark? existing;
    for (final b in bookmarks) {
      if (b.bookId == book.id && b.pageNo == currentPage) {
        existing = b;
        break;
      }
    }
    try {
      if (existing != null) {
        await _repository.deleteBookmark(existing.id);
        bookmarks = bookmarks.where((b) => b.id != existing!.id).toList();
      } else {
        final created = await _repository.createBookmark(book.id, currentPage);
        bookmarks = [...bookmarks, created];
      }
      notifyListeners();
    } catch (e) {
      downloadError = apiErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> addNote(String text) async {
    final book = selectedBook;
    if (book == null || text.trim().isEmpty) return;
    final note = PageNote(
      id: _uuid.v4(),
      bookId: book.id,
      pageNo: currentPage,
      text: text.trim(),
    );
    try {
      final saved = await _repository.upsertNote(note);
      notes = [...notes.where((n) => n.id != saved.id), saved];
      notifyListeners();
    } catch (e) {
      downloadError = apiErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> addHighlight({
    required String selectedText,
    required int pageNo,
    List<Map<String, dynamic>>? rects,
    String color = 'amber',
    String note = '',
  }) async {
    final book = selectedBook;
    if (book == null || selectedText.trim().isEmpty) return;
    final highlight = PageHighlight(
      id: _uuid.v4(),
      bookId: book.id,
      pageNo: pageNo,
      selectedText: selectedText.trim(),
      textColor: color,
      note: note,
      rects: rects,
    );
    try {
      final saved = await _repository.upsertHighlight(highlight);
      highlights = [...highlights.where((h) => h.id != saved.id), saved];
      notifyListeners();
    } catch (e) {
      downloadError = apiErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> deleteNote(PageNote note) async {
    try {
      await _repository.upsertNote(note, deleted: true);
      notes = notes.where((n) => n.id != note.id).toList();
      notifyListeners();
    } catch (e) {
      downloadError = apiErrorMessage(e);
      notifyListeners();
    }
  }

  Future<void> deleteHighlight(PageHighlight highlight) async {
    try {
      await _repository.upsertHighlight(highlight, deleted: true);
      highlights = highlights.where((h) => h.id != highlight.id).toList();
      notifyListeners();
    } catch (e) {
      downloadError = apiErrorMessage(e);
      notifyListeners();
    }
  }

  List<PageNote> notesForCurrentPage() =>
      notes.where((n) => n.pageNo == currentPage).toList();

  List<PageHighlight> highlightsForCurrentPage() =>
      highlights.where((h) => h.pageNo == currentPage).toList();
}

extension _IgnoreFuture on Future<void> {
  void ignore() {
    // fire-and-forget progress sync
    then((_) {}, onError: (_) {});
  }
}
