import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final RegExp _docketSerialRegex = RegExp(r'\b\d{6}\b');

  Future<String?> extractDocketSerial(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      // Look for a 6-digit number in the recognized text
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final match = _docketSerialRegex.firstMatch(line.text);
          if (match != null) {
            return match.group(0); // Return the first 6-digit number found
          }
        }
      }
      return null; // No docket serial found
    } catch (e) {
      print('Error in OCR processing: $e');
      return null;
    }
  }

  void dispose() {
    textRecognizer.close();
  }
}
