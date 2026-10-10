import 'bundled_book_outlines.dart';

class BookTocEntry {
  const BookTocEntry({
    required this.title,
    this.pageNumber,
    this.printedPage,
    this.children = const [],
  });

  final String title;
  final int? pageNumber;
  final int? printedPage;
  final List<BookTocEntry> children;

  int? get displayPage => printedPage ?? pageNumber;

  factory BookTocEntry.fromJson(Map<String, dynamic> json) {
    final page = json['page'] ?? json['pageNumber'] ?? json['page_no'];
    final printed = json['printed'] ?? json['printedPage'];
    final kids = json['children'];
    return BookTocEntry(
      title: (json['title'] as String?)?.trim() ?? 'Untitled',
      pageNumber: page is int ? page : int.tryParse('$page'),
      printedPage: printed is int ? printed : int.tryParse('$printed'),
      children: kids is List
          ? kids
              .whereType<Map>()
              .map((e) => BookTocEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  static List<BookTocEntry> parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => BookTocEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

List<BookTocEntry> _entriesFromRaw(List<List<Object?>> rows) {
  return rows
      .map(
        (row) => BookTocEntry(
          title: row[0] as String,
          pageNumber: row[1] as int?,
          printedPage: row[2] as int?,
        ),
      )
      .toList();
}

/// Printed TOC for CamScanner PDFs that have no embedded outline.
List<BookTocEntry> bundledOutlineFor({required String id, String? title}) {
  final key = id.toLowerCase();
  final exact = kBundledOutlineRaw[key];
  if (exact != null) return _entriesFromRaw(exact);
  for (final entry in kBundledOutlineRaw.entries) {
    if (key.contains(entry.key) || entry.key.contains(key)) {
      return _entriesFromRaw(entry.value);
    }
  }
  final t = (title ?? '').toLowerCase();
  if (t.contains('excel community medicine')) {
    return _entriesFromRaw(
      kBundledOutlineRaw['excel-community-medicine-13th-edition'] ?? const [],
    );
  }
  return const [];
}

/// Past-paper shape: option MCQs vs Q&A (SEQ/UQ).
enum PaperFormat {
  mcqOptions,
  qa,
  mixed,
}

PaperFormat inferPaperFormat({
  required String id,
  required String title,
  String blurb = '',
  String? apiValue,
}) {
  final raw = (apiValue ?? '').trim().toLowerCase();
  if (raw == 'mcq_options' || raw == 'mcq') return PaperFormat.mcqOptions;
  if (raw == 'qa' || raw == 'seq') return PaperFormat.qa;
  if (raw == 'mixed') return PaperFormat.mixed;

  final blob = '$id $title $blurb'.toLowerCase();
  const mcqOverrides = [
    'embryology past papers mcqs',
    'anatomy topic wise',
    'general anatomy (key to uhs)',
    'histology (key to uhs)',
    'lower limb past papers',
  ];
  for (final key in mcqOverrides) {
    if (blob.contains(key)) return PaperFormat.mcqOptions;
  }
  if (RegExp(r'\bmcqs?\b|\bbcqs?\b|topic\s*wise|past\s*solved\s*mcqs?')
      .hasMatch(blob)) {
    return PaperFormat.mcqOptions;
  }
  if (RegExp(
    r'\btopical\b|\bseq\b|short\s*essay|university\s*questions|\buqs?\b',
  ).hasMatch(blob)) {
    return PaperFormat.qa;
  }
  if (RegExp(
    r'key\s*to\s*uhs|compiled\s*by|amna\s*iqbal|block-?\d|chapter-?\d\s*book',
  ).hasMatch(blob)) {
    return PaperFormat.mixed;
  }
  return PaperFormat.qa;
}

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
    this.paperFormat = PaperFormat.qa,
    this.outline = const [],
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
  final PaperFormat paperFormat;
  final List<BookTocEntry> outline;

  bool get isPastPaper {
    if (contentKind == 'past_paper') return true;
    // Fallback when API has not redeployed content_kind yet
    if (id.startsWith('pp-')) return true;
    if (yearLabel.toLowerCase() == 'past papers') return true;
    if (author.toLowerCase().contains('past papers')) return true;
    return false;
  }

  bool get isMcqOptionsPaper =>
      paperFormat == PaperFormat.mcqOptions || paperFormat == PaperFormat.mixed;

  bool get isQaPaper =>
      paperFormat == PaperFormat.qa || paperFormat == PaperFormat.mixed;

  factory CatalogBook.fromJson(Map<String, dynamic> json) {
    final id = json['book_id'] as String? ?? '';
    final author = json['author'] as String? ?? 'Unknown';
    final yearLabel = json['year_label'] as String? ?? '';
    final title = (json['title'] as String?)?.trim().isNotEmpty == true
        ? json['title'] as String
        : (id.isNotEmpty ? id : 'Untitled');
    final blurb = json['blurb'] as String? ?? '';
    final rawKind = (json['content_kind'] as String?)?.trim();
    final inferredPastPaper = id.startsWith('pp-') ||
        yearLabel.toLowerCase() == 'past papers' ||
        author.toLowerCase().contains('past papers');
    final contentKind = (rawKind == null || rawKind.isEmpty)
        ? (inferredPastPaper ? 'past_paper' : 'book')
        : rawKind;

    final parsed = BookTocEntry.parseList(json['outline']);
    return CatalogBook(
      id: id,
      title: title,
      author: author,
      subject: json['subject'] as String? ?? '',
      yearLabel: yearLabel,
      blurb: blurb,
      sizeBytes: json['size_bytes'] as int? ?? json['size'] as int?,
      format: json['format'] as String? ?? 'pdf',
      r2Key: json['r2_key'] as String?,
      contentKind: contentKind,
      paperFormat: inferPaperFormat(
        id: id,
        title: title,
        blurb: blurb,
        apiValue: json['paper_format'] as String?,
      ),
      outline: parsed.isNotEmpty
          ? parsed
          : bundledOutlineFor(id: id, title: title),
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
