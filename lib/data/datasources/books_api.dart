import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/network/api_config.dart';
import '../../domain/entities/study_book.dart';

class BooksApiException implements Exception {
  BooksApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class BooksApi {
  BooksApi({http.Client? client, this.baseUrl = ApiConfig.baseUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<StudyBook>> listBooks() async {
    final response = await _client
        .get(
          _uri('/api/v1/books'),
          headers: const {'accept': 'application/json'},
        )
        .timeout(ApiConfig.requestTimeout);
    final payload = _decode(response);
    if (payload is! List) {
      throw BooksApiException('Unexpected books list from server.');
    }
    return payload
        .whereType<Map>()
        .map((item) => _bookFromSummary(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BookAccess> getAccess(String bookId, {String? filename}) async {
    final response = await _client
        .post(
          _uri('/api/v1/books/${Uri.encodeComponent(bookId)}/access'),
          headers: const {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            if (filename != null && filename.isNotEmpty) 'filename': filename,
            'expires_in': ApiConfig.bookUrlExpiresIn,
          }),
        )
        .timeout(ApiConfig.requestTimeout);
    final payload = _decode(response);
    if (payload is! Map) {
      throw BooksApiException('Unexpected access response from server.');
    }
    return BookAccess.fromJson(Map<String, dynamic>.from(payload));
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BooksApiException(
        'Could not reach the book library (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static StudyBook bookFromSummary(Map<String, dynamic> json) => _bookFromSummary(json);

  static StudyBook _bookFromSummary(Map<String, dynamic> json) {
    final id = json['book_id'] as String? ?? '';
    final key = json['key'] as String?;
    final filename = key?.split('/').last;
    return StudyBook(
      id: id,
      title: prettyBookTitle(id),
      author: 'MedQBank library',
      subject: subjectFromTitle(id),
      yearLabel: 'Online',
      blurb: 'Read in the app. Highlights, bookmarks, and notes stay on this device.',
      kind: BookKind.pdf,
      fileName: filename == null || filename.isEmpty ? '$id.pdf' : filename,
      isRemote: true,
      sizeBytes: json['size'] as int?,
    );
  }
}

String prettyBookTitle(String bookId) {
  var title = bookId.replaceAll(RegExp(r'[-_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  title = title.replaceAll(RegExp(r'\bLoves\b'), "Love's");
  final duplicateEdition = RegExp(
    r'^(\d+(?:st|nd|rd|th))\s+(.+)\s+\1$',
    caseSensitive: false,
  );
  final match = duplicateEdition.firstMatch(title);
  if (match != null) {
    return '${match.group(2)}, ${match.group(1)}';
  }
  return title;
}

String subjectFromTitle(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('surg')) return 'Surgery';
  if (lower.contains('anat')) return 'Anatomy';
  if (lower.contains('physio')) return 'Physiology';
  if (lower.contains('pharma')) return 'Pharmacology';
  if (lower.contains('path')) return 'Pathology';
  return 'Textbook';
}

String formatBookSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
