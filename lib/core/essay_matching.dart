// lib/core/essay_matching.dart
// Offline matcher for the Essay quiz type (production_plan.md §3, "Quiz
// Type 3 — Essay"): given the 7–9 essential key points an author defined
// and the short points a student actually wrote, decide how many of the
// essential points the student captured.
//
// ── Why this is hand-rolled and not an API call ──────────────────────────
// Every judgement here happens on-device in pure Dart. No AI/NLP service
// is called — that would be a paid external dependency, and the whole
// point of this file is that grading an essay attempt must work for the
// common case with nobody and nothing else in the loop. The trade-off is
// accepted honestly: this is lexical matching, not comprehension. It
// cannot tell that "the mitochondrion makes ATP" and "cellular energy is
// released in the powerhouse of the cell" are the same idea unless the
// author added a keyword alias saying so.
//
// That limitation is exactly why the output has THREE verdicts, not two:
//   captured  — confidently matched, no human needed
//   missed    — confidently absent, no human needed
//   uncertain — the matcher will not guess; this one point (not the whole
//               answer) goes to a human grader for a final call
//
// So the default path for a normally-phrased answer is fully automatic,
// and a human is pulled in only for the specific points that are actually
// ambiguous — instead of today's behaviour, where every single essay
// answer required a human to read prose from scratch.
//
// ── How a single key point is scored ─────────────────────────────────────
// 1. Both sides are normalized (lowercased, punctuation and accents
//    stripped, whitespace collapsed), tokenized, stopword-filtered, and
//    lightly stemmed (suffix stripping — not a full Porter stemmer).
// 2. A key point's tokens are weighted by how DISCRIMINATIVE they are
//    within this one question: a token appearing in many of the question's
//    own key points ("energy" in a question that is all about energy) is
//    worth less than one appearing in a single key point. Without this, a
//    student who writes the question's topic word nine times would part-
//    match all nine points.
// 3. Score = weighted recall — of the key point's own weighted tokens,
//    what fraction did this student point contain? Recall (not F1) is
//    deliberate: a student who states the right point AND adds extra
//    correct context should not be penalised for the extra words.
// 4. Tokens match exactly, or within an edit distance of 1 for tokens of
//    5+ characters, so ordinary typos don't cost a point.
// 5. Author-supplied keyword aliases are scored the same way and the BEST
//    of {main text, each alias} wins — aliases are alternatives, never
//    extra requirements.
// 6. Whole-phrase containment short-circuits to a perfect score.
//
// ── Why assignment is one-to-one ─────────────────────────────────────────
// Each student point may claim at most one key point and vice versa,
// resolved greedily best-score-first. This is the anti-gaming property
// that makes the whole thing defensible: writing one long kitchen-sink
// sentence, or pasting the same vague sentence into all nine boxes,
// captures ONE point, not nine.

import 'dart:math';
import '../models/test.dart';

/// At or above this weighted-recall score, a key point counts as captured
/// with no human involvement.
const double kEssayCapturedThreshold = 0.60;

/// At or below this score, a key point counts as missed with no human
/// involvement. Between the two thresholds the matcher refuses to guess
/// and returns [KeyPointVerdict.uncertain].
const double kEssayMissedThreshold = 0.30;

enum KeyPointVerdict { captured, uncertain, missed }

extension KeyPointVerdictExt on KeyPointVerdict {
  String get label {
    switch (this) {
      case KeyPointVerdict.captured:  return 'Captured';
      case KeyPointVerdict.uncertain: return 'Needs review';
      case KeyPointVerdict.missed:    return 'Missed';
    }
  }

  static KeyPointVerdict fromKey(String? key) => KeyPointVerdict.values
      .firstWhere((v) => v.name == key, orElse: () => KeyPointVerdict.missed);
}

/// The outcome for ONE essential key point of one essay answer.
class KeyPointMatch {
  final String keyPointId;
  final String keyPointText;

  /// Index into the student's submitted points that best matched this key
  /// point, or null if nothing matched it at all.
  final int? studentPointIndex;

  /// The student's own wording that matched — carried alongside the index
  /// so a grader can read the pairing without re-deriving it.
  final String studentText;

  final double score;
  final KeyPointVerdict verdict;

  const KeyPointMatch({
    required this.keyPointId,
    required this.keyPointText,
    required this.studentPointIndex,
    required this.studentText,
    required this.score,
    required this.verdict,
  });
}

/// The full result of matching one student's essay answer.
class EssayMatchResult {
  /// One entry per authored key point, in the author's original order.
  final List<KeyPointMatch> matches;

  const EssayMatchResult(this.matches);

  int get totalKeyPoints => matches.length;

  /// Points the matcher is confident the student captured. This is the
  /// `pointsAwarded` an auto-graded essay is scored with.
  int get capturedCount =>
      matches.where((m) => m.verdict == KeyPointVerdict.captured).length;

  int get uncertainCount =>
      matches.where((m) => m.verdict == KeyPointVerdict.uncertain).length;

  /// True when at least one key point needs a human's final call. When
  /// this is false the whole answer is graded automatically at submit
  /// time — the intended common case.
  bool get needsHumanReview => uncertainCount > 0;

