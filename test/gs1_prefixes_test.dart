import 'package:flutter_test/flutter_test.dart';
import 'package:recognition_camera/data/gs1/gs1_prefixes.dart';

void main() {
  group('Gs1Lookup.lookup', () {
    test('resolves a real EAN-13 to its member organisation', () {
      // Faber-Castell, registered with GS1 Germany (400-440).
      expect(Gs1Lookup.lookup('4006381333931')?.country, 'Germany');
    });

    test('resolves a Danish prefix', () {
      // LEGO registers in Denmark (570-579) - the app's running example.
      expect(Gs1Lookup.lookup('5702016616545')?.country, 'Denmark');
    });

    test('resolves single-value and range prefixes alike', () {
      expect(Gs1Lookup.lookup('6901234567892')?.country, 'China'); // 690-699
      expect(Gs1Lookup.lookup('8590000000006')?.country,
          'Czech Republic'); // 859 exactly
      expect(Gs1Lookup.lookup('5990000000004')?.country,
          'Hungary'); // 599 exactly
    });

    test('pads UPC-A to 13 digits so one table serves both formats', () {
      // 12-digit UPC-A becomes 0-prefixed GTIN-13 -> United States & Canada.
      expect(
        Gs1Lookup.lookup('012345678905')?.country,
        'United States & Canada',
      );
    });

    test('flags special-use prefixes instead of naming a country', () {
      expect(Gs1Lookup.lookup('9781861972712')?.isSpecialUse, isTrue); // ISBN
      expect(Gs1Lookup.lookup('2001234567893')?.isSpecialUse, isTrue); // in-store
    });

    test('returns null for unallocated ranges rather than guessing', () {
      // 391 sits between Kosovo (390) and Germany (400) and is unassigned.
      expect(Gs1Lookup.lookup('3910000000000'), isNull);
    });

    test('returns null for input that is not a barcode', () {
      expect(Gs1Lookup.lookup(''), isNull);
      expect(Gs1Lookup.lookup('123'), isNull);
      expect(Gs1Lookup.lookup('not-a-barcode'), isNull);
    });

    test('ignores separators inside the scanned string', () {
      expect(Gs1Lookup.lookup('570-2016-616545')?.country, 'Denmark');
    });
  });

  group('Gs1Lookup.prefixOf', () {
    test('reports the digits the answer was read from', () {
      expect(Gs1Lookup.prefixOf('5702016616545'), '570');
      expect(Gs1Lookup.prefixOf('012345678905'), '001'); // padded UPC-A
    });
  });

  group('Gs1Lookup.isChecksumValid', () {
    test('accepts valid EAN-13 and UPC-A codes', () {
      expect(Gs1Lookup.isChecksumValid('4006381333931'), isTrue);
      expect(Gs1Lookup.isChecksumValid('012345678905'), isTrue);
    });

    test('accepts a valid EAN-8', () {
      expect(Gs1Lookup.isChecksumValid('96385074'), isTrue);
    });

    test('rejects a single mistyped digit', () {
      // One digit off from the valid code above: a misread scan must not earn
      // a "Verified" badge just because the prefix still resolves.
      expect(Gs1Lookup.isChecksumValid('4006381333932'), isFalse);
    });

    test('rejects wrong-length input', () {
      expect(Gs1Lookup.isChecksumValid('12345'), isFalse);
      expect(Gs1Lookup.isChecksumValid('40063813339311'), isFalse);
    });
  });
}
