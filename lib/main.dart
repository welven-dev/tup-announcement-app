import 'package:flutter/material.dart';

void main() => runApp(const TupAnnouncementApp());

const burgundy = Color(0xFF850018);
const burgundyDark = Color(0xFF650012);
const paleRose = Color(0xFFF8E9EC);
const ink = Color(0xFF242124);
const muted = Color(0xFF777178);
const line = Color(0xFFECE7E9);
const canvas = Color(0xFFFFFEFE);

class TupAnnouncementApp extends StatelessWidget {
  const TupAnnouncementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TUP Campus Updates',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: burgundy).copyWith(
          primary: burgundy,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F4F5),
          hintStyle: const TextStyle(color: muted, fontSize: 13),
          prefixIconColor: muted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class Announcement {
  final String title;
  final String category;
  final String office;
  final String dates;
  final String status;
  final String description;
  final IconData icon;

  const Announcement({
    required this.title,
    required this.category,
    required this.office,
    required this.dates,
    required this.status,
    required this.description,
    this.icon = Icons.campaign_outlined,
  });
}

const sampleAnnouncements = <Announcement>[
  Announcement(
    title: 'Class Suspension – Severe Typhoon Warning Advisory',
    category: 'Class Suspension',
    office: 'TUP Admin',
    dates: 'Aug 21 – Aug 23, 2026',
    status: 'ACTIVE',
    icon: Icons.thunderstorm_outlined,
    description:
        'Due to the escalating warning signals associated with Typhoon Advisory No. 4, classes in all levels, both in-person and online, are suspended from August 21 to August 23, 2026, across all Technological University of the Philippines (TUP) campuses.\n\nStudents and staff are highly advised to remain indoors, prioritize personal safety, and monitor official news channels and state weather advisory guidelines for timely developments. Re-entry guidelines and make-up schedules will be released by the university.',
  ),
  Announcement(
    title: 'First Semester Enrollment Period Extended to End of Month',
    category: 'Academic Requirements',
    office: 'Registrar',
    dates: 'Aug 10 – Aug 31, 2026',
    status: 'ACTIVE',
    icon: Icons.school_outlined,
    description:
        'The first semester enrollment period has been extended. Students should check the registrar’s official announcements and prepare the required enrollment documents before the new deadline.',
  ),
  Announcement(
    title: 'ID Validation Announcement',
    category: 'Academic Requirements',
    office: 'Student Affairs',
    dates: 'Aug 10 – Aug 12, 2026',
    status: 'EXPIRED',
    icon: Icons.badge_outlined,
    description:
        'Students who need to validate their university identification cards should follow the schedule and instructions issued by the Student Affairs Office.',
  ),
  Announcement(
    title: 'University General Assembly 2026',
    category: 'Campus Events',
    office: 'University Secretariat',
    dates: 'Sep 05, 2026',
    status: 'ACTIVE',
    icon: Icons.groups_outlined,
    description:
        'The university community is invited to attend the General Assembly. Please check official campus channels for venue and program updates.',
  ),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final List<Announcement> _announcements = List.of(sampleAnnouncements);

  void _openDetails(Announcement announcement) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnnouncementDetailScreen(announcement: announcement),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        announcements: _announcements,
        onOpen: _openDetails,
        onOpenNotifications: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()),
        ),
      ),
      EventsScreen(onOpen: _openDetails),
      const HandbookScreen(),
      OfficerScreen(
        onPublished: (announcement) {
          setState(() {
            _announcements.insert(0, announcement);
            _tab = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sample announcement added to the home feed.')),
          );
        },
      ),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        backgroundColor: Colors.white,
        indicatorColor: paleRose,
        height: 68,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Handbook'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Officer Login'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Announcement> announcements;
  final ValueChanged<Announcement> onOpen;
  final VoidCallback onOpenNotifications;

  const HomeScreen({
    super.key,
    required this.announcements,
    required this.onOpen,
    required this.onOpenNotifications,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String _scope = 'University';
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.announcements.where((item) {
      final q = _search.text.toLowerCase();
      final matchesSearch = item.title.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.office.toLowerCase().contains(q);
      final matchesCategory = _category == 'All' || item.category == _category;
      return matchesSearch && matchesCategory;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TUP Campus Updates', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 3),
                Text('Technological University of the Philippines', style: TextStyle(fontSize: 11, color: muted)),
              ]),
            ),
            IconButton(
              tooltip: 'Notification preferences',
              onPressed: widget.onOpenNotifications,
              icon: const Icon(Icons.notifications_none_rounded, color: burgundy),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search announcements...',
            prefixIcon: Icon(Icons.search),
            suffixIcon: Icon(Icons.tune, size: 19),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: ['University', 'College', 'Clubs'].map((label) {
            final selected = _scope == label;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _scope = label),
                selectedColor: burgundy,
                backgroundColor: Colors.white,
                side: BorderSide(color: selected ? burgundy : line),
                labelStyle: TextStyle(color: selected ? Colors.white : ink, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(
            labelText: 'Filter category',
            prefixIcon: Icon(Icons.filter_list),
          ),
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All categories')),
            DropdownMenuItem(value: 'Class Suspension', child: Text('Class Suspensions')),
            DropdownMenuItem(value: 'Academic Requirements', child: Text('Academic Requirements')),
            DropdownMenuItem(value: 'Campus Events', child: Text('Campus Events')),
            DropdownMenuItem(value: 'Organization Updates', child: Text('Organization Updates')),
            DropdownMenuItem(value: 'Emergency Alerts', child: Text('Emergency Alerts')),
          ],
          onChanged: (value) => setState(() => _category = value ?? 'All'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Text('Latest announcements', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink))),
            Text('${filtered.length} posts', style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Column(children: [Icon(Icons.search_off, size: 36, color: muted), SizedBox(height: 8), Text('No announcements found.')]),
          )
        else
          ...filtered.map((item) => AnnouncementCard(announcement: item, onTap: () => widget.onOpen(item))),
      ],
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onTap;
  const AnnouncementCard({super.key, required this.announcement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = announcement.status == 'ACTIVE';
    final categoryColor = announcement.category == 'Academic Requirements'
        ? burgundy
        : announcement.category == 'Class Suspension'
            ? const Color(0xFF7750A3)
            : const Color(0xFFB56B18);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: categoryColor, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(child: Text(announcement.category, style: TextStyle(fontSize: 11, color: categoryColor, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: active ? const Color(0xFFE8F5EC) : const Color(0xFFF0EFF0), borderRadius: BorderRadius.circular(20)),
                child: Text(announcement.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: active ? const Color(0xFF27834A) : muted)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(announcement.title, style: const TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: muted),
              const SizedBox(width: 5),
              Expanded(child: Text('Effective: ${announcement.dates}', style: const TextStyle(fontSize: 10, color: muted))),
            ]),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Tap to expand', style: TextStyle(fontSize: 10, color: burgundy, fontWeight: FontWeight.w700)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 13, color: burgundy),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class AnnouncementDetailScreen extends StatelessWidget {
  final Announcement announcement;
  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final active = announcement.status == 'ACTIVE';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('Advisory Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(children: [
            const CircleAvatar(radius: 15, backgroundColor: paleRose, child: Icon(Icons.account_balance, color: burgundy, size: 16)),
            const SizedBox(width: 9),
            Expanded(child: Text('Posted by ${announcement.office}', style: const TextStyle(fontSize: 12, color: muted))),
            StatusBadge(active: active),
          ]),
          const SizedBox(height: 18),
          Text(announcement.title, style: const TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.calendar_month_outlined, size: 16, color: muted),
            const SizedBox(width: 7),
            Expanded(child: Text(announcement.dates, style: const TextStyle(fontSize: 12, color: muted))),
          ]),
          const SizedBox(height: 22),
          Text(announcement.description, style: const TextStyle(fontSize: 14, height: 1.65, color: Color(0xFF4F4A4E))),
          const SizedBox(height: 24),
          const Text('ATTACHMENT', style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800, color: muted)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8F4E9), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9DFC9))),
            child: const Row(children: [
              Icon(Icons.picture_as_pdf_outlined, color: burgundy, size: 30),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Advisory_Attachment.pdf', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                SizedBox(height: 3),
                Text('Sample document preview', style: TextStyle(fontSize: 10, color: muted)),
              ])),
              Icon(Icons.visibility_outlined, color: burgundy),
            ]),
          ),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendar action is a UI demo.'))),
              icon: const Icon(Icons.calendar_month, size: 17),
              label: const Text('Save to Calendar'),
              style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 13)),
            )),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share action is a UI demo.'))),
              icon: const Icon(Icons.share_outlined, size: 17),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(foregroundColor: burgundy, side: const BorderSide(color: burgundy), padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12)),
            ),
          ]),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final bool active;
  const StatusBadge({super.key, required this.active});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: active ? const Color(0xFFE8F5EC) : const Color(0xFFF0EFF0), borderRadius: BorderRadius.circular(20)),
    child: Text(active ? 'ACTIVE' : 'EXPIRED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: active ? const Color(0xFF27834A) : muted)),
  );
}

