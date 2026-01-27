from fastapi import FastAPI, File, UploadFile
from ultralytics import YOLO
from PIL import Image
import io

app = FastAPI()
model = YOLO('yolov8n.pt')  # Замените на свою модель, если нужно

@app.post("/detect/")
async def detect(file: UploadFile = File(...)):
    image_bytes = await file.read()
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    results = model(image)
    detections = []
    for box in results[0].boxes:
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        conf = float(box.conf[0])
        cls = int(box.cls[0])
        label = model.names[cls]
        detections.append({
            "label": label,
            "confidence": conf,
            "box": [x1, y1, x2, y2]
        })
    return {"detections": detections}
