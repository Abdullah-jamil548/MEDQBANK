import '../../domain/entities/study_book.dart';
import '../../domain/repositories/library_repository.dart';
import '../books/histology_book.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  @override
  Future<List<StudyBook>> getBooks() async => const [HistologyBook.meta];

  @override
  Future<List<BookChapter>> getChapters(String bookId) async {
    if (bookId != HistologyBook.meta.id) return const [];
    return HistologyBook.chapters
        .map(
          (chapter) => BookChapter(
            id: chapter.id,
            title: chapter.title,
            subtitle: chapter.subtitle,
            body: _tidy(chapter.body),
          ),
        )
        .toList();
  }

  String _tidy(String body) {
    return body.trim().split('\n').map((line) => line.trim()).join('\n');
  }
}
