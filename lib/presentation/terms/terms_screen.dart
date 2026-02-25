import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/consent/disclaimer_storage.dart';
import '../detection/detection_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const Color _primaryBlue = Color(0xFF052F61);
  static const Color _secondaryBlue = Color(0xFF1A497F);
  static final DisclaimerStorage _disclaimerStorage = DisclaimerStorage();

  Future<void> _exitApp() async {
    await _disclaimerStorage.setAccepted(false);
    if (Platform.isIOS) {
      Future.delayed(const Duration(milliseconds: 80), () => exit(0));
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const SizedBox(
                width: 283,
                height: 64,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Terms of Use\n',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _primaryBlue,
                            height: 1.0,
                          ),
                        ),
                        TextSpan(
                          text: 'Please review before continuing',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    textHeightBehavior: TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: double.infinity,
                    child: RichText(
                      textAlign: TextAlign.left,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'While using this application, please, be aware\n'
                                'that it uses Artificial Intelligence (AI) LLM.\n'
                                'AI has been trained and perpetually continues\n'
                                'its training based on Open-Source Real World\n'
                                'data.\n'
                                'The generated content is provided “as-is”\n'
                                'without any warranties or guarantees and may\n'
                                'contain inconsistencies or outdated information.\n'
                                'AI generated information is not legally verified\n'
                                'and shall not be used for legal advice or\n'
                                'consultation.\n\n'
                                'By tapping ',
                          ),
                          TextSpan(
                            text: 'Agree',
                            style: TextStyle(
                              color: _secondaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text:
                                ', you confirm that you\nunderstand and accept our ',
                          ),
                          TextSpan(
                            text: 'Terms of Use',
                            style: TextStyle(
                              color: _secondaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _exitApp,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryBlue,
                                side: const BorderSide(color: _primaryBlue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Decline',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: () async {
                                await _disclaimerStorage.setAccepted(true);
                                if (!context.mounted) return;
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const DetectionScreen(),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Agree',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
