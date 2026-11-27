import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rule 1, enforced rather than remembered.
///
/// `docs/FLUTTER_ARCHITECTURE.md` states the governing constraint — the
/// Flutter app is a presentation client with no financial engine — and
/// offers a review heuristic: *a Dart file that applies `+`, `-` or `/` to
/// a `*Cents` value is a defect unless it is laying out a chart bar.*
///
/// A heuristic only works while someone remembers to apply it. This test
/// applies it on every run, because the failure it guards against is
/// quiet: a widget that sums its own totals keeps working, looks correct,
/// and only diverges from the Python reporting layer months later, over
/// one of the six conventions that layer encodes.
///
/// The exemptions below are deliberate and few. Each names why.
void main() {
  /// Amount arithmetic: a `minorUnits` access next to an operator.
  final arithmetic = RegExp(
    r'minorUnits\s*[-+*/]|[-+*/]\s*\w*\.minorUnits|minorUnits\s*[-+]=',
  );

  /// Folding over amounts, which is summing by another name.
  final folding = RegExp(r'\.(fold|reduce)\s*[(<][^;]*minorUnits');

  /// Files allowed to do it, and the reason.
  const exempt = <String, String>{
    // Stands in for the reporting API. Deleted in Phase 13, sums and all.
    'mock_transaction_repository.dart':
        'plays the server while the data is mocked',
    // The value type itself: formatting an amount means splitting it into
    // whole and fractional parts.
    'money.dart': 'formats amounts, which requires dividing them',
    // Derives reports from recorded transactions. Stands in for the
    // reporting API; replaced in Phase 13 along with its arithmetic.
    'mock_report_repository.dart':
        'plays the reporting API while the data is mocked',
    // Measures budgets against recorded spending. Stands in for the
    // server; replaced in Phase 13 along with its arithmetic.
    'mock_budget_repository.dart':
        'measures budgets while the data is mocked',
    // Charts turn a value into a pixel, which the heuristic exempts.
    'charts.dart': 'lays out chart marks',
  };

  test('no arithmetic on amounts outside the places allowed to do it', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final name = entity.uri.pathSegments.last;
      if (exempt.containsKey(name)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Comments explain the rule often enough to trip a naive scan.
        final code = line.trim();
        if (code.startsWith('//') || code.startsWith('///')) continue;

        if (arithmetic.hasMatch(line) || folding.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}  ${code.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These lines do arithmetic on money, which belongs on the server '
          '(architecture Rule 1). If one of them genuinely must, add it to '
          'the exemption list above with a reason.\n\n'
          '${offenders.join('\n')}',
    );
  });

  test('the exemption list does not rot', () {
    // An exemption naming a file that no longer exists is a licence nobody
    // is using, and the next person will assume it is still needed.
    final names = <String>{
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          entity.uri.pathSegments.last,
    };

    for (final exemption in exempt.keys) {
      expect(
        names,
        contains(exemption),
        reason: '$exemption is exempt but no longer exists',
      );
    }
  });
}
