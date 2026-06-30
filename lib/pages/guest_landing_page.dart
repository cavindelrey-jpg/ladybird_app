import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/widgets.dart';

// ── Guest palette (dark editorial) ───────────────────────
class _G {
  static const bg      = Color(0xFF1E2A3A);
  static const primary = Color(0xFF7B9CC4);
  static const gold    = Color(0xFFC9952A);
  static const card    = Color(0xFF263447);
  static const card2   = Color(0xFF2E3D52);
  static const subText = Color(0xFFB0B8C4);
  static const border  = Color(0xFF3A4D64);
  // Subject colours
  static const mathBlue   = Color(0xFF1A4080);
}

// ── Mock Data ─────────────────────────────────────────────
final _mockNotes = <Map<String,dynamic>>[];

final _mockPastQuestions = <Map<String,dynamic>>[];

final _mockDownloads = <Map<String,dynamic>>[];

final _mockMagazineHero = <String,dynamic>{};

final _mockEditions = <Map<String,dynamic>>[];

final _mockArticles = <Map<String,dynamic>>[];

// ── Main Widget ───────────────────────────────────────────
class GuestLandingPage extends StatefulWidget {
  const GuestLandingPage({super.key});
  @override State<GuestLandingPage> createState() => _GuestLandingPageState();
}

class _GuestLandingPageState extends State<GuestLandingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  final _searchCtrl    = TextEditingController();
  final _searchFocus   = FocusNode();
  bool _searchFocused  = false;
  String _searchQuery  = '';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _G.bg,
        body: SafeArea(
          child: Column(children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildTabBar(),
            Expanded(child: _buildTabViews()),
          ]),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader() => Container(
    color: _G.bg,
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: Row(children: [
      AcademiaLogo(size: 34),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Academia',
          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        Text('Explore as Guest', style: TextStyle(fontSize: 10, color: _G.subText)),
      ]),
      const Spacer(),
      _ChipButton(label: 'Sign In', onTap: () {}),
      const SizedBox(width: 8),
      _ChipButton(label: 'Join Free', onTap: () {}, gold: true),
    ]),
  );

  // ── Search Bar ───────────────────────────────────────────
  Widget _buildSearchBar() => Container(
    color: _G.bg,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _G.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchFocused ? _G.gold : _G.border,
          width: _searchFocused ? 1.8 : 1.0,
        ),
        boxShadow: _searchFocused
            ? [BoxShadow(color: _G.gold.withValues(alpha: .18), blurRadius: 12, spreadRadius: 1)]
            : [],
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: _G.gold,
        decoration: InputDecoration(
          hintText: 'Search notes, past questions, subjects…',
          hintStyle: TextStyle(color: _G.subText, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: _searchFocused ? _G.gold : _G.subText, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: _G.subText, size: 18),
                  onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          filled: false,
        ),
      ),
    ),
  );

  // ── Tab Bar ──────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    color: _G.bg,
    child: TabBar(
      controller: _tc,
      labelColor: _G.gold,
      unselectedLabelColor: _G.subText,
      indicatorColor: _G.gold,
      indicatorWeight: 2.5,
      dividerColor: _G.border,
      labelStyle: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700),
      unselectedLabelStyle: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w500),
      tabs: const [
        Tab(text: 'Notes'),
        Tab(text: 'Past Questions'),
        Tab(text: 'Downloads'),
        Tab(text: 'Magazine'),
      ],
    ),
  );

  // ── Tab Views ────────────────────────────────────────────
  Widget _buildTabViews() => TabBarView(
    controller: _tc,
    children: [
      _NotesTab(query: _searchQuery),
      _PastQuestionsTab(query: _searchQuery),
      _DownloadsTab(query: _searchQuery),
      _MagazineTab(query: _searchQuery),
    ],
  );
}

