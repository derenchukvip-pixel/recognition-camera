"""Turning a vision model's prose into fields worth showing.

This is most of what the backend does. The model is asked for five fields in a
fixed format and returns something close to that most of the time; the rest of
the time it returns a placeholder it was told not to use, an apology, a generic
category word where a brand belongs, or the product name echoed back as the
manufacturer. Showing any of those to a user is worse than showing nothing,
because they arrive in the same slot as a real answer and look like one.

It lives in its own module with its own tests because it used to be a stack of
nested functions inside the request handler, where none of it could be
exercised without an API key and a network round trip. Every rule here is now
a two-line test.

    python3 -m unittest discover -s server
"""

from __future__ import annotations

import re
from typing import List, Optional

#: The literal the pipeline uses for "no answer". One spelling everywhere, so
#: the app, the harness and the cache all recognise an abstention as such.
NOT_IDENTIFIED = "Not identified"

#: Words that mean "nothing here", however the model chose to phrase it.
_PLACEHOLDER_EXACT = {
    "",
    "-",
    "—",
    "n/a",
    "na",
    "none",
    "not applicable",
    "not available",
    "not identified",
    "unknown",
}

#: Generic category words the model returns in place of a brand. **These are
#: data, not prose**: they are the exact strings the model emits, in the
#: language it emits them in, and translating them would stop the filter
#: matching what actually arrives.
_GENERIC_CATEGORY_WORDS = {
    "насадка",
    "комплект",
    "аксессуар",
    "аксессуары",
    "product",
    "the product",
    "food",
    "drink",
    "beverage",
}

_ARTICLES = {"a", "an", "the", "this", "that", "these", "those", "for"}

_REFUSAL_PATTERNS = (
    re.compile(r"\b(i\s*'?m|i am)\s+(sorry|unable)\b", re.I),
    re.compile(r"\bcan\s*'?t\b|\bcannot\b|\bunable to\b", re.I),
    re.compile(r"\bplease provide\b", re.I),
    re.compile(r"\bas an ai\b", re.I),
)

#: Field labels, in the order the response template lists them. Matching is
#: done against these rather than against positions, because the model
#: occasionally reorders the block.
_FIELD_PATTERNS = {
    "origin": re.compile(
        r"^Estimated production origin(?:\s+of\s+.+?)?\s*:\s*(.+)$", re.I
    ),
    "brand": re.compile(r"^Brand\s*:\s*(.+)$", re.I),
    "brand_owner": re.compile(r"^Brand owner\s*:\s*(.+)$", re.I),
    "hq": re.compile(r"^Country of the HQ\s*:\s*(.+)$", re.I),
    "tax": re.compile(
        r"^Country where the company pays taxes and receives profit\s*:\s*(.+)$",
        re.I,
    ),
}

#: A line that is a field label is never the product name, however the model
#: laid the block out.
_LABEL_PREFIXES = (
    "production origin",
    "estimated production origin",
    "origin and headquarters",
    "brand",
    "brand owner",
    "company",
    "company name",
    "manufacturer",
    "country of the hq",
    "country where the company pays",
    "product name",
)


def clean_line(value: Optional[str]) -> str:
    """Strip the markdown the model adds no matter how firmly it is asked not
    to: leading bullets and hashes, and the asterisks around bold text."""
    if not value:
        return ""
    stripped = value.strip()
    stripped = re.sub(r"^[\s#*\-•]+", "", stripped)
    return stripped.strip("*`_ ").strip()


def is_placeholder(value: Optional[str]) -> bool:
    """True when the value carries no information.

    Square brackets are included because the response template uses them for
    the slots the model is meant to fill; a reply containing them means the
    template came back instead of an answer.
    """
    text = clean_line(value)
    if text.lower() in _PLACEHOLDER_EXACT:
        return True
    if "[" in text or "]" in text:
        return True
    return any(pattern.search(text) for pattern in _REFUSAL_PATTERNS)


def is_label_line(value: Optional[str]) -> bool:
    text = clean_line(value).lower()
    return any(text.startswith(prefix) for prefix in _LABEL_PREFIXES)


def sanitise_product(value: Optional[str]) -> Optional[str]:
    text = clean_line(value)
    if is_placeholder(text) or is_label_line(text):
        return None
    if text.lower() in _ARTICLES | {"product", "unknown product"}:
        return None
    return text or None


