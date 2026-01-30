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
from typing import Optional

import redis

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
CACHE_TTL_SECONDS = int(os.getenv("GPT_CACHE_TTL_SECONDS", "3600"))
REDIS_URL = os.getenv("REDIS_URL")

_cache = {}
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


def _get_cached_response(cache_key: str):
    if _redis:
        value = _redis.get(cache_key)
        if value is not None:
            logger.info("cache=hit source=redis")
            return value
    entry = _cache.get(cache_key)
    if not entry:
        return None
    expires_at, value = entry
    if time.time() > expires_at:
        _cache.pop(cache_key, None)
        return None
    logger.info("cache=hit source=memory")
    return value


def _set_cached_response(cache_key: str, value: str):
    if _redis:
        _redis.setex(cache_key, CACHE_TTL_SECONDS, value)
        logger.info("cache=store source=redis")
        return
    _cache[cache_key] = (time.time() + CACHE_TTL_SECONDS, value)
    logger.info("cache=store source=memory")

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
    cached = _get_cached_response(cache_key)
    if cached is not None:
        return {"result": cached}
    logger.info("cache=miss")

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
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {e}")
    return {"result": result}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)
