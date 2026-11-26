import 'package:flutter_test/flutter_test.dart';
import 'package:lifepilot_finance/features/dashboard/domain/greeting.dart';

void main() {
  group('greetingFor', () {
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 11, 26, hour, minute);

    test('midnight through to noon is morning', () {
      expect(greetingFor(at(0)), 'Good morning');
      expect(greetingFor(at(7, 30)), 'Good morning');
      expect(greetingFor(at(11, 59)), 'Good morning');
    });

    test('noon flips to afternoon', () {
      // The boundary, which is the only part of this worth testing and the
      // part an off-by-one would land on.
      expect(greetingFor(at(12)), 'Good afternoon');
      expect(greetingFor(at(16, 59)), 'Good afternoon');
    });

    test('five flips to evening', () {
      expect(greetingFor(at(17)), 'Good evening');
      expect(greetingFor(at(23, 59)), 'Good evening');
    });
  });
}
