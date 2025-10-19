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
    // 1) Ask backend for presigned POST
    final filename = file.uri.pathSegments.last;
    final presignRes = await _dio.post(
      '/get-presigned-url',
      data: {'file_name': filename},
    );

    final data = Map<String, dynamic>.from(presignRes.data);
    final String uploadUrl = data['presigned_url'] as String;
    final Map<String, dynamic> fields =
        Map<String, dynamic>.from(data['fields'] as Map);
    final String s3Url = data['s3_url'] as String;

    // 2) Build multipart with ALL returned fields + file under 'file'
    final form = FormData();
    fields.forEach((k, v) => form.fields.add(MapEntry(k, v.toString())));
    form.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(
          file.path,
          filename: filename,
        ),
      ),
    );

    // 3) POST directly to S3. Use a raw Dio with NO baseUrl/headers.
    final rawDio = Dio();
    await rawDio.post(
      uploadUrl,
      data: form,
      options: Options(
        contentType: Headers.multipartFormDataContentType,
        headers: {}, // no auth headers for S3 presigned POST
        followRedirects: false,
        validateStatus: (s) => s != null && s >= 200 && s < 400, // accept 2xx/3xx
      ),
    );

    // 4) Return the public S3 URL to store in your task
    return s3Url;
  }
}
