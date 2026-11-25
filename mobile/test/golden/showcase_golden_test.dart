@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/core/design_system/design_system.dart';
import 'package:lifepilot_finance/showcase/showcase_sections.dart';
import 'package:material_ui/material_ui.dart';

/// Golden renders of the design system.
///
/// ## What these are for
///
/// Two jobs. First, they are the review artefact: `flutter test
/// --update-goldens` writes a PNG of every showcase tab in both themes, so the
/// whole visual language can be looked at without a device. Second, they are a
/// regression gate — change a token and the diff shows exactly which surfaces
/// moved.
///
/// ## Fonts
///
/// `flutter test` renders text with a placeholder font whose every glyph is a
/// filled box, which makes a screenshot useless for review. [_loadFont]
/// registers a real system font under the family name Flutter resolves for an
/// unstyled `fontFamily: null`, so the captures show actual words.
///
/// Goldens are platform-sensitive (font hinting differs between machines), so
/// these are tagged `golden` and are intended for local review rather than as
/// a cross-platform CI gate. Run them with:
///
/// ```
/// flutter test --update-goldens test/golden
/// ```
Future<void> _loadFont() async {
  // Flutter ships both fonts it needs with the SDK, so prefer those: they are
  // the exact faces a real build uses, on any machine.
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  final sdkFonts = Directory('$root/bin/cache/artifacts/material_fonts');

  Future<void> register(String family, File file) async {
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  if (sdkFonts.existsSync()) {
    // 'Roboto' is what an unstyled TextStyle resolves to on the test
    // binding's default platform, so registering here reaches every
    // AppTypography style without touching the tokens.
    final roboto = File('${sdkFonts.path}/roboto-regular.ttf');
    if (roboto.existsSync()) await register('Roboto', roboto);

    // Without this, every Icon renders as a hollow box and the screenshots
    // are useless for reviewing iconography.
    final icons = File('${sdkFonts.path}/materialicons-regular.otf');
    if (icons.existsSync()) await register('MaterialIcons', icons);
    return;
  }

  // Fall back to a system face if the SDK cache is not where we expect.
  const candidates = [
    r'C:\Windows\Fonts\segoeui.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      await register('Roboto', file);
      return;
    }
  }
}

/// Showcase tabs are tall; the surface is sized to fit a whole tab so nothing
/// is cut off and the lazy list builds every row.
const Size _surface = Size(430, 2400);

Future<void> _capture(
  WidgetTester tester, {
  required Widget section,
  required ThemeData theme,
  required String file,
}) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Name the loaded face explicitly so chart painters, which cannot
      // resolve a null family, draw real tick labels instead of boxes.
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: Scaffold(body: section),
    ),
  );

  // Settle animations (progress fills, shimmer) so the capture is stable.
  await tester.pump(const Duration(milliseconds: 400));

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('images/$file.png'),
  );
}

void main() {
  setUpAll(_loadFont);

  final sections = <String, Widget>{
    '01_colour': const ColourSection(),
    '02_type': const TypeSection(),
    '03_components': const ComponentsSection(),
    '04_finance': const FinanceSection(),
    '05_charts': const ChartsSection(),
  };

  group('light theme', () {
    sections.forEach((name, section) {
      testWidgets(name, (tester) async {
        await _capture(
          tester,
          section: section,
          theme: AppTheme.light,
          file: 'light_$name',
        );
      });
    });
  });

  group('dark theme', () {
    // The dark theme is a foundation rather than a shipped mode, but it is
    // captured so it can be reviewed and cannot rot unnoticed.
    sections.forEach((name, section) {
      testWidgets(name, (tester) async {
        await _capture(
          tester,
          section: section,
          theme: AppTheme.dark,
          file: 'dark_$name',
        );
      });
    });
  });

  group('accessibility renders', () {
    testWidgets('finance components at 1.6x text scale', (tester) async {
      // Proof that the layouts reflow rather than clip for a user who has
      // enlarged text — the single most common accessibility setting.
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(body: FinanceSection()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/a11y_large_text_finance.png'),
      );
    });
  });
}
