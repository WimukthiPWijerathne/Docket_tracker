import 'package:http/http.dart' as http;

void main() async {
  final testUrls = [
    'https://powerprox.sltidc.lk/docket_images/3/EST_20250901_091554.jpg',
    'https://powerprox.sltidc.lk:8000/docket_images/3/EST_20250901_091554.jpg',
  ];

  for (var url in testUrls) {
    print('Testing URL: $url');
    try {
      final response = await http.get(Uri.parse(url));
      print('Status Code: ${response.statusCode}');
      print('Content Type: ${response.headers['content-type']}');
      print('Content Length: ${response.bodyBytes.length} bytes\n');
    } catch (e) {
      print('Error: $e\n');
    }
  }
}
