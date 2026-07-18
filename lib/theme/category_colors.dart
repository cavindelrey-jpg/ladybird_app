// lib/theme/category_colors.dart
// Magazine and Courses each defined their own private
// `Map<String, Color>` plus an identical `label ?? C.primary` fallback
// lookup function — same pattern, copy-pasted, different data. This is
// the one shared version both now use. The actual category->color
// mappings stay domain-specific (Magazine's "Essay"/"Story" categories
// have nothing to do with Courses' "Mathematics"/"Science" subjects —
// this isn't a case of the same label needing the same color, just the
// same *lookup mechanism* built once instead of twice).

import 'package:flutter/material.dart';
import 'app_theme.dart';

class CategoryColorMap {
  final Map<String, Color> _colors;
  final Color fallback;
  const CategoryColorMap(this._colors, {this.fallback = C.primary});

  Color of(String category) => _colors[category] ?? fallback;
}
