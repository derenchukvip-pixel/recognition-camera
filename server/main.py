import os
import logging
from dotenv import load_dotenv
load_dotenv()
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import openai
import base64
import hashlib
import re
import time
from io import BytesIO
from typing import Optional, List

import redis
import imagehash
from PIL import Image

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
CACHE_TTL_SECONDS = int(os.getenv("GPT_CACHE_TTL_SECONDS", "3600"))
REDIS_URL = os.getenv("REDIS_URL")
PHASH_DISTANCE_THRESHOLD = int(os.getenv("GPT_PHASH_DISTANCE", "12"))
CACHE_VERSION = os.getenv("GPT_CACHE_VERSION", "4")

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
    hasher.update(CACHE_VERSION.encode("utf-8"))
    hasher.update(prompt_text.encode("utf-8"))
    hasher.update(image_bytes)
    return hasher.hexdigest()


def _make_phash(image_bytes: bytes) -> str:
    image = Image.open(BytesIO(image_bytes)).convert("RGB")
    image = image.resize((256, 256), Image.Resampling.LANCZOS)
    return str(imagehash.phash(image))


def _get_cached_response(cache_key: str):
    if _redis:
        value = _redis.get(cache_key)
        if value is not None:
            if _is_placeholder_value(value) or "[" in value or "]" in value:
                return None, None
            if _is_not_identified_result(value):
                return None, None
            if not _has_company_line(value):
                return None, None
            logger.info("cache=hit source=redis")
            return value, "redis"
    entry = _cache.get(cache_key)
    if not entry:
        return None, None
    expires_at, value = entry
    if time.time() > expires_at:
        _cache.pop(cache_key, None)
        return None, None
    if _is_placeholder_value(value) or "[" in value or "]" in value:
        return None, None
    if _is_not_identified_result(value):
        return None, None
    if not _has_company_line(value):
        return None, None
    logger.info("cache=hit source=memory")
    return value, "memory"


def _get_phash_cached_response(phash_value: str):
    versioned_phash = f"{CACHE_VERSION}:{phash_value}"
    if _redis:
        known_hashes = _redis.smembers(f"gpt:{CACHE_VERSION}:phashes")
        for known in known_hashes:
            if imagehash.hex_to_hash(known) - imagehash.hex_to_hash(phash_value) <= PHASH_DISTANCE_THRESHOLD:
                value = _redis.get(f"gpt:{CACHE_VERSION}:phash:{known}")
                if value is not None:
                    if _is_not_identified_result(value):
                        return None, None
                    if not _has_company_line(value):
                        return None, None
                    logger.info("cache=hit source=redis-phash")
                    return value, "redis-phash"

    for known, (expires_at, value) in list(_phash_cache.items()):
        if not known.startswith(f"{CACHE_VERSION}:"):
            continue
        if time.time() > expires_at:
            _phash_cache.pop(known, None)
            continue
        normalized_known = known.split(":", 1)[1]
        if imagehash.hex_to_hash(normalized_known) - imagehash.hex_to_hash(phash_value) <= PHASH_DISTANCE_THRESHOLD:
            if _is_not_identified_result(value):
                return None, None
            if not _has_company_line(value):
                return None, None
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
        _redis.setex(
            f"gpt:{CACHE_VERSION}:phash:{phash_value}",
            CACHE_TTL_SECONDS,
            value,
        )
        _redis.sadd(f"gpt:{CACHE_VERSION}:phashes", phash_value)
        logger.info("cache=store source=redis-phash")
        return
    _phash_cache[f"{CACHE_VERSION}:{phash_value}"] = (expires_at, value)
    logger.info("cache=store source=memory-phash")


def _clean_line(value: str) -> str:
    cleaned = value.strip()
    cleaned = cleaned.lstrip("#*-").strip()
    cleaned = cleaned.strip("*`_")
    return cleaned


def _is_placeholder_value(value: str) -> bool:
    normalized = value.strip().lower()
    if not normalized:
        return True
    if "[" in normalized or "]" in normalized:
        return True
    if "product name" in normalized or "country" in normalized:
        return True
    if "estimated production origin" in normalized:
        return True
    if "please provide textual information" in normalized:
        return True
    if re.search(r"\bproduct\s+name\b", normalized):
        return True
    return False


def _is_not_identified_result(value: str) -> bool:
    if not value:
        return True
    first_line = value.strip().splitlines()[0].strip().lower()
    return first_line == "not identified"


def _has_company_line(value: str) -> bool:
    normalized = value.lower()
    return "company name:" in normalized or "company:" in normalized


