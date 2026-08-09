"""Deciding whether a model's answer matches the reference one.

This module is the part of the harness that can quietly turn a bad result
into a good one, so it is small, importable, and tested on its own. Every
judgement it makes is written to the run record with the strings that
produced it, so any number in the report can be traced back to the comparison
behind it.

The design commitment worth stating: there are **four** outcomes, not two.
Most accuracy numbers are computed by a matcher that must call every answer
right or wrong, which pushes every genuinely marginal case into whichever
bucket the author preferred. Here a marginal case is reported as marginal.
"Prince Chocolate Biscuits" against a reference of "Prince Gout Chocolat au
ble complet" is neither a hit nor a miss, and rounding it either way is a
thumb on the scale.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Iterable, Optional, Set

CORRECT = "correct"
WRONG = "wrong"
AMBIGUOUS = "ambiguous"
ABSTAINED = "abstained"

#: What the backend emits when it has nothing. Treated as an abstention rather
#: than as a wrong answer — the whole point of the provenance work is that
#: saying nothing is a better outcome than saying something false, and a
#: scoring rule that punishes both equally cannot show that.
ABSTENTION_MARKERS = {
    "not identified",
    "unknown",
    "unknown company",
    "n/a",
    "",
}

#: Dropped before comparing brands. "The Coca-Cola Company" and "Coca-Cola"
#: are the same answer, and a matcher that disagrees is measuring corporate
#: naming conventions.
CORPORATE_SUFFIXES = {
    "ab", "ag", "as", "bv", "co", "company", "corp", "corporation", "gmbh",
    "group", "holding", "holdings", "inc", "incorporated", "international",
    "kg", "limited", "llc", "ltd", "nv", "oy", "plc", "sa", "sas", "spa",
    "srl", "the",
}

#: Dropped before comparing product names: articles, conjunctions, and the
#: pack-size noise that appears on labels but is not what identification
#: means. "500g" matching or not matching says nothing about whether the model
#: recognised the product.
NAME_STOPWORDS = {
    "a", "al", "and", "au", "aux", "avec", "con", "de", "del", "der", "des",
    "die", "du", "el", "en", "et", "for", "in", "la", "le", "les", "mit",
    "of", "the", "und", "with",
}

UNIT_PATTERN = re.compile(
    r"^\d+(?:[.,]\d+)?(?:g|kg|mg|l|ml|cl|dl|oz|lb|cc|pcs|x)?$"
)


def normalise(text: Optional[str]) -> str:
    """Lowercase, strip accents, and reduce punctuation to spaces.

    Accent folding matters more than it looks: the reference labels come from
    a multilingual database and the model answers in whatever it reads off the
    packaging, so "Gout" and "Goût" turn up as the same word written two ways
    on a regular basis.
    """
    if not text:
        return ""
    decomposed = unicodedata.normalize("NFKD", text)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    lowered = stripped.lower()
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", lowered)).strip()


def _stem(token: str) -> str:
    """Fold a trailing plural `s`.

    Added after the first run, when an audit of the rows the matcher called
    wrong turned up "Fibres" against "Fibre Crispbread" — a verdict about
    French pluralisation rather than about whether the product was
    identified. It is applied to every row of every run, before and after,
    because a rule introduced to rescue one item and applied only to that
    item is not a rule.
    """
    return token[:-1] if len(token) > 3 and token.endswith("s") else token


def _tokens(text: Optional[str], stopwords: Set[str]) -> Set[str]:
    out = set()
    for token in normalise(text).split():
        if token in stopwords:
            continue
        if UNIT_PATTERN.match(token):
            continue
        if len(token) < 2:
            continue
        out.add(_stem(token))
    return out


def brand_tokens(text: Optional[str]) -> Set[str]:
    return _tokens(text, CORPORATE_SUFFIXES)


def name_tokens(text: Optional[str]) -> Set[str]:
    return _tokens(text, NAME_STOPWORDS)


def is_abstention(answer: Optional[str]) -> bool:
    return normalise(answer).strip() in {
        normalise(m) for m in ABSTENTION_MARKERS
    }


def _judge(expected: Set[str], actual: Set[str]) -> str:
    """Containment, not equality.

    A model that answers "Coca-Cola Original" where the reference says
    "Coca-Cola" has identified the product; so has one that answers
    "Coca-Cola" where the reference says "Coca-Cola Original Taste". Requiring
    the two sets to be equal would score both as failures and report a number
    about label verbosity.
    """
    if not expected or not actual:
        return AMBIGUOUS
    if expected <= actual or actual <= expected:
        return CORRECT
    if expected & actual:
        return AMBIGUOUS
    return WRONG


def judge_brand(expected: Optional[str], actual: Optional[str]) -> str:
    """The reference field holds a comma-separated list often enough that a
    single-string comparison would fail on products with a parent brand and a
    sub-brand. Any one of them matching is a match."""
    if is_abstention(actual):
        return ABSTAINED
    candidates: Iterable[str] = (expected or "").split(",")
    verdicts = [
        _judge(brand_tokens(candidate), brand_tokens(actual))
        for candidate in candidates
        if brand_tokens(candidate)
    ]
    if not verdicts:
        return AMBIGUOUS
    for preferred in (CORRECT, AMBIGUOUS):
        if preferred in verdicts:
            return preferred
    return WRONG


def judge_name(expected: Optional[str], actual: Optional[str]) -> str:
    if is_abstention(actual):
        return ABSTAINED
    return _judge(name_tokens(expected), name_tokens(actual))
