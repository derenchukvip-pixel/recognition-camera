"""Tests for the matcher.

The matcher is the one component that can change the headline number without
changing the system being measured, so it is tested before it is trusted. Run
with `python3 -m unittest discover -s eval` from the repository root.
"""

import unittest

from scoring import (
    ABSTAINED,
    AMBIGUOUS,
    CORRECT,
    WRONG,
    judge_brand,
    judge_name,
    normalise,
)


class Normalisation(unittest.TestCase):
    def test_folds_accents_and_case(self):
        self.assertEqual(normalise("Goût Chocolat"), "gout chocolat")

    def test_punctuation_becomes_separators(self):
        self.assertEqual(normalise("Coca-Cola®"), "coca cola")

    def test_empty_input_is_empty(self):
        self.assertEqual(normalise(None), "")


class BrandMatching(unittest.TestCase):
    def test_exact(self):
        self.assertEqual(judge_brand("LEGO", "LEGO"), CORRECT)

    def test_corporate_suffixes_are_not_a_difference(self):
        self.assertEqual(
            judge_brand("Coca-Cola", "The Coca-Cola Company"), CORRECT
        )

    def test_a_different_brand_is_wrong(self):
        self.assertEqual(judge_brand("Coca-Cola", "PepsiCo"), WRONG)

    def test_any_brand_in_the_reference_list_may_match(self):
        # Reference fields routinely hold a parent and a sub-brand together.
        self.assertEqual(
            judge_brand("Mondelez, Prince, LU", "LU"), CORRECT
        )

    def test_a_partial_overlap_is_reported_as_such(self):
        self.assertEqual(
            judge_brand("Milky Food Professional", "Milky Way"), AMBIGUOUS
        )

    def test_saying_nothing_is_not_the_same_as_being_wrong(self):
        self.assertEqual(judge_brand("Coca-Cola", "Not identified"), ABSTAINED)
        self.assertEqual(judge_brand("Coca-Cola", ""), ABSTAINED)


class NameMatching(unittest.TestCase):
    def test_a_longer_correct_answer_still_counts(self):
        self.assertEqual(
            judge_name("coca-cola", "Coca-Cola Original"), CORRECT
        )

    def test_a_shorter_correct_answer_still_counts(self):
        self.assertEqual(
            judge_name("Coca-Cola Original Taste", "Coca-Cola"), CORRECT
        )

    def test_pack_sizes_are_not_identification(self):
        self.assertEqual(
            judge_name("Sparkling Water 500ml", "Sparkling Water"), CORRECT
        )

    def test_a_different_product_is_wrong(self):
        self.assertEqual(
            judge_name("Fromage Blanc Nature", "Orange Juice"), WRONG
        )

    def test_a_partly_right_answer_is_neither(self):
        self.assertEqual(
            judge_name(
                "Prince Goût Chocolat au blé complet",
                "Prince Chocolate Biscuits",
            ),
            AMBIGUOUS,
        )

    def test_a_plural_is_not_a_different_product(self):
        self.assertEqual(
            judge_name("Fibres", "Wasa Fibre Crispbread"), CORRECT
        )

    def test_stemming_does_not_merge_unrelated_short_words(self):
        # "as" and "a" must not collapse, or the fold starts inventing matches.
        self.assertEqual(judge_name("Gas", "Ga"), WRONG)

    def test_abstention(self):
        self.assertEqual(judge_name("anything", "Not identified"), ABSTAINED)


if __name__ == "__main__":
    unittest.main()
