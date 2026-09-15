import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medqbank/app/app.dart';
import 'package:medqbank/core/constants/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});

  testWidgets('skip onboarding opens login and reaches dashboard', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MedQBankApp());
    await tester.pump();

    expect(find.text(AppStrings.appName), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.onboardingTitle1), findsOneWidget);

    await tester.tap(find.text(AppStrings.skip));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.welcomeBack), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'student@medqbank.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.login));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.text(AppStrings.continueReading), findsOneWidget);
    expect(find.text(AppStrings.dailyMcqs), findsOneWidget);
  });
}
