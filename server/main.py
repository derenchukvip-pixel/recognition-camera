"""Cloud recognition for the app's photo path.

One endpoint. It takes a product photograph, asks a vision model what it is,
puts the answer through `answers.py`, and returns a block the app parses into
provenance-tagged claims.

Everything interesting is in two places: the prompt below, and the filtering
in `answers.py`. The model is the easy part.
"""

import base64
import hashlib
import logging
import os
import time
from io import BytesIO
from typing import Optional

import imagehash
import redis
from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI, OpenAIError
from PIL import Image

from answers import extract_fields, is_unusable_reply, render_reply

load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# Configurable so the evaluation harness can put two models over the same
# fifty products and compare them, rather than arguing about which is better.
# The default balances cost against capability; `gpt-5.6-luna` is roughly a
# tenth of the price and `gpt-5.6-sol` more capable, and `eval/` is how you
# find out whether either difference shows up on this task.
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5.6-terra")

CACHE_TTL_SECONDS = int(os.getenv("GPT_CACHE_TTL_SECONDS", "3600"))
REDIS_URL = os.getenv("REDIS_URL")
PHASH_DISTANCE_THRESHOLD = int(os.getenv("GPT_PHASH_DISTANCE", "12"))

# Bumped whenever the prompt or the filtering changes, which invalidates every
# stored reply. Without it a prompt fix is invisible for as long as the cache
# lives — the reason invented percentages outlived the code that removed them.
CACHE_VERSION = os.getenv("GPT_CACHE_VERSION", "5")

PROMPT = """You identify a retail product from a photograph.

Report only what the photograph and your knowledge of the product actually
support. Where you do not know, write exactly: Not identified

That instruction is not a formality. A wrong answer stated plainly is worse
than no answer, because the person reading it cannot tell the two apart.
"Not identified" is a valid and expected response for any individual field,
and for all of them.

Fields:

1. Product name — the commercial name. If the exact model or variant is not
   legible, give the most precise identification the image supports (brand
   plus product type) rather than inventing a variant.
2. Estimated production origin — the countries where the goods were likely
   manufactured, as country names only. Never give percentages, proportions,
   probabilities or numbers of any kind. Manufacturing location is rarely
   disclosed; "Not identified" is usually the correct answer here.
3. Brand — the brand as printed on the packaging. Not the parent company.
4. Brand owner — the company that owns the brand, if different from it.
5. Country of the HQ — where the brand owner is headquartered.
6. Country where the company pays taxes and receives profit — if it differs
   from the HQ, give the actual profit jurisdiction.

Answer in exactly this format and add nothing else — no preamble, no
explanation, no apology:

<product name>

Production origin and headquarters:
- Estimated production origin of <product name>: <countries, or Not identified>
- Brand: <brand, or Not identified>
- Brand owner: <company, or Not identified>
- Country of the HQ: <country, or Not identified>
- Country where the company pays taxes and receives profit: <country, or Not identified>
"""

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("recognition")

_memory_cache = {}
_memory_phash_cache = {}
_redis: Optional[redis.Redis] = None
if REDIS_URL:
    _redis = redis.Redis.from_url(REDIS_URL, decode_responses=True)
    logger.info("cache=redis status=initialized")
else:
    logger.info("cache=memory status=initialized")

_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None


def _cache_key(image_bytes: bytes) -> str:
    hasher = hashlib.sha256()
    hasher.update(CACHE_VERSION.encode())
    hasher.update(OPENAI_MODEL.encode())
    hasher.update(PROMPT.encode())
    hasher.update(image_bytes)
    return hasher.hexdigest()


def _phash(image_bytes: bytes) -> str:
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    image = image.resize((256, 256), Image.Resampling.LANCZOS)
    return str(imagehash.phash(image))


def _usable_or_none(value: Optional[str]) -> Optional[str]:
    """Cached replies are re-checked on the way out, not only on the way in.

    A reply stored under an older version of the filtering can be worse than
    what the current code would produce, and the cache key does not cover
    every change that matters.
    """
    if value is None or is_unusable_reply(value):
        return None
    return value


def _cache_get(key: str):
    if _redis:
        cached = _usable_or_none(_redis.get(key))
        if cached:
            return cached, "redis"

    entry = _memory_cache.get(key)
    if entry:
        expires_at, value = entry
        if time.time() > expires_at:
            _memory_cache.pop(key, None)
        else:
            cached = _usable_or_none(value)
            if cached:
                return cached, "memory"

    return None, None


def _cache_set(key: str, value: str) -> None:
    if _redis:
        _redis.setex(key, CACHE_TTL_SECONDS, value)
        return
    _memory_cache[key] = (time.time() + CACHE_TTL_SECONDS, value)


