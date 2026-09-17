import '../../domain/entities/study_book.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/books_api.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({BooksApi? booksApi}) : _booksApi = booksApi;

  final BooksApi? _booksApi;

  @override
  Future<List<StudyBook>> getBooks() async => const [];

  @override
  Future<List<StudyBook>> getRemoteBooks() async {
    final api = _booksApi;
    if (api == null) return const [];
    return api.listBooks();
  }

  @override
  Future<BookAccess> getBookAccess(String bookId, {String? filename}) {
    final api = _booksApi;
    if (api == null) {
      throw BooksApiException('Book library is not connected.');
    }
    return api.getAccess(bookId, filename: filename);
  }

  @override
  Future<List<BookChapter>> getChapters(String bookId) async => const [];
}
