import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR service wrapping Google ML Kit Text Recognition.
///
/// Manages the [TextRecognizer] lifecycle and exposes simple methods
/// for extracting text from images.
class OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _instance {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  /// Recognises all text from the image at [imagePath].
  ///
  /// Returns the full recognised text as a single string.
  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognised = await _instance.processImage(inputImage);
    return recognised.text;
  }

  /// Recognises text and returns individual lines.
  ///
  /// Each element in the returned list is one line of recognised text.
  Future<List<String>> recognizeLines(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognised = await _instance.processImage(inputImage);

    final lines = <String>[];
    for (final block in recognised.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }
    return lines;
  }

  /// Releases the underlying native recognizer resources.
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

/// Riverpod provider for [OcrService].
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(() => service.dispose());
  return service;
});