def _phash_get(phash_value: str):
    """Near-duplicate lookup.

    Two photographs of the same box from slightly different angles are the
    same request as far as the model is concerned, and a shopper comparing
    products takes several. The threshold is deliberately loose; the cost of a
    false match is showing the answer for a very similar-looking package.
    """
    target = imagehash.hex_to_hash(phash_value)

    if _redis:
        for known in _redis.smembers(f"gpt:{CACHE_VERSION}:phashes"):
            if imagehash.hex_to_hash(known) - target <= PHASH_DISTANCE_THRESHOLD:
                cached = _usable_or_none(
                    _redis.get(f"gpt:{CACHE_VERSION}:phash:{known}")
                )
                if cached:
                    return cached, "redis-phash"

    for known, (expires_at, value) in list(_memory_phash_cache.items()):
        if not known.startswith(f"{CACHE_VERSION}:"):
            continue
        if time.time() > expires_at:
            _memory_phash_cache.pop(known, None)
            continue
        if imagehash.hex_to_hash(known.split(":", 1)[1]) - target <= (
            PHASH_DISTANCE_THRESHOLD
        ):
            cached = _usable_or_none(value)
            if cached:
                return cached, "memory-phash"

    return None, None


def _phash_set(phash_value: str, value: str) -> None:
    if _redis:
        _redis.setex(
            f"gpt:{CACHE_VERSION}:phash:{phash_value}", CACHE_TTL_SECONDS, value
        )
        _redis.sadd(f"gpt:{CACHE_VERSION}:phashes", phash_value)
        return
    _memory_phash_cache[f"{CACHE_VERSION}:{phash_value}"] = (
        time.time() + CACHE_TTL_SECONDS,
        value,
    )


def _response_text(response) -> str:
    """Read the text out of a Responses API result.

    `output_text` is the documented accessor; the walk below is a fallback so
    a change in the SDK's convenience layer degrades into a slower path rather
    than into a 500.
    """
    text = getattr(response, "output_text", None)
    if text:
        return text

    chunks = []
    for item in getattr(response, "output", []) or []:
        for part in getattr(item, "content", []) or []:
            value = getattr(part, "text", None)
            if value:
                chunks.append(value)
    return "\n".join(chunks)


def _ask_model(image_b64: str) -> str:
    response = _client.responses.create(
        model=OPENAI_MODEL,
        input=[
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": PROMPT},
                    {
                        "type": "input_image",
                        "image_url": f"data:image/jpeg;base64,{image_b64}",
                    },
                ],
            }
        ],
    )
    return _response_text(response)


app = FastAPI(title="Recognition Camera backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    """Names the model without exposing anything secret.

    The evaluation harness records this alongside its numbers: an accuracy
    figure with no model attached is a number with no subject.
    """
    return {
        "status": "ok",
        "model": OPENAI_MODEL,
        "cache_version": CACHE_VERSION,
        "cache": "redis" if _redis else "memory",
    }


@app.post("/analyze/")
async def analyze(file: UploadFile = File(...)):
    if _client is None:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY is not set")

    started = time.perf_counter()
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty upload")

    def reply(result: str, cache: str, source: str):
        duration_ms = (time.perf_counter() - started) * 1000
        logger.info("request=complete source=%s duration_ms=%.0f", source, duration_ms)
        return {
            "result": result,
            "cache": cache,
            "cache_source": source,
            "model": OPENAI_MODEL,
            "duration_ms": round(duration_ms, 2),
        }

    key = _cache_key(image_bytes)
    cached, source = _cache_get(key)
    if cached:
        return reply(cached, "hit", source)

    phash_value = _phash(image_bytes)
    cached, source = _phash_get(phash_value)
    if cached:
        return reply(cached, "hit", source)

    image_b64 = base64.b64encode(image_bytes).decode()
    try:
        raw = _ask_model(image_b64)
    except OpenAIError as error:
        # The model's own message can quote the prompt back; only the type
        # goes to the client, and the detail goes to the log.
        logger.exception("model call failed")
        raise HTTPException(
            status_code=502, detail="Recognition service is unavailable"
        ) from error

    result = render_reply(extract_fields(raw))

    # A reply that identified nothing is not stored. It is cheap to recompute
    # and a second photograph of the same product may well succeed, whereas
    # caching it freezes one bad look at the product for the life of the entry.
    if not is_unusable_reply(result):
        _cache_set(key, result)
        _phash_set(phash_value, result)

    return reply(result, "miss", "openai")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