def _infer_product_from_text(text: str) -> Optional[str]:
    normalized = text.lower()
    if "apple" in normalized:
        if "macbook" in normalized:
            return "Apple MacBook"
        if "laptop" in normalized or "notebook" in normalized:
            return "Apple laptop"
        if "iphone" in normalized:
            return "Apple iPhone"
        if "ipad" in normalized:
            return "Apple iPad"
        if "airpods" in normalized:
            return "Apple AirPods"
        return "Apple device"
    return None


def _is_invalid_product_line(value: str) -> bool:
    normalized = value.strip().lower()
    if _is_placeholder_value(normalized):
        return True
    if normalized in {"the", "product", "the product", "unknown product"}:
        return True
    if normalized in {"product name", "product", "name", "productname"}:
        return True
    if "production origin" in normalized or "origin and headquarters" in normalized:
        return True
    if normalized.startswith("estimated production origin"):
        return True
    if "country of the hq" in normalized or "country where the company pays" in normalized:
        return True
    if re.search(r"\bfor a product like this\b", normalized):
        return True
    if re.search(r"\b(i\s*'m|im)\s+unable\b", normalized):
        return True
    if re.search(r"\b(i\s*'m|im)\s+sorry\b", normalized):
        return True
    if re.search(r"\bcan't\b|\bcannot\b", normalized):
        return True
    return False


def _pick_product_candidate(lines: List[str]) -> Optional[str]:
    for line in lines:
        normalized = line.strip().lower()
        if any(
            marker in normalized
            for marker in (
                "production origin",
                "origin and headquarters",
                "country of the hq",
                "country where the company pays",
                "company name:",
            )
        ):
            continue
        if _is_invalid_product_line(line):
            continue
        return line
    return None


def _extract_fields(text: str):
    lines = [
        _clean_line(line)
        for line in text.splitlines()
        if _clean_line(line)
    ]
    product = None
    for line in lines:
        match = re.search(r"Estimated production origin of\s+(.+?)\s*:", line, re.IGNORECASE)
        if match:
            candidate = _clean_line(match.group(1))
            if not _is_invalid_product_line(candidate):
                product = candidate
            break
    if not product and lines:
        first_line = lines[0]
        if re.search(r"Estimated production origin", first_line, re.IGNORECASE):
            product = None
        elif re.fullmatch(r"product name", first_line, re.IGNORECASE) and len(lines) > 1:
            candidate = lines[1]
            product = None if _is_invalid_product_line(candidate) else candidate
        else:
            product = first_line

    if not product:
        product = _pick_product_candidate(lines)

    if product and _is_invalid_product_line(product):
        product = None
    if product and "production origin" in product.lower():
        product = None

    production = None
    hq = None
    tax = None

    for line in lines:
        prod_match = re.search(
            r"Estimated production origin.*?:\s*(.+)$",
            line,
            re.IGNORECASE,
        )
        if prod_match:
            candidate = _clean_line(prod_match.group(1))
            production = None if _is_placeholder_value(candidate) else candidate
            continue
        hq_match = re.search(r"Country of the HQ:\s*(.+)$", line, re.IGNORECASE)
        if hq_match:
            candidate = _clean_line(hq_match.group(1))
            hq = None if _is_placeholder_value(candidate) else candidate
            continue
        tax_match = re.search(
            r"Country where the company pays taxes and receives profit:\s*(.+)$",
            line,
            re.IGNORECASE,
        )
        if tax_match:
            candidate = _clean_line(tax_match.group(1))
            tax = None if _is_placeholder_value(candidate) else candidate

    return product, production, hq, tax