// ── Chip Button ───────────────────────────────────────────
class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool gold;
  const _ChipButton({required this.label, required this.onTap, this.gold = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: gold ? _G.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold ? _G.gold : _G.border),
      ),
      child: Text(label,
        style: GoogleFonts.sora(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: gold ? Colors.black : Colors.white)),
    ),
  );
}

// ── Notes Tab ─────────────────────────────────────────────
class _NotesTab extends StatelessWidget {
  final String query;
  const _NotesTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final items = query.isEmpty
        ? _mockNotes
        : _mockNotes.where((n) =>
            (n['title'] as String).toLowerCase().contains(query.toLowerCase()) ||
            (n['subject'] as String).toLowerCase().contains(query.toLowerCase())).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _SectionLabel(label: 'TRENDING NOTES', count: items.length),
        const SizedBox(height: 12),
        ...items.map((n) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _NoteCard(note: n),
        )),
        _GuestCtaCard(),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final color    = note['color'] as Color;
    final popular  = note['popular'] as bool;
    final views    = note['views'] as int;
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: _G.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _G.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Banner
          Container(
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: .7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SubjectPill(label: note['subject'] as String),
                  const SizedBox(height: 8),
                  Text(note['title'] as String,
                    style: GoogleFonts.sora(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
              if (popular) ...[
                const SizedBox(width: 8),
                const _FlameIcon(),
              ],
            ]),
          ),
          // Meta row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.person_outline_rounded, size: 13, color: _G.subText),
              const SizedBox(width: 4),
              Expanded(child: Text(note['author'] as String,
                style: TextStyle(fontSize: 11, color: _G.subText),
                overflow: TextOverflow.ellipsis)),
              _LevelBadge(label: note['level'] as String),
              const SizedBox(width: 10),
              Icon(Icons.visibility_outlined, size: 13, color: _G.subText),
              const SizedBox(width: 3),
              Text(_fmtNum(views),
                style: TextStyle(fontSize: 11, color: _G.subText, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Past Questions Tab ────────────────────────────────────
class _PastQuestionsTab extends StatelessWidget {
  final String query;
  const _PastQuestionsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final items = query.isEmpty
        ? _mockPastQuestions
        : _mockPastQuestions.where((p) =>
            (p['subject'] as String).toLowerCase().contains(query.toLowerCase()) ||
            (p['board'] as String).toLowerCase().contains(query.toLowerCase())).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _SectionLabel(label: 'EXAM PAPERS', count: items.length),
        const SizedBox(height: 8),
        _BoardFilterRow(),
        const SizedBox(height: 12),
        ...items.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PastQuestionCard(paper: p),
        )),
        _GuestCtaCard(),
      ],
    );
  }
}

class _PastQuestionCard extends StatelessWidget {
  final Map<String, dynamic> paper;
  const _PastQuestionCard({required this.paper});

  @override
  Widget build(BuildContext context) {
    final premium     = paper['premium'] as bool;
    final hasSolutions= paper['hasSolutions'] as bool;
    final downloads   = paper['downloads'] as int;
    final board       = paper['board'] as String;
    final level       = paper['level'] as String;

    Color boardColor;
    switch (board) {
      case 'GCE Board': boardColor = _G.primary; break;
      case 'BEPC':      boardColor = const Color(0xFF2E7D32); break;
      default:          boardColor = const Color(0xFF6A1B9A); break;
    }

    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _G.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: premium ? _G.gold.withValues(alpha: .4) : _G.border,
            width: premium ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          // Year block
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: _G.card2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _G.border),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(paper['year'] as String,
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              Text(level, style: TextStyle(fontSize: 8, color: _G.subText, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(paper['subject'] as String,
                    style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                if (premium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _G.gold.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _G.gold.withValues(alpha: .4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_rounded, size: 10, color: _G.gold),
                      const SizedBox(width: 3),
                      Text('Premium', style: TextStyle(fontSize: 9, color: _G.gold, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _BoardBadge(label: board, color: boardColor),
                const SizedBox(width: 8),
                if (hasSolutions)
                  _SolutionsBadge(),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.download_rounded, size: 12, color: _G.subText),
                const SizedBox(width: 3),
                Text('${_fmtNum(downloads)} downloads',
                  style: TextStyle(fontSize: 11, color: _G.subText)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Icon(
            premium ? Icons.lock_rounded : Icons.arrow_forward_ios_rounded,
            size: 16,
            color: premium ? _G.gold : _G.subText,
          ),
        ]),
      ),
    );
  }
}

// ── Downloads Tab ─────────────────────────────────────────
class _DownloadsTab extends StatelessWidget {
  final String query;
  const _DownloadsTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final items = query.isEmpty
        ? _mockDownloads
        : _mockDownloads.where((d) =>
            (d['title'] as String).toLowerCase().contains(query.toLowerCase()) ||
            (d['subject'] as String).toLowerCase().contains(query.toLowerCase())).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _SectionLabel(label: 'RESOURCE LIBRARY', count: items.length),
        const SizedBox(height: 12),
        ...items.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _NoteCard(note: d),
        )),
        _GuestCtaCard(),
      ],
    );
  }
}

