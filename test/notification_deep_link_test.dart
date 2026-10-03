import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/services/notification_router.dart';

void main() {
  test('typed links split into kind and value', () {
    expect(parseDeepLink('course:abc-123'), (kind: 'course', value: 'abc-123'));
    expect(parseDeepLink('program:2026-10-09:Form 5'), (kind: 'program', value: '2026-10-09:Form 5'));
    expect(parseDeepLink('challenge:2026-10-09').kind, 'challenge');
  });
  test('legacy bare ids and unknown prefixes stay whole', () {
    expect(parseDeepLink('6f1c2d9e-0000-4000-8000-000000000000').kind, '');
    expect(parseDeepLink('weird:thing'), (kind: '', value: 'weird:thing'));
    expect(parseDeepLink(null), (kind: '', value: ''));
  });
}
