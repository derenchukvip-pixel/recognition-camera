#!/usr/bin/env python3
"""Builds the evaluation dataset manifest from Open Food Facts.

Run once; the output is committed. `run_eval.py` reads the committed manifest
and never touches the search API, because that API is heavily rate-limited and
a benchmark whose contents depend on which day it was assembled is not a
benchmark.

    python3 eval/build_dataset.py --size 50 --out eval/dataset.json

Why this source. It supplies three things at once that are otherwise hard to
get together: product photographs under an open licence (images are CC-BY-SA,
data is ODbL), a reference product name and brand for each one, and a stable
barcode to identify the record by. Photographs taken specially would be a
better test of real scanning conditions but could not be published with them.

## Selection

Products are taken in descending order of `unique_scans_n` — how many distinct
people have scanned the barcode — from the pool that has a selected front
photo, capped at two items per brand.

The cap is the interesting part. Without it the top of that ranking is five
cartons from one Moroccan dairy and four bottles of water, because the
ranking reflects who uses the Open Food Facts app rather than what is on a
shelf anywhere in particular. A set like that measures one brand's packaging
five times and calls the result an accuracy figure.

**What this set is, stated plainly:** mostly European and North African
supermarket groceries, labelled in French as often as in English, skewed
towards products that Open Food Facts contributors scan. It is not a sample of
"products in general", and no number produced from it should be read as one.

## Filters, and what they are not

Records are dropped when the reference labels cannot support a comparison:
an empty name or brand, a name shorter than three characters, or a label in a
non-Latin script (the matcher folds accents but does not transliterate, so
scoring those would measure the matcher rather than the model). None of these
look at difficulty. Nothing is dropped for being a hard photograph, and
nothing is dropped after a result is known — the manifest is fixed before the
first request is made.

What the filters cannot catch is a label that is well-formed and wrong. The
reference data is community-entered and some of it is simply mistaken: a
bottle of Cristaline water carrying the product name "isabelle", a cream
cheese whose brand field reads "Original". Those records stay in, because
removing the ones that look wrong *before* seeing the results and keeping the
ones that look wrong *after* is the same decision made twice with different
information. They put a ceiling on the achievable score, and the per-item run
record shows exactly which rows they are.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Dict, List, Optional

SEARCH_URL = "https://world.openfoodfacts.org/api/v2/search"

# Open Food Facts asks for a descriptive agent and a low request rate on the
# search endpoint. Being a good citizen of the source is not optional when the
# whole dataset is a gift from it.
#
# Kept to a bare name/version deliberately: the conventional
# "name/version (contact-url)" form is rejected by the edge in front of the
# search API with a 503 and an HTML holding page, which is indistinguishable
# from an outage until you try the same request with a shorter agent. Measured,
# not guessed — the identical query succeeds with this string and fails with
# the parenthesised one.
USER_AGENT = "recognition-camera-eval/1.0"
SEARCH_DELAY_SECONDS = 7.0

FIELDS = "code,product_name,brands,image_front_url,unique_scans_n"

LATIN_RATIO_MINIMUM = 0.6


def _looks_latin(text: str) -> bool:
    letters = [c for c in text if c.isalpha()]
    if not letters:
        return False
    latin = sum(1 for c in letters if "a" <= c.lower() <= "z" or ord(c) < 0x250)
    return latin / len(letters) >= LATIN_RATIO_MINIMUM


def _usable(product: Dict) -> bool:
    name = (product.get("product_name") or "").strip()
    brand = (product.get("brands") or "").strip()
    image = (product.get("image_front_url") or "").strip()
    code = (product.get("code") or "").strip()

    if not (name and brand and image and code):
        return False
    if len(name) < 3:
        return False
    if not re.search(r"[A-Za-zÀ-ɏ]", name):
        return False
    return _looks_latin(name) and _looks_latin(brand)


def _fetch_page(page: int, page_size: int, attempts: int = 4) -> List[Dict]:
    query = urllib.parse.urlencode(
        {
            "fields": FIELDS,
            "page_size": page_size,
            "page": page,
            "sort_by": "unique_scans_n",
            "states_tags": "en:front-photo-selected",
        }
    )
    request = urllib.request.Request(
        f"{SEARCH_URL}?{query}", headers={"User-Agent": USER_AGENT}
    )

    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.loads(response.read()).get("products", [])
        except (urllib.error.URLError, json.JSONDecodeError, OSError) as error:
            # The search endpoint returns an HTML holding page under load, so
            # a decode failure here is a rate limit wearing a different hat.
            wait = SEARCH_DELAY_SECONDS * (attempt + 1) * 2
            print(
                f"  page {page}: {type(error).__name__}, retrying in {wait:.0f}s",
                file=sys.stderr,
            )
            time.sleep(wait)
    raise SystemExit(f"Open Food Facts search failed for page {page}")


def _brand_key(brands: str) -> str:
    """The first brand in the field, folded, as the deduplication key.

    Crude on purpose. "Jaouda" and "jaouda" are one brand and must collapse;
    "La Boulangère" and "Gerblé" are two and must not. Anything cleverer would
    need a brand ontology to make a decision that a fold already gets right.
    """
    first = brands.split(",")[0].strip().lower()
    return re.sub(r"[^a-z0-9]+", "", first)


def build(size: int, page_size: int, max_per_brand: int) -> List[Dict]:
    collected: List[Dict] = []
    seen = set()
    brand_counts: Dict[str, int] = {}
    page = 1

    while len(collected) < size and page <= 40:
        print(f"fetching page {page} ({len(collected)}/{size} kept)")
        for product in _fetch_page(page, page_size):
            code = (product.get("code") or "").strip()
            if code in seen or not _usable(product):
                continue

            brand = _brand_key(product["brands"])
            if brand_counts.get(brand, 0) >= max_per_brand:
                continue
            brand_counts[brand] = brand_counts.get(brand, 0) + 1
            seen.add(code)
            collected.append(
                {
                    "barcode": code,
                    "expected_name": product["product_name"].strip(),
                    "expected_brand": product["brands"].strip(),
                    "image_url": product["image_front_url"].strip(),
                    "unique_scans": product.get("unique_scans_n"),
                }
            )
            if len(collected) == size:
                break
        page += 1
        if len(collected) < size:
            time.sleep(SEARCH_DELAY_SECONDS)

    return collected


def main() -> Optional[int]:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=50)
    parser.add_argument("--page-size", type=int, default=50)
    parser.add_argument("--max-per-brand", type=int, default=2)
    parser.add_argument("--out", default="eval/dataset.json")
    args = parser.parse_args()

    items = build(args.size, args.page_size, args.max_per_brand)
    if len(items) < args.size:
        print(
            f"warning: kept {len(items)} of {args.size} requested",
            file=sys.stderr,
        )

    manifest = {
        "source": "Open Food Facts",
        "source_url": "https://world.openfoodfacts.org",
        "data_licence": "Open Database License (ODbL) 1.0",
        "image_licence": "Creative Commons Attribution-ShareAlike 3.0",
        "selection": (
            "Descending unique_scans_n over products with a selected front "
            f"photo, at most {args.max_per_brand} per brand; records with "
            "unusable reference labels dropped. Mostly European and North "
            "African groceries — not a sample of products in general. See "
            "build_dataset.py."
        ),
        "max_per_brand": args.max_per_brand,
        "built_at": time.strftime("%Y-%m-%d", time.gmtime()),
        "count": len(items),
        "items": items,
    }

    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"wrote {len(items)} items to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
