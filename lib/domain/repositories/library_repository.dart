import '../entities/study_book.dart';

abstract class LibraryRepository {
  Future<List<StudyBook>> getBooks();
  Future<List<StudyBook>> getRemoteBooks();
  Future<List<BookChapter>> getChapters(String bookId);
  Future<BookAccess> getBookAccess(String bookId, {String? filename});
}
