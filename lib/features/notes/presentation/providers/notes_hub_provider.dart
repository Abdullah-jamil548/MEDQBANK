import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../../domain/repositories/books_repository.dart';

class BookNotesGroup {
  const BookNotesGroup({
    required this.bookId,
    required this.bookTitle,
    required this.subject,
    required this.notes,
  });

  final String bookId;
  final String bookTitle;
  final String subject;
  final List<PageNote> notes;

  int get count => notes.length;
}

class NotesHubProvider extends ChangeNotifier {
  NotesHubProvider(this._books);

  final BooksRepository _books;

  List<BookNotesGroup> groups = [];
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final notes = await _books.listNotes();
      final books = await _books.listBooks();
      final titles = <String, CatalogBook>{
        for (final b in books) b.id: b,
      };
      final byBook = <String, List<PageNote>>{};
      for (final note in notes) {
        byBook.putIfAbsent(note.bookId, () => []).add(note);
      }
      final next = <BookNotesGroup>[];
      byBook.forEach((bookId, list) {
        list.sort((a, b) => a.pageNo.compareTo(b.pageNo));
        final book = titles[bookId];
        next.add(
          BookNotesGroup(
            bookId: bookId,
            bookTitle: book?.title ?? bookId,
            subject: book?.subject ?? '',
            notes: list,
          ),
        );
      });
      next.sort((a, b) => b.count.compareTo(a.count));
      groups = next;
    } catch (e) {
      error = apiErrorMessage(e);
      groups = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
