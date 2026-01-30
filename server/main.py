import os
import logging
from dotenv import load_dotenv
load_dotenv()
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import openai
import base64
import hashlib
import time
from io import BytesIO
from typing import Optional

import redis
import imagehash
from PIL import Image

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
CACHE_TTL_SECONDS = int(os.getenv("GPT_CACHE_TTL_SECONDS", "3600"))
REDIS_URL = os.getenv("REDIS_URL")
PHASH_DISTANCE_THRESHOLD = int(os.getenv("GPT_PHASH_DISTANCE", "6"))

_cache = {}
_phash_cache = {}
_redis: Optional[redis.Redis] = None
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("cache")
if REDIS_URL:
    _redis = redis.Redis.from_url(REDIS_URL, decode_responses=True)
    logger.info("cache=redis status=initialized")
else:
    logger.info("cache=memory status=initialized")


def _make_cache_key(prompt_text: str, image_bytes: bytes) -> str:
    hasher = hashlib.sha256()
    hasher.update(prompt_text.encode("utf-8"))
    hasher.update(image_bytes)
    return hasher.hexdigest()


def _make_phash(image_bytes: bytes) -> str:
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    return str(imagehash.phash(image))


def _get_cached_response(cache_key: str):
    if _redis:
        value = _redis.get(cache_key)
        if value is not None:
            logger.info("cache=hit source=redis")
            return value, "redis"
    entry = _cache.get(cache_key)
    if not entry:
        return None, None
    expires_at, value = entry
    if time.time() > expires_at:
        _cache.pop(cache_key, None)
        return None, None
    logger.info("cache=hit source=memory")
    return value, "memory"


def _get_phash_cached_response(phash_value: str):
    if _redis:
        known_hashes = _redis.smembers("gpt:phashes")
        for known in known_hashes:
            if imagehash.hex_to_hash(known) - imagehash.hex_to_hash(phash_value) <= PHASH_DISTANCE_THRESHOLD:
                value = _redis.get(f"gpt:phash:{known}")
                if value is not None:
                    logger.info("cache=hit source=redis-phash")
                    return value, "redis-phash"

    for known, (expires_at, value) in list(_phash_cache.items()):
        if time.time() > expires_at:
            _phash_cache.pop(known, None)
            continue
        if imagehash.hex_to_hash(known) - imagehash.hex_to_hash(phash_value) <= PHASH_DISTANCE_THRESHOLD:
            logger.info("cache=hit source=memory-phash")
            return value, "memory-phash"

    return None, None


def _set_cached_response(cache_key: str, value: str):
    if _redis:
        _redis.setex(cache_key, CACHE_TTL_SECONDS, value)
        logger.info("cache=store source=redis")
        return
    _cache[cache_key] = (time.time() + CACHE_TTL_SECONDS, value)
    logger.info("cache=store source=memory")


def _set_phash_cached_response(phash_value: str, value: str):
    expires_at = time.time() + CACHE_TTL_SECONDS
    if _redis:
        _redis.setex(f"gpt:phash:{phash_value}", CACHE_TTL_SECONDS, value)
        _redis.sadd("gpt:phashes", phash_value)
        logger.info("cache=store source=redis-phash")
        return
    _phash_cache[phash_value] = (expires_at, value)
    logger.info("cache=store source=memory-phash")

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/analyze/")
async def analyze(file: UploadFile = File(...)):
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=500, detail="OpenAI API key not set")
    start_time = time.perf_counter()
    image_bytes = await file.read()
    b64_img = base64.b64encode(image_bytes).decode()
    prompt = (
        "1. Extract the product name from the image.\n"
        "2. Estimate the production origin of this product using the template: 'country name %', listing all relevant countries and их approximate percentages. If you are not sure, provide your best guess based on available information, but always include percentage estimates with the most likely country first.\n"
        "3. Specify the country of the headquarters (HQ) of the company.\n"
        "4. Specify the country where the company pays taxes and receives profit.\n"
        "Format the answer exactly as in this example (replace with actual product name and countries):\n"
        "Product Name\n"
        "Production origin and headquarters:\n"
        "- Estimated production origin of Product Name: Country1 70%, Country2 30%\n"
        "- Country of the HQ: CountryName\n"
        "- Country where the company pays taxes and receives profit: CountryName\n"
        "If any information is missing, do your best to estimate or leave it blank."
    )
    cache_key = _make_cache_key(prompt, image_bytes)
    cached, cache_source = _get_cached_response(cache_key)
    if cached is not None:
        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.info("request=complete source=cache duration_ms=%.2f", duration_ms)
        return {
            "result": cached,
            "cache": "hit",
            "cache_source": cache_source,
            "duration_ms": round(duration_ms, 2),
        }
    logger.info("cache=miss")

    phash_value = _make_phash(image_bytes)
    phash_cached, phash_source = _get_phash_cached_response(phash_value)
    if phash_cached is not None:
        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.info("request=complete source=cache-phash duration_ms=%.2f", duration_ms)
        return {
            "result": phash_cached,
            "cache": "hit",
            "cache_source": phash_source,
            "duration_ms": round(duration_ms, 2),
        }

    try:
        response = openai.ChatCompletion.create(
            model="gpt-4o",
            messages=[
                {"role": "user", "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_img}"}}
                ]}
            ],
            api_key=OPENAI_API_KEY
        )
        result = response.choices[0].message["content"]
        _set_cached_response(cache_key, result)
    _set_phash_cached_response(phash_value, result)
        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.info("request=complete source=openai duration_ms=%.2f", duration_ms)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {e}")
    return {
        "result": result,
        "cache": "miss",
        "cache_source": "openai",
        "duration_ms": round(duration_ms, 2),
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)
