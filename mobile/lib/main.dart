import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/tasks_screen.dart';
import 'screens/photos_screen.dart';

/// Brand palette (updated)
class AppColors {
  static const background = Colors.white;          // white background
  static const primary    = Color(0xFF008CBB);     // buttons
  static const card       = Color(0xFF9DC4D1);     // dog card
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Kibble',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme.copyWith(primary: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const TasksScreen(),
      routes: {
        '/photos': (_) => const PhotosScreen(),
      },
    );
  }
}
