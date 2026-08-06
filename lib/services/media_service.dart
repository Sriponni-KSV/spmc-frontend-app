import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class MediaService {
  /// Uploads file bytes directly to Cloudinary using an unsigned upload preset.
  /// Returns the secure URL of the uploaded asset, or throws an exception on failure.
  static Future<String?> uploadToCloudinary({
    required List<int> fileBytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3001/api';
      final Uri uploadUri = Uri.parse('$baseUrl/media/upload');

      // Determine resource type based on file extension (for content-type setting)
      final ext = fileName.split('.').last.toLowerCase();
      String resourceType = 'raw';
      if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
        resourceType = 'image';
      }

      final request = http.MultipartRequest('POST', uploadUri);
      
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }
      
      // Determine content type
      MediaType? contentType;
      if (resourceType == 'image') {
        contentType = MediaType('image', ext == 'jpg' ? 'jpeg' : ext);
      } else if (ext == 'pdf') {
        contentType = MediaType('application', 'pdf');
      }

      // Add file bytes to request
      final fileUpload = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: contentType,
      );
      
      request.files.add(fileUpload);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return decoded['secure_url'] as String?;
        } else {
          throw Exception(decoded['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server upload failed (Status: ${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }
}
