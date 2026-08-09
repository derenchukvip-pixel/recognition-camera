"""Tests for the answer filtering.

Every case here is something a vision model actually returned at some point,
which is why several of them look like they could not happen.

    python3 -m unittest discover -s server
"""

import unittest

from answers import (
    NOT_IDENTIFIED,
    extract_fields,
    is_placeholder,
    is_unusable_reply,
    render_reply,
    sanitise_brand,
    sanitise_country,
    sanitise_product,
)

GOOD_REPLY = """Nutella Hazelnut Spread

Production origin and headquarters:
- Estimated production origin of Nutella Hazelnut Spread: Italy, France
- Brand: Nutella
- Brand owner: Ferrero
- Country of the HQ: Luxembourg
- Country where the company pays taxes and receives profit: Luxembourg"""


class Placeholders(unittest.TestCase):
    def test_the_obvious_ones(self):
        for value in ("", "  ", "N/A", "unknown", "Not identified", "-"):
            self.assertTrue(is_placeholder(value), value)

    def test_the_template_coming_back_instead_of_an_answer(self):
        self.assertTrue(is_placeholder("[Product Name]"))

    def test_refusals(self):
        for value in (
            "I'm sorry, I can't identify this product.",
            "I am unable to determine the brand.",
            "As an AI, I cannot see images.",
            "Please provide textual information",
        ):
            self.assertTrue(is_placeholder(value), value)

    def test_a_real_answer_is_not_a_placeholder(self):
        self.assertFalse(is_placeholder("Ferrero"))


class ProductNames(unittest.TestCase):
    def test_markdown_is_stripped(self):
        self.assertEqual(sanitise_product("**Nutella**"), "Nutella")
        self.assertEqual(sanitise_product("- Nutella"), "Nutella")

    def test_a_field_label_is_not_a_product(self):
        self.assertIsNone(sanitise_product("Estimated production origin: Italy"))
        self.assertIsNone(sanitise_product("Brand: Nutella"))
        self.assertIsNone(sanitise_product("Country of the HQ: Italy"))

    def test_a_bare_article_is_not_a_product(self):
        self.assertIsNone(sanitise_product("the"))
        self.assertIsNone(sanitise_product("unknown product"))


class Brands(unittest.TestCase):
    def test_a_generic_category_word_is_rejected(self):
        # Russian generics are data, not prose — the model returns these.
        self.assertIsNone(sanitise_brand("насадка"))
        self.assertIsNone(sanitise_brand("комплект"))
        self.assertIsNone(sanitise_brand("beverage"))

    def test_the_product_name_echoed_back_is_rejected(self):
        self.assertIsNone(
            sanitise_brand("Nutella Hazelnut Spread", "Nutella Hazelnut Spread")
        )

    def test_a_brand_the_product_is_named_after_is_kept(self):
        # The asymmetry that matters: the product is named after the brand,
        # which is the normal case, not the model repeating itself.
        self.assertEqual(
            sanitise_brand("Nutella", "Nutella Hazelnut Spread"), "Nutella"
        )

    def test_an_unrelated_brand_is_kept(self):
        self.assertEqual(
            sanitise_brand("Ferrero", "Nutella Hazelnut Spread"), "Ferrero"
        )


class Countries(unittest.TestCase):
    def test_percentages_are_stripped_at_the_boundary(self):
        self.assertEqual(
            sanitise_country("Czech Republic 70%, Hungary 30%"),
            "Czech Republic, Hungary",
        )

    def test_the_other_shape_the_same_box_produced(self):
        self.assertEqual(
            sanitise_country("Denmark x50%, Mexico x25%, China x25%"),
            "Denmark, Mexico, China",
        )

    def test_a_value_that_was_only_numbers_becomes_nothing(self):
        self.assertIsNone(sanitise_country("70%, 30%"))

    def test_country_spelling_is_normalised(self):
        self.assertEqual(sanitise_country("USA"), "United States")

    def test_a_plain_country_survives_untouched(self):
        self.assertEqual(sanitise_country("Italy, France"), "Italy, France")


class Extraction(unittest.TestCase):
    def test_a_well_formed_reply(self):
        fields = extract_fields(GOOD_REPLY)
        self.assertEqual(fields["product"], "Nutella Hazelnut Spread")
        self.assertEqual(fields["brand"], "Nutella")
        self.assertEqual(fields["brand_owner"], "Ferrero")
        self.assertEqual(fields["origin"], "Italy, France")
        self.assertEqual(fields["hq"], "Luxembourg")
        self.assertEqual(fields["tax"], "Luxembourg")

    def test_reordered_fields_are_still_found(self):
        reordered = "\n".join(
            [
                "Nutella",
                "- Country of the HQ: Luxembourg",
                "- Brand: Nutella",
            ]
        )
        fields = extract_fields(reordered)
        self.assertEqual(fields["hq"], "Luxembourg")
        self.assertEqual(fields["product"], "Nutella")

    def test_missing_fields_come_back_as_none_not_as_a_guess(self):
        fields = extract_fields("Nutella")
        self.assertEqual(fields["product"], "Nutella")
        self.assertIsNone(fields["hq"])
        self.assertIsNone(fields["origin"])

    def test_a_refusal_identifies_nothing(self):
        fields = extract_fields("I'm sorry, I can't identify this product.")
        self.assertIsNone(fields["product"])


class Rendering(unittest.TestCase):
    def test_a_full_round_trip_is_stable(self):
        once = render_reply(extract_fields(GOOD_REPLY))
        twice = render_reply(extract_fields(once))
        self.assertEqual(once, twice)

    def test_absent_fields_say_so(self):
        rendered = render_reply(extract_fields("Nutella"))
        self.assertIn(f"Country of the HQ: {NOT_IDENTIFIED}", rendered)

    def test_percentages_cannot_survive_a_round_trip(self):
        legacy = "\n".join(
            [
                "Lego Recycling Truck",
                "- Estimated production origin of Lego Recycling Truck: "
                "Czech Republic 70%, Hungary 30%",
                "- Brand: LEGO",
            ]
        )
        self.assertNotIn("%", render_reply(extract_fields(legacy)))


class CacheGate(unittest.TestCase):
    def test_a_reply_that_identified_nothing_is_not_worth_keeping(self):
        self.assertTrue(is_unusable_reply(""))
        self.assertTrue(is_unusable_reply("I'm sorry, I can't help with that."))

    def test_a_real_reply_is(self):
        self.assertFalse(is_unusable_reply(GOOD_REPLY))


if __name__ == "__main__":
    unittest.main()
