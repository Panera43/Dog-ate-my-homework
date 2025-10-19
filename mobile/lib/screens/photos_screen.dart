import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import 'tasks_screen.dart' show tasksFutureProvider; // <- shared loader

class PhotosScreen extends ConsumerWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meals Fed')),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          final withPhotos = tasks
              .where((t) => t.completed && t.photoUrl != null && t.photoUrl!.startsWith('http'))
              .toList();

          if (withPhotos.isEmpty) {
            return const Center(child: Text('No meals yet. Feed some kibble with a photo!'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: withPhotos.length,
            itemBuilder: (_, i) {
              final Task t = withPhotos[i];
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: t.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(
                        color: Color(0x11000000),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0x11FF0000),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    Positioned(
                      left: 6, bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54, borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          t.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
