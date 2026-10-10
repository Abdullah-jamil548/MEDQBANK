class McqOption {
  const McqOption({required this.key, required this.text});

  final String key;
  final String text;

  factory McqOption.fromJson(Map<String, dynamic> json) {
    return McqOption(
      key: (json['key'] as String? ?? '').toUpperCase(),
      text: (json['text'] as String? ?? '').trim(),
    );
  }
}

class McqQuestion {
  const McqQuestion({
    required this.id,
    required this.stem,
    required this.options,
    this.topic,
    this.explanation = '',
    this.answerKey,
    this.sortOrder = 0,
    this.sourcePage,
    this.stemImage,
    this.mode = 'text',
  });

  final String id;
  final String stem;
  final String? topic;
  final String explanation;
  final String? answerKey;
  final int sortOrder;
  final int? sourcePage;
  /// Flutter asset path (`assets/...`) or API path (`/mcq-images/...`).
  final String? stemImage;
  /// `text` | `image` — image only when unreadable / figure options.
  final String mode;
  final List<McqOption> options;

  bool get hasImage => stemImage != null && stemImage!.trim().isNotEmpty;

  /// Show scan image in quiz only for true image-fallback items.
  bool get showStemImage =>
      mode == 'image' && hasImage;

  factory McqQuestion.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List?)
            ?.whereType<Map>()
            .map((e) => McqOption.fromJson(Map<String, dynamic>.from(e)))
            .where((o) => o.key.isNotEmpty && o.text.isNotEmpty)
            .toList() ??
        const <McqOption>[];
    final mode = ((json['mode'] as String?) ?? 'text').trim().toLowerCase();
    final stemImage = (json['stem_image'] as String?)?.trim();
    return McqQuestion(
      id: json['question_id']?.toString() ??
          '${json['sort_order'] ?? json['stem']}',
      stem: (json['stem'] as String? ?? '').trim(),
      topic: json['topic'] as String?,
      explanation: json['explanation'] as String? ?? '',
      answerKey: (json['answer_key'] as String?)?.toUpperCase(),
      sortOrder: json['sort_order'] as int? ?? 0,
      sourcePage: json['source_page'] as int?,
      stemImage: stemImage,
      mode: mode == 'image' ? 'image' : 'text',
      options: opts,
    );
  }
}

class McqSetSummary {
  const McqSetSummary({
    required this.id,
    required this.subject,
    required this.title,
    this.sourcePdf,
    this.topic,
    this.questionCount = 0,
  });

  final String id;
  final String subject;
  final String title;
  final String? sourcePdf;
  final String? topic;
  final int questionCount;

  factory McqSetSummary.fromJson(Map<String, dynamic> json) {
    return McqSetSummary(
      id: json['set_id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      title: json['title'] as String? ?? 'MCQs',
      sourcePdf: json['source_pdf'] as String?,
      topic: json['topic'] as String?,
      questionCount: json['question_count'] as int? ??
          ((json['questions'] as List?)?.length ?? 0),
    );
  }
}

class McqSetDetail {
  const McqSetDetail({
    required this.summary,
    required this.questions,
  });

  final McqSetSummary summary;
  final List<McqQuestion> questions;

  factory McqSetDetail.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List?)
            ?.whereType<Map>()
            .map((e) => McqQuestion.fromJson(Map<String, dynamic>.from(e)))
            .where(
              (q) =>
                  q.options.length >= 3 &&
                  (q.stem.isNotEmpty || q.showStemImage),
            )
            .toList() ??
        const <McqQuestion>[];
    return McqSetDetail(
      summary: McqSetSummary.fromJson(json),
      questions: questions,
    );
  }
}

class McqSubjectInfo {
  const McqSubjectInfo({
    required this.subject,
    this.setCount = 0,
    this.questionCount = 0,
  });

  final String subject;
  final int setCount;
  final int questionCount;

  factory McqSubjectInfo.fromJson(Map<String, dynamic> json) {
    return McqSubjectInfo(
      subject: json['subject'] as String? ?? '',
      setCount: json['set_count'] as int? ?? 0,
      questionCount: json['question_count'] as int? ?? 0,
    );
  }
}
