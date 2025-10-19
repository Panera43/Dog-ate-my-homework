import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/task.dart';
import '../providers.dart'; // for apiClientProvider

// Loads the list (used by the screen + invalidated after actions)
final tasksFutureProvider = FutureProvider<List<Task>>((ref) async {
  final api = ref.read(apiClientProvider);
  return api.listTasks();
});

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _titleCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).createTask(_titleCtrl.text.trim());
      _titleCtrl.clear();
      ref.invalidate(tasksFutureProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeWithPhoto(Task t) async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
      );
      if (x == null) return;
      final file = File(x.path);
      final api = ref.read(apiClientProvider);
      final photoUrl = await api.uploadPhoto(file);
      await api.completeTask(t.id, photoUrl: photoUrl);
      ref.invalidate(tasksFutureProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task completed!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Task t) async {
    // called after the swipe confirmation
    try {
      await ref.read(apiClientProvider).deleteTask(t.id);
      ref.invalidate(tasksFutureProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${t.title}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dog Ate My Homework')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    decoration:
                        const InputDecoration(hintText: 'New task title...'),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => ListView.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final t = tasks[i];
                  return Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red.withOpacity(0.15),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Icon(Icons.delete),
                    ),
                    confirmDismiss: (_) async {
                      if (_busy) return false;
                      return await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete task?'),
                              content: Text(
                                  'This will permanently remove "${t.title}".'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) => _delete(t),
                    child: ListTile(
                      title: Text(t.title),
                      subtitle: Text(t.completed ? 'Completed' : 'Open'),
                      trailing: t.completed
                          ? const Icon(Icons.check, color: Colors.green)
                          : FilledButton(
                              onPressed:
                                  _busy ? null : () => _completeWithPhoto(t),
                              child: const Text('Add Photo & Complete'),
                            ),
                    ),
                  );
                },
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
