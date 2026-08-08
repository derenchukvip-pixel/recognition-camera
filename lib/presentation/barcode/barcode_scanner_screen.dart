import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  String? _barcode;
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (barcode != null) {
      setState(() {
        _isProcessing = true;
        _barcode = barcode;
      });
      // The scanner keeps firing while the sheet animates out, so the result is
      // handed back to the caller (which does the Open Food Facts lookup) after
      // a short settle delay. Resolved before the gap: by the time it fires the
      // user may have hit back and this State would be gone.
      final navigator = Navigator.of(context);
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
        navigator.pop(barcode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_barcode != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Text('Barcode: $_barcode'),
              ),
            ),
        ],
      ),
    );
  }
}
