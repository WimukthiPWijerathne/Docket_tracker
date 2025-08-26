import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Returns the path to the app's dockets storage directory.
/// Creates the directory if it doesn't exist.
Future<String> getAppStoragePath() async {
  // Get the application documents directory
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  
  // Create the dockets subfolder path
  final String docketsPath = '${appDocumentsDir.path}/dockets';
  
  // Create the directory if it doesn't exist
  final Directory docketsDir = Directory(docketsPath);
  if (!await docketsDir.exists()) {
    await docketsDir.create(recursive: true);
  }
  
  return docketsPath;
}
