import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nirapod_click/services/ai_service.dart';

/// A fake [http.Client] that returns [body] with status 200 for every POST.
http.Client _fakeOkClient(String body) => MockClient((req) async {
      expect(req.method, 'POST');
      expect(
        req.url.host,
        'generativelanguage.googleapis.com',
        reason: 'HTTPS endpoint must be the public Gemini REST API.',
      );
      return http.Response(body, 200,
          headers: {'content-type': 'application/json'});
    });

/// A fake [http.Client] that returns a non-2xx response.
http.Client _fakeErrorClient(int status, String body) =>
    MockClient((req) async => http.Response(body, status));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Build a valid Gemini envelope around a given JSON payload.
  String envelope(String innerJson) => jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': innerJson},
              ],
            },
          },
        ],
      });

  group('AiService.analyzeMessage', () {
    test('parses a well-formed Gemini envelope into a RiskResult', () async {
      final inner = jsonEncode({
        'risk_score': 95,
        'risk_level': 'CRITICAL',
        'category': 'Credential Theft',
        'reasons': ['requests OTP', 'creates urgency'],
        'recommendations': ["don't send OTP", 'verify officially'],
      });

      final ai = AiService(
        client: _fakeOkClient(envelope(inner)),
        apiKey: 'test-key',
      );
      final result = await ai.analyzeMessage('any message');

      expect(result.level.name, 'critical');
      expect(result.score, 95);
      expect(result.confidence, 0.90);
      expect(result.category, 'Credential Theft');
      expect(result.reasons, ['requests OTP', 'creates urgency']);
      expect(result.recommendations, ["don't send OTP", 'verify officially']);
      expect(result.usedAi, isTrue);
    });

    test('falls back to RiskLevel.safe on unknown level string', () async {
      final inner = jsonEncode({
        'risk_score': 10,
        'risk_level': 'NOT_A_LEVEL',
        'category': 'General',
        'reasons': <String>[],
        'recommendations': <String>[],
      });
      final ai = AiService(
        client: _fakeOkClient(envelope(inner)),
        apiKey: 'test-key',
      );
      final r = await ai.analyzeMessage('hello');
      expect(r.level.name, 'safe');
      expect(r.score, 10);
    });

    test('clamps out-of-range score into [0,100]', () async {
      final inner = jsonEncode({
        'risk_score': 250,
        'risk_level': 'HIGH',
        'category': 'Phishing',
        'reasons': <String>[],
        'recommendations': <String>[],
      });
      final ai = AiService(
        client: _fakeOkClient(envelope(inner)),
        apiKey: 'test-key',
      );
      final r = await ai.analyzeMessage('x');
      expect(r.score, 100);
    });

    test('throws when the API returns non-2xx', () async {
      final ai = AiService(
        client: _fakeErrorClient(403, 'forbidden'),
        apiKey: 'test-key',
      );
      expect(
        () => ai.analyzeMessage('x'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when the envelope has no text part', () async {
      final empty = jsonEncode({'candidates': []});
      final ai = AiService(
        client: _fakeOkClient(empty),
        apiKey: 'test-key',
      );
      expect(
        () => ai.analyzeMessage('x'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws StateError when no API key is provided', () async {
      final ai = AiService(client: _fakeOkClient('{}'), apiKey: '');
      expect(
        () => ai.analyzeMessage('x'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
