import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;

/// A page that allows the user to pan, zoom, rotate, and crop an image
/// into a 1:1 square matching the QR center emblem area.
class ImageCropPage extends StatefulWidget {
  const ImageCropPage({
    required this.imageBytes,
    super.key,
  });

  final Uint8List imageBytes;

  /// Helper to push the [ImageCropPage] and return the cropped PNG bytes,
  /// or null if the user canceled.
  static Future<Uint8List?> crop(
    BuildContext context, {
    required Uint8List imageBytes,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => ImageCropPage(imageBytes: imageBytes),
      ),
    );
  }

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  final TransformationController _transformController =
      TransformationController();

  image_lib.Image? _decodedImage;
  Uint8List? _displayBytes;
  bool _isLoading = true;
  bool _hasInitializedTransform = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _decodeImage(widget.imageBytes);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _decodeImage(Uint8List bytes) {
    try {
      var decoded = image_lib.decodeImage(bytes);
      if (decoded == null) {
        setState(() {
          _errorMessage = 'Could not read the selected image.';
          _isLoading = false;
        });
        return;
      }
      // Bake EXIF camera orientation into pixels so the decoded pixel buffer
      // exactly matches what Flutter displays on screen.
      decoded = image_lib.bakeOrientation(decoded);
      final display = Uint8List.fromList(image_lib.encodePng(decoded));

      setState(() {
        _decodedImage = decoded;
        _displayBytes = display;
        _hasInitializedTransform = false;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Failed to process the image.';
        _isLoading = false;
      });
    }
  }

  void _rotateClockwise() {
    final current = _decodedImage;
    if (current == null) return;
    setState(() => _isLoading = true);

    // Rotate 90 degrees clockwise
    final rotated = image_lib.copyRotate(current, angle: 90);
    final display = Uint8List.fromList(image_lib.encodePng(rotated));

    setState(() {
      _decodedImage = rotated;
      _displayBytes = display;
      _hasInitializedTransform = false;
      _isLoading = false;
    });
  }

  void _resetTransform(double cropSize, double childWidth, double childHeight) {
    final tx = (cropSize - childWidth) / 2;
    final ty = (cropSize - childHeight) / 2;

    _transformController.value = Matrix4.translationValues(tx, ty, 0.0);
  }

  Future<void> _applyCrop(
    double cropSize,
    double childWidth,
    double childHeight,
  ) async {
    final original = _decodedImage;
    if (original == null) return;

    setState(() => _isLoading = true);

    try {
      // toScene accurately translates viewport coordinates (0,0) and
      // (cropSize, cropSize) to the child's local coordinates.
      final topLeft = _transformController.toScene(Offset.zero);
      final bottomRight = _transformController.toScene(
        Offset(cropSize, cropSize),
      );

      final factor = original.width / childWidth;

      final cropX = (topLeft.dx * factor).round().clamp(0, original.width - 1);
      final cropY = (topLeft.dy * factor).round().clamp(0, original.height - 1);
      final cropW = ((bottomRight.dx - topLeft.dx) * factor)
          .round()
          .clamp(1, original.width - cropX);
      final cropH = ((bottomRight.dy - topLeft.dy) * factor)
          .round()
          .clamp(1, original.height - cropY);

      final squareSize = math.min(cropW, cropH);

      final cropped = image_lib.copyCrop(
        original,
        x: cropX,
        y: cropY,
        width: squareSize,
        height: squareSize,
      );

      // Normalize to a clean 512x512 square
      final normalized = image_lib.copyResize(
        cropped,
        width: 512,
        height: 512,
        interpolation: image_lib.Interpolation.cubic,
      );

      final pngBytes = Uint8List.fromList(image_lib.encodePng(normalized));

      if (mounted) {
        Navigator.of(context).pop(pngBytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not crop the image.')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop Center Image'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _rotateClockwise,
            tooltip: 'Rotate 90°',
            icon: const Icon(Icons.rotate_right_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _decodedImage == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final maxAvailableWidth = constraints.maxWidth;
                      final maxAvailableHeight = constraints.maxHeight - 110;

                      // Square crop box size
                      final cropSize = math.min(
                        maxAvailableWidth - 32,
                        math.min(maxAvailableHeight, 360.0),
                      );

                      final original = _decodedImage!;
                      final aspectRatio = original.width / original.height;

                      // Sizing the child widget inside InteractiveViewer so it
                      // covers the crop box in both dimensions at scale 1.0.
                      double childWidth;
                      double childHeight;
                      if (aspectRatio >= 1.0) {
                        childHeight = cropSize;
                        childWidth = cropSize * aspectRatio;
                      } else {
                        childWidth = cropSize;
                        childHeight = cropSize / aspectRatio;
                      }

                      // Initialize transform once per loaded/rotated image
                      if (!_hasInitializedTransform) {
                        _hasInitializedTransform = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _resetTransform(cropSize, childWidth, childHeight);
                          }
                        });
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Text(
                              'Pan and pinch to frame the center emblem area of your QR code.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                width: cropSize,
                                height: cropSize,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.primary,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    InteractiveViewer(
                                      transformationController:
                                          _transformController,
                                      minScale: 1.0,
                                      maxScale: 6.0,
                                      boundaryMargin: EdgeInsets.zero,
                                      clipBehavior: Clip.hardEdge,
                                      child: SizedBox(
                                        width: childWidth,
                                        height: childHeight,
                                        child: Image.memory(
                                          _displayBytes!,
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                    ),
                                    // Guide overlay with corner accents and rule of thirds
                                    IgnorePointer(
                                      child: CustomPaint(
                                        size: Size(cropSize, cropSize),
                                        painter: _CropGuidePainter(
                                          accentColor: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (_isLoading)
                                      Container(
                                        color: Colors.black54,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Controls toolbar
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            color: Colors.black,
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () =>
                                      Navigator.of(context).pop(null),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Cancel'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                  ),
                                ),
                                const Spacer(),
                                IconButton.filledTonal(
                                  onPressed: () => _resetTransform(
                                    cropSize,
                                    childWidth,
                                    childHeight,
                                  ),
                                  tooltip: 'Reset Framing',
                                  icon: const Icon(Icons.center_focus_strong),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _applyCrop(
                                            cropSize,
                                            childWidth,
                                            childHeight,
                                          ),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Apply'),
                                ),
                              ],
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

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Rule of thirds
    final thirdW = size.width / 3;
    final thirdH = size.height / 3;

    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), gridPaint);
    canvas.drawLine(
      Offset(thirdW * 2, 0),
      Offset(thirdW * 2, size.height),
      gridPaint,
    );
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), gridPaint);
    canvas.drawLine(
      Offset(0, thirdH * 2),
      Offset(size.width, thirdH * 2),
      gridPaint,
    );

    // Corner accents
    final cornerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 22.0;

    // Top-Left
    canvas.drawLine(Offset.zero, const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(Offset.zero, const Offset(0, cornerLength), cornerPaint);

    // Top-Right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropGuidePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
