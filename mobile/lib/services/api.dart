import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers.dart';

final apiProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json', ...ApiConfig.defaultHeaders},
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
  return ApiClient(dio);
});

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

  Future<void> deleteTask(String id) async {
    await _dio.delete('/tasks/$id');
  }

  Future<Task> completeTask(String id, {required String photoUrl}) async {
    final res = await _dio.post('/tasks/$id/complete', data: {'photo_url': photoUrl});
    return Task.fromJson(Map<String, dynamic>.from(res.data['task']));
  }

  Future<String> uploadPhoto(File file) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });
    final res = await _dio.post('/upload-photo', data: form,
        options: Options(contentType: Headers.multipartFormDataContentType));
    return res.data['photo_url'] as String;
  }
}
