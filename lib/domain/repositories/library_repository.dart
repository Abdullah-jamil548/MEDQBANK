import '../entities/study_book.dart';

abstract class LibraryRepository {
  Future<List<StudyBook>> getBooks();
  Future<List<BookChapter>> getChapters(String bookId);
}
