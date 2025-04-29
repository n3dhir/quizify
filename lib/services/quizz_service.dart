import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart'; // Needed for mime types
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<String?> uploadImageToBytescale(
    dynamic image, String quizId, int index) async {
  final String uploadUrl = dotenv.env['BYTESCALE_API_URL']!;
  final String apiKey = dotenv.env['BYTESCALE_API_KEY']!;

  try {
    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.headers['Authorization'] = 'Bearer $apiKey';

    // Add the file depending on platform
    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        image,
        filename: 'question_$index.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        image.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final fileUrl = RegExp(r'"fileUrl"\s*:\s*"([^"]+)"')
          .firstMatch(responseBody)
          ?.group(1);
      return fileUrl;
    } else {
      print('Upload failed with status: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Bytescale upload error: $e');
    return null;
  }
}
