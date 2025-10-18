class Task {
  final String id;
  final String title;
  final bool completed;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? completedAt;

  Task({
    required this.id,
    required this.title,
    required this.completed,
    this.photoUrl,
    this.createdAt,
    this.completedAt,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: (j['id'] ?? j['task-id']) as String,
        title: j['title'] as String,
        completed: (j['completed'] as bool?) ?? false,
        photoUrl: j['photo_url'] as String?,
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
        completedAt: j['completed_at'] != null ? DateTime.tryParse(j['completed_at']) : null,
      );
}