// ── Magazine Tab ──────────────────────────────────────────
class _MagazineTab extends StatelessWidget {
  final String query;
  const _MagazineTab({required this.query});

  @override
  Widget build(BuildContext context) {
    final hero     = _mockMagazineHero;
    final articles = query.isEmpty
        ? _mockArticles
        : _mockArticles.where((a) =>
            (a['title'] as String).toLowerCase().contains(query.toLowerCase()) ||
            (a['tag'] as String).toLowerCase().contains(query.toLowerCase())).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // ── Hero ──
        _MagazineHeroCard(data: hero),
        const SizedBox(height: 20),
        // ── Editions ──
        Row(children: [
          Text('RECENT EDITIONS',
            style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700,
              color: _G.gold, letterSpacing: 1.2)),
          const Spacer(),
          Text('View all', style: TextStyle(fontSize: 11, color: _G.primary)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _mockEditions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _EditionCard(edition: _mockEditions[i]),
          ),
        ),
        const SizedBox(height: 20),
        // ── Articles ──
        Row(children: [
          Text('LATEST ARTICLES',
            style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700,
              color: _G.gold, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        ...articles.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ArticleCard(article: e.value, index: e.key),
        )),
        _GuestCtaCard(),
      ],
    );
  }
}

class _MagazineHeroCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MagazineHeroCard({required this.data});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [data['colorTop'] as Color, data['colorBot'] as Color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _G.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        // Decorative geometry
        Positioned(top: -30, right: -30, child: _GeoCircle(size: 140, opacity: .08)),
        Positioned(bottom: -20, left: -20, child: _GeoCircle(size: 100, opacity: .05)),
        Positioned(top: 20, right: 20, child: _GeoCircle(size: 60, opacity: .12)),
        // Content
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _G.gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('ACADEMIA MAGAZINE',
                  style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: .8)),
              ),
              const SizedBox(width: 8),
              Text(data['edition'] as String,
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: .6))),
            ]),
            const Spacer(),
            Text(data['title'] as String,
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1.25),
              maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(data['subtitle'] as String,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .7), height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.person_outline_rounded, size: 12, color: Colors.white.withValues(alpha: .6)),
              const SizedBox(width: 4),
              Text(data['author'] as String,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .8), fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Text('·', style: TextStyle(color: Colors.white.withValues(alpha: .4))),
              const SizedBox(width: 4),
              Text(data['school'] as String,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .6))),
              const Spacer(),
              Icon(Icons.schedule_rounded, size: 12, color: Colors.white.withValues(alpha: .6)),
              const SizedBox(width: 4),
              Text(data['readTime'] as String,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .6))),
            ]),
          ]),
        ),
      ]),
    ),
  );
}

