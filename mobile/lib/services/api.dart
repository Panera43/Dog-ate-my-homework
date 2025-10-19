import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';

import '../models/task.dart';

class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  // ---- Tasks ----

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
    final res = await _dio.post(
      '/tasks/$id/complete',
      data: {'photo_url': photoUrl},
    );
    return Task.fromJson(Map<String, dynamic>.from(res.data['task']));
  }

  Future<void> deleteTask(String id) async {
    await _dio.delete('/tasks/$id');
  }

  // ---- Photos (S3 Presigned POST) ----
  //
  // Backend: POST /get-presigned-url
  // Response:
  // {
  //   "presigned_url": "https://<bucket>.s3.<region>.amazonaws.com",
  //   "fields": { ... },           // must be echoed back in the multipart POST
  //   "s3_url": "https://<bucket>.s3.<region>.amazonaws.com/<key>"
  // }
  //
  // Client then POSTs multipart form to presigned_url with:
  //   all "fields" + the file under field name "file"
  // If S3 returns 204/201, use s3_url as the photo URL.
  //
    Future<String> uploadPhoto(File file) async {
      // 1) Ask backend for a presigned POST
      final fileName = file.uri.pathSegments.last;
      final presign = await _dio.post(
        '/get-presigned-url',
        data: {'file_name': fileName},
      );

      final url = presign.data['presigned_url'] as String?; // S3 form endpoint
      final fields = Map<String, dynamic>.from(presign.data['fields'] as Map);
      final s3Url = presign.data['s3_url'] as String?;      // final public URL

      if (url == null || fields.isEmpty || s3Url == null) {
        throw Exception('Invalid presigned URL response');
      }

      // 2) Build a multipart form: all fields FIRST, then the file with key "file"
      final formMap = <String, dynamic>{...fields};
      formMap['file'] = await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      );
      final form = FormData.fromMap(formMap);

      // 3) POST directly to S3
      await Dio().post(
        url,
        data: form,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          // S3 wants no custom headers besides multipart defaults
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );

      // 4) Return the public S3 URL for saving in DynamoDB
      return s3Url;
    }

  
}
