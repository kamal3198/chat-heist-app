import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/message.dart';
import 'api_service.dart';
import 'auth_service.dart';

class MessageService extends ApiService {
  final AuthService _authService = AuthService();

  // Get messages with a contact
  Future<List<Message>> getMessages(String contactId) async {
    try {
      final response = await get(
        '${ApiConfig.baseUrl}${ApiConfig.getMessages(contactId)}',
      );
      
      if (isSuccess(response)) {
        final data = parseResponse(response);
        final List messages = data['messages'] ?? [];
        return messages.map((json) => Message.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get messages error: $e');
      return [];
    }
  }

  // Mark messages as read
  Future<bool> markMessagesAsRead(String contactId) async {
    try {
      final response = await put(
        '${ApiConfig.baseUrl}${ApiConfig.markMessagesAsRead(contactId)}',
      );
      
      return isSuccess(response);
    } catch (e) {
      print('Mark as read error: $e');
      return false;
    }
  }

  Future<bool> deleteMessages(List<String> messageIds) async {
    try {
      final response = await post(
        '${ApiConfig.baseUrl}${ApiConfig.bulkDeleteMessages}',
        {'messageIds': messageIds},
      );
      return isSuccess(response);
    } catch (e) {
      print('Delete messages error: $e');
      return false;
    }
  }

  // Upload file
  Future<Map<String, dynamic>?> uploadFile(File file) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadFile}'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = parseResponse(http.Response(responseData, response.statusCode));
        return {
          'fileUrl': data['fileUrl'],
          'fileName': data['fileName'],
          'fileType': data['fileType'],
        };
      }
      print('Upload file failed: ${response.statusCode} $responseData');
      return null;
    } catch (e) {
      print('Upload file error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadFileBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadFile}'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      final resolvedMime = mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(resolvedMime),
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = parseResponse(http.Response(responseData, response.statusCode));
        return {
          'fileUrl': data['fileUrl'],
          'fileName': data['fileName'],
          'fileType': data['fileType'],
        };
      }

      print('Upload bytes failed: ${response.statusCode} $responseData');
      return null;
    } catch (e) {
      print('Upload bytes error: $e');
      return null;
    }
  }
}
