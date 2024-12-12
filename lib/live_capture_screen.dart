import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LiveCaptureScreen extends StatefulWidget {
  final File priorityImage;

  const LiveCaptureScreen({Key? key, required this.priorityImage})
      : super(key: key);

  @override
  _LiveCaptureScreenState createState() => _LiveCaptureScreenState();
}

class _LiveCaptureScreenState extends State<LiveCaptureScreen> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: false,
      enableLandmarks: true,
      enableTracking: true,
    ),
  );
  bool _isMatching = false;
  String _resultMessage = "Initializing...";
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _resultMessage = 'No camera found.');
        return;
      }
      _cameraController = CameraController(cameras[1], ResolutionPreset.medium);
      await _cameraController?.initialize();
      setState(() => _cameraInitialized = true);
    } catch (e) {
      setState(() => _resultMessage = 'Error initializing camera: $e');
    }
  }

  Future<void> _captureAndMatch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorMessage('Camera not initialized. Try again.');
      return;
    }

    setState(() {
      _isMatching = true;
      _resultMessage = 'Matching in progress...';
    });

    try {
      final capturedImage = await _cameraController!.takePicture();
      final liveImageFile = File(capturedImage.path);

      final uploadedFaceEmbeddings =
          await _extractFaceEmbeddings(widget.priorityImage);
      final liveFaceEmbeddings = await _extractFaceEmbeddings(liveImageFile);

      if (uploadedFaceEmbeddings == null || liveFaceEmbeddings == null) {
        _showErrorMessage('Could not detect faces in one or both images.');
        return;
      }

      final isMatch =
          _compareEmbeddings(uploadedFaceEmbeddings, liveFaceEmbeddings);
      setState(() {
        _resultMessage = isMatch ? 'Faces Match!' : 'Faces Do Not Match!';
      });
    } catch (e) {
      _showErrorMessage('An error occurred: $e');
    } finally {
      setState(() => _isMatching = false);
    }
  }

  Future<List<double>?> _extractFaceEmbeddings(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) return null;

    final face = faces.first;
    return _normalizeEmbedding(
      face.landmarks.values
          .where((landmark) => landmark != null && landmark.position != null)
          .map((landmark) => [
                landmark!.position!.x.toDouble(),
                landmark.position!.y.toDouble()
              ])
          .expand((coords) => coords)
          .toList(),
    );
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    final magnitude = sqrt(embedding.fold(0.0, (sum, val) => sum + val * val));
    return embedding.map((e) => e / (magnitude == 0 ? 1 : magnitude)).toList();
  }

  bool _compareEmbeddings(List<double> embedding1, List<double> embedding2) {
    const threshold = 0.89; // Increased threshold for stricter matching
    final similarity = _cosineSimilarity(embedding1, embedding2);
    return similarity > threshold;
  }

  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length) return 0.0;

    final dotProduct = vec1
        .asMap()
        .entries
        .fold(0.0, (sum, entry) => sum + entry.value * vec2[entry.key]);
    final magnitude1 = sqrt(vec1.fold(0.0, (sum, val) => sum + val * val));
    final magnitude2 = sqrt(vec2.fold(0.0, (sum, val) => sum + val * val));
    return dotProduct / (magnitude1 * magnitude2);
  }

  void _showErrorMessage(String message) {
    setState(() => _resultMessage = message);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Facial Verification',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Align your face in the center.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            _cameraInitialized
                ? Expanded(child: CameraPreview(_cameraController!))
                : const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isMatching ? null : _captureAndMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: Text(
                _isMatching ? 'Processing...' : 'Capture and Match',
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _resultMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
