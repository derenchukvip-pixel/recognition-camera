import 'package:flutter_test/flutter_test.dart';

import 'package:recognition_camera/domain/models/recognition_result.dart';

void main() {
  test('parses product and country details from narrative response', () {
    const response = """
I'm unable to determine the exact product name from the image, but it appears to be an LG remote control. Here’s my best estimate:

LG Remote Control
Production origin and headquarters:
- Estimated production origin of LG Remote Control: South Korea 50%, China 40%
- Country of the HQ: South Korea
- Country where the company pays taxes and receives profit: South Korea
""";

    final result = RecognitionResult.fromResponse(response);

  expect(result.productName, 'LG Remote Control');
    expect(result.productionOrigin, 'South Korea 50%, China 40%');
    expect(result.hqCountry, 'South Korea');
    expect(result.taxCountry, 'South Korea');
  });

  test('extracts product from production origin line', () {
    const response = """
Production origin and headquarters:
- Estimated production origin of LG products: South Korea 60%, China 30%
- Country of the HQ: Italy
- Country where the company pays taxes and receives profit: Italy
""";

    final result = RecognitionResult.fromResponse(response);

    expect(result.productName, 'LG products');
    expect(result.companyName, 'LG');
  });


  test('returns nulls when response is a full refusal', () {
    const response = "I'm sorry, I can't determine the product name or the countries from this image.";

    final result = RecognitionResult.fromResponse(response);

    expect(result.productName, isNull);
    expect(result.productionOrigin, isNull);
    expect(result.hqCountry, isNull);
    expect(result.taxCountry, isNull);
  });

  test('does not extract product name from estimated analysis phrase', () {
    const response =
        "I'm unable to identify or extract text from the image. However, based on the visible logo, I can provide an estimated analysis for an LG product.";

    final result = RecognitionResult.fromResponse(response);

    expect(result.productName, isNull);
  });

  test('parses company from Company line', () {
    const response = """
Oral-B iO Series 4

Production origin and headquarters:
- Estimated production origin of Oral-B iO Series 4: Germany 50%, China 40%
- Company: Oral-B
- Country of the HQ: United States
- Country where the company pays taxes and receives profit: United States
""";

    final result = RecognitionResult.fromResponse(response);

    expect(result.companyName, 'Oral-B');
  });

  test('parses the current backend format, which names the on-pack brand', () {
    const response = """
Nutella Hazelnut Spread

Production origin and headquarters:
- Estimated production origin of Nutella Hazelnut Spread: Italy, France
- Brand: Nutella
- Brand owner: Ferrero
- Country of the HQ: Luxembourg
- Country where the company pays taxes and receives profit: Luxembourg
""";

    final result = RecognitionResult.fromResponse(response);

    expect(result.productName, 'Nutella Hazelnut Spread');
    // The brand as printed on the pack, which is what the result screen
    // shows under "by ...". The backend reports the owning company on its own
    // line; conflating the two is what invalidated the first brand metric in
    // eval/.
    expect(result.companyName, 'Nutella');
    expect(result.productionOrigin, 'Italy, France');
    expect(result.hqCountry, 'Luxembourg');
  });

  test('a field label is never mistaken for the product name', () {
    // Happens when the model omits the name line. Before the guard the first
    // label became the product, and the screen showed a product called
    // "Brand: LU" with a straight face.
    const response = """
Production origin and headquarters:
- Brand: LU
- Brand owner: Mondelez
- Country of the HQ: United States
""";

    final result = RecognitionResult.fromResponse(response);

    expect(result.productName, isNull);
    expect(result.companyName, isNull);
  });
}
