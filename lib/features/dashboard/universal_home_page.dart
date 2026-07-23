// lib/features/dashboard/universal_home_page.dart

import 'package:flutter/material.dart';

class UniversalHomePage extends StatefulWidget {
  const UniversalHomePage({super.key});

  @override
  State<UniversalHomePage> createState() => _UniversalHomePageState();
}

class _UniversalHomePageState extends State<UniversalHomePage> {
  int _bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light app background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              _buildGreetingAndStats(),
              const SizedBox(height: 20),
              _buildLibraryBanner(),
              const SizedBox(height: 24),
              _buildSectionHeader('Quick Access', onViewAll: () {}),
              const SizedBox(height: 12),
              _buildQuickAccess(),
              const SizedBox(height: 24),
              _buildProgressAndChallenge(),
              const SizedBox(height: 24),
              _buildWritersAndAnnouncements(),
              const SizedBox(height: 24),
              _buildSectionHeader('Recommended for You', onViewAll: () {}),
              const SizedBox(height: 12),
              _buildRecommendedRow(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.menu, color: Colors.black87),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Academia',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                Text(
                  'Your Complete Smart School Platform',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Icon(Icons.search, color: Colors.black54),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: Colors.black54),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Greeting & Stats ────────────────────────────────────────────────────
  Widget _buildGreetingAndStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and Name
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?img=11'), // Placeholder avatar
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Text(
                  'Nso Dylan',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Super Admin',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          // Stats & Week Tracker
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statBox(Icons.local_fire_department, Colors.deepOrange,
                        '7', 'Day Streak'),
                    _statBox(Icons.star, Colors.amber, '1,250', 'XP Points'),
                    _statBox(Icons.menu_book, Colors.purple, '12', 'Courses'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _dayDot('M', true),
                    _dayDot('T', true),
                    _dayDot('W', true),
                    _dayDot('T', true),
                    _dayDot('F', true),
                    _dayDot('S', false, isCurrent: true),
                    _dayDot('S', false),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statBox(IconData icon, Color iconColor, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400)
        ],
      ),
    );
  }

  Widget _dayDot(String day, bool completed, {bool isCurrent = false}) {
    return Column(
      children: [
        completed
            ? const Icon(Icons.check_circle, color: Colors.amber, size: 18)
            : Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isCurrent ? Colors.grey.shade400 : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(day, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  // ── Library Banner ──────────────────────────────────────────────────────
  Widget _buildLibraryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: NetworkImage(
                'https://images.unsplash.com/photo-1507842217343-583bb7270b66?ixlib=rb-1.2.1&auto=format&fit=crop&w=1000&q=80'), // Placeholder library image
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Library',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Discover books, past papers\nand other study materials.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.grey, size: 16),
                  const SizedBox(width: 6),
                  const Text('4,521 Resources Available',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Row(
                      children: [
                        Text('Explore Now',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16)
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _bannerDot(true),
                      _bannerDot(false),
                      _bannerDot(false),
                      _bannerDot(false),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerDot(bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.amber : Colors.white54,
        shape: BoxShape.circle,
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {required VoidCallback onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          GestureDetector(
            onTap: onViewAll,
            child: Text('View All',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600)),
          ),
        ],
      ),
    );
  }

  // ── Quick Access ────────────────────────────────────────────────────────
  Widget _buildQuickAccess() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _quickAccessItem('Magazine', Icons.menu_book, Colors.purple),
          _quickAccessItem('Clubs', Icons.groups, Colors.amber),
          _quickAccessItem('Library', Icons.import_contacts, Colors.blue),
          _quickAccessItem(
              'Past Questions', Icons.description, Colors.green),
          _quickAccessItem('Quizzes', Icons.assignment, Colors.deepOrange,
              isNew: true),
        ],
      ),
    );
  }

  Widget _quickAccessItem(String title, IconData icon, Color color,
      {bool isNew = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              )
            ],
          ),
          if (isNew)
            Positioned(
              top: -10,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('New',
                    style: TextStyle(color: Colors.white, fontSize: 9)),
              ),
            )
        ],
      ),
    );
  }

  // ── Middle Section: Progress & Daily Challenge ──────────────────────────
  Widget _buildProgressAndChallenge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Today's Progress
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.show_chart,
                              size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          const Text("Today's Progress",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Text('62%',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: 0.62,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.menu_book,
                            color: Colors.blue.shade600, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Continue Reading',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.blue)),
                            Text('Mechanics',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            Text('Page 14 of 26',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400)
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Daily Challenge
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.purple.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_fire_department,
                          color: Colors.deepOrange, size: 16),
                      SizedBox(width: 4),
                      Text('Daily Challenge',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("Today's Physics Quiz",
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.assignment,
                          size: 12, color: Colors.purple),
                      const SizedBox(width: 4),
                      const Text('3 Questions',
                          style: TextStyle(fontSize: 10, color: Colors.purple)),
                      const SizedBox(width: 8),
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text('+50 XP',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Start Challenge',
                              style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14)
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ── Lower Section: Writers & Announcements ──────────────────────────────
  Widget _buildWritersAndAnnouncements() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Writers
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Top Writers',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('View All',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            shape: BoxShape.circle),
                        child: const Text('#1',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber)),
                      ),
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage(
                            'https://i.pravatar.cc/150?img=11'),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nso Dylan',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            Text('5 reads • 1 comments',
                                style: TextStyle(
                                    fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.emoji_events,
                          color: Colors.amber, size: 16)
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Recent Announcements
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Announcements',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('View All',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle),
                        child: Icon(Icons.campaign,
                            color: Colors.blue.shade300, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No announcements yet. Magazine posts, paper uploads, and club news will show up here.',
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ── Recommended For You ─────────────────────────────────────────────────
  Widget _buildRecommendedRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _recommendedCard(
              'Document',
              'Additional Mathematics\n2015 Paper 2',
              'PDF • 2.4 MB',
              Colors.purple.shade50,
              Colors.purple),
          _recommendedCard(
              'Document',
              '2018_AdditionalMathem\natics_Paper1.docx',
              'DOCX • 1.7 MB',
              Colors.amber.shade50,
              Colors.amber),
          _recommendedCard(
              'Book',
              'A Military History of\nAfrica',
              'PDF • 3.8 MB',
              Colors.blue.shade50,
              Colors.blue),
          _recommendedCard(
              'Past Paper',
              'The Atom\nQuestions',
              'PDF • 1.2 MB',
              Colors.green.shade50,
              Colors.green),
        ],
      ),
    );
  }

  Widget _recommendedCard(String type, String title, String subtitle,
      Color bgColor, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Text(type,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: iconColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
              Icon(Icons.bookmark, size: 16, color: iconColor)
            ],
          )
        ],
      ),
    );
  }

  // ── Bottom Navigation ───────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) => setState(() => _bottomNavIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade500,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        backgroundColor: Colors.transparent,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.home),
            ),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: 'Library'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined), label: 'Courses'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.school), label: 'Clubs'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}