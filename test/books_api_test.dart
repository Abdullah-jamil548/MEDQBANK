import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medqbank/data/datasources/books_api.dart';
import 'package:medqbank/domain/entities/study_book.dart';

void main() {
  test('maps the R2 book list into library titles', () async {
    final api = BooksApi(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/books');
        return http.Response(
          '[{"book_id":"27th-Bailey-Loves-Short-Practice-of-Surgery-27th","prefix":null,"key":"books/27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf","size":55979744,"layout":"flat"}]',
          200,
        );
      }),
    );

    final books = await api.listBooks();
    expect(books, hasLength(1));
    expect(books.single.id, '27th-Bailey-Loves-Short-Practice-of-Surgery-27th');
    expect(books.single.title, "Bailey Love's Short Practice of Surgery, 27th");
    expect(books.single.fileName, '27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf');
    expect(books.single.isRemote, isTrue);
    expect(books.single.kind, BookKind.pdf);
    expect(books.single.subject, 'Surgery');
    expect(formatBookSize(books.single.sizeBytes), '53.4 MB');
  });

  test('requests a presigned access URL for a book id', () async {
    final api = BooksApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/books/27th-Bailey-Loves-Short-Practice-of-Surgery-27th/access',
        );
        expect(request.body, contains('"expires_in":3600'));
        return http.Response(
          '{"book_id":"27th-Bailey-Loves-Short-Practice-of-Surgery-27th","key":"books/27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf","filename":"27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf","size":55979744,"content_type_hint":"application/pdf","expires_in":3600,"url":"https://example.com/book.pdf"}',
          200,
        );
      }),
    );

    final access = await api.getAccess(
      '27th-Bailey-Loves-Short-Practice-of-Surgery-27th',
      filename: '27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf',
    );
    expect(access.url, 'https://example.com/book.pdf');
    expect(access.filename, '27th-Bailey-Loves-Short-Practice-of-Surgery-27th.pdf');
    expect(access.size, 55979744);
  });
}
