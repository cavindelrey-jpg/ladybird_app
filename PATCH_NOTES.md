# Academia — Patch: Open Club Creation + Mod Structure

## HOW TO APPLY
Same as before: extract to a temp folder, copy files into your project
preserving paths (this one only overwrites/adds, nothing to delete).
This builds on top of the previous patch — apply that one first if you
haven't already (the `firestore.rules` file here is the FULL file again,
not a diff, so just replace it wholesale).

1. Copy `lib/` files into your project's `lib/`.
2. Replace `firestore.rules` at your project root.
3. `firebase deploy --only firestore:rules`
4. `flutter analyze`

## WHAT CHANGED

**The backend already had the mod structure you wanted** —
`ClubRole` (visitor/member/moderator/admin) and `createClub()` already
made the founder an admin. What was actually missing was **any UI to
create a club at all**, and a screen to manage member roles. Also found
and fixed: club chat's `messages` subcollection had no Firestore rule at
all in the previous patch — anyone could read/write it. Fixed now.

### 1. Create Club (`create_club_page.dart`) — NEW
Any signed-in (non-guest) user can create a club: name, emoji (tap one
of 12 suggestions), description, category, optional banner image. If
the creator is school-linked, a toggle lets them choose "restrict to my
school" (default on) vs. open to everyone — independent users' clubs are
always open. Reachable via a new "Create Club" FAB on the Clubs list.
You become the club's admin automatically.

### 2. Member management (`club_members_page.dart`) — NEW
Reachable via a new "Members" icon in a club's app bar. Shows every
member with a role badge (Admin/Moderator/Member). Normal mod structure:
- **Admins** can set anyone's role (member/moderator/admin) or remove
  them from the club.
- **Moderators** can manage regular members (promote to moderator,
  remove) but can't touch other moderators or admins.
- Everyone else gets a read-only list.
- A club can't be left with zero admins — the last remaining admin's
  remove/demote option is disabled with an explanatory tooltip.

### 3. Repository additions (`club_repository.dart`)
- `joinClub()` and `createClub()` now store the member's name/photo
  alongside their role, so the member list doesn't need N extra reads
  against `users/`.
- Added `watchMembers()`, `updateMemberRole()`, `removeMember()`,
  `uploadBanner()`, `updateClub()`.

### 4. Firestore rules — clubs section rewritten
- `create` opened to any signed-in user (was schoolAdmin/lecturer-only).
- `update` on the club doc: any member can bump `memberCount` (join/leave),
  but editing name/description/banner is restricted to that club's own
  admin/moderator, its founder, or school staff.
- **Added the missing `messages` subcollection rule** (club chat) — this
  had no rule at all before, meaning the default-deny behavior of
  Firestore was silently blocking all chat reads/writes once you deployed
  the previous rules file. Caught this while reviewing the clubs block.
- `members` subcollection: join/leave is self-service; role changes and
  removals enforce the same admin-vs-moderator distinction as the UI
  (defense in depth — the real gate, not just the app's own checks).

## ONE THING TO CONFIRM
Independent (non-school) users' clubs are always "open to everyone" —
there's no equivalent restriction toggle for them since they have no
school to restrict to. If you'd rather independent users get a "private,
invite-only" option instead of "open to all," that's a small follow-up
(an `inviteOnly` flag + a join-request flow instead of instant join) —
didn't build it since it wasn't asked for, just flagging the gap.
