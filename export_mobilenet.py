import tensorflow as tf

model = tf.keras.applications.MobileNet(weights="imagenet", input_shape=(224,224,3))
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open("mobilenet_v1_1.0_224.tflite", "wb") as f:
    f.write(tflite_model)
