// lib/models/school_config.dart

class SchoolConfig {
  final String id;
  final String name;
  final String motto;
  final String academicYear;
  final String? logoUrl;
  final String? country;
  final String? city;

  const SchoolConfig({
    required this.id,
    required this.name,
    required this.motto,
    required this.academicYear,
    this.logoUrl,
    this.country,
    this.city,
  });

  factory SchoolConfig.fromFirestore(String id, Map<String, dynamic> d) =>
      SchoolConfig(
        id: id,
        name: d['name'] ?? '',
        motto: d['motto'] ?? '',
        academicYear: d['academicYear'] ?? '',
        logoUrl: d['logoUrl'],
        country: d['country'],
        city: d['city'],
      );

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'motto': motto,
    'academicYear': academicYear,
    'logoUrl': logoUrl,
    'country': country,
    'city': city,
  };
}
