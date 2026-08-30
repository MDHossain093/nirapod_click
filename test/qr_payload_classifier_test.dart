/// Unit tests for [QrPayloadClassifier].
///
/// The classifier is pure-Dart so we can exhaustively cover every
/// branch — URL / phone / text routing — without needing the camera
/// or any platform channels. The exhaustive coverage matters
/// because the QR screen calls `classify()` on every successful
/// decode; a wrong route silently drops the user into the wrong
/// checker.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/models/qr_route.dart';
import 'package:nirapod_click/services/qr_payload_classifier.dart';

void main() {
  const classifier = QrPayloadClassifier();

  group('QrPayloadClassifier — URL routing', () {
    test('https URL routes to url checker (verbatim extracted)', () {
      final r = classifier.classify(
        'https://bit.ly/3xBkash-Fake-Login-Verify',
      );
      expect(r.route, QrRoute.url);
      expect(r.extracted, 'https://bit.ly/3xBkash-Fake-Login-Verify');
      expect(r.raw, 'https://bit.ly/3xBkash-Fake-Login-Verify');
    });

    test('http URL routes to url checker', () {
      final r = classifier.classify('http://example.com/path?q=1');
      expect(r.route, QrRoute.url);
      expect(r.extracted, 'http://example.com/path?q=1');
    });

    test('www-prefixed URL gets https:// scheme prepended', () {
      final r = classifier.classify('www.bkash-update.example/login');
      expect(r.route, QrRoute.url);
      expect(r.extracted, 'https://www.bkash-update.example/login');
    });

    test('bare hostname gets https:// prepended', () {
      final r = classifier.classify('example.com');
      expect(r.route, QrRoute.url);
      expect(r.extracted, 'https://example.com');
    });

    test('bare hostname with path gets https:// prepended', () {
      final r = classifier.classify('bit.ly/abc123');
      expect(r.route, QrRoute.url);
      expect(r.extracted, 'https://bit.ly/abc123');
    });

    test('bKash deep-link URI routes to url checker', () {
      final r = classifier.classify(
        'bkash://payment?amount=5000&receiver=01712345678',
      );
      expect(r.route, QrRoute.url);
      expect(r.extracted, 'bkash://payment?amount=5000&receiver=01712345678');
    });

    test('Nagad deep-link URI routes to url checker', () {
      final r = classifier.classify(
        'nagad://sendmoney?number=01912345678&amount=3000',
      );
      expect(r.route, QrRoute.url);
    });

    test('Rocket deep-link URI routes to url checker', () {
      final r = classifier.classify('rocket://transfer?id=01812345678');
      expect(r.route, QrRoute.url);
    });

    test('upay / surecash / mcash / tap schemes also route to URL', () {
      expect(
        classifier.classify('upay://merchant?id=abc').route,
        QrRoute.url,
      );
      expect(
        classifier.classify('surecash://pay?x=1').route,
        QrRoute.url,
      );
      expect(
        classifier.classify('mcash://payment?x=1').route,
        QrRoute.url,
      );
      expect(
        classifier.classify('tap://merchant?id=abc').route,
        QrRoute.url,
      );
    });

    test('scheme detection is case-insensitive', () {
      final r = classifier.classify('HTTPS://Example.Com/Path');
      expect(r.route, QrRoute.url);
      expect(r.extracted, 'HTTPS://Example.Com/Path');
    });

    test('URLs containing dots that look like phones still route to URL', () {
      // Edge case: a URL with a 10-digit number that *almost*
      // matches a phone shape — must still go to URL checker
      // because of the `.` and `/` in the payload.
      final r = classifier.classify('https://example.com/01712345678');
      expect(r.route, QrRoute.url);
    });
  });

  group('QrPayloadClassifier — phone routing', () {
    test('plain 11-digit BD mobile routes to phone checker', () {
      final r = classifier.classify('01712345678');
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('+88-prefixed number is normalized to BD local format', () {
      final r = classifier.classify('+8801712345678');
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('88-prefixed number is normalized to BD local format', () {
      final r = classifier.classify('8801712345678');
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('number with dashes and spaces is normalized', () {
      final r = classifier.classify('+88 01712 - 345 678');
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('TEL: URI routes to phone checker and is normalized', () {
      final r = classifier.classify('tel:+8801712345678');
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('lowercase tel: URI also routes to phone checker', () {
      final r = classifier.classify('tel:01712345678');
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('vCard payload with TEL field routes to phone checker', () {
      final payload = 'BEGIN:VCARD\n'
          'VERSION:3.0\n'
          'FN:John Doe\n'
          'TEL;TYPE=CELL:+8801712345678\n'
          'EMAIL:john@example.com\n'
          'END:VCARD';
      final r = classifier.classify(payload);
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('vCard with TEL parameters (TYPE=WORK) is parsed', () {
      final payload = 'BEGIN:VCARD\n'
          'VERSION:3.0\n'
          'FN:Jane\n'
          'TEL;TYPE=WORK:+8801912345678\n'
          'END:VCARD';
      final r = classifier.classify(payload);
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01912345678');
    });

    test('MECARD payload with TEL field routes to phone checker', () {
      final payload = 'MECARD:N:Doe,John;TEL:+8801712345678;EMAIL:j@e.com;;';
      final r = classifier.classify(payload);
      expect(r.route, QrRoute.phone);
      expect(r.extracted, '01712345678');
    });

    test('vCard without a TEL field falls through to text', () {
      final payload = 'BEGIN:VCARD\n'
          'VERSION:3.0\n'
          'FN:John Doe\n'
          'EMAIL:john@example.com\n'
          'END:VCARD';
      final r = classifier.classify(payload);
      expect(r.route, QrRoute.text);
      expect(r.extracted, payload);
    });

    test('foreign number in TEL: URI falls through to text', () {
      final r = classifier.classify('tel:+14155551234');
      expect(r.route, QrRoute.text);
    });

    test('too-short number falls through to text', () {
      final r = classifier.classify('0171234');
      expect(r.route, QrRoute.text);
    });
  });

  group('QrPayloadClassifier — text routing', () {
    test('plain text routes to message checker', () {
      final r = classifier.classify('Send 5000 to 01712345678 urgent!!!');
      expect(r.route, QrRoute.text);
      expect(r.extracted, 'Send 5000 to 01712345678 urgent!!!');
    });

    test('WiFi credentials route to text', () {
      final r = classifier.classify(
        'WIFI:T:WPA;S:MyNetwork;P:mypassword;;',
      );
      expect(r.route, QrRoute.text);
      expect(r.extracted, 'WIFI:T:WPA;S:MyNetwork;P:mypassword;;');
    });

    test('empty input routes to text with empty extracted', () {
      final r = classifier.classify('');
      expect(r.route, QrRoute.text);
      expect(r.extracted, '');
      expect(r.raw, '');
    });

    test('whitespace-only input routes to text with empty extracted', () {
      final r = classifier.classify('   \n\t  ');
      expect(r.route, QrRoute.text);
      expect(r.extracted, '');
    });

    test('leading and trailing whitespace is trimmed from raw', () {
      final r = classifier.classify('   hello world   ');
      expect(r.route, QrRoute.text);
      expect(r.raw, 'hello world');
      expect(r.extracted, 'hello world');
    });
  });

  group('QrPayloadClassifier — detection order', () {
    test('URL wins over phone when both could match', () {
      // "https://01712345678.bkash.fake" — has 11 consecutive
      // digits but the .bd TLD pattern makes it a URL, and that
      // matches first. Phone regex requires an exact 11-digit
      // string so it won't match the whole thing anyway, but the
      // test documents the order.
      final r = classifier.classify('https://01712345678.example.com');
      expect(r.route, QrRoute.url);
    });

    test('vCard detection fires before URL detection', () {
      // A vCard whose body contains URLs should still be parsed
      // as a contact card first; if no TEL line exists, it falls
      // through to text — NOT to the URL checker.
      final payload = 'BEGIN:VCARD\n'
          'VERSION:3.0\n'
          'FN:Test\n'
          'URL:https://example.com\n'
          'END:VCARD';
      final r = classifier.classify(payload);
      expect(r.route, QrRoute.text);
    });
  });
}