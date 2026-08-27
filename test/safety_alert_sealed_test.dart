import 'package:flutter_test/flutter_test.dart';

import 'package:nirapod_click/models/admin_alert.dart';
import 'package:nirapod_click/models/risk_result.dart';
import 'package:nirapod_click/models/safety_alert.dart';
import 'package:nirapod_click/services/checker_repository.dart';

void main() {
  group('SafetyAlert sealed type', () {
    test('ScanAlert and AdminAlertItem are distinct subtypes', () {
      final result = RiskResult(
        level: RiskLevel.high,
        score: 80,
        confidence: 0.9,
        reasons: const ['pin-request'],
        recommendations: const ['do not share'],
        category: 'message',
        usedAi: false,
        aiWasUnavailable: false,
      );
      final entry = HistoryEntry(
        checkId: 'check-1',
        result: result,
        originalText: 'hello',
      );
      final admin = AdminAlert(
        id: 'bkash-warning',
        titleEn: 'bKash warning',
        titleBn: 'bkash-sh-sh',
        bodyEn: 'never share pin',
        bodyBn: 'pin share korben na',
        severity: AdminAlert.severityWarning,
        active: true,
      );

      final scan = ScanAlert(id: entry.checkId, entry: entry);
      final adminItem = AdminAlertItem(id: admin.id, alert: admin);

      // Exhaustive switch - compile-time check that both branches are handled.
      String describe(SafetyAlert a) => switch (a) {
            ScanAlert() => 'scan:${a.entry.checkId}',
            AdminAlertItem() => 'admin:${a.alert.severity}',
          };

      expect(describe(scan), 'scan:check-1');
      expect(describe(adminItem), 'admin:warning');

      expect(scan.id, 'check-1');
      expect(adminItem.id, 'bkash-warning');
    });

    test('AdminAlert.hasValidSeverity accepts only known severities', () {
      AdminAlert a(String s) => AdminAlert(
            id: 'x',
            titleEn: 't',
            titleBn: 't',
            bodyEn: 'b',
            bodyBn: 'b',
            severity: s,
            active: true,
          );
      expect(a(AdminAlert.severityInfo).hasValidSeverity, isTrue);
      expect(a(AdminAlert.severityWarning).hasValidSeverity, isTrue);
      expect(a(AdminAlert.severityCritical).hasValidSeverity, isTrue);
      expect(a('catastrophic').hasValidSeverity, isFalse);
      expect(a('').hasValidSeverity, isFalse);
    });
  });
}