class EventsScreen extends StatefulWidget {
  final ValueChanged<Announcement> onOpen;
  const EventsScreen({super.key, required this.onOpen});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _scope = 'University';
  @override
  Widget build(BuildContext context) {
    final events = sampleAnnouncements.where((a) => a.category == 'Campus Events' || a.category == 'Class Suspension').toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Campus Events', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 4),
      const Text('Discover what is happening around TUP.', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 18),
      Row(children: ['University', 'College', 'Clubs'].map((s) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(s), selected: _scope == s, showCheckmark: false, selectedColor: burgundy,
          labelStyle: TextStyle(color: _scope == s ? Colors.white : ink),
          onSelected: (_) => setState(() => _scope = s)),
      )).toList()),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: burgundy, borderRadius: BorderRadius.circular(18)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.event_available, color: Colors.white, size: 30),
          SizedBox(height: 14),
          Text('Stay connected with campus life', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text('University-wide, college-specific, and student organization events.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('Upcoming and featured', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      ...events.map((e) => AnnouncementCard(announcement: e, onTap: () => widget.onOpen(e))),
      Card(
        elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
        child: const ListTile(
          leading: CircleAvatar(backgroundColor: paleRose, child: Icon(Icons.groups_outlined, color: burgundy)),
          title: Text('TUP Student Research Symposium', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text('University-wide • Sample event', style: TextStyle(fontSize: 11)),
          trailing: Icon(Icons.chevron_right, color: burgundy),
        ),
      ),
    ]);
  }
}

