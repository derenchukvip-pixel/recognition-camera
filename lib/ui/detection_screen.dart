import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  void _animateResultText(String text) async {
    _animatedResult = '';
    for (int i = 0; i < text.length; i++) {
      await Future.delayed(const Duration(milliseconds: 12));
      setState(() {
        _animatedResult = text.substring(0, i + 1);
      });
    }
  }
  File? _imageFile;
  String? _result;
  String _animatedResult = '';
  bool _loading = false;


  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _result = null;
      });
    }
  }

  Future<void> _sendToServer() async {
    if (_imageFile == null) return;
  setState(() { _loading = true; _result = null; _animatedResult = ''; });
    try {
  // Используем публичный Railway-URL
  var uri = Uri.parse('https://recognition-camera-production.up.railway.app/analyze/');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _imageFile!.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        try {
          final jsonResp = json.decode(respStr);
          setState(() { _result = jsonResp['result'] ?? respStr; });
          this._animateResultText(jsonResp['result'] ?? respStr);
        } catch (e) {
          setState(() { _result = respStr; });
          this._animateResultText(respStr);
        }
      } else {
        setState(() { _result = 'Error: ${response.statusCode}'; _animatedResult = 'Error: ${response.statusCode}'; });
      }
    } catch (e) {
      setState(() { _result = 'Error: ${e.toString()}'; _animatedResult = 'Error: ${e.toString()}'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recognition Camera')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_imageFile != null)
                Image.file(_imageFile!, height: 200),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _takePhoto,
                child: const Text('Add photo'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _imageFile != null && !_loading ? _sendToServer : null,
                child: const Text('Send photo to server'),
              ),
              const SizedBox(height: 24),
              if (_loading && _imageFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 100),
                          style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
                          child: Text(_animatedResult.isEmpty ? 'Analyzing...' : _animatedResult),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_loading && _animatedResult.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 100),
                    style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
                    child: Text(_animatedResult),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
