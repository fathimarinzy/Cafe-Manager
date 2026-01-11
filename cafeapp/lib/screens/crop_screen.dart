import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class CropScreen extends StatefulWidget {
  final Uint8List image;

  const CropScreen({super.key, required this.image});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final CropController _controller = CropController();
  bool _isCropping = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Crop Logo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isCropping 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                : const Icon(Icons.check, color: Colors.green),
            onPressed: (_isCropping)
                ? null 
                : () {
                    debugPrint('Crop check icon pressed');
                    setState(() {
                      _isCropping = true;
                    });
                    _controller.crop();
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _controller,
              onCropped: (result) {
                debugPrint('onCropped called. Result type: ${result.runtimeType}');
                if (mounted) {
                  switch (result) {
                    case CropSuccess(:final croppedImage):
                      debugPrint('Crop success. Size: ${croppedImage.length} bytes');
                      setState(() {
                        _isCropping = false;
                      });
                      Navigator.of(context).pop(croppedImage);
                      break;
                    case CropFailure(:final cause):
                      debugPrint('Crop failure: $cause');
                      setState(() {
                        _isCropping = false;
                        _status = 'Error: $cause';
                      });
                      break;
                  }
                }
              },
              aspectRatio: 1.0, // Force square crop
              withCircleUi: true, // Show circle mask since we use circular logo
              baseColor: Colors.black,
              maskColor: Colors.black.withAlpha(179),
              cornerDotBuilder: (size, edgeAlignment) => const DotControl(color: Colors.white),
              interactive: true,
              onStatusChanged: (status) {
                if (mounted) {
                   debugPrint('Crop Status: $status');
                   setState(() {
                     _status = status.toString();
                   });
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Text(
              _status.isNotEmpty ? 'Status: $_status' : 'Pinch to zoom, pan to adjust',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
