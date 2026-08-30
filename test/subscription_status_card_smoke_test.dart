/// Smoke test for the redesigned SubscriptionStatusCard.
///
/// The free card reads as "you're on Free → tap Go Premium" with
/// a hero strip, a "What you get" benefits preview, and a CTA. No
/// quota tiles or per-kind counters — those live on Home. The
/// active state still shows the price + renewal tiles + benefits
/// reminder + Manage CTA.
///
/// Run with:
///   flutter test test/subscription_status_card_smoke_test.dart
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/locale/app_locale.dart';
import 'package:nirapod_click/models/subscription.dart';
import 'package:nirapod_click/screens/subscription/subscription_status_card.dart';
import 'package:nirapod_click/services/subscription_service.dart';

void main() {
  testWidgets('Free card renders hero strip + benefits + Go Premium CTA only',
      (tester) async {
    final service = SubscriptionService.instance;
    service.emitForTest(SubscriptionState(
      status: SubscriptionStatus.free,
      limits: const PlanLimits(
        messageScansRemaining: 5,
        screenshotScansRemaining: 5,
      ),
    ));

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.bangla,
        onChanged: (_) {},
        child: SubscriptionScope(
          service: service,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SubscriptionStatusCard(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Hero strip title in BN.
    expect(find.text('নিরাপদক্লিক ফ্রি'), findsOneWidget);
    // Subtitle renders.
    expect(find.text('আপনার দৈনিক নিরাপত্তা যাচাই বাজেট'), findsOneWidget);
    // Go Premium CTA in BN.
    expect(find.textContaining('প্রিমিয়ামে যান'), findsOneWidget);
    // No per-kind counts should leak through — those live on Home now.
    expect(find.text('স্ক্রিনশট স্ক্যান'), findsNothing);
    expect(find.text('বার্তা স্ক্যান'), findsNothing);
    expect(find.text('মোট স্ক্যান বাকি'), findsNothing);
    // ignore: avoid_print
    print('[free BN] hero + benefits + Go Premium CTA only ✓');
  });

  testWidgets(
      'Active card renders the navy hero, renewal tile, and manage CTA',
      (tester) async {
    final service = SubscriptionService.instance;
    service.emitForTest(SubscriptionState(
      status: SubscriptionStatus.active,
      limits: PlanLimits.unlimited(),
      nextRenewalAt: DateTime(2026, 12, 31),
    ));

    await tester.pumpWidget(
      AppLocaleScope(
        locale: AppLocale.english,
        onChanged: (_) {},
        child: SubscriptionScope(
          service: service,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SubscriptionStatusCard(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Premium title in EN.
    expect(find.text('NirapodClick Premium'), findsOneWidget);
    // New navy-hero tagline.
    expect(find.text('All checks unlocked'), findsOneWidget);
    // "Active" status pill.
    expect(find.text('Active'), findsOneWidget);
    // Renewal tile (formatDate is "Mon Day" — Dec 31 → "Dec 31").
    expect(find.textContaining('Dec 31'), findsOneWidget);
    // Plan price receipt row.
    expect(find.text('৳2.78 / day'), findsOneWidget);
    // "Your benefits" section header.
    expect(find.text('Your benefits'), findsOneWidget);
    // Manage CTA.
    expect(find.text('Manage Subscription'), findsOneWidget);
    // ignore: avoid_print
    print(
        '[active EN] navy hero + tagline + renewal + benefits + manage CTA rendered ✓');
  });
}