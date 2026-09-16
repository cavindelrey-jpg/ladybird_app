with open('lib/features/dashboard/universal_home_page.dart', 'r') as f:
    content = f.read()

# We want to replace from '  Widget _heroAndStats(BuildContext context) {'
# down to the end of that method.
# In the original file, _heroAndStats ends right before '  Widget _resumeLearningButton(BuildContext context) {'

start_idx = content.find('  Widget _heroAndStats(BuildContext context) {')
end_idx = content.find('  Widget _resumeLearningButton(BuildContext context) {')

if start_idx != -1 and end_idx != -1:
    new_method = """  String get _dateLabel {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}\\n${now.day} ${months[now.month - 1]}, ${now.year}';
  }

  Widget _heroAndStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Container(
          width: double.infinity,
          height: 190,
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [ac.primary, ac.navy],
            ),
            borderRadius: BorderRadius.circular(Rad.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(
              right: -16, top: 4,
              child: Icon(Icons.auto_stories_rounded, size: 120, color: Colors.white.withValues(alpha: .15)),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$_timeGreeting, '),
                      TextSpan(text: _isGuest ? 'Guest' : (_u!.name.isEmpty ? 'Member' : _u!.name.split(' ').first)),
                      const TextSpan(text: ' \\u{1F44B}'),
                    ]),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(Branding.current.tagline,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: .9), height: 1.3)),
                ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: ac.primary),
                  const SizedBox(width: 6),
                  Text(_dateLabel, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: ac.txt, height: 1.3)),
                ]),
              ),
            ]),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: _statCard(),
        ),
      ]),
    );
  }

"""
    # Now we must also remove _canManageHeroBanner, _pickHeroBanner, _deleteHeroBanner, _resumeLearningButton
    # Let's just do it manually in python by replacing the content block cleanly.
    
    # We will slice from start_idx and just replace it. We'll leave _resumeLearningButton there for now, 
    # but we should remove its usages. Oh wait, _resumeLearningButton is defined but not used anymore because we replaced _heroAndStats.
    # The flutter analyze warnings are just warnings for unused methods, not errors.
    
    content = content[:start_idx] + new_method + content[end_idx:]

with open('lib/features/dashboard/universal_home_page.dart', 'w') as f:
    f.write(content)

