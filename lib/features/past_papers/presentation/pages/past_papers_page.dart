import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/responsive/app_responsive.dart';
import '../../../../core/responsive/responsive_body.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../domain/entities/catalog_book.dart';
import '../../../../domain/entities/mcq.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../providers/mcq_provider.dart';

enum _PaperMode { mcq, qa }

class PastPapersPage extends StatefulWidget {
  const PastPapersPage({super.key});

  @override
  State<PastPapersPage> createState() => _PastPapersPageState();
}

class _PastPapersPageState extends State<PastPapersPage> {
  _PaperMode _mode = _PaperMode.mcq;
  String _subject = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().loadPastPapers();
      context.read<McqProvider>().loadCatalog();
    });
  }

  List<String> _subjectsForMode({
    required List<CatalogBook> papers,
    required McqProvider mcq,
  }) {
    final set = <String>{};
    if (_mode == _PaperMode.mcq) {
      for (final p in papers.where((e) => e.isMcqOptionsPaper)) {
        set.add(p.subject.isEmpty ? 'Past Papers' : p.subject);
      }
      for (final s in mcq.subjects) {
        set.add(s.subject);
      }
    } else {
      for (final p in papers.where((e) => e.isQaPaper)) {
        set.add(p.subject.isEmpty ? 'Past Papers' : p.subject);
      }
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  bool _matchesSubject(String subject) {
    if (_subject == 'All') return true;
    return subject == _subject;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final mcq = context.watch<McqProvider>();
    final rs = context.rs;

    final subjects = _subjectsForMode(papers: library.pastPapers, mcq: mcq);
    if (!subjects.contains(_subject)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _subject = 'All');
      });
    }

    final mcqSets = mcq.setsBySubject.entries
        .where((e) => _matchesSubject(e.key))
        .expand((e) => e.value)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final mcqPdfs = library.pastPapers
        .where((p) => p.isMcqOptionsPaper)
        .where((p) => _matchesSubject(p.subject.isEmpty ? 'Past Papers' : p.subject))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final qaPdfs = library.pastPapers
        .where((p) => p.isQaPaper)
        .where((p) => _matchesSubject(p.subject.isEmpty ? 'Past Papers' : p.subject))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final loading =
        library.loadingPastPapers && library.pastPapers.isEmpty && mcq.subjects.isEmpty;
    final empty = _mode == _PaperMode.mcq
        ? mcqSets.isEmpty && mcqPdfs.isEmpty
        : qaPdfs.isEmpty;

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
                onPressed: (library.loadingPastPapers || mcq.loading)
                    ? null
                    : () {
                        library.loadPastPapers();
                        mcq.loadCatalog();
                      },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          SizedBox(height: rs.scale(6)),
          Text(
            _mode == _PaperMode.mcq
                ? 'Practice choice questions or open MCQ PDFs'
                : 'Open short-question and key-style PDF papers',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: rs.font(14),
            ),
          ),
          SizedBox(height: rs.scale(16)),
          _ModeSwitcher(
            mode: _mode,
            onChanged: (m) => setState(() {
              _mode = m;
              _subject = 'All';
            }),
            mcqCount: library.pastPapers.where((p) => p.isMcqOptionsPaper).length +
                mcq.setsBySubject.values.fold<int>(0, (a, s) => a + s.length),
            qaCount: library.pastPapers.where((p) => p.isQaPaper).length,
          ),
          SizedBox(height: rs.scale(14)),
          if (subjects.length > 1)
            SizedBox(
              height: rs.scale(38),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                separatorBuilder: (_, _) => SizedBox(width: rs.scale(8)),
                itemBuilder: (context, i) {
                  final s = subjects[i];
                  final selected = s == _subject;
                  return FilterChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (_) => setState(() => _subject = s),
                    showCheckmark: false,
                    selectedColor: AppColors.primarySoft,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: rs.font(13),
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: rs.scale(4)),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          if (library.error != null) ...[
            SizedBox(height: rs.scale(10)),
            Text(
              library.error!,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ],
          if (mcq.error != null) ...[
            SizedBox(height: rs.scale(10)),
            Text(
              mcq.error!,
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
          SizedBox(height: rs.scale(16)),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (empty)
            _EmptyState(mode: _mode)
          else if (_mode == _PaperMode.mcq) ...[
            if (mcqSets.isNotEmpty) ...[
              _BlockHeader(
                title: 'Practice',
                detail: '${mcqSets.length} set${mcqSets.length == 1 ? '' : 's'}',
              ),
              ...mcqSets.map(
                (set) => Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(10)),
                  child: _PracticeTile(set: set),
                ),
              ),
              if (mcqPdfs.isNotEmpty) SizedBox(height: rs.scale(8)),
            ],
            if (mcqPdfs.isNotEmpty) ...[
              _BlockHeader(
                title: 'MCQ PDFs',
                detail: '${mcqPdfs.length} file${mcqPdfs.length == 1 ? '' : 's'}',
              ),
              ...mcqPdfs.map(
                (paper) => Padding(
                  padding: EdgeInsets.only(bottom: rs.scale(10)),
                  child: _PdfTile(
                    paper: paper,
                    accent: AppColors.primary,
                    badge: paper.paperFormat == PaperFormat.mixed ? 'Also has Q&A' : null,
                  ),
                ),
              ),
            ],
          ] else ...[
            _BlockHeader(
              title: 'Q&A PDFs',
              detail: '${qaPdfs.length} file${qaPdfs.length == 1 ? '' : 's'}',
            ),
            ...qaPdfs.map(
              (paper) => Padding(
                padding: EdgeInsets.only(bottom: rs.scale(10)),
                child: _PdfTile(
                  paper: paper,
                  accent: AppColors.secondary,
                  badge: paper.paperFormat == PaperFormat.mixed ? 'Also has MCQs' : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.mode,
    required this.onChanged,
    required this.mcqCount,
    required this.qaCount,
  });

  final _PaperMode mode;
  final ValueChanged<_PaperMode> onChanged;
  final int mcqCount;
  final int qaCount;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return Container(
      padding: EdgeInsets.all(rs.scale(4)),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              selected: mode == _PaperMode.mcq,
              icon: Icons.quiz_rounded,
              title: 'MCQs with options',
              count: mcqCount,
              onTap: () => onChanged(_PaperMode.mcq),
            ),
          ),
          Expanded(
            child: _ModeTab(
              selected: mode == _PaperMode.qa,
              icon: Icons.notes_rounded,
              title: 'Question & answer',
              count: qaCount,
              onTap: () => onChanged(_PaperMode.qa),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.selected,
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: rs.scale(10),
            vertical: rs.scale(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              SizedBox(height: rs.scale(8)),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: rs.font(13),
                  height: 1.2,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: rs.scale(4)),
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: rs.font(12),
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockHeader extends StatelessWidget {
  const _BlockHeader({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    return Padding(
      padding: EdgeInsets.only(bottom: rs.scale(8)),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: rs.font(14),
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            detail,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: rs.font(12),
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.mode});

  final _PaperMode mode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mode == _PaperMode.mcq ? 'No option MCQs here' : 'No Q&A papers here',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            mode == _PaperMode.mcq
                ? 'Try another subject, or switch to Question & answer.'
                : 'Try another subject, or switch to MCQs with options.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({required this.set});

  final McqSetSummary set;

  @override
  Widget build(BuildContext context) {
    final rs = context.rs;
    final mcq = context.watch<McqProvider>();
    final openingThis = mcq.openingSetId == set.id;
    final openingOther = mcq.isOpeningSet && !openingThis;

    return AppCard(
      padding: EdgeInsets.all(rs.scale(14)),
      color: openingThis ? AppColors.primarySoft : AppColors.surface,
      onTap: openingOther
          ? null
          : () async {
              final provider = context.read<McqProvider>();
              final result = await provider.openSet(set.id);
              if (!context.mounted) return;
              if (result == OpenSetResult.opened) {
                await Navigator.of(context).pushNamed(AppRoutes.mcqQuiz);
              }
            },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: openingThis ? AppColors.warning : AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: openingThis
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),
          SizedBox(width: rs.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  set.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  openingThis
                      ? 'Loading… tap again to cancel'
                      : openingOther
                          ? 'Wait for the other set to finish'
                          : '${set.subject} · ${set.questionCount} questions · tap to practice',
                  style: TextStyle(
                    color: openingThis ? AppColors.warning : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            openingThis ? Icons.close_rounded : Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _PdfTile extends StatelessWidget {
  const _PdfTile({
    required this.paper,
    required this.accent,
    this.badge,
  });

  final CatalogBook paper;
  final Color accent;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final rs = context.rs;
    final isDownloaded = library.downloaded[paper.id] == true;
    final progress = library.downloadProgress[paper.id];
    final downloading = progress != null;

    return AppCard(
      padding: EdgeInsets.all(rs.scale(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.picture_as_pdf_rounded, color: accent, size: 22),
              ),
              SizedBox(width: rs.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (paper.subject.isNotEmpty) _chip(paper.subject),
                        if (paper.sizeLabel.isNotEmpty) _chip(paper.sizeLabel),
                        _chip(isDownloaded ? 'On device' : 'Cloud'),
                        if (badge != null) _chip(badge!),
                      ],
                    ),
                  ],
                ),
              ),
              if (downloading)
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress.clamp(0.05, 1.0),
                        strokeWidth: 2.5,
                      ),
                      IconButton(
                        tooltip: 'Cancel',
                        iconSize: 14,
                        padding: EdgeInsets.zero,
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
            SizedBox(height: rs.scale(10)),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress.clamp(0.01, 1.0),
                minHeight: 5,
                backgroundColor: AppColors.surfaceMuted,
                color: accent,
              ),
            ),
            SizedBox(height: rs.scale(4)),
            Text(
              'Downloading… tap download again to cancel',
              style: TextStyle(
                fontSize: rs.font(11),
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
          SizedBox(height: rs.scale(10)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: downloading
                  ? () => library.cancelDownload(paper.id)
                  : isDownloaded
                      ? () async {
                          if (library.openingBookId == paper.id) {
                            library.cancelOpenBook();
                            return;
                          }
                          if (library.isOpeningBook) return;
                          final ok = await library.openBook(paper);
                          if (!context.mounted || !ok) return;
                          await Navigator.of(context).pushNamed(AppRoutes.bookReader);
                        }
                      : () => library.downloadBook(paper),
              child: Text(
                downloading
                    ? 'Cancel download'
                    : library.openingBookId == paper.id
                        ? 'Opening… tap to cancel'
                        : isDownloaded
                            ? 'Open PDF'
                            : 'Download',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
