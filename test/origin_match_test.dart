import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/domain/models/product_report.dart';
import 'package:recognition_camera/domain/models/report_from_barcode.dart';
import 'package:recognition_camera/domain/origin_match.dart';
import 'package:recognition_camera/domain/provenance.dart';
import 'package:recognition_camera/presentation/report/product_report_view.dart';

OriginMatch _match(String? value) => matchOrigin(
      value,
      preferred: const ['Denmark', 'Germany'],
      avoided: const ['China'],
    );

void main() {
  group('matching a claim against the lists', () {
    test('a preferred country', () {
      expect(_match('Denmark'), OriginMatch.preferred);
    });

    test('an avoided country', () {
      expect(_match('China'), OriginMatch.avoided);
    });

    test('case and spacing do not decide it', () {
      expect(_match('  denmark '), OriginMatch.preferred);
    });

    test('a claim naming several countries reports both lists', () {
      // Half an answer is the wrong answer here: the user asked to be told
      // about both, and showing only the first hides the one they may care
      // about more.
      expect(_match('Denmark, China'), OriginMatch.mixed);
    });

    test('an unrelated country matches nothing', () {
      expect(_match('Italy'), OriginMatch.none);
    });

    test('a non-answer matches nothing', () {
      expect(_match(null), OriginMatch.none);
      expect(_match('Not identified'), OriginMatch.none);
      expect(_match(''), OriginMatch.none);
    });

    test('matching is exact, not a substring test', () {
      // The bug the obvious implementation ships with: a preference for
      // "China" quietly marking Indochina, or "Oman" marking Romania. A false
      // mark puts a flag next to a country the user never asked about.
      expect(_match('Indochina'), OriginMatch.none);
      expect(
        matchOrigin('Romania', preferred: const [], avoided: const ['Oman']),
        OriginMatch.none,
      );
    });

    test('empty lists match nothing', () {
      expect(
        matchOrigin('Denmark', preferred: const [], avoided: const []),
        OriginMatch.none,
      );
    });
  });

  group('what the screen shows for a match', () {
    Future<void> pump(WidgetTester tester, {bool withMatcher = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductReportView(
            report: reportFromBarcode('5702016616545'),
            originMatcher:
                withMatcher ? (claim) => _match(claim.value) : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a matched country is marked, and the mark explains itself',
        (tester) async {
      // The barcode resolves to Denmark, which is on the preferred list.
      await pump(tester);

      expect(find.text('On your preferred list'), findsOneWidget);
      // The sentence that keeps this from reading as a verification. An
      // earlier build put a green tick here — the same green as VERIFIED.
      expect(
        find.textContaining('Says nothing about whether the country above is'),
        findsOneWidget,
      );
    });

    testWidgets('the legend explains the mark separately from the badges',
        (tester) async {
      await pump(tester);

      expect(
        find.descendant(
          of: find.byKey(provenanceLegendKey),
          matching: find.textContaining('match against your settings'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('without a matcher nothing about preferences appears',
        (tester) async {
      // This is the shared-image case: the recipient must not receive the
      // sender's settings.
      await pump(tester, withMatcher: false);

      expect(find.text('On your preferred list'), findsNothing);
      expect(find.textContaining('match against your settings'), findsNothing);
    });

    testWidgets('an unknown claim is never marked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductReportView(
            report: ProductReport(
              barcode: '5702016616545',
              productName: const ProvenanceClaim.unknown(),
              brand: const ProvenanceClaim.unknown(),
              registeredIn: const ProvenanceClaim.unknown(),
              manufacturedIn: const ProvenanceClaim.unknown(),
              headquarters: const ProvenanceClaim.unknown(),
            ),
            originMatcher: (claim) => _match(claim.value),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('On your preferred list'), findsNothing);
      expect(find.text('On your avoid list'), findsNothing);
    });
  });
}
