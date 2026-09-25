class StudyBook {
  const StudyBook({
    required this.id,
    required this.title,
    required this.author,
    required this.subject,
    required this.yearLabel,
    required this.blurb,
  });

  final String id;
  final String title;
  final String author;
  final String subject;
  final String yearLabel;
  final String blurb;
}

class BookChapter {
  const BookChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String id;
  final String title;
  final String subtitle;
  final String body;
}

enum HighlightTint { amber, mint, rose }

class TextHighlight {
  const TextHighlight({
    required this.id,
    required this.chapterId,
    required this.start,
    required this.end,
    required this.tint,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String chapterId;
  final int start;
  final int end;
  final HighlightTint tint;
  final DateTime createdAt;
  final String note;

  TextHighlight copyWith({String? note, HighlightTint? tint}) {
    return TextHighlight(
      id: id,
      chapterId: chapterId,
      start: start,
      end: end,
      tint: tint ?? this.tint,
      createdAt: createdAt,
      note: note ?? this.note,
    );
  }
}

class ChapterNote {
  const ChapterNote({
    required this.id,
    required this.chapterId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String chapterId;
  final String text;
  final DateTime createdAt;
}
