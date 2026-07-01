// lib/models/institution.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum InstitutionFeature {
  library, clubs, announcements, marks,
  timetable, attendance, chat, analytics,
  events, payments, assignments, courses,
}

extension InstitutionFeatureExt on InstitutionFeature {
  String get key => name;
}

class Institution {
  final String institutionId;
  final String schoolCode;
  final String schoolName;
  final String? logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String fontFamily;
  final String? bannerImage;
  final List<InstitutionFeature> enabledFeatures;
  final String? tagline;
  final String? contactEmail;
  final String? websiteUrl;
  final String? country;

  const Institution({
    required this.institutionId,
    required this.schoolCode,
    required this.schoolName,
    this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.fontFamily,
    this.bannerImage,
    required this.enabledFeatures,
    this.tagline,
    this.contactEmail,
    this.websiteUrl,
    this.country,
  });

  factory Institution.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final features = (d['enabledFeatures'] as List<dynamic>? ?? [])
        .map((f) => InstitutionFeature.values
            .firstWhere((e) => e.key == f.toString(),
                orElse: () => InstitutionFeature.library))
        .toList();
    return Institution(
      institutionId: doc.id,
      schoolCode: d['schoolCode'] ?? '',
      schoolName: d['schoolName'] ?? 'My School',
      logoUrl: d['logoUrl'],
      primaryColor: d['primaryColor'] ?? '#1A56DB',
      secondaryColor: d['secondaryColor'] ?? '#3B82F6',
      accentColor: d['accentColor'] ?? '#F59E0B',
      fontFamily: d['fontFamily'] ?? 'Inter',
      bannerImage: d['bannerImage'],
      enabledFeatures: features,
      tagline: d['tagline'],
      contactEmail: d['contactEmail'],
      websiteUrl: d['websiteUrl'],
      country: d['country'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'schoolCode': schoolCode, 'schoolName': schoolName, 'logoUrl': logoUrl,
    'primaryColor': primaryColor, 'secondaryColor': secondaryColor,
    'accentColor': accentColor, 'fontFamily': fontFamily,
    'bannerImage': bannerImage,
    'enabledFeatures': enabledFeatures.map((f) => f.key).toList(),
    'tagline': tagline, 'contactEmail': contactEmail,
    'websiteUrl': websiteUrl, 'country': country,
  };

  bool hasFeature(InstitutionFeature f) => enabledFeatures.contains(f);
  Color get primary   => _hexColor(primaryColor);
  Color get secondary => _hexColor(secondaryColor);
  Color get accent    => _hexColor(accentColor);

  static Color _hexColor(String hex) {
    final c = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.parse('FF$c', radix: 16));
  }

  String get poweredByLabel => '$schoolName powered by Academia';

  static Institution get fallback => const Institution(
    institutionId: 'default', schoolCode: '', schoolName: 'Academia',
    primaryColor: '#1A56DB', secondaryColor: '#3B82F6', accentColor: '#F59E0B',
    fontFamily: 'Inter', enabledFeatures: InstitutionFeature.values,
  );

  /// Branding used for Normal / Premium independent accounts — no school,
  /// so only the school-agnostic features are enabled. Note: HomeShell's
  /// "Courses" tab is currently unconditional regardless of feature flags
  /// (see app_router.dart _buildNav) — that's a known follow-up, not
  /// something this feature set can hide on its own yet.
  static Institution get independentDefault => const Institution(
    institutionId: 'independent', schoolCode: '', schoolName: 'Academia',
    tagline: 'Independent Member',
    primaryColor: '#0A1F44', secondaryColor: '#152D5E', accentColor: '#C9A227',
    fontFamily: 'Inter',
    enabledFeatures: [InstitutionFeature.library, InstitutionFeature.announcements],
  );
}
