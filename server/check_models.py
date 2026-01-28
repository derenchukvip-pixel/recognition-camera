import openai
import os

api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    api_key = "REMOVED"

openai.api_key = api_key

try:
    models = openai.Model.list()
    print("Available models:")
    for m in models.data:
        print(m.id)
except Exception as e:
    print(f"Error: {e}")
