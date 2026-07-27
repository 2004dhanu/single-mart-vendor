import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SquareImageCropper extends StatefulWidget {
  final File imageFile;

  const SquareImageCropper({super.key, required this.imageFile});

  static Future<File?> crop(BuildContext context, File imageFile) async {
    return Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => SquareImageCropper(imageFile: imageFile),
      ),
    );
  }

  @override
  State<SquareImageCropper> createState() => _SquareImageCropperState();
}

class _SquareImageCropperState extends State<SquareImageCropper> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  int _quarterTurns = 0;
  bool _isProcessing = false;

  void _rotateImage() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _resetImage() {
    setState(() {
      _quarterTurns = 0;
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _cropAndSave() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Failed to locate crop boundary");

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) throw Exception("Failed to convert image to byte data");
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final originalPath = widget.imageFile.path;
      final extension = originalPath.split('.').last;
      final separator = originalPath.contains('\\') ? '\\' : '/';
      final dirPath = originalPath.substring(0, originalPath.lastIndexOf(separator));
      final newPath = '$dirPath${separator}cropped_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      final croppedFile = File(newPath);
      await croppedFile.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cropSize = screenWidth - 40;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crop Image',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reset',
            onPressed: _resetImage,
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right, color: Colors.white),
            tooltip: 'Rotate 90°',
            onPressed: _rotateImage,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SizedBox(
              width: cropSize,
              height: cropSize,
              child: RepaintBoundary(
                key: _cropKey,
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: EdgeInsets.zero,
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: SizedBox(
                      width: cropSize,
                      height: cropSize,
                      child: RotatedBox(
                        quarterTurns: _quarterTurns,
                        child: kIsWeb
                            ? Image.network(
                                widget.imageFile.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                widget.imageFile,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: CropOverlayPainter(cropSize: cropSize),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFF97316)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _cropAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Crop & Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final double cropSize;

  CropOverlayPainter({required this.cropSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final outerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    final left = (size.width - cropSize) / 2;
    final top = (size.height - cropSize) / 2;
    final innerRect = Rect.fromLTWH(left, top, cropSize, cropSize);

    final path = Path()
      ..addRect(outerRect)
      ..addRect(innerRect);
    path.fillType = PathFillType.evenOdd;
    
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(innerRect, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(left + cropSize / 3, top), Offset(left + cropSize / 3, top + cropSize), gridPaint);
    canvas.drawLine(Offset(left + 2 * cropSize / 3, top), Offset(left + 2 * cropSize / 3, top + cropSize), gridPaint);

    canvas.drawLine(Offset(left, top + cropSize / 3), Offset(left + cropSize, top + cropSize / 3), gridPaint);
    canvas.drawLine(Offset(left, top + 2 * cropSize / 3), Offset(left + cropSize, top + 2 * cropSize / 3), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