  /// Best-case score if a human were to allow every uncertain point —
  /// used only to show a grader the range they're deciding within.
  int get bestCaseCount => capturedCount + uncertainCount;
}

// ── Text normalization ───────────────────────────────────────────────────

/// Words carrying no discriminative meaning for this kind of matching.
/// Kept deliberately short: over-aggressive stopword lists start eating
/// real content words in science/technical phrasing.
const Set<String> _stopwords = {
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'been', 'being', 'but', 'by',
  'can', 'could', 'did', 'do', 'does', 'for', 'from', 'had', 'has', 'have',
  'how', 'in', 'into', 'is', 'it', 'its', 'may', 'might', 'must', 'not',
  'of', 'on', 'or', 'should', 'so', 'such', 'than', 'that', 'the',
  'their', 'them', 'then', 'there', 'these', 'they', 'this', 'those', 'to',
  'was', 'were', 'when', 'which', 'while', 'who', 'will', 'with', 'would',
  'you', 'your', 'we', 'our', 'i', 'he', 'she', 'his', 'her', 'also',
  'both', 'each', 'more', 'most', 'other', 'some', 'very', 'because',
};

const Map<String, String> _accentFolding = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Lowercase, fold accents (French-influenced spellings are ordinary in
/// Cameroonian classrooms), reduce anything non-alphanumeric to a space,
/// and collapse runs of whitespace.
String normalizeEssayText(String input) {
  final lowered = input.toLowerCase();
  final folded = StringBuffer();
  for (final ch in lowered.split('')) {
    folded.write(_accentFolding[ch] ?? ch);
  }
  return folded
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Longest-first so 'ational' is tried before 'ation' before 'ing'.
const List<String> _suffixes = [
  'ational', 'ization', 'iveness', 'fulness', 'ousness',
  'ation', 'ities', 'ement', 'ments', 'ingly',
  'ment', 'ness', 'ance', 'ence', 'able', 'ible', 'tion',
  'ing', 'ies', 'ied', 'ers', 'est', 'ity', 'ive', 'ful', 'ous',
  'ed', 'es', 'ly', 's',
];

/// Light suffix-stripping stemmer. Not linguistically complete on
/// purpose — it exists to make 'converts'/'converting'/'conversion' land
/// near each other, and the edit-distance tolerance in [_tokensMatch]
/// covers most of what it misses.
String _stem(String word) {
  if (word.length <= 4) return word;
  if (word.endsWith('ies') && word.length > 4) {
    return '${word.substring(0, word.length - 3)}y';
  }
  for (final suffix in _suffixes) {
    if (word.length > suffix.length + 2 && word.endsWith(suffix)) {
      return word.substring(0, word.length - suffix.length);
    }
  }
  return word;
}

/// Normalized, stopword-filtered, stemmed tokens. Single characters are
/// dropped (they are almost always list markers or stray letters), but
/// digits are kept — a date or a quantity can be the essential content of
/// a key point.
List<String> essayTokens(String input) {
  return normalizeEssayText(input)
      .split(' ')
      .where((t) => t.isNotEmpty && t.length > 1 && !_stopwords.contains(t))
      .map(_stem)
      .toList();
}

/// Levenshtein distance, abandoned early once it provably exceeds
/// [limit] — the matcher only ever asks "is this within 1 edit?", so
/// computing an exact large distance would be wasted work.
int _editDistance(String a, String b, {int limit = 1}) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    var rowBest = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = min(min(current[j - 1] + 1, previous[j] + 1), previous[j - 1] + cost);
      rowBest = min(rowBest, current[j]);
    }
    if (rowBest > limit) return limit + 1;
    previous = current;
  }
  return previous[b.length];
}

/// Exact match, or a single typo's worth of difference for tokens long
/// enough that a 1-character edit is unlikely to change the word into a
/// genuinely different one ('cell' vs 'sell' must NOT match; 'photosynthesis'
/// vs 'photosynthesys' must).
bool _tokensMatch(String a, String b) {
  if (a == b) return true;
  if (a.length < 5 || b.length < 5) return false;
  return _editDistance(a, b) <= 1;
}

// ── Scoring ──────────────────────────────────────────────────────────────

/// Weight for each token of the key points, based on how many of THIS
/// question's key points use it. A token unique to one key point carries
/// full weight; a token shared across many is mostly topic noise.
Map<String, double> _tokenWeights(List<List<String>> allKeyPointTokens) {
  final documentFrequency = <String, int>{};
  for (final tokens in allKeyPointTokens) {
    for (final token in tokens.toSet()) {
      documentFrequency[token] = (documentFrequency[token] ?? 0) + 1;
    }
  }
  return documentFrequency.map(
    (token, df) => MapEntry(token, 1.0 / (1.0 + log(df))),
  );
}

/// Weighted recall of [targetTokens] within [studentTokens].
double _weightedRecall(
  List<String> targetTokens,
  List<String> studentTokens,
  Map<String, double> weights,
) {
  if (targetTokens.isEmpty) return 0;
  var total = 0.0;
  var found = 0.0;
  for (final target in targetTokens.toSet()) {
    final weight = weights[target] ?? 1.0;
    total += weight;
    if (studentTokens.any((s) => _tokensMatch(s, target))) {
      found += weight;
    }
  }
  return total == 0 ? 0 : found / total;
}

