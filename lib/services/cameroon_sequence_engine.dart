class CameroonSequenceEngine {
  // Typical coefficients for Francophone / Anglophone subsystem in Cameroon
  static const Map<String, int> defaultCoefficients = {
    'Mathematics': 4,
    'English': 4,
    'French': 3,
    'Physics': 3,
    'Chemistry': 3,
    'Biology': 3,
    'History': 2,
    'Geography': 2,
    'Citizenship': 2,
  };

  static Map<String, dynamic> generateGazette(List<Map<String, dynamic>> rawMarks) {
    // rawMarks: [{ 'studentId': ..., 'subject': ..., 'mark': ... }]
    final studentAggregates = <String, Map<String, dynamic>>{};

    for (var markRecord in rawMarks) {
      final sId = markRecord['studentId'];
      final subject = markRecord['subject'];
      final mark = (markRecord['mark'] as num).toDouble();
      
      final coef = defaultCoefficients[subject] ?? 1;
      final weightedMark = mark * coef;

      if (!studentAggregates.containsKey(sId)) {
        studentAggregates[sId] = {
          'totalWeightedMark': 0.0,
          'totalCoefficients': 0,
          'subjectsFailing': <String>[],
          'marks': <String, double>{},
        };
      }

      studentAggregates[sId]!['totalWeightedMark'] += weightedMark;
      studentAggregates[sId]!['totalCoefficients'] += coef;
      studentAggregates[sId]!['marks'][subject] = mark;

      if (mark < 10.0) { // Cameroon passing mark is usually 10/20
        studentAggregates[sId]!['subjectsFailing'].add(subject);
      }
    }

    final rankedList = studentAggregates.entries.map((e) {
      final avg = e.value['totalWeightedMark'] / e.value['totalCoefficients'];
      return {
        'studentId': e.key,
        'average': avg,
        'failingSubjects': e.value['subjectsFailing'],
      };
    }).toList();

    rankedList.sort((a, b) => (b['average'] as double).compareTo(a['average'] as double));

    for (int i = 0; i < rankedList.length; i++) {
      rankedList[i]['rank'] = i + 1;
    }

    return {
      'rankedResults': rankedList,
    };
  }
}
