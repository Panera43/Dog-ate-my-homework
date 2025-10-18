import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiConfig {
  // Override at runtime:
  // flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000',
  );

  static const defaultHeaders = <String, String>{};
}

final baseUrlProvider = Provider<String>((_) => ApiConfig.baseUrl);
