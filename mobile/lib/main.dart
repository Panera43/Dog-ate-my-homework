import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/tasks_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dog Ate My Homework',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const TasksScreen(),
    );
  }
}
