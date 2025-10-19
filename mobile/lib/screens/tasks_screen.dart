import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/task.dart';
import '../providers.dart';

/// Local palette to keep this file standalone
class _C {
  static const background = Colors.white;
  static const primary    = Color(0xFF008CBB); // buttons
  static const card       = Color(0xFF9DC4D1); // dog card
  static const textDark   = Color(0xFF1B1B1B);
}

/// Shared loader so PhotosScreen can import it if needed
final tasksFutureProvider = FutureProvider<List<Task>>((ref) async {
  final api = ref.read(apiClientProvider);
  return api.listTasks();
});

/// AppBar title with larger logo + custom slogan font
class _KibbleAppBarTitle extends StatelessWidget {
  const _KibbleAppBarTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/logo/logo.png', height: 56, fit: BoxFit.contain),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '“My dog ate my HW”',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Joongnajoche', // requires pubspec entry below
                  fontSize: 18,
                  color: _C.textDark,
                ),
          ),
        ),
      ],
    );
  }
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _titleCtrl = TextEditingController();
  bool _busy = false;

  int _lastStageIndex = -1;

  static const _dogStages = <String>[
    'assets/dog/0_puppy.png',
    'assets/dog/1_sit.png',
    'assets/dog/2_play.png',
    'assets/dog/3_grown.png',
  ];

  // grow every 2 completions
  int _stageIndexFor(int totalFed) => ((totalFed ~/ 2) % 4);

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

      final api = ref.read(apiClientProvider);
      final photoUrl = await api.uploadPhoto(file);
      await api.completeTask(t.id, photoUrl: photoUrl);

      await ref.read(totalFedProvider.notifier).increment();
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
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  Widget _growthHeader(int totalFed) {
    final stage = _stageIndexFor(totalFed);
    final asset = _dogStages[stage];
    final label = _stageLabel(stage);
    final progressWithinStage = (totalFed % 2) / 2.0;

    if (_lastStageIndex == 3 && stage == 0 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dog fully grown! New pup adopted 🐕✨')),
        );
      });
    }
    _lastStageIndex = stage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Card(
        elevation: 0,
        color: _C.card, // new card color
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: Center(child: Image.asset(asset, fit: BoxFit.contain)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Kibble progress', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text('$totalFed fed', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progressWithinStage,
                  backgroundColor: Colors.white.withOpacity(.6),
                  color: _C.primary,
                ),
              ),
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksFutureProvider);
    final totalFed = ref.watch(totalFedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const _KibbleAppBarTitle(),
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
              _growthHeader(totalFed),
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
                        subtitle: Text(t.completed ? 'Kibble fed' : 'Feed kibble'),
                        trailing: t.completed
                            ? const Icon(Icons.check, color: Colors.green)
                            : _BoneButton(
                                label: 'Add Photo',
                                width: 150,
                                height: 44,
                                onPressed: _busy ? null : () => _completeWithPhoto(t),
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
              _BoneButton(
                label: 'Add kibble',
                width: 170,
                height: 56,
                onPressed: _busy ? null : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bone-styled button with readable text
class _BoneButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;

  const _BoneButton({
    required this.label,
    required this.onPressed,
    this.width = 160,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: enabled ? _C.primary : _C.primary.withOpacity(.4),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: .95,
              child: Image.asset(
                'assets/ui/bone.png',
                width: width * .72,
                height: height * .7,
                fit: BoxFit.contain,
              ),
            ),
            Text(
              label,
              // Dark text so it doesn't vanish over the white bone
              style: const TextStyle(
                color: _C.textDark,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(offset: Offset(0, 0), blurRadius: 1.2, color: Colors.white70),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