class _EditionCard extends StatelessWidget {
  final Map<String, dynamic> edition;
  const _EditionCard({required this.edition});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Container(
      width: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [edition['color'] as Color, (edition['color'] as Color).withValues(alpha: .6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _G.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        Positioned(top: -10, right: -10, child: _GeoCircle(size: 60, opacity: .1)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACADEMIA', style: GoogleFonts.sora(fontSize: 7, fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: .6), letterSpacing: .8)),
            const Spacer(),
            Text(edition['theme'] as String,
              style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(edition['edition'] as String,
              style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: .6))),
          ]),
        ),
      ]),
    ),
  );
}

class _ArticleCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final int index;
  const _ArticleCard({required this.article, required this.index});

  static const _tagColors = [_G.primary, Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFF1A5C38), _G.mathBlue];

  @override
  Widget build(BuildContext context) {
    final tagColor = _tagColors[index % _tagColors.length];
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _G.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _G.border),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(article['tag'] as String,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tagColor.withValues(alpha: .9))),
              ),
              const SizedBox(height: 7),
              Text(article['title'] as String,
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white, height: 1.35),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.school_outlined, size: 11, color: _G.subText),
                const SizedBox(width: 4),
                Text(article['school'] as String,
                  style: TextStyle(fontSize: 10, color: _G.subText)),
                const SizedBox(width: 6),
                Text('·', style: TextStyle(color: _G.border)),
                const SizedBox(width: 6),
                Icon(Icons.schedule_rounded, size: 11, color: _G.subText),
                const SizedBox(width: 3),
                Text(article['readTime'] as String,
                  style: TextStyle(fontSize: 10, color: _G.subText)),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _G.subText),
        ]),
      ),
    );
  }
}

// ── Shared Small Widgets ──────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label,
      style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700,
        color: _G.gold, letterSpacing: 1.2)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _G.gold.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count', style: TextStyle(fontSize: 10, color: _G.gold, fontWeight: FontWeight.w700)),
    ),
  ]);
}

class _SubjectPill extends StatelessWidget {
  final String label;
  const _SubjectPill({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
  );
}

class _LevelBadge extends StatelessWidget {
  final String label;
  const _LevelBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _G.primary.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _G.primary)),
  );
}

class _BoardBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _BoardBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withValues(alpha: .9))),
  );
}

class _SolutionsBadge extends StatelessWidget {
  const _SolutionsBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF0FAB6E).withValues(alpha: .15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_outline_rounded, size: 10, color: Color(0xFF0FAB6E)),
      const SizedBox(width: 3),
      const Text('Solutions available',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0FAB6E))),
    ]),
  );
}

class _FlameIcon extends StatelessWidget {
  const _FlameIcon();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFFFF6B35)),
  );
}

class _BoardFilterRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: ['All', 'GCE O/L', 'GCE A/L', 'BEPC', 'BAC'].asMap().entries.map((e) {
        final active = e.key == 0;
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _G.gold : _G.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _G.gold : _G.border),
          ),
          child: Text(e.value,
            style: GoogleFonts.sora(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? Colors.black : _G.subText)),
        );
      }).toList(),
    ),
  );
}

class _GeoCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _GeoCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: opacity), width: 1.5),
    ),
  );
}

class _GuestCtaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A3060), Color(0xFF0F1E42)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _G.gold.withValues(alpha: .3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _G.gold, borderRadius: BorderRadius.circular(6)),
          child: Text('FREE', style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
        ),
        const SizedBox(width: 8),
        Text('Join Academia Today',
          style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      const SizedBox(height: 6),
      Text('Get unlimited access to notes, past questions, AI tutoring, and your school\'s full platform.',
        style: TextStyle(fontSize: 12, color: _G.subText, height: 1.45)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _G.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text('Create Free Account',
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {},
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _G.border),
            ),
            alignment: Alignment.center,
            child: Text('Sign In',
              style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ]),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────
String _fmtNum(int n) {
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
  return n.toString();
}
