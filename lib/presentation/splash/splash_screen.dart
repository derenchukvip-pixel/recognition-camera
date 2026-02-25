import 'package:flutter/material.dart';

import '../terms/terms_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Color _brandBlue = Color(0xFF1F4C7A);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TermsScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double horizontalPadding =
                ((constraints.maxWidth - 203) / 2).clamp(16, 100);
            final double bottomPadding =
                (constraints.maxHeight * 0.12).clamp(64, 96);
            return Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'materials/Icons/main.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'WerWo',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: SplashScreen._brandBlue,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: bottomPadding,
                  child: SizedBox(
                    height: 40,
                    child: Text(
                      'Know the origin.\nUnderstand the impact.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: SplashScreen._brandBlue,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
