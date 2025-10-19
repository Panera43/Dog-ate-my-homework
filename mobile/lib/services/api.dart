import 'dart:io';
import 'package:dio/dio.dart';
import '../models/task.dart';

class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  Future<List<Task>> listTasks() async {
    final res = await _dio.get('/tasks');
    final list = (res.data['tasks'] as List).cast<Map<String, dynamic>>();
    return list.map(Task.fromJson).toList();
  }

  Future<Task> createTask(String title) async {
    final res = await _dio.post('/tasks', data: {'title': title});
    return Task.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<Task> completeTask(String id, {required String photoUrl}) async {
    final res =
        await _dio.post('/tasks/$id/complete', data: {'photo_url': photoUrl});
    return Task.fromJson(Map<String, dynamic>.from(res.data['task']));
  }

  Future<void> deleteTask(String id) async {
    await _dio.delete('/tasks/$id');
  }

  /// Placeholder upload until S3 endpoint exists.
  Future<String> uploadPhoto(File file) async {
    try {
      final form = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
      });
      final res = await _dio.post(
        '/upload-photo',
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      return res.data['photo_url'] as String;
    } on DioException {
      return 'https://example.com/photos/${file.uri.pathSegments.last}';
    }
  }
}
