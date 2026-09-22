import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../providers/library_provider.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final rs = context.rs;

    final grouped = <String, List<CatalogBook>>{};
    for (final book in library.books) {
      final key = book.yearLabel.isEmpty ? 'All years' : book.yearLabel;
      grouped.putIfAbsent(key, () => []).add(book);
    }

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Library',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: rs.font(26),
                        letterSpacing: -0.4,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: library.loading ? null : () => library.load(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          SizedBox(height: rs.scale(6)),
          Text(
            'Download to app storage, then read offline',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: rs.font(14),
            ),
          ),
          if (library.downloadError != null) ...[
            SizedBox(height: rs.scale(10)),
            Text(
              library.downloadError!,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ],
          if (library.error != null) ...[
            SizedBox(height: rs.scale(10)),
            Text(
              library.error!,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ],
          SizedBox(height: rs.scale(18)),
          if (library.loading && library.books.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (library.books.isEmpty)
            const Text('No books in the catalog yet.')
          else
            ...grouped.entries.expand((entry) {
              return [
                Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(8), top: rs.scale(4)),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ...entry.value.map(
                  (book) => Padding(
                    padding: EdgeInsets.only(bottom: rs.scale(12)),
                    child: _BookCard(book: book),
                  ),
                ),
              ];
            }),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final CatalogBook book;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isDownloaded = library.downloaded[book.id] == true;
    final progress = library.downloadProgress[book.id];
    final downloading = progress != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (book.subject.isNotEmpty) _meta(book.subject),
                        if (book.sizeLabel.isNotEmpty) _meta(book.sizeLabel),
                        _meta(isDownloaded ? 'On device' : 'Cloud'),
                      ],
                    ),
                  ],
                ),
              ),
              if (downloading)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(value: progress.clamp(0.05, 1.0), strokeWidth: 3),
                      IconButton(
                        tooltip: 'Cancel',
                        iconSize: 16,
                        onPressed: () => library.cancelDownload(book.id),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                )
              else
                IconButton(
                  tooltip: isDownloaded ? 'Re-download' : 'Download to app',
                  onPressed: () => library.downloadBook(book),
                  icon: Icon(
                    isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                    color: isDownloaded ? AppColors.secondary : AppColors.primary,
                  ),
                ),
            ],
          ),
          if (downloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.clamp(0.01, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading ${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isDownloaded
                      ? () async {
                          final ok = await library.openBook(book);
                          if (!context.mounted || !ok) return;
                          Navigator.of(context).pushNamed(AppRoutes.bookReader);
                        }
                      : null,
                  child: Text(isDownloaded ? 'Open' : 'Download first'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
