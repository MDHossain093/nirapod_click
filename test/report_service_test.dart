import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/services/report_service.dart';

void main() {
  group('ReportService.normalize', () {
    test('leaves an already-canonical BD mobile untouched', () {
      expect(ReportService.normalize('01712345678'), '01712345678');
    });

    test('strips spaces', () {
      expect(
        ReportService.normalize('017 1234 5678'),
        '01712345678',
      );
    });

    test('strips dashes', () {
      expect(
        ReportService.normalize('017-1234-5678'),
        '01712345678',
      );
    });

    test('strips parens', () {
      expect(
        ReportService.normalize('(0171) 234 5678'),
        '01712345678',
      );
    });

    test('strips a mix of spaces, dashes, and parens', () {
      expect(
        ReportService.normalize(' +880 (171) 234-5678 '),
        '01712345678',
      );
    });

    test('strips +88 country prefix', () {
      expect(
        ReportService.normalize('+8801712345678'),
        '01712345678',
      );
    });

    test('strips 88 country prefix when total length is 13', () {
      expect(
        ReportService.normalize('8801712345678'),
        '01712345678',
      );
    });

    test('does NOT strip 8 that is part of the local number', () {
      // '08' followed by something isn't valid here, but the helper
      // should leave it alone because length isn't 13.
      expect(
        ReportService.normalize('8808'),
        '8808',
      );
    });

    test('returns empty string when given empty input', () {
      expect(ReportService.normalize(''), '');
    });

    test('returns empty string when given whitespace only', () {
      expect(ReportService.normalize('   '), '');
    });

    test('handles a foreign-looking number without crashing', () {
      // No +88 / 88 prefix in the expected position; should pass
      // through unchanged so the engine can later flag it invalid.
      expect(
        ReportService.normalize('+15551234567'),
        '+15551234567',
      );
    });
  });

  group('PhoneReportCounts shape', () {
    test('holds total, byType map, and reportTypes list', () {
      const counts = PhoneReportCounts(
        total: 4,
        byType: {'scam': 3, 'payment': 1, 'otp': 0, 'job': 0,
                'harassment': 0, 'other': 0},
        reportTypes: ['scam', 'payment'],
      );
      expect(counts.total, 4);
      expect(counts.byType['scam'], 3);
      expect(counts.reportTypes, ['scam', 'payment']);
    });
  });
}