# Measuring the recognition backend

Everyone building on a vision model writes "AI-powered". Almost nobody writes
down how often theirs is wrong. This directory is that number, the code that
produced it, and the audit that found the first version of it was measuring
the wrong thing.

```bash
python3 eval/run_eval.py                 # full run, ~6 minutes, standard library only
python3 -m unittest discover -s eval     # the matcher's own tests
```

## Results

**Run `2026-08-09T15-37-43Z`** · 50 products · `gpt-4o` via the Railway
deployment · dataset built 2026-08-09 · 3 of 50 replies served from the
backend's cache · 0 request failures · median round trip 1.9 s.

| Outcome | Product name |
|---|---|
| Correct | 29 (58%) |
| **Wrong, stated as an answer** | 8 (16%) |
| Partly right — not scored either way | 10 (20%) |
| Abstained — "Not identified" | 3 (6%) |

Per-item results, including every raw reply, are in
[`runs/2026-08-09T15-37-43Z.json`](runs/2026-08-09T15-37-43Z.json). Every
figure above can be checked against the row that produced it.

The brand figure from this run is **withheld deliberately**. It is not a
measurement — see [The metric that had to be thrown
away](#the-metric-that-had-to-be-thrown-away).

### What the number means for the app

Sixteen percent of these products got a confident, wrong name. Not one of
them would have appeared in the app as a fact. Everything the photo path
produces is rendered `ESTIMATED`, because a photo cannot yield a reproducible
claim — asserted by `report_from_recognition.dart` and enforced by a test that
fails if any claim on that path is ever marked `VERIFIED`.

That is what the provenance model buys, stated as a number rather than as a
design principle: the system is wrong about one product in six, and it never
once presents those answers as established.

The 6% abstention rate is low, and it is low **on purpose** in the version
measured here. The backend prompt instructs the model to "never leave any
section empty" and to "use the most likely estimate" — it is told to guess.
That is the first thing the server change addresses.

## How it works

```
dataset.json ──> run_eval.py ──> POST /analyze/ ──> scoring.py ──> runs/<id>.json
  50 barcodes      fetches         the same          four            every row,
  + reference      the photo       endpoint the      outcomes,       every reply
  labels           by URL          app calls         not two
```

The measurement is **end to end**, not a model benchmark. A change to the
backend's prompt or to its answer-filtering moves it, which is the point:
those are the parts of the pipeline this project actually wrote.

### Four outcomes, not two

A matcher forced to call every answer right or wrong pushes each genuinely
marginal case into whichever bucket its author preferred. `scoring.py` reports
marginal cases as marginal:

| Outcome | Rule |
|---|---|
| **Correct** | One side's significant tokens are contained in the other's. "Coca-Cola Original" against a reference of "Coca-Cola" is a hit. |
| **Wrong** | No token in common. |
| **Ambiguous** | Some overlap, neither contained. Reported, never counted as either. |
| **Abstained** | The reply was "Not identified" or empty. |

Comparison folds accents, case and punctuation, drops pack sizes (`500g`,
`1L`), articles and corporate suffixes (`Ltd`, `GmbH`, `The … Company`), and
folds a trailing plural `s`. The rules are in `scoring.py` and have their own
tests, because the matcher is the one component that can move the headline
figure without anything about the system changing.

**Abstention is not counted as an error.** An identifier that is right 60% of
the time and silent the rest is worth more than one that is right 70% and
invents the other 30%: the first can be trusted when it speaks. A scoring rule
that punishes silence and confident invention equally cannot express that,
and this project exists because of that distinction.

### Reproducibility

* `dataset.json` is committed and fixed. `build_dataset.py` produced it once
  and is not run again; the eval never touches the Open Food Facts search
  API, which is rate-limited and returns different results under load.
* Photographs are fetched by URL and cached in `eval/images/` (not committed —
  they are CC-BY-SA and belong to their photographers). Every run records the
  SHA-256 of each image it actually sent, so a run against a re-uploaded photo
  is visibly a different run.
* The backend caches by image bytes and by perceptual hash. Every row records
  whether it was a cache hit, and the report refuses to present a mostly
  cached run as a measurement.
* `run_eval.py --rescore runs/<id>.json` re-judges a completed run with the
  current matcher and makes no requests. A revised matcher gets applied to
  every past run or to none — which also removes any reason to re-run the
  model until a number comes out nicer.

## The metric that had to be thrown away

The first version of this harness measured brand accuracy too, and reported
30% of brands as confident errors. Reading the rows before publishing the
figure showed it was nearly worthless:

| Reference brand | Backend answered | Actually |
|---|---|---|
| Nutella | Ferrero | Ferrero owns Nutella |
| alpro | Danone | Danone owns Alpro |
| Bonne Maman | Andros | Andros owns Bonne Maman |
| wasa | Barilla Group | Barilla owns Wasa |
| Elle & Vire | Savencia Fromage & Dairy | Savencia owns Elle & Vire |
| Gerblé | Nutrition & Santé | Nutrition & Santé owns Gerblé |

Thirteen of the fifteen "errors" were the model answering correctly. The
backend prompt asks for "the company name (brand owner)"; the Open Food Facts
`brands` field holds the brand printed on the packaging. Two different
questions, compared as if they were one.

Nothing was wrong with the model or with the reference data. The metric was
wrong, and publishing it would have been a fabricated number arrived at by
carelessness rather than by intent — which reads the same to whoever relies
on it. So the brand figure is withheld until the backend is asked for the
brand *as printed on the pack*, which is also the answer the result screen
should be showing under "by …". That change is pending redeployment; the
figure returns with the next run.

The product-name metric is unaffected: both sides of that comparison are
answering the same question.

## What this set is, and is not

Fifty products from Open Food Facts, taken in descending order of how many
distinct people have scanned the barcode, capped at two per brand.

The cap matters. Without it the top of that ranking is five cartons from one
Moroccan dairy and four bottles of water, because the ranking reflects who
uses the Open Food Facts app rather than what is on a shelf anywhere. A set
like that measures one brand's packaging five times and calls it accuracy.

Stated plainly: **mostly European and North African supermarket groceries,
labelled in French about as often as in English.** It is not a sample of
"products in general" and no figure here should be read as one. Electronics,
cosmetics and household goods are absent entirely.

### Known limits, found by reading the rows

The audit turned up cases where the mechanical verdict is disputable. They are
listed rather than corrected, because removing the rows that look wrong after
seeing the results is how a benchmark stops meaning anything:

* **Reference labels are community-entered and some are simply wrong.**
  Barcode `3274080005003` is a bottle of Cristaline water whose reference
  product name is `isabelle`. The backend answered "Cristaline Eau de Source"
  and was scored wrong. Barcode `6111246721278` has a brand field of
  `Original`.
* **The matcher does not translate.** `5411188112709` has a German reference
  name ("Geröstete Mandel Ohne Zucker") and the backend answered in English
  ("Alpro No Sugars Nutty Almond"). Same product, scored wrong.
* **The ambiguous bucket leans conservative.** Most of the ten entries in it
  are the backend returning the brand plus a fuller product name where the
  reference holds a terse one. A human reviewer would call many of them
  correct. They are not counted as correct here.

Two or three of the eight confident errors are artefacts of the two limits
above. The figure is therefore, if anything, pessimistic — which is the
direction an unaudited accuracy figure almost never errs in, and the reason
the rows are committed alongside the summary.

## Attribution

Product data and photographs from [Open Food Facts](https://world.openfoodfacts.org).
Data under the [Open Database License](https://opendatacommons.org/licenses/odbl/1-0/);
photographs under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
