from ultralytics import YOLO

model = YOLO('yolov12n.pt')
model.export(format="tflite", imgsz=640)
