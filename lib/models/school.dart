// lib/models/school.dart
// The school registry — architecture brief item 4: "Do not hard-code
// Green Hills as the only possible school."
//
// Supabase: this is NOT a new table. It's public.institutions, the same
// table academia-cameroon's Institution model reads (id, school_code,
// school_name, created_at — see supabase/migrations/20260828060000
// and .../20260829160000_institutions_branding_columns.sql). Reusing it
// keeps one school-identity table in this shared multi-tenant database;
// see supabase/migrations/20260829370000_school_vouchers.sql's header
// for the reasoning.

class School {
  final String id;

  /// Short, human-typed prefix used inside every voucher code for this
  /// school (e.g. "GH" for Green Hills) — see school_voucher.dart. Stored
  /// uppercase; unique across institutions (institutions.school_code has
  /// a unique constraint).
  final String code;

  final String name;
  final DateTime createdAt;

  const School({
    required this.id,
    required this.code,
    required this.name,
    required this.createdAt,
  });

  factory School.fromSupabase(Map<String, dynamic> d) => School(
        id: d['id'] as String,
        code: (d['school_code'] ?? '').toString().toUpperCase(),
        name: d['school_name'] ?? '',
        createdAt: d['created_at'] != null
            ? DateTime.tryParse(d['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toSupabase() => {
        'school_code': code.toUpperCase(),
        'school_name': name,
      };
}
