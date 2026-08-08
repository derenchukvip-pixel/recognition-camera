/// GS1 prefix → the GS1 member organisation that issued the company's number.
///
/// This is the one piece of country information in the whole app that is a fact
/// rather than a guess: it is encoded in the barcode digits themselves, so the
/// same barcode always resolves to the same answer, offline, with no model and
/// no network call.
///
/// **It is not the country of manufacture.** It identifies where the *brand
/// owner* registered with GS1. A German company registers with GS1 Germany and
/// gets a 400–440 prefix regardless of which factory on which continent
/// actually makes the goods. This is the single most misread number on a
/// package, which is exactly why [Gs1Lookup.lookup] returns a caveat alongside
/// the country instead of the country alone.
///
/// Ranges follow the GS1 General Specifications prefix allocation table.
library;

class Gs1Allocation {
  const Gs1Allocation(this.country, {this.isSpecialUse = false});

  final String country;

  /// Prefixes that encode a scheme rather than a member organisation — ISBN,
  /// ISSN, coupons, and in-store codes. Reporting "this book was registered in
  /// Bookland" would be nonsense, so callers surface these differently.
  final bool isSpecialUse;
}

class Gs1Lookup {
  const Gs1Lookup._();

  /// Inclusive prefix ranges, keyed by the first three digits of the GTIN.
  static const List<(int, int, Gs1Allocation)> _ranges = [
    (0, 19, Gs1Allocation('United States & Canada')),
    (20, 29, Gs1Allocation('In-store / restricted', isSpecialUse: true)),
    (30, 39, Gs1Allocation('United States')),
    (40, 49, Gs1Allocation('In-store / restricted', isSpecialUse: true)),
    (50, 59, Gs1Allocation('Coupons', isSpecialUse: true)),
    (60, 139, Gs1Allocation('United States & Canada')),
    (200, 299, Gs1Allocation('In-store / restricted', isSpecialUse: true)),
    (300, 379, Gs1Allocation('France & Monaco')),
    (380, 380, Gs1Allocation('Bulgaria')),
    (383, 383, Gs1Allocation('Slovenia')),
    (385, 385, Gs1Allocation('Croatia')),
    (387, 387, Gs1Allocation('Bosnia and Herzegovina')),
    (389, 389, Gs1Allocation('Montenegro')),
    (390, 390, Gs1Allocation('Kosovo')),
    (400, 440, Gs1Allocation('Germany')),
    (450, 459, Gs1Allocation('Japan')),
    (460, 469, Gs1Allocation('Russia')),
    (470, 470, Gs1Allocation('Kyrgyzstan')),
    (471, 471, Gs1Allocation('Taiwan')),
    (474, 474, Gs1Allocation('Estonia')),
    (475, 475, Gs1Allocation('Latvia')),
    (476, 476, Gs1Allocation('Azerbaijan')),
    (477, 477, Gs1Allocation('Lithuania')),
    (478, 478, Gs1Allocation('Uzbekistan')),
    (479, 479, Gs1Allocation('Sri Lanka')),
    (480, 480, Gs1Allocation('Philippines')),
    (481, 481, Gs1Allocation('Belarus')),
    (482, 482, Gs1Allocation('Ukraine')),
    (483, 483, Gs1Allocation('Turkmenistan')),
    (484, 484, Gs1Allocation('Moldova')),
    (485, 485, Gs1Allocation('Armenia')),
    (486, 486, Gs1Allocation('Georgia')),
    (487, 487, Gs1Allocation('Kazakhstan')),
    (488, 488, Gs1Allocation('Tajikistan')),
    (489, 489, Gs1Allocation('Hong Kong SAR')),
    (490, 499, Gs1Allocation('Japan')),
    (500, 509, Gs1Allocation('United Kingdom')),
    (520, 521, Gs1Allocation('Greece')),
    (528, 528, Gs1Allocation('Lebanon')),
    (529, 529, Gs1Allocation('Cyprus')),
    (530, 530, Gs1Allocation('Albania')),
    (531, 531, Gs1Allocation('North Macedonia')),
    (535, 535, Gs1Allocation('Malta')),
    (539, 539, Gs1Allocation('Ireland')),
    (540, 549, Gs1Allocation('Belgium & Luxembourg')),
    (560, 560, Gs1Allocation('Portugal')),
    (569, 569, Gs1Allocation('Iceland')),
    (570, 579, Gs1Allocation('Denmark')),
    (590, 590, Gs1Allocation('Poland')),
    (594, 594, Gs1Allocation('Romania')),
    (599, 599, Gs1Allocation('Hungary')),
    (600, 601, Gs1Allocation('South Africa')),
    (603, 603, Gs1Allocation('Ghana')),
    (604, 604, Gs1Allocation('Senegal')),
    (608, 608, Gs1Allocation('Bahrain')),
    (609, 609, Gs1Allocation('Mauritius')),
    (611, 611, Gs1Allocation('Morocco')),
    (613, 613, Gs1Allocation('Algeria')),
    (615, 615, Gs1Allocation('Nigeria')),
    (616, 616, Gs1Allocation('Kenya')),
    (618, 618, Gs1Allocation('Côte d\'Ivoire')),
    (619, 619, Gs1Allocation('Tunisia')),
    (620, 620, Gs1Allocation('Tanzania')),
    (621, 621, Gs1Allocation('Syria')),
    (622, 622, Gs1Allocation('Egypt')),
    (623, 623, Gs1Allocation('Brunei')),
    (624, 624, Gs1Allocation('Libya')),
    (625, 625, Gs1Allocation('Jordan')),
    (626, 626, Gs1Allocation('Iran')),
    (627, 627, Gs1Allocation('Kuwait')),
    (628, 628, Gs1Allocation('Saudi Arabia')),
    (629, 629, Gs1Allocation('United Arab Emirates')),
    (630, 630, Gs1Allocation('Qatar')),
    (640, 649, Gs1Allocation('Finland')),
    (690, 699, Gs1Allocation('China')),
    (700, 709, Gs1Allocation('Norway')),
    (729, 729, Gs1Allocation('Israel')),
    (730, 739, Gs1Allocation('Sweden')),
    (740, 740, Gs1Allocation('Guatemala')),
    (741, 741, Gs1Allocation('El Salvador')),
    (742, 742, Gs1Allocation('Honduras')),
    (743, 743, Gs1Allocation('Nicaragua')),
    (744, 744, Gs1Allocation('Costa Rica')),
    (745, 745, Gs1Allocation('Panama')),
    (746, 746, Gs1Allocation('Dominican Republic')),
    (750, 750, Gs1Allocation('Mexico')),
    (754, 755, Gs1Allocation('Canada')),
    (759, 759, Gs1Allocation('Venezuela')),
    (760, 769, Gs1Allocation('Switzerland & Liechtenstein')),
    (770, 771, Gs1Allocation('Colombia')),
    (773, 773, Gs1Allocation('Uruguay')),
    (775, 775, Gs1Allocation('Peru')),
    (777, 777, Gs1Allocation('Bolivia')),
    (778, 779, Gs1Allocation('Argentina')),
    (780, 780, Gs1Allocation('Chile')),
    (784, 784, Gs1Allocation('Paraguay')),
    (786, 786, Gs1Allocation('Ecuador')),
    (789, 790, Gs1Allocation('Brazil')),
    (800, 839, Gs1Allocation('Italy, San Marino & Vatican City')),
    (840, 849, Gs1Allocation('Spain & Andorra')),
    (850, 850, Gs1Allocation('Cuba')),
    (858, 858, Gs1Allocation('Slovakia')),
    (859, 859, Gs1Allocation('Czech Republic')),
    (860, 860, Gs1Allocation('Serbia')),
    (865, 865, Gs1Allocation('Mongolia')),
    (867, 867, Gs1Allocation('North Korea')),
    (868, 869, Gs1Allocation('Türkiye')),
    (870, 879, Gs1Allocation('Netherlands')),
    (880, 880, Gs1Allocation('South Korea')),
    (883, 883, Gs1Allocation('Myanmar')),
    (884, 884, Gs1Allocation('Cambodia')),
    (885, 885, Gs1Allocation('Thailand')),
    (888, 888, Gs1Allocation('Singapore')),
    (890, 890, Gs1Allocation('India')),
    (893, 893, Gs1Allocation('Vietnam')),
    (896, 896, Gs1Allocation('Pakistan')),
    (899, 899, Gs1Allocation('Indonesia')),
    (900, 919, Gs1Allocation('Austria')),
    (930, 939, Gs1Allocation('Australia')),
    (940, 949, Gs1Allocation('New Zealand')),
    (950, 950, Gs1Allocation('GS1 Global Office', isSpecialUse: true)),
    (951, 951, Gs1Allocation('GS1 Global Office', isSpecialUse: true)),
    (955, 955, Gs1Allocation('Malaysia')),
    (958, 958, Gs1Allocation('Macau SAR')),
    (977, 977, Gs1Allocation('Serial publications (ISSN)', isSpecialUse: true)),
    (978, 979, Gs1Allocation('Books (ISBN)', isSpecialUse: true)),
    (980, 980, Gs1Allocation('Refund receipts', isSpecialUse: true)),
    (981, 984, Gs1Allocation('Coupons', isSpecialUse: true)),
    (990, 999, Gs1Allocation('Coupons', isSpecialUse: true)),
  ];

