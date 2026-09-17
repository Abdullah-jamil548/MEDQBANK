import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../data/datasources/books_api.dart';
import '../../../../domain/entities/study_book.dart';
import '../providers/library_provider.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  Future<void> _openBook(BuildContext context, StudyBook book) async {
    final library = context.read<LibraryProvider>();
    library.selectBook(book);
    if (!context.mounted) return;
    Navigator.of(context).pushNamed(AppRoutes.bookReader);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final rs = context.rs;

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: ScreenTitle(
                  title: 'Library',
                  subtitle: 'MBBS textbooks, ready to read, highlight, and annotate.',
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: library.remoteCatalogLoading ? null : library.refreshRemoteBooks,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: library.remoteCatalogLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          SizedBox(height: rs.scale(20)),
          if (library.remoteCatalogError != null)
            _InfoBanner(
              color: AppColors.errorSoft,
              iconColor: AppColors.error,
              icon: Icons.wifi_off_rounded,
              title: 'Could not load the library',
              body: 'Check your connection, then refresh to try again.',
              action: 'Retry',
              onAction: library.refreshRemoteBooks,
            )
          else if (library.remoteCatalogLoading && library.books.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (library.books.isEmpty)
            const _EmptyLibrary()
          else
            ...library.books.map(
              (book) => Padding(
                padding: EdgeInsets.only(bottom: rs.scale(12)),
                child: _BookCard(
                  book: book,
                  onOpen: () => _openBook(context, book),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primarySoft,
      child: const Column(
        children: [
          Icon(Icons.menu_book_rounded, size: 36, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'No books yet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'When textbooks are published to MedQBank, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onAction, child: Text(action)),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onOpen});

  final StudyBook book;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final progress = library.progressFor(book);
    final highlights = library.highlightCountFor(book);
    final label = library.progressLabelFor(book);
    final sizeLabel = formatBookSize(book.sizeBytes);
    final started = progress > 0 || highlights > 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BookCover(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.author,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(book.subject),
                        if (sizeLabel.isNotEmpty) _Chip(sizeLabel, muted: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress <= 0 ? 0.03 : progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            highlights == 0 ? label : '$label · $highlights highlights',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                started ? 'Continue reading' : 'Open book',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 10,
            bottom: 10,
            child: Container(width: 4, color: Colors.white.withValues(alpha: 0.22)),
          ),
          const Center(
            child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceMuted : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: muted ? AppColors.textSecondary : AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
