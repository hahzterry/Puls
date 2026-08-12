import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/utils/formatters.dart';

void main() {
  group('formatCents', () {
    test('formats probability/price values to cents', () {
      expect(formatCents(0.0), '0¢');
      expect(formatCents(0.5), '50¢');
      expect(formatCents(0.99), '99¢');
      expect(formatCents(1.0), '100¢');
    });

    test('rounds fractional cents correctly (e.g. 0.615)', () {
      expect(formatCents(0.615), '62¢');
    });
  });

  group('withThousands edge cases', () {
    test('formats single digit, hundreds, and multi-thousands correctly', () {
      expect(withThousands(5), '5');
      expect(withThousands(100), '100');
      expect(withThousands(10000), '10,000');
      expect(withThousands(100000), '100,000');
    });
  });

  group('compactUsd edge cases', () {
    test('formats boundary values like exactly 1000 and 1000000', () {
      expect(compactUsd(1000), '\$1K');
      expect(compactUsd(1000000), '\$1.0M');
    });

    test('handles negative values with and without dashForZero', () {
      expect(compactUsd(-500), '\$-500');
      expect(compactUsd(-500, dashForZero: true), '—');
    });

    test('formats large millions correctly', () {
      expect(compactUsd(50000000), '\$50.0M');
      expect(compactUsd(123456789), '\$123.5M');
    });
  });

  group('timeAgo exact boundaries', () {
    test('renders correct labels at exact minute, hour, and day boundaries', () {
      final now = DateTime.now();
      expect(timeAgo(now.subtract(const Duration(minutes: 1))), '1m ago');
      expect(timeAgo(now.subtract(const Duration(hours: 1))), '1h ago');
      expect(timeAgo(now.subtract(const Duration(hours: 24))), '1d ago');
    });
  });

  group('timeAgoShort custom justNow', () {
    test('honours a custom justNow label', () {
      final now = DateTime.now();
      expect(
        timeAgoShort(now, justNow: 'just now'),
        'just now',
      );
    });
  });

  group('trimTrailingZeros extended cases', () {
    test('handles string with no decimal point', () {
      expect(trimTrailingZeros('123'), '123');
    });

    test('removes all trailing zeros after decimal point', () {
      expect(trimTrailingZeros('5.000'), '5');
    });

    test('removes single trailing zero after decimal point', () {
      expect(trimTrailingZeros('1.20'), '1.2');
    });
  });

  group('formatShortDateTime extended cases', () {
    test('formats different valid dates', () {
      expect(formatShortDateTime('2024-05-15T14:30:00'), '15/5 14:30');
      expect(formatShortDateTime('2025-12-31T23:59:00'), '31/12 23:59');
    });

    test('formats edge midnight time correctly', () {
      expect(formatShortDateTime('2024-01-01T00:00:00'), '1/1 0:00');
    });
  });
}
