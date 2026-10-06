import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../library/presentation/providers/library_provider.dart';

class PastPapersPage extends StatefulWidget {
  const PastPapersPage({super.key});

  @override
  State<PastPapersPage> createState() => _PastPapersPageState();
}

class _PastPapersPageState extends State<PastPapersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadPastPapers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final rs = context.rs;

    final grouped = <String, List<CatalogBook>>{};
    for (final paper in library.pastPapers) {
      final key = paper.subject.isEmpty ? 'Past Papers' : paper.subject;
      grouped.putIfAbsent(key, () => []).add(paper);
    }
    final subjects = grouped.keys.toList()..sort();

    return ResponsiveBody(
      mode: ResponsiveMode.scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Past Papers',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: rs.font(26),
                        letterSpacing: -0.4,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: library.loadingPastPapers
                    ? null
                    : () => library.loadPastPapers(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          SizedBox(height: rs.scale(6)),
          Text(
            'UHS key / topical past papers — download then open offline',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: rs.font(14),
            ),
          ),
          if (library.error != null) ...[
            SizedBox(height: rs.scale(10)),
            Text(
              library.error!,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ],
          if (library.downloadError != null) ...[
            SizedBox(height: rs.scale(10)),
            Text(
              library.downloadError!,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ],
          SizedBox(height: rs.scale(18)),
          if (library.loadingPastPapers && library.pastPapers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (library.pastPapers.isEmpty)
            AppCard(
              child: Text(
                'No past papers in the catalog yet. Upload them on the server, then pull to refresh.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: rs.font(14),
                ),
              ),
            )
          else
            ...subjects.expand((subject) {
              final items = grouped[subject]!;
              return [
                Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(8), top: rs.scale(4)),
                  child: Text(
                    '$subject · ${items.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ...items.map(
                  (paper) => Padding(
                    padding: EdgeInsets.only(bottom: rs.scale(12)),
                    child: _PaperCard(paper: paper),
                  ),
                ),
              ];
            }),
        ],
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.paper});

  final CatalogBook paper;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final isDownloaded = library.downloaded[paper.id] == true;
    final progress = library.downloadProgress[paper.id];
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
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (paper.subject.isNotEmpty) _meta(paper.subject),
                        if (paper.sizeLabel.isNotEmpty) _meta(paper.sizeLabel),
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
                      CircularProgressIndicator(
                        value: progress.clamp(0.05, 1.0),
                        strokeWidth: 3,
                      ),
                      IconButton(
                        tooltip: 'Cancel',
                        iconSize: 16,
                        onPressed: () => library.cancelDownload(paper.id),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                )
              else
                IconButton(
                  tooltip: isDownloaded ? 'Re-download' : 'Download',
                  onPressed: () => library.downloadBook(paper),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isDownloaded
                  ? () async {
                      final ok = await library.openBook(paper);
                      if (!context.mounted || !ok) return;
                      Navigator.of(context).pushNamed(AppRoutes.bookReader);
                    }
                  : null,
              child: Text(isDownloaded ? 'Open' : 'Download first'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.secondary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
