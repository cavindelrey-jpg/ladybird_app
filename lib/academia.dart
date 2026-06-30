// lib/academia.dart
// Main barrel file: export the entire Academia module architecture.
// Usage in your main app:
//   import 'package:academia/academia.dart';
//   
// Components:
//   - Models: Institution, AcademicContent, AppUser
//   - Repositories: Institution, AcademicContent (singleton pattern)
//   - Providers: InstitutionProvider (ChangeNotifier)
//   - Features: Institution setup, Academic content library
//   - Theme: Institution theme engine, color palette
//   - Core: Constants, Result type, Debouncer

// Core
export 'core/core.dart';

// Models
export 'models/models.dart';

// Repositories
export 'repositories/repositories.dart';

// Providers
export 'providers/providers.dart';

// Theme
export 'theme/theme.dart';

// Features
export 'features/features.dart';

// Router
export 'screens/app_router.dart';