  /// Resolves a scanned barcode to its GS1 member organisation.
  ///
  /// Accepts EAN-13, UPC-A (12 digits, zero-padded to 13 as GS1 specifies), and
  /// EAN-8. Returns null when the input is not a barcode this table can speak
  /// about — an unallocated range answers null rather than guessing at the
  /// nearest neighbour.
  static Gs1Allocation? lookup(String barcode) {
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;

    // UPC-A is a GTIN-13 with a leading zero; padding makes one table serve both.
    final gtin = digits.length == 12 ? '0$digits' : digits;
    final prefix = int.tryParse(gtin.substring(0, 3));
    if (prefix == null) return null;

    for (final (start, end, allocation) in _ranges) {
      if (prefix >= start && prefix <= end) return allocation;
    }
    return null;
  }

  /// The three digits the answer was read from, for display as attribution.
  static String? prefixOf(String barcode) {
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    final gtin = digits.length == 12 ? '0$digits' : digits;
    return gtin.substring(0, 3);
  }

  /// Validates the GTIN check digit.
  ///
  /// A scanner can misread a digit, and a misread barcode resolves to a
  /// perfectly confident wrong country. Checking this before showing a
  /// "Verified" badge is what keeps the badge meaningful.
  static bool isChecksumValid(String barcode) {
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8 && digits.length != 12 && digits.length != 13) {
      return false;
    }
    final body = digits.substring(0, digits.length - 1);
    final check = int.parse(digits[digits.length - 1]);

    var sum = 0;
    // Weights alternate 3 and 1 from the rightmost body digit leftwards.
    for (var i = 0; i < body.length; i++) {
      final digit = int.parse(body[body.length - 1 - i]);
      sum += digit * (i.isEven ? 3 : 1);
    }
    return (10 - (sum % 10)) % 10 == check;
  }
}
