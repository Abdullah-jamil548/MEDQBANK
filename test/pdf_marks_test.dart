import 'package:flutter_test/flutter_test.dart';
import 'package:medqbank/data/repositories/library_repository_impl.dart';
import 'package:medqbank/domain/entities/study_book.dart';
import 'package:medqbank/domain/repositories/library_repository.dart';
import 'package:medqbank/features/library/presentation/providers/library_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLibraryRepository implements LibraryRepository {
  static const book = StudyBook(
    id: '27th-Bailey-Loves-Short-Practice-of-Surgery-27th',
    title: 'Bailey Love',
    author: 'MedQBank library',
    subject: 'Surgery',
    yearLabel: 'Online',
    blurb: 'Streamed book',
    kind: BookKind.pdf,
    fileName: '27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf',
    isRemote: true,
    sizeBytes: 10,
  );

  @override
  Future<List<StudyBook>> getBooks() async => const [];

  @override
  Future<List<StudyBook>> getRemoteBooks() async => const [book];

  @override
  Future<List<BookChapter>> getChapters(String bookId) async => const [];

  @override
  Future<BookAccess> getBookAccess(String bookId, {String? filename}) async {
    return const BookAccess(
      bookId: '27th-Bailey-Loves-Short-Practice-of-Surgery-27th',
      filename: '27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf',
      size: 10,
      url: 'https://example.com/book.pdf',
      expiresIn: 3600,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('server book highlights, bookmarks, and notes persist on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeLibraryRepository();

    final first = LibraryProvider(repo);
    await first.refreshRemoteBooks();
    await first.selectBook(first.books.single);
    first.setPdfPage(12, pageCount: 80);
    first.addPdfHighlight(
      page: 12,
      start: 0,
      end: 6,
      excerpt: 'hernia',
      boxes: const [PdfBox(left: 10, top: 40, right: 80, bottom: 20)],
      note: 'viva trap',
    );
    first.toggleBookmark();
    first.addPdfNote('Revise inguinal canal');

    final second = LibraryProvider(repo);
    await second.refreshRemoteBooks();
    await second.selectBook(second.books.single);

    expect(second.pdfPage, 12);
    expect(second.pdfHighlights.single.excerpt, 'hernia');
    expect(second.pdfHighlights.single.note, 'viva trap');
    expect(second.pdfBookmarks, contains(12));
    expect(second.pdfNotes.single.text, 'Revise inguinal canal');
  });

  test('bundled catalog stays empty so only API books appear', () async {
    expect(await LibraryRepositoryImpl().getBooks(), isEmpty);
  });
}
