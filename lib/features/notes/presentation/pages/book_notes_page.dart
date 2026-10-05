import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../providers/notes_hub_provider.dart';

class BookNotesPage extends StatelessWidget {
  const BookNotesPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  final String bookId;
  final String bookTitle;

  Future<void> _openAtPage(BuildContext context, int pageNo) async {
    final library = context.read<LibraryProvider>();
    if (library.books.isEmpty) {
      await library.load();
    }
    if (!context.mounted) return;
    CatalogBook? book;
    for (final item in library.books) {
      if (item.id == bookId) {
        book = item;
        break;
      }
    }
    if (book == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book not found in library')),
      );
      return;
    }
    if (!(library.downloaded[book.id] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download ${book.title} from Library first')),
      );
      return;
    }
    final ok = await library.openBook(book, initialPage: pageNo);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(library.downloadError ?? 'Could not open book')),
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.bookReader);
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<NotesHubProvider>();
    BookNotesGroup? group;
    for (final g in hub.groups) {
      if (g.bookId == bookId) {
        group = g;
        break;
      }
    }
    final notes = group?.notes ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: notes.isEmpty
          ? const Center(
              child: Text(
                'No notes for this book yet.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = notes[index];
                return AppCard(
                  onTap: () => _openAtPage(context, note.pageNo),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Page ${note.pageNo}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Open',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        note.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
