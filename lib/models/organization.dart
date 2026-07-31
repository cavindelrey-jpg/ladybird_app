import 'package:flutter/material.dart';

/// The organization type determines which snapshot modules, nav tabs,
/// and content sections render. Add new types here as Academia expands
/// into new verticals (university, corporate, etc.) — no new screens
/// needed elsewhere, just a new case in the module registry.
enum OrganizationType {
  independent, // no organization — plain Academia experience
  school,
  university,
  corporate,
}

OrganizationType organizationTypeFromString(String? value) {
  switch (value) {
    case 'school':
      return OrganizationType.school;
    case 'university':
      return OrganizationType.university;
    case 'corporate':
      return OrganizationType.corporate;
    default:
      return OrganizationType.independent;
  }
}

/// Everything the UI needs to "become" a school's app. Loaded once at
/// login/app-start from Firestore (`organizations/{orgId}`) and never
/// hardcoded per-school in the app itself.
class OrganizationTheme {
  final String name;
  final String? shortName;
  final String? logoUrl;
  final String? bannerUrl;
  final String? faviconUrl;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String welcomeMessage;
  final String subtitle; // e.g. "Powered by Academia"

  const OrganizationTheme({
    required this.name,
    this.shortName,
    this.logoUrl,
    this.bannerUrl,
    this.faviconUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.welcomeMessage,
    this.subtitle = 'Powered by Academia',
  });

  /// The default Academia identity for independent (non-school) users.
  factory OrganizationTheme.academiaDefault() => const OrganizationTheme(
        name: 'Academia',
        logoUrl: 'assets/branding/academia_logo.png',
        primaryColor: Color(0xFF4F46E5),
        secondaryColor: Color(0xFF7C3AED),
        accentColor: Color(0xFFF59E0B),
        welcomeMessage: 'Your Learning Platform',
        subtitle: '',
      );

  factory OrganizationTheme.fromMap(Map<String, dynamic> map) {
    Color parseColor(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    }

    return OrganizationTheme(
      name: map['name'] ?? 'Academia',
      shortName: map['shortName'],
      logoUrl: map['logo'],
      bannerUrl: map['banner'],
      faviconUrl: map['favicon'],
      primaryColor: parseColor(map['primaryColor'], const Color(0xFF4F46E5)),
      secondaryColor:
          parseColor(map['secondaryColor'], const Color(0xFF7C3AED)),
      accentColor: parseColor(map['accentColor'], const Color(0xFFF59E0B)),
      welcomeMessage: map['welcomeMessage'] ?? '',
      subtitle: map['subtitle'] ?? 'Powered by Academia',
    );
  }
}

/// The organization record itself — identity + which snapshot/nav
/// modules the backend says this org's users should see.
class Organization {
  final String id;
  final OrganizationType type;
  final OrganizationTheme theme;
  final List<String> snapshotModules; // e.g. ["attendance","next_class",...]
  final List<String> navTabs; // e.g. ["home","learn","school","profile"]

  const Organization({
    required this.id,
    required this.type,
    required this.theme,
    required this.snapshotModules,
    required this.navTabs,
  });

  /// The "no organization" state — plain independent-learner Academia.
  factory Organization.independent() => Organization(
        id: 'academia',
        type: OrganizationType.independent,
        theme: OrganizationTheme.academiaDefault(),
        snapshotModules: const [
          'continue_learning',
          'daily_goal',
          'upcoming',
          'learning_streak',
        ],
        navTabs: const ['home', 'learn', 'profile'],
      );

  factory Organization.fromFirestore(
      String id, Map<String, dynamic> data) {
    final type = organizationTypeFromString(data['type'] as String?);
    return Organization(
      id: id,
      type: type,
      theme: OrganizationTheme.fromMap(
          Map<String, dynamic>.from(data['theme'] ?? {})),
      snapshotModules: List<String>.from(
          data['snapshotModules'] ?? _defaultModulesFor(type)),
      navTabs: List<String>.from(
          data['navTabs'] ?? ['home', 'learn', 'school', 'profile']),
    );
  }

  static List<String> _defaultModulesFor(OrganizationType type) {
    switch (type) {
      case OrganizationType.school:
        return ['attendance', 'next_class', 'homework', 'announcements'];
      case OrganizationType.university:
        return ['lecture', 'exam_schedule', 'assignment', 'notice'];
      case OrganizationType.corporate:
        return [
          'assigned_training',
          'deadline',
          'manager_feedback',
          'certificate_progress'
        ];
      case OrganizationType.independent:
        return ['continue_learning', 'daily_goal', 'upcoming', 'learning_streak'];
    }
  }
}
