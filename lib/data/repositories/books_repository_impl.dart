import '../../core/network/api_client.dart';
import '../../domain/entities/catalog_book.dart';
import '../../domain/entities/weekly_progress.dart';
import '../../domain/repositories/books_repository.dart';

class BooksRepositoryImpl implements BooksRepository {
  BooksRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<CatalogBook>> listBooks() async {
    final res = await _api.get<List<dynamic>>('/books', queryParameters: {'source': 'db'});
    final data = res.data ?? const [];
    return data
        .whereType<Map>()
        .map((e) => CatalogBook.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<({String url, String filename, int size, int expiresIn})> getAccess(
    String bookId, {
    int expiresIn = 3600,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/books/$bookId/access',
      data: {'expires_in': expiresIn},
    );
    final data = res.data ?? {};
    return (
      url: data['url'] as String,
      filename: data['filename'] as String? ?? '$bookId.pdf',
      size: data['size'] as int? ?? 0,
      expiresIn: data['expires_in'] as int? ?? expiresIn,
    );
  }

  @override
  Future<List<PageHighlight>> listHighlights({String? bookId}) async {
    final res = await _api.get<List<dynamic>>(
      '/highlights',
      queryParameters: {if (bookId != null) 'book_id': bookId},
    );
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => PageHighlight.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<PageHighlight> upsertHighlight(PageHighlight highlight, {bool deleted = false}) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/highlights',
      data: highlight.toUpsertJson(deleted: deleted),
    );
    return PageHighlight.fromJson(res.data ?? {});
  }

  @override
  Future<List<PageNote>> listNotes({String? bookId}) async {
    final res = await _api.get<List<dynamic>>(
      '/notes',
      queryParameters: {if (bookId != null) 'book_id': bookId},
    );
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => PageNote.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<PageNote> upsertNote(PageNote note, {bool deleted = false}) async {
    final res = await _api.put<Map<String, dynamic>>(
      '/notes',
      data: note.toUpsertJson(deleted: deleted),
    );
    return PageNote.fromJson(res.data ?? {});
  }

  @override
  Future<List<PageBookmark>> listBookmarks({String? bookId}) async {
    final res = await _api.get<List<dynamic>>(
      '/bookmarks',
      queryParameters: {if (bookId != null) 'book_id': bookId},
    );
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => PageBookmark.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<PageBookmark> createBookmark(String bookId, int pageNo) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/bookmarks',
      data: {'book_id': bookId, 'page_no': pageNo},
    );
    return PageBookmark.fromJson(res.data ?? {});
  }

  @override
  Future<void> deleteBookmark(String bookmarkId) async {
    await _api.delete('/bookmarks/$bookmarkId');
  }

  @override
  Future<void> upsertProgress(String bookId, int pageNo, {double? progressPct}) async {
    await _api.put(
      '/progress',
      data: {
        'book_id': bookId,
        'page_no': pageNo,
        if (progressPct != null) 'progress_pct': progressPct,
      },
    );
  }

  @override
  Future<List<BookReadingProgress>> listProgress() async {
    final res = await _api.get<List<dynamic>>('/progress');
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => BookReadingProgress.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