class HandbookScreen extends StatefulWidget {
  const HandbookScreen({super.key});

  @override
  State<HandbookScreen> createState() => _HandbookScreenState();
}

class _HandbookScreenState extends State<HandbookScreen> {
  final _search = TextEditingController();
  final _topics = const [
    ('Academic Policies', 'University rules and academic regulations', Icons.school_outlined),
    ('Code of Conduct', 'Student responsibilities and policies', Icons.gavel_outlined),
    ('Grading System', 'Understand grading and assessment', Icons.grade_outlined),
    ('Student Services', 'Counseling, support, and campus services', Icons.support_agent_outlined),
    ('Student Calendar', 'Academic calendar and important dates', Icons.calendar_month_outlined),
    ('Dress Code', 'Uniform and campus attire guidelines', Icons.checkroom_outlined),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _topics.where((t) => t.$1.toLowerCase().contains(_search.text.toLowerCase()) || t.$2.toLowerCase().contains(_search.text.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Student Handbook', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 4),
      const Text('Quick access to frequently referenced campus policies.', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 18),
      TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Search handbook...', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 18),
      ...visible.map((topic) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: line)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          leading: CircleAvatar(backgroundColor: paleRose, child: Icon(topic.$3, color: burgundy, size: 20)),
          title: Text(topic.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          subtitle: Text(topic.$2, style: const TextStyle(fontSize: 10, color: muted)),
          trailing: const Icon(Icons.chevron_right, color: burgundy),
          onTap: () => showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(topic.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('${topic.$2}.\n\nThis is placeholder handbook content for the UI prototype. Replace it with verified text from the official TUP student handbook.', style: const TextStyle(height: 1.6, color: muted)),
              ]),
            ),
          ),
        ),
      )),
      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No handbook topics found.')),
    ]);
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final Map<String, bool> _settings = {
    'Class Suspensions': true,
    'Emergency Alerts': true,
    'Campus Events': true,
    'TUP Admin Office': true,
    'Student Council': false,
    'College Organizations': false,
  };

  @override
  Widget build(BuildContext context) {
    final categories = _settings.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('FILTER BY CATEGORY', style: TextStyle(fontSize: 10, letterSpacing: 1, color: muted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...categories.take(3).map((name) => _preferenceTile(name, 'Urgent campus updates and important notices')),
        const SizedBox(height: 20),
        const Text('FILTER BY CONTRIBUTOR', style: TextStyle(fontSize: 10, letterSpacing: 1, color: muted, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...categories.skip(3).map((name) => _preferenceTile(name, 'Updates from this office or organization')),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences saved for this demo session.')));
          },
          child: const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _preferenceTile(String name, String subtitle) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: muted)),
    value: _settings[name]!,
    activeThumbColor: burgundy,
    onChanged: (value) => setState(() => _settings[name] = value),
  );
}

class OfficerScreen extends StatefulWidget {
  final ValueChanged<Announcement> onPublished;
  const OfficerScreen({super.key, required this.onPublished});

  @override
  State<OfficerScreen> createState() => _OfficerScreenState();
}

