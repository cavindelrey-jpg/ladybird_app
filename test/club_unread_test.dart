// test/club_unread_test.dart
// Unit tests for clubHasUnreadMessages (lib/models/club.dart) -- the
// timestamp comparison behind the Club Chat unread indicator in the
// merged Messages inbox (MessagesHomePage). Added alongside this session's
// Clubs + Messaging audit (production_plan.md §1's "Verify unread/read
// states" line) after finding Club had NO unread concept at all -- unlike
// Conversation.unreadCount, which existed as a field but was dead (never
// written by sendMessage/markConversationRead) until this same pass fixed
// it. This is the one piece of new logic here with real branching worth
// pinning down with tests; the rest (ClubRepository.markClubRead/
// watchMyClubReadState) is thin Firestore plumbing with no branching to
// unit-test without an emulator.

import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/models/club.dart';

void main() {
  group('clubHasUnreadMessages', () {
    test('no chat activity at all (lastMessageAt null) is never unread', () {
      expect(clubHasUnreadMessages(lastMessageAt: null, lastReadAt: null), isFalse);
      expect(
          clubHasUnreadMessages(
              lastMessageAt: null, lastReadAt: DateTime(2026, 1, 1)),
          isFalse);
    });

    test('has activity, never opened Chat (lastReadAt null) is unread', () {
      expect(
          clubHasUnreadMessages(
              lastMessageAt: DateTime(2026, 1, 1), lastReadAt: null),
          isTrue);
    });

    test('last message after last read is unread', () {
      expect(
          clubHasUnreadMessages(
            lastMessageAt: DateTime(2026, 1, 2),
            lastReadAt: DateTime(2026, 1, 1),
          ),
          isTrue);
    });

    test('last message before last read is read (caught up)', () {
      expect(
          clubHasUnreadMessages(
            lastMessageAt: DateTime(2026, 1, 1),
            lastReadAt: DateTime(2026, 1, 2),
          ),
          isFalse);
    });

    test('exactly equal timestamps count as read, not unread', () {
      final t = DateTime(2026, 1, 1, 12, 30);
      expect(clubHasUnreadMessages(lastMessageAt: t, lastReadAt: t), isFalse);
    });
  });
}
