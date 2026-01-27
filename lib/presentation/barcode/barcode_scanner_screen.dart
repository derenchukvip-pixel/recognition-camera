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
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null) {
      setState(() {
        _isProcessing = true;
        _barcode = barcode;
      });
      // TODO: отправить barcode в Open Food Facts или другой обработчик
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isProcessing = false;
        });
        Navigator.of(context).pop(barcode);
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
