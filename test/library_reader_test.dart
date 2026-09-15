import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medqbank/core/theme/app_theme.dart';
import 'package:medqbank/data/repositories/library_repository_impl.dart';
import 'package:medqbank/features/library/presentation/pages/book_reader_page.dart';
import 'package:medqbank/features/library/presentation/providers/library_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('in-app histology reader opens bundled chapters', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final library = LibraryProvider(LibraryRepositoryImpl());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: library,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const BookReaderPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Medical Histology'), findsOneWidget);
    expect(find.text('How to use this book'), findsWidgets);
    expect(find.textContaining('Select any line'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Introduction to histology'), findsWidgets);
    expect(find.text('Previous'), findsOneWidget);
  });
}
