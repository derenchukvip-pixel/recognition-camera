from ultralytics import YOLO

model = YOLO('yolov8n.pt')
model.export(format='tflite', imgsz=640, int8=True)