class _OfficerScreenState extends State<OfficerScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _loggedIn = false;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn) {
      return PublishAnnouncementScreen(onPublished: (a) {
        widget.onPublished(a);
        setState(() => _loggedIn = false);
      }, onLogout: () => setState(() => _loggedIn = false));
    }
    return ListView(padding: const EdgeInsets.all(22), children: [
      const SizedBox(height: 22),
      const Center(child: CircleAvatar(radius: 34, backgroundColor: paleRose, child: Icon(Icons.admin_panel_settings_outlined, size: 36, color: burgundy))),
      const SizedBox(height: 18),
      const Text('TUP Account Sign-in', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      const Text('For authorized university officers and contributors', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 26),
      const Text('Officer Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Use your Student/Admin ID to continue.', style: TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 18),
      TextField(controller: _id, decoration: const InputDecoration(labelText: 'Student / Admin ID', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 12),
      TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 15)),
        onPressed: () {
          if (_id.text.trim().isEmpty || _password.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a sample ID and password to preview the next screen.')));
          } else {
            setState(() => _loggedIn = true);
          }
        },
        child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 12),
      const Text('UI prototype only. This form does not authenticate real TUP accounts.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: muted)),
    ]);
  }
}

class PublishAnnouncementScreen extends StatefulWidget {
  final ValueChanged<Announcement> onPublished;
  final VoidCallback onLogout;
  const PublishAnnouncementScreen({super.key, required this.onPublished, required this.onLogout});

  @override
  State<PublishAnnouncementScreen> createState() => _PublishAnnouncementScreenState();
}

class _PublishAnnouncementScreenState extends State<PublishAnnouncementScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _office = TextEditingController(text: 'TUP Admin');
  String _category = 'Class Suspension';
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _office.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 10, 20),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() { if (start) { _start = picked; } else { _end = picked; } });
  }

  String _dateLabel(DateTime? date) => date == null ? 'Select date' : '${date.month}/${date.day}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Row(children: [
        const Expanded(child: Text('Publish Announcement', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink))),
        TextButton(onPressed: widget.onLogout, child: const Text('Log out', style: TextStyle(color: burgundy))),
      ]),
      const SizedBox(height: 6),
      const Text('Create a campus update for students and staff.', style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 20),
      const Text('Announcement Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      TextField(controller: _title, decoration: const InputDecoration(hintText: 'Enter announcement title')),
      const SizedBox(height: 16),
      const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      DropdownButtonFormField<String>(
        value: _category,
        items: const [
          DropdownMenuItem(value: 'Class Suspension', child: Text('Class Suspension')),
          DropdownMenuItem(value: 'Academic Requirements', child: Text('Academic Requirements')),
          DropdownMenuItem(value: 'Campus Events', child: Text('Campus Events')),
          DropdownMenuItem(value: 'Organization Updates', child: Text('Organization Updates')),
          DropdownMenuItem(value: 'Emergency Alerts', child: Text('Emergency Alerts')),
          DropdownMenuItem(value: 'Department Notices', child: Text('Department Notices')),
        ],
        onChanged: (v) => setState(() => _category = v ?? _category),
      ),
      const SizedBox(height: 16),
      const Text('Issuing Office', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      TextField(controller: _office, decoration: const InputDecoration(hintText: 'Office or organization')),
      const SizedBox(height: 16),
      const Text('Announcement Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      TextField(controller: _description, minLines: 4, maxLines: 7, decoration: const InputDecoration(hintText: 'Enter announcement details')),
      const SizedBox(height: 16),
      const Text('Effective Date Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.calendar_today, size: 15), label: Text(_dateLabel(_start), style: const TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: burgundy))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.event, size: 15), label: Text(_dateLabel(_end), style: const TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: burgundy))),
      ]),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attachment picker can be connected later.'))),
        icon: const Icon(Icons.attach_file),
        label: const Text('Add attachment (demo)'),
        style: OutlinedButton.styleFrom(foregroundColor: burgundy, alignment: Alignment.centerLeft, padding: const EdgeInsets.all(14)),
      ),
      const SizedBox(height: 22),
      FilledButton.icon(
        onPressed: () {
          if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a title and description first.')));
            return;
          }
          final dates = '${_dateLabel(_start)} – ${_dateLabel(_end)}';
          widget.onPublished(Announcement(
            title: _title.text.trim(),
            category: _category,
            office: _office.text.trim().isEmpty ? 'TUP Contributor' : _office.text.trim(),
            dates: dates,
            status: 'ACTIVE',
            description: _description.text.trim(),
            icon: Icons.campaign_outlined,
          ));
        },
        icon: const Icon(Icons.publish),
        label: const Text('Publish Announcement', style: TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(vertical: 15)),
      ),
      const SizedBox(height: 10),
      const Text('Prototype note: publishing adds this sample item to the local home feed only.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: muted)),
    ]);
  }
}
