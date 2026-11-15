import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fast_paddle_ocr/ocr.dart';
import 'package:fast_paddle_ocr/ocr_camera_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ocr_service.dart';
import '../services/theme_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> with SingleTickerProviderStateMixin {
  final Ocr _ocrPlugin = OcrService.ocrPlugin;

  bool _isCameraReady = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _flashOn = false;
  int _facing = 0; // 0 = back camera, 1 = front camera

  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _setupScanner();
  }

  Future<void> _setupScanner() async {
    setState(() => _isLoading = true);

    // 1. Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCameraReady = false;
        });
      }
      return;
    }

    // 2. Initialize PaddleOCR model (560px detection for high receipt accuracy)
    final bool loaded = await OcrService.initModel(sizeid: 3);
    if (!loaded) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCameraReady = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize PaddleOCR models.')),
        );
      }
      return;
    }

    // 3. Open camera with Photo Mode enabled (disables heavy preview recognition for smooth 60fps)
    try {
      final bool openSuccess = await _ocrPlugin.openCamera(_facing);
      if (openSuccess) {
        // Photo mode ensures zero background recognition overhead during camera preview
        await _ocrPlugin.setPhotoMode(true);
        if (mounted) {
          setState(() {
            _isCameraReady = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isCameraReady = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error starting camera: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCameraReady = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await _ocrPlugin.toggleFlash();
      setState(() => _flashOn = !_flashOn);
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _ocrPlugin.closeCamera();
      _facing = 1 - _facing;
      _flashOn = false;
      final success = await _ocrPlugin.openCamera(_facing);
      if (success) {
        await _ocrPlugin.setPhotoMode(true);
        if (mounted) setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Switch camera error: $e');
    }
  }

  /// Triggered strictly ON BUTTON PRESS: captures high-res photo & runs full PaddleOCR offline
  Future<void> _captureReceipt() async {
    if (_isProcessing || !_isCameraReady) return;

    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${dir.path}/temp_receipts');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      final savePath = '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1. Capture sharp, full-resolution photo from camera
      final resultPaths = await _ocrPlugin.takePhoto(savePath);
      String photoPath = savePath;
      String? cropPath;

      if (resultPaths != null && resultPaths.isNotEmpty) {
        final parts = resultPaths.split('|');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          photoPath = parts[0];
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          cropPath = parts[1];
        }
      }

      // 2. Run full offline PaddleOCR inference on the sharp still image
      OcrResult result = await OcrService.processReceipt(photoPath);

      // If detection was empty or missed amount, check cropped path if available
      if ((result.amount == null || result.vendorName == null) &&
          cropPath != null &&
          File(cropPath).existsSync()) {
        final cropResult = await OcrService.processReceipt(cropPath);
        if (cropResult.hasTextDetected) {
          result = cropResult;
        }
      }

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      debugPrint('Error capturing & processing receipt: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to scan receipt: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await OcrService.processReceipt(pickedFile.path);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      debugPrint('Gallery OCR error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _ocrPlugin.closeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeService.getHeaderPillColor();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Smooth 60fps Native Camera Preview (photo mode)
          if (_isCameraReady)
            const Positioned.fill(
              child: OcrCameraView(),
            )
          else if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Starting Camera...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera permission or device initialization failed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Pick from Gallery instead'),
                      onPressed: _pickFromGallery,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      child: const Text('Back', style: TextStyle(color: Colors.white70)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

          // Viewfinder Framing Overlay
          if (_isCameraReady && !_isProcessing)
            _buildViewfinderOverlay(primaryColor),

          // Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, color: primaryColor, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'PaddleOCR Scanner',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _flashOn ? Colors.amber : Colors.black54,
                      child: IconButton(
                        icon: Icon(
                          _flashOn ? Icons.flash_on : Icons.flash_off,
                          color: _flashOn ? Colors.black : Colors.white,
                        ),
                        tooltip: 'Flash',
                        onPressed: _isProcessing ? null : _toggleFlash,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                        tooltip: 'Flip',
                        onPressed: _isProcessing ? null : _switchCamera,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Shutter Controls
          if (!_isProcessing)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Align receipt inside frame & tap Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery option
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.photo_library, color: Colors.white),
                        tooltip: 'Pick from Gallery',
                        onPressed: _pickFromGallery,
                      ),

                      // Large Shutter Button
                      GestureDetector(
                        onTap: _captureReceipt,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.5),
                                blurRadius: 18,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.document_scanner, color: Colors.white, size: 40),
                          ),
                        ),
                      ),

                      // Back button
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Loading & Processing Overlay (shown only during scan)
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primaryColor, strokeWidth: 3.5),
                      const SizedBox(height: 20),
                      const Text(
                        'Scanning Receipt...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'PaddleOCR is extracting merchant and amount details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewfinderOverlay(Color primaryColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanW = constraints.maxWidth * 0.85;
        final scanH = constraints.maxHeight * 0.60;

        return Center(
          child: SizedBox(
            width: scanW,
            height: scanH,
            child: Stack(
              children: [
                // Corner Brackets
                CustomPaint(
                  size: Size(scanW, scanH),
                  painter: _ViewfinderPainter(
                    borderColor: primaryColor,
                    cornerLength: 36,
                    strokeWidth: 4,
                  ),
                ),

                // Smooth Scanning Guide
                AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: scanH * _scanAnimation.value,
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.85),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color borderColor;
  final double cornerLength;
  final double strokeWidth;

  _ViewfinderPainter({
    required this.borderColor,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final l = cornerLength;

    // Top Left
    canvas.drawLine(Offset(0, l), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(l, 0), paint);

    // Top Right
    canvas.drawLine(Offset(w - l, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, l), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, h - l), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(l, h), paint);

    // Bottom Right
    canvas.drawLine(Offset(w - l, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - l), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
