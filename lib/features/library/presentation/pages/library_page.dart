import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../domain/entities/study_book.dart';
import '../providers/library_provider.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final rs = context.rs;

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Library',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                  fontSize: rs.font(26),
                  letterSpacing: -0.4,
                ),
          ),
          SizedBox(height: rs.scale(6)),
          Text(
            'Books on this device',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: rs.font(14),
            ),
          ),
          SizedBox(height: rs.scale(18)),
          if (library.books.isEmpty)
            const Text('No books yet.')
          else
            ...library.books.map(
              (book) => Padding(
                padding: EdgeInsets.only(bottom: rs.scale(12)),
                child: _BookCard(book: book),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final StudyBook book;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isSelected = library.selectedBook?.id == book.id;
    final progress = isSelected ? library.progress : 0.0;
    final highlightCount = library.highlights.length;
    final canContinue = isSelected && library.chapterIndex > 0;

    return AppCard(
      onTap: () {
        library.selectBook(book);
        Navigator.of(context).pushNamed(AppRoutes.bookReader);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.biotech_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
                        _meta(book.subject),
                        _meta('${library.chapters.length} chapters'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            book.blurb,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress <= 0 ? 0.04 : progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            highlightCount == 0
                ? 'Select text inside to highlight, note, and bookmark.'
                : '$highlightCount highlights saved on this device',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: canContinue ? 'Continue reading' : 'Open book',
            onPressed: () {
              library.selectBook(book);
              Navigator.of(context).pushNamed(AppRoutes.bookReader);
            },
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
