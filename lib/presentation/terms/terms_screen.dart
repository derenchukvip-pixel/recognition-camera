import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/consent/disclaimer_storage.dart';
import '../design/tokens.dart';
import '../detection/detection_screen.dart';
import 'terms_content.dart';

/// The consent gate, shown once before the camera is reachable.
///
/// Only the two decisions live here — record the acceptance and go, or end the
/// session. Everything the user actually reads is in [TermsContent], which has
/// no platform dependency and so can be rendered in the web preview.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static final DisclaimerStorage _disclaimerStorage = DisclaimerStorage();

  Future<void> _decline() async {
    await _disclaimerStorage.setAccepted(false);
    if (Platform.isIOS) {
      Future.delayed(const Duration(milliseconds: 80), () => exit(0));
    }
    SystemNavigator.pop();
  }

  Future<void> _accept(BuildContext context) async {
    await _disclaimerStorage.setAccepted(true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DetectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: TermsContent(
        onAccept: () => _accept(context),
        onDecline: _decline,
      ),
    );
  }
}
