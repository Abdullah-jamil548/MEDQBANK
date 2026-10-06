class CatalogBook {
  const CatalogBook({
    required this.id,
    required this.title,
    required this.author,
    required this.subject,
    required this.yearLabel,
    required this.blurb,
    this.sizeBytes,
    this.format = 'pdf',
    this.r2Key,
    this.contentKind = 'book',
  });

  final String id;
  final String title;
  final String author;
  final String subject;
  final String yearLabel;
  final String blurb;
  final int? sizeBytes;
  final String format;
  final String? r2Key;
  final String contentKind; // book | past_paper

  bool get isPastPaper {
    if (contentKind == 'past_paper') return true;
    // Fallback when API has not redeployed content_kind yet
    if (id.startsWith('pp-')) return true;
    if (yearLabel.toLowerCase() == 'past papers') return true;
    if (author.toLowerCase().contains('past papers')) return true;
    return false;
  }

  factory CatalogBook.fromJson(Map<String, dynamic> json) {
    final id = json['book_id'] as String? ?? '';
    final author = json['author'] as String? ?? 'Unknown';
    final yearLabel = json['year_label'] as String? ?? '';
    final rawKind = (json['content_kind'] as String?)?.trim();
    final inferredPastPaper = id.startsWith('pp-') ||
        yearLabel.toLowerCase() == 'past papers' ||
        author.toLowerCase().contains('past papers');
    final contentKind = (rawKind == null || rawKind.isEmpty)
        ? (inferredPastPaper ? 'past_paper' : 'book')
        : rawKind;

    return CatalogBook(
      id: id,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : (id.isNotEmpty ? id : 'Untitled'),
      author: author,
      subject: json['subject'] as String? ?? '',
      yearLabel: yearLabel,
      blurb: json['blurb'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? json['size'] as int?,
      format: json['format'] as String? ?? 'pdf',
      r2Key: json['r2_key'] as String?,
      contentKind: contentKind,
    );
  }

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PageHighlight {
  const PageHighlight({
    required this.id,
    required this.bookId,
    required this.pageNo,
    required this.textColor,
    this.selectedText,
    this.note = '',
    this.rects,
  });

  final String id;
  final String bookId;
  final int pageNo;
  final String textColor;
  final String? selectedText;
  final String note;
  final dynamic rects;

  factory PageHighlight.fromJson(Map<String, dynamic> json) {
    return PageHighlight(
      id: json['highlight_id'].toString(),
      bookId: json['book_id'] as String,
      pageNo: json['page_no'] as int,
      textColor: json['text_color'] as String? ?? 'amber',
      selectedText: json['selected_text'] as String?,
      note: json['note'] as String? ?? '',
      rects: json['rects'],
    );
  }

  Map<String, dynamic> toUpsertJson({bool deleted = false}) => {
        'highlight_id': id,
        'book_id': bookId,
        'page_no': pageNo,
        'selected_text': selectedText,
        'rects': rects,
        'text_color': textColor,
        'note': note,
        'deleted': deleted,
      };
}

class PageNote {
  const PageNote({
    required this.id,
    required this.bookId,
    required this.pageNo,
    required this.text,
  });

  final String id;
  final String bookId;
  final int pageNo;
  final String text;

  factory PageNote.fromJson(Map<String, dynamic> json) {
    return PageNote(
      id: json['note_id'].toString(),
      bookId: json['book_id'] as String,
      pageNo: json['page_no'] as int,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toUpsertJson({bool deleted = false}) => {
        'note_id': id,
        'book_id': bookId,
        'page_no': pageNo,
        'text': text,
        'deleted': deleted,
      };
}

class PageBookmark {
  const PageBookmark({
    required this.id,
    required this.bookId,
    required this.pageNo,
  });

  final String id;
  final String bookId;
  final int pageNo;

  factory PageBookmark.fromJson(Map<String, dynamic> json) {
    return PageBookmark(
      id: json['bookmark_id'].toString(),
      bookId: json['book_id'] as String,
      pageNo: json['page_no'] as int,
    );
  }
}
