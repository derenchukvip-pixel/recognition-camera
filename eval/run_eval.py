#!/usr/bin/env python3
"""Measures how often the recognition backend is right, wrong, or silent.

    python3 eval/run_eval.py                       # full run against the default endpoint
    python3 eval/run_eval.py --limit 5             # smoke test
    python3 eval/run_eval.py --endpoint http://localhost:8000

Standard library only, so there is nothing to install before running it.

## What is being measured

The whole cloud path as the app uses it: an image goes to `POST /analyze/`,
the backend calls a vision model and cleans up the answer, and the reply is
compared to the reference labels in `dataset.json`. It is an end-to-end
number, not a model benchmark — a change to the backend's prompt or its
answer-filtering moves it, which is the point, because those are the parts
this project actually wrote.

## The number that matters

Not accuracy. **Confident errors** — the count of products the system named
wrongly while presenting the answer as an answer. An identification system
that is right 60% of the time and says nothing the rest of the time is more
useful than one that is right 70% of the time and invents the other 30%,
because the first can be trusted when it speaks and the second cannot. Every
run reports both, and the report leads with the errors.

## Honesty mechanics

* The backend caches by image bytes and by perceptual hash. A cached reply
  means the model did not run, so every row records whether it was a cache
  hit and the report refuses to present a run that was mostly cached as a
  measurement.
* Every row is written to `runs/<timestamp>.json` with the reference label,
  the raw reply, and the verdict. Any figure in the summary can be checked
  against the row that produced it.
* Marginal answers are counted as marginal. See `scoring.py`.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scoring import (  # noqa: E402
    ABSTAINED,
    AMBIGUOUS,
    CORRECT,
    WRONG,
    judge_brand,
    judge_name,
)

DEFAULT_ENDPOINT = "https://recognition-camera-production.up.railway.app"
ANALYZE_PATH = "/analyze/"

# Short and unparenthesised: the edge in front of Open Food Facts rejects the
# conventional "name/version (url)" agent with a 503. See build_dataset.py.
USER_AGENT = "recognition-camera-eval/1.0"

OUTCOMES = (CORRECT, WRONG, AMBIGUOUS, ABSTAINED)


def _download(url: str, cache_dir: str, barcode: str) -> Tuple[bytes, str]:
    """Fetch the product photo, caching it by barcode.

    Cached rather than committed: the images are CC-BY-SA and belong to their
    photographers, so the repository carries the manifest that points at them
    and not copies of them. The digest is recorded in the run so a later run
    against a re-uploaded photo is visibly a different run.
    """
    os.makedirs(cache_dir, exist_ok=True)
    path = os.path.join(cache_dir, f"{barcode}.jpg")

    if os.path.exists(path):
        with open(path, "rb") as handle:
            data = handle.read()
    else:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
        with open(path, "wb") as handle:
            handle.write(data)

    return data, hashlib.sha256(data).hexdigest()


def _post_image(endpoint: str, image: bytes, timeout: int) -> Dict:
    boundary = "----recognition-camera-eval"
    body = b"".join(
        [
            f"--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="file"; '
            b'filename="product.jpg"\r\n',
            b"Content-Type: image/jpeg\r\n\r\n",
            image,
            f"\r\n--{boundary}--\r\n".encode(),
        ]
    )
    request = urllib.request.Request(
        endpoint.rstrip("/") + ANALYZE_PATH,
        data=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "User-Agent": USER_AGENT,
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read())


def parse_reply(result_text: str) -> Tuple[Optional[str], Optional[str]]:
    """Pull the product name and the company out of the backend's prose.

    Mirrors the parsing the app does in `RecognitionResult`. Kept as a
    separate implementation on purpose — a harness that reused the app's
    parser would score the app against itself and could not detect the two
    drifting apart.
    """
    lines = [line.strip(" -*#\t") for line in result_text.splitlines()]
    lines = [line for line in lines if line]

    company = None
    for line in lines:
        match = re.match(r"^(?:Company|Company name|Brand)\s*:\s*(.+)$", line, re.I)
        if match:
            company = match.group(1).strip()
            break

    name = None
    for line in lines:
        if re.match(
            r"^(Production origin|Estimated production origin|Company"
            r"|Company name|Brand|Country of the HQ|Country where)",
            line,
            re.I,
        ):
            continue
        name = line
        break

    return name, company


def _percent(count: int, total: int) -> str:
    return f"{100.0 * count / total:.0f}%" if total else "—"


def summarise(rows: List[Dict]) -> Dict:
    total = len(rows)
    summary = {"total": total, "brand": {}, "name": {}}
    for field in ("brand", "name"):
        for outcome in OUTCOMES:
            summary[field][outcome] = sum(
                1 for row in rows if row[f"{field}_verdict"] == outcome
            )
    summary["cache_hits"] = sum(1 for row in rows if row.get("cache") == "hit")
    return summary


def render_report(summary: Dict, meta: Dict) -> str:
    total = summary["total"]
    lines = [
        f"Run {meta['run_id']} · {total} products · endpoint {meta['endpoint']}",
        "",
        "| Outcome | Brand | Product name |",
        "|---|---|---|",
    ]
    labels = {
        CORRECT: "Correct",
        WRONG: "**Wrong, stated as an answer**",
        AMBIGUOUS: "Partly right (not scored either way)",
        ABSTAINED: 'Abstained ("Not identified")',
    }
    for outcome in OUTCOMES:
        brand = summary["brand"][outcome]
        name = summary["name"][outcome]
        lines.append(
            f"| {labels[outcome]} "
            f"| {brand} ({_percent(brand, total)}) "
            f"| {name} ({_percent(name, total)}) |"
        )

    lines += [
        "",
        "The brand column compares the backend's answer to the brand printed "
        "on the pack. While the backend prompt asks for the brand *owner* "
        "instead, that column measures the wrong thing and must not be "
        "quoted — see eval/README.md, 'The metric that had to be thrown "
        "away'.",
        "",
        f"Cache hits: {summary['cache_hits']} of {total}. "
        "A cache hit means the model did not run for that item.",
        f"Request failures: {summary['errors']}.",
    ]
    if summary["cache_hits"] > total * 0.2:
        lines += [
            "",
            "> More than a fifth of this run was served from cache. Treat it "
            "as a regression check, not as a measurement.",
        ]
    return "\n".join(lines)


def rescore(path: str) -> int:
    """Re-judge a completed run with the current matcher.

    Scoring is separable from the expensive part on purpose. The raw replies
    are in the run record, so a change to the match rules can be applied to
    every past run without spending another request — and, more to the point,
    without the temptation to re-run until a number comes out nicer. A revised
    matcher is applied to all history or it is not applied.
    """
    with open(path, encoding="utf-8") as handle:
        run = json.load(handle)

    for row in run["rows"]:
        if row.get("error"):
            continue
        row["name_verdict"] = judge_name(
            row["expected_name"], row.get("actual_name")
        )
        row["brand_verdict"] = judge_brand(
            row["expected_brand"], row.get("actual_brand")
        )

    scored = [row for row in run["rows"] if not row.get("error")]
    run["summary"] = summarise(scored)
    run["summary"]["errors"] = len(run["rows"]) - len(scored)
    run["meta"]["rescored_at"] = time.strftime("%Y-%m-%dT%H-%M-%SZ", time.gmtime())

    with open(path, "w", encoding="utf-8") as handle:
        json.dump(run, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    print(render_report(run["summary"], run["meta"]))
    print()
    print(f"Re-scored in place: {path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rescore",
        metavar="RUN_JSON",
        help="Re-judge a saved run with the current matcher; makes no requests.",
    )
    parser.add_argument("--dataset", default="eval/dataset.json")
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT)
    parser.add_argument("--out-dir", default="eval/runs")
    parser.add_argument("--cache-dir", default="eval/images")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument(
        "--delay",
        type=float,
        default=1.0,
        help="Seconds between requests. The backend is a single small dyno.",
    )
    args = parser.parse_args()

    if args.rescore:
        return rescore(args.rescore)

    with open(args.dataset, encoding="utf-8") as handle:
        dataset = json.load(handle)
    items = dataset["items"][: args.limit] if args.limit else dataset["items"]

    run_id = time.strftime("%Y-%m-%dT%H-%M-%SZ", time.gmtime())
    rows: List[Dict] = []

    for index, item in enumerate(items, 1):
        barcode = item["barcode"]
        row = {
            "barcode": barcode,
            "expected_name": item["expected_name"],
            "expected_brand": item["expected_brand"],
        }
        try:
            image, digest = _download(item["image_url"], args.cache_dir, barcode)
            row["image_sha256"] = digest
            reply = _post_image(args.endpoint, image, args.timeout)
            result_text = reply.get("result", "")
            actual_name, actual_brand = parse_reply(result_text)
            row.update(
                {
                    "actual_name": actual_name,
                    "actual_brand": actual_brand,
                    "raw_result": result_text,
                    "cache": reply.get("cache"),
                    # Reported by the backend so the run record names the
                    # model that produced it. A published accuracy figure
                    # without the model behind it is a number with no subject.
                    "model": reply.get("model"),
                    "duration_ms": reply.get("duration_ms"),
                    "name_verdict": judge_name(item["expected_name"], actual_name),
                    "brand_verdict": judge_brand(
                        item["expected_brand"], actual_brand
                    ),
                }
            )
        except (urllib.error.URLError, OSError, ValueError) as error:
            # A transport failure is not a wrong answer, and folding the two
            # together would let a flaky network look like a careful model.
            row.update(
                {
                    "error": f"{type(error).__name__}: {error}",
                    "name_verdict": None,
                    "brand_verdict": None,
                }
            )

        rows.append(row)
        print(
            f"[{index:>3}/{len(items)}] {barcode} "
            f"brand={row.get('brand_verdict')} name={row.get('name_verdict')} "
            f"{'' if not row.get('error') else row['error']}"
        )
        time.sleep(args.delay)

    scored = [row for row in rows if not row.get("error")]
    summary = summarise(scored)
    summary["errors"] = sum(1 for row in rows if row.get("error"))

    meta = {
        "run_id": run_id,
        "endpoint": args.endpoint,
        "dataset": os.path.basename(args.dataset),
        "dataset_built_at": dataset.get("built_at"),
        "dataset_count": dataset.get("count"),
        "requested": len(items),
    }

    os.makedirs(args.out_dir, exist_ok=True)
    out_path = os.path.join(args.out_dir, f"{run_id}.json")
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(
            {"meta": meta, "summary": summary, "rows": rows},
            handle,
            ensure_ascii=False,
            indent=2,
        )
        handle.write("\n")

    print()
    print(render_report(summary, meta))
    print()
    print(f"Per-item results: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
