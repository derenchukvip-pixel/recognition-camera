import 'package:flutter/material.dart';
import 'presentation/detection/detection_screen.dart';

void main() {
  runApp(const RecognitionCameraApp());
}

class RecognitionCameraApp extends StatelessWidget {
  const RecognitionCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conscious consumption',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const DetectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
