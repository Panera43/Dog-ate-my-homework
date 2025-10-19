import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/task.dart';
import 'services/api.dart';

class ApiConfig {
  // Override at run:
  // flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000',
  );

  static const defaultHeaders = <String, String>{};
}

final baseUrlProvider = Provider<String>((_) => ApiConfig.baseUrl);

/// Builds the ApiClient with the configured base URL.
final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: {'Content-Type': 'application/json', ...ApiConfig.defaultHeaders},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  return ApiClient(dio);
});

/// Task list (server-backed) using Riverpod's Notifier.
class TaskList extends Notifier<List<Task>> {
  late final ApiClient _api = ref.read(apiClientProvider);

  @override
  List<Task> build() {
    // Build must be sync; kick off async load immediately.
    Future.microtask(_load);
    return const <Task>[];
  }

  Future<void> _load() async {
    final items = await _api.listTasks();
    state = items;
  }

  Future<void> refresh() => _load();

  Future<void> create(String title) async {
    final t = await _api.createTask(title);
    state = <Task>[t, ...state];
  }

  Future<void> complete(String id, {String? photoUrl}) async {
    final updated = await _api.completeTask(
      id,
      photoUrl: photoUrl ?? 'https://example.com/photos/placeholder.jpg',
    );
    state = [for (final t in state) if (t.id == id) updated else t];
  }

  Future<void> deleteById(String id) async {
    await _api.deleteTask(id);
    state = [for (final t in state) if (t.id != id) t];
  }
}

/// Public provider the UI watches (list of tasks).
final taskListProvider = NotifierProvider<TaskList, List<Task>>(TaskList.new);

/// ---------- Local "Hide" (archive) store so gallery keeps photos ----------
const _hiddenKey = 'hidden_task_ids';

class HiddenIds extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    Future.microtask(_load);
    return <String>{};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_hiddenKey) ?? const <String>[];
    state = list.toSet();
  }

  Future<void> hide(String id) async {
    final next = {...state, id};
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenKey, next.toList());
  }

  Future<void> unhide(String id) async {
    final next = {...state}..remove(id);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenKey, next.toList());
  }

  Future<void> clearAll() async {
    state = <String>{};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hiddenKey);
  }
}

final hiddenIdsProvider = NotifierProvider<HiddenIds, Set<String>>(HiddenIds.new);
