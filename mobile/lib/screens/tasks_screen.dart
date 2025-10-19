import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/task.dart';
import '../providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _titleCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(taskListProvider.notifier).create(title);
      _titleCtrl.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeWithPhoto(Task t) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
      );
      if (picked == null) return;

      final api = ref.read(apiClientProvider);
      final photoUrl = await api.uploadPhoto(File(picked.path));
      await ref.read(taskListProvider.notifier).complete(t.id, photoUrl: photoUrl);

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

  Future<bool> _confirmHide(Task t) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Hide task from list?'),
            content: Text('This hides "${t.title}" from the list but keeps its photo in the gallery.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hide')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskListProvider);
    final hidden = ref.watch(hiddenIdsProvider);

    final visibleTasks = tasks.where((t) => !hidden.contains(t.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dog Ate My Homework'),
        actions: [
          IconButton(
            tooltip: 'Photos',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/photos'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(hintText: 'New task title...'),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _create, child: const Text('Add')),
              ],
            ),
          ),
          if (visibleTasks.isEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
                child: ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No tasks (or all hidden). Pull to refresh.')),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
                child: ListView.separated(
                  itemCount: visibleTasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = visibleTasks[i];
                    return Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.orange,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.archive_outlined, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Hide', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      confirmDismiss: (_) => _confirmHide(t),
                      onDismissed: (_) async {
                        await ref.read(hiddenIdsProvider.notifier).hide(t.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hidden "${t.title}". Photo kept in gallery.')),
                          );
                        }
                      },
                      child: ListTile(
                        title: Text(t.title),
                        subtitle: Text(t.completed ? 'Completed' : 'Open'),
                        trailing: t.completed
                            ? const Icon(Icons.check, color: Colors.green)
                            : FilledButton(
                                onPressed: _busy ? null : () => _completeWithPhoto(t),
                                child: const Text('Add Photo & Complete'),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
