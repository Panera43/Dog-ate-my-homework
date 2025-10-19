// lib/screens/tasks_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/task.dart';
import '../providers.dart';

/// Shared loader so PhotosScreen can import it.
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

  // Remember the last shown stage so we can detect wrap-around.
  int _lastStageIndex = -1;

  // Map stage index (0..3) to asset path — in proper visual order.
  static const _dogStages = <String>[
    'assets/dog/0_puppy.png',
    'assets/dog/1_sit.png',
    'assets/dog/2_play.png',
    'assets/dog/3_grown.png',
  ];

  // Given totalFed (monotonic), each 3 feeds advances one stage. Loops every 12.
  int _stageIndexFor(int totalFed) => ((totalFed ~/ 3) % 4);

  String _stageLabel(int stage) => switch (stage) {
        0 => 'Tiny pup',
        1 => 'Learning tricks',
        2 => 'Playful pupper',
        _ => 'Legendary pupper',
      };

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).createTask(title);
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
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2000);
      if (picked == null) return;

      final file = File(picked.path);

      // Upload + complete on server
      final api = ref.read(apiClientProvider);
      final photoUrl = await api.uploadPhoto(file);
      await api.completeTask(t.id, photoUrl: photoUrl);

      // ✅ bump total-fed (dog never shrinks)
      await ref.read(totalFedProvider.notifier).increment();

      // Refresh task list
      ref.invalidate(tasksFutureProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kibble fed!')),
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

  Future<bool> _confirmDelete(Task t) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete kibble task?'),
            content: Text('This will remove "${t.title}". (Photos remain in Meals Fed.)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _growthHeader(int totalFed) {
    final stage = _stageIndexFor(totalFed);
    final asset = _dogStages[stage];
    final label = _stageLabel(stage);
    final progressWithinStage = (totalFed % 3) / 3.0;

    // Detect wrap back to puppy (3 -> 0)
    if (_lastStageIndex == 3 && stage == 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dog fully grown! New pup adopted 🐕✨'),
        ));
      });
    }
    _lastStageIndex = stage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Image first (centered, a bit smaller to avoid clipping)
              SizedBox(
                height: 160, // slightly larger but still safe from cropping
                child: Center(
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Title + count
              Row(
                children: [
                  Text('Kibble progress',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text('$totalFed fed',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar beneath image
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progressWithinStage,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksFutureProvider);
    final totalFed = ref.watch(totalFedProvider); // 👈 drives the dog UI (never decreases)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kibble — My Dog Ate My Homework'),
        actions: [
          IconButton(
            tooltip: 'Meals Fed',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/photos'),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          return Column(
            children: [
              _growthHeader(totalFed),           // <-- now driven by totalFedProvider
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = tasks[i];
                    return Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _confirmDelete(t),
                      onDismissed: (_) async {
                        try {
                          await ref.read(apiClientProvider).deleteTask(t.id);
                          ref.invalidate(tasksFutureProvider);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted "${t.title}"')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
                            );
                          }
                        }
                      },
                      child: ListTile(
                        title: Text(t.title),
                        subtitle:
                            Text(t.completed ? 'Kibble fed' : 'Feed kibble'),
                        trailing: t.completed
                            ? const Icon(Icons.check, color: Colors.green)
                            : FilledButton(
                                onPressed:
                                    _busy ? null : () => _completeWithPhoto(t),
                                child: const Text('Add Photo & Feed'),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      // Add box at the bottom (near system home bar)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'New kibble task...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: const Text('Add kibble'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