KeyPointVerdict _verdictFor(double score) {
  if (score >= kEssayCapturedThreshold) return KeyPointVerdict.captured;
  if (score <= kEssayMissedThreshold) return KeyPointVerdict.missed;
  return KeyPointVerdict.uncertain;
}

/// Matches a student's submitted essay points against the authored key
/// points. [studentPoints] are the student's own short phrasings, in the
/// order they entered them; blank entries are ignored.
///
/// Every authored key point gets exactly one [KeyPointMatch] in the
/// result, in the author's original order, so callers can render a
/// complete captured/missed breakdown without cross-referencing.
EssayMatchResult matchEssayKeyPoints({
  required List<EssayKeyPoint> keyPoints,
  required List<String> studentPoints,
}) {
  if (keyPoints.isEmpty) return const EssayMatchResult([]);

  final answers = studentPoints
      .map((s) => s.trim())
      .toList(growable: false);
  final answerTokens =
      answers.map(essayTokens).toList(growable: false);
  final answerNormalized =
      answers.map(normalizeEssayText).toList(growable: false);

  final keyPointTokens =
      keyPoints.map((k) => essayTokens(k.text)).toList(growable: false);
  final weights = _tokenWeights(keyPointTokens);

  // Score every (key point, student point) pair first, then assign — a
  // greedy pass over the raw pairs is what enforces one-to-one.
  final pairScores = List.generate(
    keyPoints.length,
    (_) => List<double>.filled(answers.length, 0),
  );

  for (var k = 0; k < keyPoints.length; k++) {
    final keyPoint = keyPoints[k];
    final mainTokens = keyPointTokens[k];
    final mainNormalized = normalizeEssayText(keyPoint.text);
    final aliasTokenSets =
        keyPoint.keywords.map(essayTokens).toList(growable: false);
    final aliasNormalized =
        keyPoint.keywords.map(normalizeEssayText).toList(growable: false);

    for (var s = 0; s < answers.length; s++) {
      if (answerNormalized[s].isEmpty) continue;

      // Whole-phrase containment, and ONLY in this direction: the student
      // restating the entire key point (plus any extra context) is an
      // unambiguous capture. The reverse — the student's words appearing
      // somewhere inside the key point — is deliberately NOT a shortcut,
      // because a one-word answer is a substring of almost any key point
      // that happens to use that word, which would hand out perfect
      // scores for writing a single topic word. Partial answers are the
      // weighted-recall path's job, and it scores them proportionally.
      var best = 0.0;
      if (mainNormalized.isNotEmpty &&
          answerNormalized[s].contains(mainNormalized)) {
        best = 1.0;
      }
      for (final alias in aliasNormalized) {
        if (alias.isNotEmpty && answerNormalized[s].contains(alias)) {
          best = 1.0;
        }
      }

      if (best < 1.0) {
        // A key point made entirely of stopwords has no tokens to score
        // against; fall back to raw normalized equality rather than
        // silently scoring every answer 0.
        if (mainTokens.isEmpty) {
          best = max(best,
              answerNormalized[s] == mainNormalized ? 1.0 : 0.0);
        } else {
          best = max(best,
              _weightedRecall(mainTokens, answerTokens[s], weights));
        }
        for (final aliasTokens in aliasTokenSets) {
          if (aliasTokens.isEmpty) continue;
          best = max(best,
              _weightedRecall(aliasTokens, answerTokens[s], weights));
        }
      }

      pairScores[k][s] = best;
    }
  }

  // Greedy one-to-one assignment, best pair first.
  final candidates = <({int keyIndex, int answerIndex, double score})>[];
  for (var k = 0; k < keyPoints.length; k++) {
    for (var s = 0; s < answers.length; s++) {
      if (pairScores[k][s] > 0) {
        candidates.add((keyIndex: k, answerIndex: s, score: pairScores[k][s]));
      }
    }
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));

  final assignedKey = <int, ({int answerIndex, double score})>{};
  final usedAnswers = <int>{};
  for (final candidate in candidates) {
    if (assignedKey.containsKey(candidate.keyIndex)) continue;
    if (usedAnswers.contains(candidate.answerIndex)) continue;
    assignedKey[candidate.keyIndex] =
        (answerIndex: candidate.answerIndex, score: candidate.score);
    usedAnswers.add(candidate.answerIndex);
  }

  final matches = <KeyPointMatch>[];
  for (var k = 0; k < keyPoints.length; k++) {
    final assignment = assignedKey[k];
    final score = assignment?.score ?? 0.0;
    matches.add(KeyPointMatch(
      keyPointId: keyPoints[k].id,
      keyPointText: keyPoints[k].text,
      studentPointIndex: assignment?.answerIndex,
      studentText:
          assignment == null ? '' : answers[assignment.answerIndex],
      score: score,
      verdict: _verdictFor(score),
    ));
  }

  return EssayMatchResult(matches);
}
