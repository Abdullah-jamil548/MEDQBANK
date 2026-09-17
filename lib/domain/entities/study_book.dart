enum BookKind { notes, pdf }

class StudyBook {
  const StudyBook({
    required this.id,
    required this.title,
    required this.author,
    required this.subject,
    required this.yearLabel,
    required this.blurb,
    this.kind = BookKind.notes,
    this.fileName,
    this.storedName,
    this.isRemote = false,
    this.sizeBytes,
  });

  final String id;
  final String title;
  final String author;
  final String subject;
  final String yearLabel;
  final String blurb;
  final BookKind kind;
  final String? fileName;
  final String? storedName;
  final bool isRemote;
  final int? sizeBytes;
}

class BookAccess {
  const BookAccess({
    required this.bookId,
    required this.filename,
    required this.size,
    required this.url,
    required this.expiresIn,
  });

  final String bookId;
  final String filename;
  final int size;
  final String url;
  final int expiresIn;

  factory BookAccess.fromJson(Map<String, dynamic> json) {
    return BookAccess(
      bookId: json['book_id'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }
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

class PdfBox {
  const PdfBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class PdfHighlight {
  const PdfHighlight({
    required this.id,
    required this.page,
    required this.start,
    required this.end,
    required this.excerpt,
    required this.tint,
    required this.createdAt,
    required this.boxes,
    this.note = '',
  });

  final String id;
  final int page;
  final int start;
  final int end;
  final String excerpt;
  final HighlightTint tint;
  final DateTime createdAt;
  final List<PdfBox> boxes;
  final String note;
}

class PdfPageNote {
  const PdfPageNote({
    required this.id,
    required this.page,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final int page;
  final String text;
  final DateTime createdAt;
}


