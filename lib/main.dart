import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'presentation/detection/detection_screen.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong. Please restart the app.',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() {
    runApp(const RecognitionCameraApp());
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Unhandled error: $error');
    }
  });
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
