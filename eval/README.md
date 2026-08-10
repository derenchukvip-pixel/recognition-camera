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

Two runs over the same fifty products, either side of a prompt change.

| Product name | **Before** `gpt-4o` | **After** `gpt-5.6-terra` |
|---|---|---|
| Correct | 29 (58%) | 29 (58%) |
| **Wrong, stated as an answer** | 8 (16%) | **6 (12%)** |
| Partly right — not scored either way | 10 (20%) | 11 (22%) |
| Abstained — "Not identified" | 3 (6%) | 4 (8%) |

| Brand | Before | After |
|---|---|---|
| Correct | *withheld* | 37 (74%) |
| Wrong, stated as an answer | *withheld* | 6 (12%) |
| Abstained | *withheld* | 7 (14%) |

* **Before** — [`runs/2026-08-09T15-37-43Z.json`](runs/2026-08-09T15-37-43Z.json),
  `gpt-4o`, the prompt that required percentages and said "never leave any
  section empty". 3 of 50 from cache, 0 failures, median round trip 1.9 s.
* **After** — [`runs/2026-08-10T10-02-08Z.json`](runs/2026-08-10T10-02-08Z.json),
  `gpt-5.6-terra`, the prompt that permits "Not identified" and asks for the
  on-pack brand. 2 of 50 from cache, 0 failures.

Two variables moved at once — prompt and model — so the change cannot be
attributed to either alone. `OPENAI_MODEL` exists so that can be separated
when it matters; it has not been.

Correct identifications did not move. Confident errors fell by a quarter, and
the run records show what replaced them: on barcode `5449000061515` the old
prompt answered "Al Ain Water" — a real brand, wrong product — and the new
one answers "Bottled water". Still scored wrong, and a different kind of
wrong: it stopped inventing a name it could not read. That is the trade the
prompt change was making, and it shows up in the rows rather than in the
totals.

The brand figure is reported for the first time here. It was withheld from
the earlier run, and the reason is the more useful part of this document —
see [The metric that had to be thrown
away](#the-metric-that-had-to-be-thrown-away).

### What the number means for the app

Twelve percent of these products get a confident, wrong name. Not one of them
reaches a user as a fact. Everything the photo path produces is rendered
`ESTIMATED`, because a photo cannot yield a reproducible claim — asserted by
`report_from_recognition.dart` and enforced by a test that fails if any claim
on that path is ever marked `VERIFIED`.

That is what the provenance model buys, stated as a number rather than as a
design principle: the system is wrong about roughly one product in eight, and
it never once presents those answers as established.

The abstention rate is the other half of it. It was 6% under a prompt that
instructed the model to "never leave any section empty" and to "use the most
likely estimate" — the system was told to guess, and it obeyed. Removing that
instruction moved abstention to 8% and confident errors from 16% to 12%.
Small numbers, and the direction is the point: the errors that disappeared
did not become correct answers, they became silence.

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
on it.

The fix was to change the question rather than the scoring. The backend now
asks for the brand as printed on the pack and reports the owning company on a
separate line, which is also the right answer for the result screen's "by …"
line. Measured that way, brand identification is **74% correct, 12% wrong,
14% abstained**.

That 12% is still an upper bound, because the reference field is not
consistent about which of the two it holds. Barcode `7622210449283` has a
reference brand of `Mondelez` and the backend answered `LU`, which is the
brand on the packet — the same disagreement as before, with the sides
reversed. Four of the six brand errors are of that kind or are reference
labels that are simply wrong (`6111246721278` has a brand field of
`Original`). Two are genuine misreads: `Ciel` read as `Sial`, `Cappy` as
`Kabi`.

The product-name metric was never affected: both sides of that comparison
have always been answering the same question.

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
* **It does not do near-misses either.** "Ain Saïss" against "Sais bottled
  water" (`6111128000071`) and "sidi ali" against "Sidiali" (`6111035000058`)
  are both scored wrong: one letter and one space. Fuzzy matching would fix
  these two and start inventing matches elsewhere, which is the worse trade
  for a number whose job is to be trusted.
* **The ambiguous bucket leans conservative.** Most of the ten entries in it
  are the backend returning the brand plus a fuller product name where the
  reference holds a terse one. A human reviewer would call many of them
  correct. They are not counted as correct here.

Three of the six confident name errors in the latest run are artefacts of the
limits above rather than failures to identify the product. The figure is
therefore, if anything, pessimistic — which is the direction an unaudited
accuracy figure almost never errs in, and the reason every row is committed
alongside the summary.

One thing the percentage strip deliberately leaves alone: four products in
this set have a percentage in their actual name — "Lindt Excellence 85%
Cacao", "Carré Frais 0%", "Menguy's Peanut 100%". The strip applies to the
origin value, never to the product name, and a Flutter test pins that
distinction. A blunter rule would have renamed them.

## Attribution

Product data and photographs from [Open Food Facts](https://world.openfoodfacts.org).
Data under the [Open Database License](https://opendatacommons.org/licenses/odbl/1-0/);
photographs under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
