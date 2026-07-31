import 'package:flutter/material.dart';

/// Data passed into every snapshot module — kept generic so the same
/// widget shape works whether the value is "96%", "Mathematics", or
/// "2 New". Fetch the right numbers from Firestore per module type
/// and hand them to the card; the card itself never knows *why*.
class SnapshotModuleData {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  const SnapshotModuleData({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
  });
}

/// One rounded card, matching the existing "School Snapshot" cards
/// (icon chip, title, big value, subtitle). Same widget renders
/// attendance for a school student or "Learning Streak" for an
/// independent learner — only the data passed in differs.
class SnapshotCard extends StatelessWidget {
  final SnapshotModuleData data;

  const SnapshotCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.title,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 26,
              backgroundColor: data.iconBackground,
              child: Icon(data.icon, color: data.iconColor, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              data.value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (data.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                data.subtitle!,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The registry: module id (as returned by the backend) -> a builder
/// that fetches/derives its data. Adding a new org type or a new
/// module never touches the homepage widget tree — just add an
/// entry here and return it from the backend's `snapshotModules` list.
typedef ModuleBuilder = SnapshotModuleData Function(BuildContext context);

class SnapshotModuleRegistry {
  static final Map<String, ModuleBuilder> _builders = {
    // School
    'attendance': (context) => const SnapshotModuleData(
          icon: Icons.check_circle,
          iconColor: Colors.green,
          iconBackground: Color(0xFFE8F5E9),
          title: 'Attendance',
          value: '96%',
          subtitle: 'Present Today',
        ),
    'next_class': (context) => const SnapshotModuleData(
          icon: Icons.menu_book,
          iconColor: Colors.deepPurple,
          iconBackground: Color(0xFFEDE7F6),
          title: "Tomorrow's First Class",
          value: '08:00 AM',
          subtitle: 'Mathematics · Room 12',
        ),
    'homework': (context) => const SnapshotModuleData(
          icon: Icons.assignment,
          iconColor: Colors.deepOrange,
          iconBackground: Color(0xFFFBE9E7),
          title: 'Homework',
          value: 'Physics Assignment',
          subtitle: 'Due Tomorrow',
        ),
    'announcements': (context) => const SnapshotModuleData(
          icon: Icons.campaign,
          iconColor: Colors.blue,
          iconBackground: Color(0xFFE3F2FD),
          title: 'Announcements',
          value: '2 New',
          subtitle: 'See all',
        ),

    // Independent learner
    'continue_learning': (context) => const SnapshotModuleData(
          icon: Icons.menu_book,
          iconColor: Colors.deepPurple,
          iconBackground: Color(0xFFEDE7F6),
          title: 'Continue Reading',
          value: 'Modern Physics',
          subtitle: 'Page 48',
        ),
    'daily_goal': (context) => const SnapshotModuleData(
          icon: Icons.flag,
          iconColor: Colors.teal,
          iconBackground: Color(0xFFE0F2F1),
          title: 'Daily Goal',
          value: 'Read 20 Pages',
        ),
    'upcoming': (context) => const SnapshotModuleData(
          icon: Icons.quiz,
          iconColor: Colors.deepOrange,
          iconBackground: Color(0xFFFBE9E7),
          title: 'Upcoming',
          value: 'Chemistry Quiz',
          subtitle: '7 PM',
        ),
    'learning_streak': (context) => const SnapshotModuleData(
          icon: Icons.local_fire_department,
          iconColor: Colors.orange,
          iconBackground: Color(0xFFFFF3E0),
          title: 'Streak',
          value: '12 Days',
        ),

    // University
    'lecture': (context) => const SnapshotModuleData(
          icon: Icons.school,
          iconColor: Colors.indigo,
          iconBackground: Color(0xFFE8EAF6),
          title: 'Next Lecture',
          value: 'Thermodynamics',
        ),
    'exam_schedule': (context) => const SnapshotModuleData(
          icon: Icons.event_note,
          iconColor: Colors.redAccent,
          iconBackground: Color(0xFFFFEBEE),
          title: 'Exam Schedule',
          value: 'View Dates',
        ),

    // Corporate
    'assigned_training': (context) => const SnapshotModuleData(
          icon: Icons.work,
          iconColor: Colors.brown,
          iconBackground: Color(0xFFEFEBE9),
          title: 'Assigned Training',
          value: 'Compliance 101',
        ),
    'certificate_progress': (context) => const SnapshotModuleData(
          icon: Icons.workspace_premium,
          iconColor: Colors.amber,
          iconBackground: Color(0xFFFFF8E1),
          title: 'Certificate Progress',
          value: '3/5 Modules',
        ),
  };

  /// Register or override a module builder at runtime (e.g. once real
  /// Firestore-backed data fetchers are ready to replace the stubs above).
  static void register(String moduleId, ModuleBuilder builder) {
    _builders[moduleId] = builder;
  }

  static SnapshotModuleData? build(BuildContext context, String moduleId) {
    final builder = _builders[moduleId];
    return builder?.call(context);
  }
}
