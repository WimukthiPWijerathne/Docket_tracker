import 'dart:developer' as developer;

import 'package:image_picker/image_picker.dart';

/// Opens the device camera for the given [docketType] and returns the captured
/// image as an [XFile]. Returns `null` if the user cancels or an error occurs.
Future<XFile?> openCameraForDocket(String docketType) async {
  developer.log(
    'Opening camera for docket type: $docketType',
    name: 'DocketCamera',
  );

  final ImagePicker imagePicker = ImagePicker();
  try {
    final XFile? captured = await imagePicker.pickImage(
      source: ImageSource.camera,
    );
    return captured; // null if user cancelled
  } catch (error, stackTrace) {
    developer.log(
      'Error opening camera for $docketType: $error',
      name: 'DocketCamera',
      stackTrace: stackTrace,
    );
    return null;
  }
}
