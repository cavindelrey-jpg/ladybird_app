// lib/widgets/formula_embed_builder.dart
//
// Renders Quill's built-in `formula` embed (BlockEmbed.formula / the
// compiler's `{"insert": {"formula": "<tex>"}}` ops) via a real LaTeX
// renderer, per Academia_Course_Generation_Rules.md Rule 1: math must
// never show up as literal `E = mc^2` / caret-notation text — only a
// proper renderer output. flutter_quill ships no formula EmbedBuilder of
// its own (only image/video in flutter_quill_extensions), so this fills
// that gap.

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class FormulaEmbedBuilder extends quill.EmbedBuilder {
  const FormulaEmbedBuilder();

  @override
  String get key => 'formula';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final tex = embedContext.node.value.data.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Math.tex(
        tex,
        mathStyle: MathStyle.text,
        textStyle: embedContext.textStyle,
        onErrorFallback: (err) => Text(
          tex,
          style: embedContext.textStyle.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
