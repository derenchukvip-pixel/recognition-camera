import os
from dotenv import load_dotenv
load_dotenv()
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import openai
import base64

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

app = FastAPI()
print("App started")
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
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {e}")
    return {"result": result}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)
