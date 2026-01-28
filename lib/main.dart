
import 'package:flutter/material.dart';
import 'ui/detection_screen.dart';

void main() {
  runApp(const RecognitionCameraApp());
}

class RecognitionCameraApp extends StatelessWidget {
  const RecognitionCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Осознанное потребление',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
  home: const DetectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}


