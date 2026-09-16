import re

with open('lib/models/app_user.dart', 'r') as f:
    content = f.read()

# Add import
content = content.replace("import 'teaching_assignment.dart';", "import 'teaching_assignment.dart';\nimport 'school_membership.dart';")

# Add field
content = re.sub(
    r'(final String\? schoolId;)',
    r'\1\n  final String? activeSchoolId;\n  final List<SchoolMembership> schoolMemberships;',
    content
)

# Add to constructor
content = re.sub(
    r'(this\.schoolId,)',
    r'\1\n    this.activeSchoolId,\n    this.schoolMemberships = const [],',
    content
)

# Update copyWith
content = re.sub(
    r'(String\? schoolId, )(String\? serialNumber,)',
    r'\1String? activeSchoolId, List<SchoolMembership>? schoolMemberships, \2',
    content
)
content = re.sub(
    r'(schoolId: schoolId \?\? this\.schoolId,)',
    r'\1\n    activeSchoolId: activeSchoolId ?? this.activeSchoolId,\n    schoolMemberships: schoolMemberships ?? this.schoolMemberships,',
    content
)

# Update fromSupabase
content = re.sub(
    r"schoolId: d\['institution_id'\],",
    r"schoolId: d['institution_id'],\n    activeSchoolId: d['institution_id'],\n    schoolMemberships: (d['school_memberships'] as List<dynamic>? ?? []).map((m) => SchoolMembership.fromSupabase(Map<String, dynamic>.from(m as Map))).toList(),",
    content
)

# Update toSupabase
content = re.sub(
    r"'institution_id': schoolId,",
    r"'institution_id': schoolId,\n    'school_memberships': schoolMemberships.map((m) => m.toSupabase()).toList(),",
    content
)

# We also need to add logic: if there is an active membership, maybe the getters return its values.
# But for now, just adding the array is the core part of the model refactor.

with open('lib/models/app_user.dart', 'w') as f:
    f.write(content)
print("AppUser updated.")
