import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../domain/entities/mcq.dart';
import '../providers/mcq_provider.dart';

class McqQuizPage extends StatelessWidget {
  const McqQuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mcq = context.watch<McqProvider>();
    final set = mcq.activeSet;
    final q = mcq.current;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          set?.summary.title ?? 'Practice MCQs',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: mcq.loading && set == null
          ? const Center(child: CircularProgressIndicator())
          : set == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      mcq.error ?? 'No MCQ set loaded.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : mcq.quizFinished
                  ? _ScorePane(
                      correct: mcq.correctCount,
                      total: set.questions.length,
                      onRetry: mcq.resetQuiz,
                      onDone: () => Navigator.of(context).maybePop(),
                    )
                  : q == null
                      ? const Center(child: Text('No questions in this set.'))
                      : _QuestionPane(question: q, provider: mcq),
    );
  }
}

class _QuestionPane extends StatelessWidget {
  const _QuestionPane({required this.question, required this.provider});

  final McqQuestion question;
  final McqProvider provider;

  @override
  Widget build(BuildContext context) {
    final total = provider.activeSet?.questions.length ?? 0;
    final idx = provider.index + 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question $idx of $total',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (question.stem.isNotEmpty)
                      Text(
                        question.stem,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.35,
                        ),
                      ),
                    if (question.showStemImage) ...[
                      if (question.stem.isNotEmpty) const SizedBox(height: 12),
                      _StemImage(path: question.stemImage!),
                      const SizedBox(height: 8),
                      const Text(
                        'Pick A–E from the image above',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ...question.options.map((o) {
                      final selected = provider.selectedKey == o.key;
                      final isCorrect = question.answerKey == o.key;
                      Color border = AppColors.border;
                      Color bg = Colors.white;
                      if (provider.revealed) {
                        if (isCorrect) {
                          border = AppColors.success;
                          bg = AppColors.successSoft;
                        } else if (selected) {
                          border = AppColors.error;
                          bg = AppColors.errorSoft;
                        }
                      } else if (selected) {
                        border = AppColors.primary;
                        bg = AppColors.primarySoft;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: provider.revealed
                              ? null
                              : () => provider.selectOption(o.key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border, width: 1.4),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${o.key}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    // Image sets often use letter-only option text
                                    (o.text.trim().toUpperCase() == o.key)
                                        ? 'Option ${o.key}'
                                        : o.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (provider.revealed && question.answerKey != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Correct: ${question.answerKey}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                      if (question.explanation.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          question.explanation,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!provider.revealed)
              FilledButton(
                onPressed: provider.selectedKey == null ? null : provider.reveal,
                child: const Text('Check answer'),
              )
            else
              FilledButton(
                onPressed: provider.next,
                child: Text(
                  idx >= total ? 'See score' : 'Next question',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StemImage extends StatelessWidget {
  const _StemImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final trimmed = path.trim();
    final Widget image;
    if (trimmed.startsWith('assets/')) {
      image = Image.asset(
        trimmed,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
      );
    } else {
      // API static mount: /mcq-images/...
      final url = trimmed.startsWith('http')
          ? trimmed
          : trimmed.startsWith('/mcq-images/')
              ? trimmed
              : '/mcq-images/${trimmed.replaceFirst(RegExp(r'^/+'), '')}';
      // Relative URLs need host — prefer asset fallback path style in bundled JSON.
      image = Image.network(
        url.startsWith('http') ? url : url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _ImageFallback(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: AppColors.surfaceMuted,
        constraints: const BoxConstraints(maxHeight: 420),
        width: double.infinity,
        child: image,
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Image unavailable — open the source PDF from Past Papers.',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }
}

class _ScorePane extends StatelessWidget {
  const _ScorePane({
    required this.correct,
    required this.total,
    required this.onRetry,
    required this.onDone,
  });

  final int correct;
  final int total;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((correct / total) * 100).round();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            '$correct / $total correct',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            '$pct%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onDone, child: const Text('Back to Past Papers')),
        ],
      ),
    );
  }
}