def sanitise_brand(
    value: Optional[str], product_name: Optional[str] = None
) -> Optional[str]:
    """Reject the three ways a brand answer goes wrong.

    A generic category word, an article, or the product name handed back as
    the manufacturer. The last is the common one, and the check is asymmetric
    on purpose: "Nutella" as the brand of "Nutella Hazelnut Spread" is
    correct — the product is named after the brand — while "Nutella Hazelnut
    Spread" as the brand of "Nutella Hazelnut Spread" is the model repeating
    itself. So a brand that the product name *starts with* is kept, and one
    that merely equals or contains it is not.
    """
    text = clean_line(value)
    if is_placeholder(text) or is_label_line(text):
        return None

    lowered = text.lower()
    if lowered in _GENERIC_CATEGORY_WORDS or lowered in _ARTICLES:
        return None

    if product_name:
        product = clean_line(product_name).lower()
        if product.startswith(f"{lowered} "):
            return text
        if lowered == product or lowered in product or product in lowered:
            return None

    return text or None


def sanitise_country(value: Optional[str]) -> Optional[str]:
    """Countries as words, with any percentage removed.

    The backend no longer asks for percentages, but two sources still supply
    them: replies cached under the previous prompt, and a model that has seen
    enough of the internet to volunteer them anyway. A number here is the
    exact failure the app was rebuilt to remove — the same box returning
    "Czech Republic 70%, Hungary 30%" on one scan and different figures on the
    next — so it is stripped at the boundary rather than trusted not to occur.
    """
    text = clean_line(value)
    if is_placeholder(text):
        return None

    text = re.sub(r"\s*x?\s*\d+(?:[.,]\d+)?\s*%", "", text)
    text = re.sub(r"\s*,\s*,+", ",", text)
    text = re.sub(r"^[\s,;]+|[\s,;]+$", "", text)
    text = re.sub(r"\s{2,}", " ", text).strip()

    # Normalised so the app and the harness see one spelling of one country.
    text = re.sub(r"\b(USA|U\.S\.A\.|US|U\.S\.)\b", "United States", text)
    return text or None


def extract_fields(reply: str) -> dict:
    """Parse the model's block into the five fields, plus the product name.

    Values that fail their filter come back as None rather than as the
    model's text, and the caller renders None as [NOT_IDENTIFIED]. Nothing
    here invents a fallback: a field with no trustworthy answer says so.
    """
    lines: List[str] = [clean_line(line) for line in reply.splitlines()]
    lines = [line for line in lines if line]

    found = {key: None for key in _FIELD_PATTERNS}
    for line in lines:
        for key, pattern in _FIELD_PATTERNS.items():
            match = pattern.match(line)
            if match and found[key] is None:
                found[key] = match.group(1).strip()

    product = None
    for line in lines:
        candidate = sanitise_product(line)
        if candidate:
            product = candidate
            break

    brand = sanitise_brand(found["brand"], product)
    return {
        "product": product,
        "brand": brand,
        "brand_owner": sanitise_brand(found["brand_owner"], product),
        "origin": sanitise_country(found["origin"]),
        "hq": sanitise_country(found["hq"]),
        "tax": sanitise_country(found["tax"]),
    }


def render_reply(fields: dict) -> str:
    """Assemble the response the app parses.

    The field labels are fixed by the app's parser, so they are the one part
    of this file that cannot change without changing the client too.
    """

    def value(key: str) -> str:
        return fields.get(key) or NOT_IDENTIFIED

    product = value("product")
    return (
        f"{product}\n\n"
        "Production origin and headquarters:\n"
        f"- Estimated production origin of {product}: {value('origin')}\n"
        f"- Brand: {value('brand')}\n"
        f"- Brand owner: {value('brand_owner')}\n"
        f"- Country of the HQ: {value('hq')}\n"
        "- Country where the company pays taxes and receives profit: "
        f"{value('tax')}"
    )


def is_unusable_reply(reply: str) -> bool:
    """Whether a reply is too empty to be worth caching or returning.

    Used as the cache gate. A reply that identified nothing is cheap to
    recompute and might succeed on a second attempt with a different frame,
    so storing it under the image hash would freeze one bad look at the
    product for the life of the entry.
    """
    if not reply or not reply.strip():
        return True
    fields = extract_fields(reply)
    return fields["product"] is None
