import '../entities/catalog_book.dart';

abstract class BooksRepository {
  Future<List<CatalogBook>> listBooks();

  Future<({String url, String filename, int size, int expiresIn})> getAccess(
    String bookId, {
    int expiresIn = 3600,
  });

  Future<List<PageHighlight>> listHighlights({String? bookId});
  Future<PageHighlight> upsertHighlight(PageHighlight highlight, {bool deleted = false});

  Future<List<PageNote>> listNotes({String? bookId});
  Future<PageNote> upsertNote(PageNote note, {bool deleted = false});

  Future<List<PageBookmark>> listBookmarks({String? bookId});
  Future<PageBookmark> createBookmark(String bookId, int pageNo);
  Future<void> deleteBookmark(String bookmarkId);

  Future<void> upsertProgress(String bookId, int pageNo, {double? progressPct});
}
