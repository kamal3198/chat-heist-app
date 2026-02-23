import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/message.dart';
import 'api_service.dart';
import 'auth_service.dart';

class MessageService extends ApiService {
  final AuthService _authService = AuthService();

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

  Future<Map<String, dynamic>?> uploadFile(File file) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadFile}');
      var headers = await _authService.requiredAuthHeaders(includeContentType: false);
      var hasRetried = false;

      var response = await _sendFileMultipart(
        uri: uri,
        headers: headers,
        file: file,
      );

      if (response.statusCode == 401 && !hasRetried) {
        hasRetried = true;
        await _authService.getFirebaseIdToken(forceRefresh: true);
        headers = await _authService.requiredAuthHeaders(includeContentType: false);
        response = await _sendFileMultipart(
          uri: uri,
          headers: headers,
          file: file,
        );
      }

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
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadFile}');
      var headers = await _authService.requiredAuthHeaders(includeContentType: false);
      var hasRetried = false;

      var response = await _sendBytesMultipart(
        uri: uri,
        headers: headers,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );

      if (response.statusCode == 401 && !hasRetried) {
        hasRetried = true;
        await _authService.getFirebaseIdToken(forceRefresh: true);
        headers = await _authService.requiredAuthHeaders(includeContentType: false);
        response = await _sendBytesMultipart(
          uri: uri,
          headers: headers,
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        );
      }

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

  Future<http.StreamedResponse> _sendFileMultipart({
    required Uri uri,
    required Map<String, String> headers,
    required File file,
  }) async {
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);

    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ),
    );

    return request.send();
  }

  Future<http.StreamedResponse> _sendBytesMultipart({
    required Uri uri,
    required Map<String, String> headers,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);

    final resolvedMime = mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(resolvedMime),
      ),
    );

    return request.send();
  }
}
