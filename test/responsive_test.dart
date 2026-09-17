import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medqbank/app/app.dart';
import 'package:medqbank/core/constants/app_strings.dart';
import 'package:medqbank/core/responsive/app_responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});

  testWidgets('AppResponsive maps mobile, tablet, and desktop widths', (tester) async {
    late AppResponsive mobile;
    late AppResponsive tablet;
    late AppResponsive desktop;

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            mobile = context.rs;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(mobile.isMobile, isTrue);
    expect(mobile.contentWidth, mobile.width);

    tester.view.physicalSize = const Size(800, 1024);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            tablet = context.rs;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tablet.isTablet, isTrue);
    expect(tablet.contentWidth, 600);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            desktop = context.rs;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(desktop.isDesktop, isTrue);
    expect(desktop.contentWidth, 720);
  });

  testWidgets('login stays usable on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MedQBankApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.skip));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.welcomeBack), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