def _call_openai(prompt: str, b64_img: str) -> str:
    response = openai.ChatCompletion.create(
        model="gpt-4o",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_img}"}},
                ],
            }
        ],
        temperature=0,
        top_p=1,
        api_key=OPENAI_API_KEY,
    )
    return response.choices[0].message["content"]

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
        "You are a system for precise product identification from images.\n\n"
        "Your task is to identify the product strictly from the image and provide a structured answer.\n\n"
        "Analysis rules:\n\n"
        "1. Determine the exact commercial product name.\n"
        "2. If the name is not visible, infer the most likely official name based on shape, packaging, design, logo, colors, markings, and other visual cues.\n"
        "3. Do not invent non-existent models.\n"
        "4. If the exact model cannot be identified, return the most precise identification possible (brand + line + product type).\n"
        "5. Estimate probable production countries.\n"
        "   - Include ALL countries with probability above 30%.\n"
        "   - Maximum 5 countries.\n"
        "   - Sort in descending order.\n"
        "   - Always include percentages.\n"
        "   - If unsure, make a reasoned estimate.\n"
        "   - Percentages do not have to sum to 100% but must be logically consistent.\n"
    "6. Specify:\n"
    "   - The company name (brand owner).\n"
    "   - The country of the company HQ.\n"
    "   - The country where the company pays primary taxes and receives profit\n"
    "     (if different from HQ, specify the actual profit jurisdiction).\n\n"
        "The response must follow this exact format (no extra text):\n\n"
        "Product Name\n\n"
        "Production origin and headquarters:\n\n"
    "Estimated production origin of Product Name: Country1 XX%, Country2 XX%, Country3 XX%\n\n"
    "Company: Company\n\n"
        "Country of the HQ: Country\n\n"
        "Country where the company pays taxes and receives profit: Country\n\n"
        "If data cannot be determined precisely:\n"
        "- Use the most likely estimate.\n"
        "- Never leave any section empty.\n"
        "- Never use placeholders like 'Product Name', 'Product', or 'Company name'.\n"
        "- Do not output any descriptive sentences or explanations.\n"
        "- Do not add comments outside the specified format.\n"
        "- Do not output apologies or phrases like 'I'm sorry' or 'I can't'.\n"
        "- For the same image, the result must be identical.\n"
        "- Do not change wording.\n"
        "- Use the same structure every time."
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
        first_result = _call_openai(prompt, b64_img)
        product, production, hq, tax = _extract_fields(first_result)
        if not product:
            product = _infer_product_from_text(first_result)
        product = product or "Not identified"
        if product.lower() == "not identified":
            retry_result = _call_openai(prompt, b64_img)
            product, production, hq, tax = _extract_fields(retry_result)
            if not product:
                product = _infer_product_from_text(retry_result)
            product = product or "Not identified"
        if product.lower() == "not identified":
            production = "Not identified"
            hq = "Not identified"
            tax = "Not identified"
            company = "Not identified"
        production = production or "Not identified"
        hq = hq or "Not identified"
        tax = tax or "Not identified"

        company_prompt = (
            "You are a system for identifying the manufacturer company (brand owner).\n\n"
            f"Product name: {product}\n\n"
            "Return ONLY the exact company name (brand owner).\n"
            "Do NOT return the product name.\n"
            "If you cannot determine the company, return 'Not identified'.\n"
            "No extra text, no explanations, no punctuation besides the name."
        )
        company_response = openai.ChatCompletion.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": company_prompt}],
            temperature=0,
            top_p=1,
            api_key=OPENAI_API_KEY,
        )
        company = company_response.choices[0].message["content"].strip()
        logger.info("company=raw value=%s", company)

        def _is_invalid_company(value: str, product_name: str) -> bool:
            if not value:
                return True
            normalized = value.strip().lower()
            if normalized in {"not identified", "unknown", "n/a", "-"}:
                return True
            if "please provide textual information" in normalized or normalized == "please":
                return True
            # Russian generic category words the model sometimes returns in place
            # of a brand ("nozzle", "set", "accessory"). These are data, not
            # comments: translating them would stop the guard from matching what
            # the model actually emits.
            if normalized in {"насадка", "комплект", "аксессуар", "аксессуары"}:
                return True
            if _is_placeholder_value(normalized):
                return True
            if normalized in {"for", "a", "an", "the", "this", "that", "these", "those", "product", "the product"}:
                return True
            product_norm = product_name.strip().lower()
            if product_norm.startswith(f"{normalized} "):
                return False
            return (
                normalized == product_norm
                or normalized in product_norm
                or product_norm in normalized
            )

        if _is_invalid_company(company, product):
            retry_prompt = (
                "Identify the manufacturer company (brand owner) for this product.\n\n"
                f"Product name: {product}\n\n"
                "Return ONLY the company name (brand owner).\n"
                "Do NOT return the product name.\n"
                "If unknown, return 'Not identified'."
            )
            retry_response = openai.ChatCompletion.create(
                model="gpt-4o",
                messages=[{"role": "user", "content": retry_prompt}],
                temperature=0,
                top_p=1,
                api_key=OPENAI_API_KEY,
            )
            company = retry_response.choices[0].message["content"].strip()
            logger.info("company=retry value=%s", company)
            if _is_invalid_company(company, product):
                inferred = None
                if re.search(r"\bbosch\b", product, re.IGNORECASE):
                    inferred = "Bosch"
                company = inferred or "Not identified"

        if not company:
            company = "Not identified"
        logger.info("company=final value=%s", company)

        result = (
            f"{product}\n\n"
            "Production origin and headquarters:\n"
            f"- Estimated production origin of {product}: {production}\n"
            f"- Company: {company}\n"
            f"- Country of the HQ: {hq}\n"
            "- Country where the company pays taxes and receives profit: "
            f"{tax}"
        )

        if product.lower() != "not identified":
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
