import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  runApp(const TupAnnouncementApp());
}

const bool kRequireApproval = true;

const kCategories = <String>[
  'Class Suspension',
  'Academic Requirements',
  'Campus Events',
  'Organization Updates',
  'Department Notices',
  'Emergency Alerts',
];

const kOffices = <String>[
  'TUP Admin',
  'Student Council',
  'College Organizations',
];

const kScopes = <String>['University', 'College', 'Clubs'];

const kRoles = <String>[
  'School Administrator',
  'Department Head',
  'Student Org Officer',
];

const burgundy = Color(0xFF850018);
const burgundyDark = Color(0xFF650012);
const paleRose = Color(0xFFF8E9EC);
const ink = Color(0xFF242124);
const muted = Color(0xFF777178);
const line = Color(0xFFECE7E9);
const canvas = Color(0xFFFFFEFE);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _ymd(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

bool hasEnded(DateTime? start, DateTime? end) {
  final last = end ?? start;
  if (last == null) return false;
  return DateTime.now().isAfter(_endOfDay(last));
}

bool startsLater(DateTime? start) {
  if (start == null) return false;
  return DateTime.now().isBefore(DateTime(start.year, start.month, start.day));
}

Color categoryColor(String category) {
  switch (category) {
    case 'Academic Requirements':
      return burgundy;
    case 'Class Suspension':
      return const Color(0xFF7750A3);
    case 'Emergency Alerts':
      return const Color(0xFFC62828);
    case 'Campus Events':
      return const Color(0xFF1E6FB0);
    case 'Organization Updates':
      return const Color(0xFF2E7D6B);
    default:
      return const Color(0xFFB56B18);
  }
}

void showMsg(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

const kEmailDomain = '@tup.edu.ph';

bool isTupEmail(String email) =>
    email.trim().toLowerCase().endsWith(kEmailDomain);

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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
  final String id;
  final String title;
  final String category;
  final String scope;
  final String office;
  final String description;
  final String attachment;
  final String imageUrl;
  final String createdBy;
  final String legacyDates;
  final List<String> tags;
  final DateTime? start;
  final DateTime? end;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.category,
    required this.scope,
    required this.office,
    required this.description,
    required this.attachment,
    this.imageUrl = '',
    required this.createdBy,
    required this.legacyDates,
    this.tags = const [],
    this.start,
    this.end,
    this.createdAt,
  });

  factory Announcement.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;

    String legacy = '${data['dates'] ?? ''}';
    if (legacy.isEmpty && data['date_range'] is Timestamp) {
      legacy = fmtDate((data['date_range'] as Timestamp).toDate());
    }

    final rawTags = data['tags'];

    return Announcement(
      id: doc.id,
      title: '${data['title'] ?? ''}',
      category: '${data['category'] ?? ''}',
      scope: '${data['scope'] ?? 'University'}',
      office: '${data['issuing_office'] ?? ''}',
      description: '${data['description'] ?? ''}',
      attachment: '${data['attachment_link'] ?? ''}',
      imageUrl: '${data['imageUrl'] ?? ''}',
      createdBy: '${data['createdBy'] ?? ''}',
      legacyDates: legacy,
      tags: rawTags is List ? rawTags.map((e) => '$e').toList() : <String>[],
      start: ts(data['start_date']),
      end: ts(data['end_date']),
      createdAt: ts(data['createdAt']),
    );
  }

  bool get isExpired => hasEnded(start, end);

  bool get isScheduled => startsLater(start);

  bool get active => !isExpired;

  String get status => isExpired ? 'EXPIRED' : 'ACTIVE';

  String get dates {
    final s = start;
    final e = end;
    if (s != null && e != null) {
      final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
      if (sameDay) return fmtDate(s);
      return '${fmtDate(s)} – ${fmtDate(e)}';
    }
    if (s != null) return fmtDate(s);
    if (e != null) return 'Until ${fmtDate(e)}';
    if (legacyDates.isNotEmpty) return legacyDates;
    final c = createdAt;
    if (c != null) return 'Posted ${fmtDate(c)}';
    return 'No date set';
  }
}

class OfficerSession {
  final User? user;
  final bool ready;
  final bool approved;
  final bool approvalKnown;
  final String role;

  const OfficerSession({
    this.user,
    this.ready = false,
    this.approved = false,
    this.approvalKnown = false,
    this.role = '',
  });

  bool canManage(Announcement a) {
    final u = user;
    return u != null && approved && a.createdBy == u.uid;
  }
}

Future<void> openAnnouncementForm(
    BuildContext context, User user, Announcement? existing) async {
  final messenger = ScaffoldMessenger.of(context);
  final msg = await Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => AnnouncementFormScreen(user: user, existing: existing),
  ));
  if (msg != null) {
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }
}

Future<void> confirmDeleteAnnouncement(
    BuildContext context, Announcement a) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete announcement?'),
      content: Text('"${a.title}" will be removed for everyone. '
          'This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: burgundy))),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(a.id)
        .delete();
    messenger
        .showSnackBar(const SnackBar(content: Text('Announcement deleted.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
  }
}

Widget announcementCardFor(
  BuildContext context,
  Announcement a,
  OfficerSession session,
  ValueChanged<Announcement> onOpen,
) {
  final user = session.user;
  final manage = user != null && session.canManage(a);
  return AnnouncementCard(
    announcement: a,
    onTap: () => onOpen(a),
    onEdit: manage ? () => openAnnouncementForm(context, user, a) : null,
    onDelete: manage ? () => confirmDeleteAnnouncement(context, a) : null,
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  OfficerSession _session = const OfficerSession();
  bool _freshLogin = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _officerSub;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true);

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.userChanges().listen(_onAuth);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _officerSub?.cancel();
    super.dispose();
  }

  void _onAuth(User? user) {
    if (!mounted) return;
    if (user != null && _session.user?.uid == user.uid && _officerSub != null) {
      setState(() => _session = OfficerSession(
          user: user,
          ready: true,
          approved: _session.approved,
          approvalKnown: _session.approvalKnown,
          role: _session.role));
      return;
    }
    _officerSub?.cancel();
    _officerSub = null;

    if (user == null) {
      _freshLogin = false;
      setState(() => _session = const OfficerSession(ready: true));
      return;
    }

    if (_session.ready && _session.user == null) _freshLogin = true;

    if (!kRequireApproval) {
      setState(() => _session = OfficerSession(
          user: user, ready: true, approved: true, approvalKnown: true));
      _finishLogin();
      return;
    }

    setState(() => _session = OfficerSession(user: user, ready: true));

    _officerSub = FirebaseFirestore.instance
        .collection('officers')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final approved = snap.data()?['approved'] == true;
      final role = '${snap.data()?['role'] ?? ''}';
      setState(() => _session = OfficerSession(
          user: user,
          ready: true,
          approved: approved,
          approvalKnown: true,
          role: role));
      if (approved) _finishLogin();
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _session = OfficerSession(
          user: user, ready: true, approved: false, approvalKnown: true));
    });
  }

  void _finishLogin() {
    if (!_freshLogin || !mounted) return;
    _freshLogin = false;
    final email = _session.user?.email ?? 'your account';
    setState(() => _tab = 0);
    showMsg(context, 'Logged in as $email');
  }

  void _openDetails(Announcement announcement) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AnnouncementDetailScreen(announcement: announcement),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final loading = !snap.hasData && !snap.hasError;
        final error = snap.hasError ? '${snap.error}' : null;
        final offline = snap.hasData && snap.data!.metadata.isFromCache;
        final all = snap.hasData
            ? snap.data!.docs.map(Announcement.fromDoc).toList()
            : <Announcement>[];
        final session = _session;

        final pages = [
          HomeScreen(
            announcements: all,
            loading: loading,
            error: error,
            offline: offline,
            session: session,
            onOpen: _openDetails,
            onOpenNotifications: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesScreen()),
            ),
          ),
          EventsScreen(
            announcements: all,
            loading: loading,
            error: error,
            session: session,
            onOpen: _openDetails,
          ),
          const HandbookScreen(),
          OfficerScreen(
            session: session,
            onRefresh: () => setState(() {}),
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
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home'),
              const NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Events'),
              const NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Handbook'),
              NavigationDestination(
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: const Icon(Icons.admin_panel_settings),
                  label: session.user != null ? 'Account' : 'Officer Login'),
            ],
          ),
        );
      },
    );
  }
}

Widget scopeChips(String selected, ValueChanged<String> onSelected) {
  return Wrap(
    spacing: 8,
    runSpacing: 4,
    children: ['All', ...kScopes].map((label) {
      final isSelected = selected == label;
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) => onSelected(label),
        selectedColor: burgundy,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? burgundy : line),
        labelStyle: TextStyle(
            color: isSelected ? Colors.white : ink,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      );
    }).toList(),
  );
}

class StatusBadge extends StatelessWidget {
  final bool active;
  final bool scheduled;
  const StatusBadge({super.key, required this.active, this.scheduled = false});

  @override
  Widget build(BuildContext context) {
    final label = scheduled ? 'SCHEDULED' : (active ? 'ACTIVE' : 'EXPIRED');
    final bg = scheduled
        ? const Color(0xFFFFF3E0)
        : (active ? const Color(0xFFE8F5EC) : const Color(0xFFF0EFF0));
    final fg = scheduled
        ? const Color(0xFFB56B18)
        : (active ? const Color(0xFF27834A) : muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class TagWrap extends StatelessWidget {
  final List<String> tags;
  const TagWrap({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags
          .map((t) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: paleRose, borderRadius: BorderRadius.circular(10)),
                child: Text('#$t',
                    style: const TextStyle(
                        fontSize: 10,
                        color: burgundy,
                        fontWeight: FontWeight.w600)),
              ))
          .toList(),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12)),
      child: const Row(children: [
        Icon(Icons.cloud_off_outlined, size: 16, color: Color(0xFFB56B18)),
        SizedBox(width: 8),
        Expanded(
            child: Text('You are offline. Showing saved announcements.',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB56B18),
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class OfficerModeBanner extends StatelessWidget {
  const OfficerModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: paleRose, borderRadius: BorderRadius.circular(12)),
      child: const Row(children: [
        Icon(Icons.admin_panel_settings_outlined, size: 16, color: burgundy),
        SizedBox(width: 8),
        Expanded(
            child: Text(
                'Officer mode: you can edit or delete your own announcements.',
                style: TextStyle(
                    fontSize: 11,
                    color: burgundy,
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  Widget _cardAction(IconData icon, String label, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: burgundy,
        backgroundColor: paleRose,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final color = categoryColor(a.category);
    final edit = onEdit;
    final del = onDelete;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(
                  child: Text(a.category.isEmpty ? 'General' : a.category,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w700))),
              StatusBadge(active: a.active, scheduled: a.isScheduled),
            ]),
            if (a.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  a.imageUrl,
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(a.title,
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: ink)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: muted),
              const SizedBox(width: 5),
              Expanded(
                  child: Text('Effective: ${a.dates}',
                      style: const TextStyle(fontSize: 10, color: muted))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.account_balance_outlined,
                  size: 12, color: muted),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(a.office,
                      style: const TextStyle(fontSize: 10, color: muted))),
            ]),
            if (a.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              TagWrap(tags: a.tags),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: (edit == null && del == null)
                    ? const SizedBox.shrink()
                    : Wrap(spacing: 6, children: [
                        if (edit != null)
                          _cardAction(Icons.edit_outlined, 'Edit', edit),
                        if (del != null)
                          _cardAction(Icons.delete_outline, 'Delete', del),
                      ]),
              ),
              const Text('Tap to expand',
                  style: TextStyle(
                      fontSize: 10,
                      color: burgundy,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 13, color: burgundy),
            ]),
          ]),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Announcement> announcements;
  final bool loading;
  final String? error;
  final bool offline;
  final OfficerSession session;
  final ValueChanged<Announcement> onOpen;
  final VoidCallback onOpenNotifications;

  const HomeScreen({
    super.key,
    required this.announcements,
    required this.loading,
    required this.error,
    this.offline = false,
    required this.session,
    required this.onOpen,
    required this.onOpenNotifications,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  String? _value;

  static const _menuFilters = ['Category', 'Issuing Office', 'Status'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> _optionsFor(String filter) {
    switch (filter) {
      case 'Category':
        return kCategories;
      case 'Issuing Office':
        final extra = widget.announcements
            .map((a) => a.office)
            .where((o) => o.isNotEmpty && !kOffices.contains(o))
            .toSet()
            .toList();
        return [...kOffices, ...extra];
      case 'Status':
        return const ['Active', 'Expired'];
      default:
        return const [];
    }
  }

  Widget _pill(String label, bool selected, {bool arrow = false}) {
    final fg = selected ? Colors.white : ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? burgundy : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? burgundy : line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        if (arrow) Icon(Icons.arrow_drop_down, size: 18, color: fg),
      ]),
    );
  }

  Widget _filterButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _filter = 'All';
            _value = null;
          }),
          child: _pill('All', _filter == 'All'),
        ),
        ..._menuFilters.map((label) {
          return PopupMenuButton<String>(
            color: Colors.white,
            tooltip: '',
            onSelected: (v) => setState(() {
              _filter = label;
              _value = v;
            }),
            itemBuilder: (_) => _optionsFor(label)
                .map((o) => PopupMenuItem<String>(value: o, child: Text(o)))
                .toList(),
            child: _pill(label, _filter == label, arrow: true),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final session = widget.session;

    final filtered = widget.announcements.where((a) {
      if (a.isScheduled && !session.canManage(a)) return false;
      final v = _value;
      if (v != null) {
        if (_filter == 'Category' && a.category != v) return false;
        if (_filter == 'Issuing Office' && a.office != v) return false;
        if (_filter == 'Status') {
          if (v == 'Active' && !a.active) return false;
          if (v == 'Expired' && a.active) return false;
        }
      }
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q) ||
          a.office.toLowerCase().contains(q) ||
          a.description.toLowerCase().contains(q) ||
          a.tags.any((t) => t.toLowerCase().contains(q)) ||
          a.dates.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TUP Campus Updates',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ink)),
                SizedBox(height: 3),
                Text('Technological University of the Philippines',
                    style: TextStyle(fontSize: 11, color: muted)),
              ]),
            ),
            IconButton(
              tooltip: 'Notification preferences',
              onPressed: widget.onOpenNotifications,
              icon: const Icon(Icons.notifications_none_rounded,
                  color: burgundy),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (widget.offline) ...[
          const OfflineBanner(),
          const SizedBox(height: 14),
        ],
        if (session.user != null && session.approved) ...[
          const OfficerModeBanner(),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search by keyword or date...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        _filterButtons(),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
                child: Text('Latest announcements',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ink))),
            Text('${filtered.length} posts',
                style: const TextStyle(color: muted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.error != null)
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Could not load announcements: ${widget.error}'))
        else if (widget.loading)
          const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Column(children: [
              Icon(Icons.search_off, size: 36, color: muted),
              SizedBox(height: 8),
              Text('No announcements found.')
            ]),
          )
        else
          ...filtered.map((item) =>
              announcementCardFor(context, item, session, widget.onOpen)),
      ],
    );
  }
}

class AnnouncementDetailScreen extends StatelessWidget {
  final Announcement announcement;
  const AnnouncementDetailScreen({super.key, required this.announcement});

  Future<void> _share(BuildContext context) async {
    final a = announcement;
    final text =
        '${a.title}\n${a.dates}\nPosted by ${a.office}\n\n${a.description}';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showMsg(context, 'Announcement copied. Paste it anywhere to share.');
    }
  }

  Future<void> _saveToCalendar(BuildContext context) async {
    final a = announcement;
    final s = a.start ?? a.end;
    if (s == null) {
      showMsg(context, 'This announcement has no date to save.');
      return;
    }
    final e = a.end ?? s;
    final endExclusive =
        DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': a.title,
      'dates': '${_ymd(s)}/${_ymd(endExclusive)}',
      'details': '${a.description}\n\nPosted by ${a.office}',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (context.mounted) {
        showMsg(context, 'Could not open Google Calendar. Link copied instead.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Advisory Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(children: [
            const CircleAvatar(
                radius: 15,
                backgroundColor: paleRose,
                child: Icon(Icons.account_balance, color: burgundy, size: 16)),
            const SizedBox(width: 9),
            Expanded(
                child: Text('Posted by ${a.office}',
                    style: const TextStyle(fontSize: 12, color: muted))),
            StatusBadge(active: a.active, scheduled: a.isScheduled),
          ]),
          const SizedBox(height: 18),
          Text(a.title,
              style: const TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: ink)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.calendar_month_outlined, size: 16, color: muted),
            const SizedBox(width: 7),
            Expanded(
                child: Text(a.dates,
                    style: const TextStyle(fontSize: 12, color: muted))),
          ]),
          if (a.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            TagWrap(tags: a.tags),
          ],
          if (a.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                a.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(a.description,
              style: const TextStyle(
                  fontSize: 14, height: 1.65, color: Color(0xFF4F4A4E))),
          if (a.attachment.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('ATTACHMENT',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: muted)),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: a.attachment));
                if (context.mounted) showMsg(context, 'Link copied.');
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8F4E9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE9DFC9))),
                child: Row(children: [
                  const Icon(Icons.link, color: burgundy, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(a.attachment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12))),
                  const Icon(Icons.copy_outlined, color: burgundy, size: 20),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
                child: FilledButton.icon(
              onPressed: () => _saveToCalendar(context),
              icon: const Icon(Icons.calendar_month, size: 17),
              label: const Text('Save to Calendar'),
              style: FilledButton.styleFrom(
                  backgroundColor: burgundy,
                  padding: const EdgeInsets.symmetric(vertical: 13)),
            )),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _share(context),
              icon: const Icon(Icons.share_outlined, size: 17),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: burgundy,
                  side: const BorderSide(color: burgundy),
                  padding: const EdgeInsets.symmetric(
                      vertical: 13, horizontal: 12)),
            ),
          ]),
        ],
      ),
    );
  }
}

class EventsScreen extends StatefulWidget {
  final List<Announcement> announcements;
  final bool loading;
  final String? error;
  final OfficerSession session;
  final ValueChanged<Announcement> onOpen;
  const EventsScreen({
    super.key,
    required this.announcements,
    required this.loading,
    required this.error,
    required this.session,
    required this.onOpen,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _scope = 'All';

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final events = widget.announcements.where((a) {
      final isEvent =
          a.category == 'Campus Events' || a.category == 'Organization Updates';
      if (!isEvent) return false;
      if (a.isScheduled && !session.canManage(a)) return false;
      if (_scope != 'All' && a.scope != _scope) return false;
      return true;
    }).toList();

    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Campus Events',
          style:
              TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 4),
      const Text('Discover what is happening around TUP.',
          style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 18),
      scopeChips(_scope, (v) => setState(() => _scope = v)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: burgundy, borderRadius: BorderRadius.circular(18)),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.event_available, color: Colors.white, size: 30),
              SizedBox(height: 14),
              Text('Stay connected with campus life',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text(
                  'University-wide, college-specific, and student organization events.',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4)),
            ]),
      ),
      const SizedBox(height: 20),
      const Text('Upcoming and featured',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (widget.error != null)
        Text('Could not load events: ${widget.error}')
      else if (widget.loading)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()))
      else if (events.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.event_busy, size: 36, color: muted),
            SizedBox(height: 8),
            Text('No events posted yet.')
          ]),
        )
      else
        ...events.map(
            (e) => announcementCardFor(context, e, session, widget.onOpen)),
    ]);
  }
}

class HandbookSection {
  final String group;
  final String title;
  final String text;
  const HandbookSection(this.group, this.title, this.text);
}

IconData handbookIcon(String group) {
  switch (group) {
    case 'Academic Policies':
      return Icons.school_outlined;
    case 'Student Services':
      return Icons.support_agent_outlined;
    case 'Rules on Conduct and Discipline':
      return Icons.gavel_outlined;
    default:
      return Icons.info_outline;
  }
}

class HandbookScreen extends StatefulWidget {
  const HandbookScreen({super.key});

  @override
  State<HandbookScreen> createState() => _HandbookScreenState();
}

class _HandbookScreenState extends State<HandbookScreen> {
  final _search = TextEditingController();
  List<HandbookSection> _sections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/handbook.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final sections = list.map((e) {
        final m = e as Map<String, dynamic>;
        return HandbookSection('${m['group']}', '${m['title']}', '${m['text']}');
      }).toList();
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _snippet(HandbookSection s, String q) {
    final i = s.text.toLowerCase().indexOf(q);
    if (i < 0) return s.group;
    final start = i - 30 < 0 ? 0 : i - 30;
    final endRaw = i + q.length + 60;
    final end = endRaw > s.text.length ? s.text.length : endRaw;
    final piece = s.text.substring(start, end).replaceAll('\n', ' ');
    return '${start > 0 ? '...' : ''}$piece${end < s.text.length ? '...' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final visible = _sections.where((s) {
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.group.toLowerCase().contains(q) ||
          s.text.toLowerCase().contains(q);
    }).toList();

    final items = <Widget>[];
    String? lastGroup;
    for (final s in visible) {
      if (q.isEmpty && s.group != lastGroup) {
        items.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(s.group.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: muted)),
        ));
        lastGroup = s.group;
      }
      items.add(Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: line)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          leading: CircleAvatar(
              backgroundColor: paleRose,
              child: Icon(handbookIcon(s.group), color: burgundy, size: 20)),
          title: Text(s.title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          subtitle: Text(q.isEmpty ? s.group : _snippet(s, q),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: muted)),
          trailing: const Icon(Icons.chevron_right, color: burgundy),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HandbookDetailScreen(section: s),
          )),
        ),
      ));
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Student Handbook',
          style:
              TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 4),
      const Text('TUP 2013 Revised Student Handbook.',
          style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 18),
      TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
              hintText: 'Search handbook...', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 10),
      if (_loading)
        const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()))
      else if (_error != null)
        Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load the handbook: $_error'))
      else if (visible.isEmpty)
        const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No handbook topics found.'))
      else
        ...items,
    ]);
  }
}

class HandbookDetailScreen extends StatelessWidget {
  final HandbookSection section;
  const HandbookDetailScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(section.group,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(section.title,
              style: const TextStyle(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: ink)),
          const SizedBox(height: 14),
          SelectableText(section.text,
              style: const TextStyle(
                  fontSize: 14, height: 1.65, color: Color(0xFF4F4A4E))),
        ],
      ),
    );
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final Map<String, bool> _settings = {
    'Class Suspensions': true,
    'Emergency Alerts': true,
    'Campus Events': true,
    'TUP Admin Office': true,
    'Student Council': false,
    'College Organizations': false,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _settings.keys.toList()) {
        _settings[key] = prefs.getBool('notif_$key') ?? _settings[key]!;
      }
    });
  }

 
Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in _settings.entries) {
      await prefs.setBool('notif_${entry.key}', entry.value);
    }

    if (!mounted) return;

    Navigator.pop(context);
    showMsg(context, 'Preferences saved.');
  }

  @override
  Widget build(BuildContext context) {
    final categories = _settings.keys.toList();
    return Scaffold(
      appBar: AppBar(
          title: const Text('Notification Preferences',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('FILTER BY CATEGORY',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                color: muted,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...categories.take(3).map((name) =>
            _preferenceTile(name, 'Urgent campus updates and important notices')),
        const SizedBox(height: 20),
        const Text('FILTER BY CONTRIBUTOR',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                color: muted,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...categories.skip(3).map((name) =>
            _preferenceTile(name, 'Updates from this office or organization')),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: burgundy,
              padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: _save,
          child: const Text('Save Preferences',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _preferenceTile(String name, String subtitle) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 10, color: muted)),
        value: _settings[name]!,
        activeThumbColor: burgundy,
        onChanged: (value) => setState(() => _settings[name] = value),
      );
}

class OfficerScreen extends StatelessWidget {
  final OfficerSession session;
  final VoidCallback onRefresh;
  const OfficerScreen(
      {super.key, required this.session, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (!session.ready) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = session.user;
    if (user == null) return const OfficerLoginView();
    if (!session.approvalKnown) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!session.approved) return PendingApprovalView(user: user);
    return OfficerAccountView(user: user, role: session.role);
  }
}

Future<void> ensureOfficerDoc(User user, {String? role}) async {
  final ref = FirebaseFirestore.instance.collection('officers').doc(user.uid);
  final snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      'email': user.email,
      'approved': false,
      'createdAt': Timestamp.now(),
      if (role != null) 'role': role,
    }, SetOptions(merge: true));
  } else if (role != null && '${snap.data()?['role'] ?? ''}'.isEmpty) {
    try {
      await ref.update({'role': role});
    } catch (_) {}
  }
}

class OfficerLoginView extends StatefulWidget {
  const OfficerLoginView({super.key});

  @override
  State<OfficerLoginView> createState() => _OfficerLoginViewState();
}

class _OfficerLoginViewState extends State<OfficerLoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      showMsg(context, 'Enter your email and password to log in.');
      return;
    }
    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      final user = cred.user;
      if (user != null) await ensureOfficerDoc(user);
    } on FirebaseAuthException catch (e) {
      if (mounted) showMsg(context, 'Login failed: ${e.message}');
    } catch (e) {
      if (mounted) showMsg(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSignUp() async {
    final messenger = ScaffoldMessenger.of(context);
    final msg = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
    if (msg != null) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(22), children: [
      const SizedBox(height: 22),
      const Center(
          child: CircleAvatar(
              radius: 34,
              backgroundColor: paleRose,
              child: Icon(Icons.admin_panel_settings_outlined,
                  size: 36, color: burgundy))),
      const SizedBox(height: 18),
      const Text('TUP Account Sign-in',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      const Text('For authorized university officers and contributors',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 26),
      const Text('Officer Login',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Use your TUP email and password to continue.',
          style: TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 18),
      TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
              labelText: 'Email', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 12),
      TextField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) {
            if (!_busy) _login();
          },
          decoration: const InputDecoration(
              labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: burgundy,
            padding: const EdgeInsets.symmetric(vertical: 15)),
        onPressed: _busy ? null : _login,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Log In',
                style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('New officer?',
            style: TextStyle(fontSize: 12, color: muted)),
        TextButton(
          onPressed: _busy ? null : _openSignUp,
          child: const Text('Create account',
              style: TextStyle(color: burgundy, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
          kRequireApproval
              ? 'New accounts must be approved by an administrator before they can publish.'
              : 'Log in to publish announcements.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: muted)),
    ]);
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = kRoles.last;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;

    if (email.isEmpty || pass.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = 'Please fill in every field.');
      return;
    }
    if (!isTupEmail(email)) {
      setState(() => _error = 'Please sign up with your official TUP email address.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Your password must be at least 6 characters.');
      return;
    }
    if (pass != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
      final user = cred.user;
      if (user != null) {
        await ensureOfficerDoc(user, role: _role);
      }
      if (!mounted) return;
      Navigator.pop(context,
          'Account created. An administrator will approve it before you can publish.');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Could not create the account.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 28), children: [
        const Text('Officer sign-up',
            style:
                TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 6),
        const Text(
            'Use your official TUP email. An administrator will approve your account before you can publish.',
            style: TextStyle(fontSize: 12, color: muted, height: 1.5)),
        const SizedBox(height: 22),
        const Text('TUP email',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
                hintText: 'name@tup.edu.ph',
                prefixIcon: Icon(Icons.mail_outline))),
        const SizedBox(height: 16),
        const Text('Role',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: _role,
          decoration:
              const InputDecoration(prefixIcon: Icon(Icons.badge_outlined)),
          items: kRoles
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) => setState(() => _role = v ?? _role),
        ),
        const SizedBox(height: 16),
        const Text('Password',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
                hintText: 'At least 6 characters',
                prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 16),
        const Text('Confirm password',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextField(
            controller: _confirm,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
            decoration: const InputDecoration(
                hintText: 'Type your password again',
                prefixIcon: Icon(Icons.lock_outline))),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: paleRose, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, size: 16, color: burgundy),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: burgundy,
                          fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
              backgroundColor: burgundy,
              padding: const EdgeInsets.symmetric(vertical: 15)),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create account',
                  style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Back to login',
              style: TextStyle(color: burgundy)),
        ),
      ]),
    );
  }
}

class PendingApprovalView extends StatefulWidget {
  final User user;
  const PendingApprovalView({super.key, required this.user});

  @override
  State<PendingApprovalView> createState() => _PendingApprovalViewState();
}

class _PendingApprovalViewState extends State<PendingApprovalView> {
  @override
  void initState() {
    super.initState();
    ensureOfficerDoc(widget.user).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 40),
      const Center(
          child: CircleAvatar(
              radius: 34,
              backgroundColor: paleRose,
              child: Icon(Icons.hourglass_top, size: 34, color: burgundy))),
      const SizedBox(height: 18),
      const Text('Waiting for approval',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 8),
      Text(
          '${widget.user.email ?? 'This account'} has not been approved to publish yet. Please ask a TUP administrator to approve it.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: muted, height: 1.5)),
      const SizedBox(height: 22),
      OutlinedButton(
        onPressed: () => FirebaseAuth.instance.signOut(),
        style: OutlinedButton.styleFrom(
            foregroundColor: burgundy,
            side: const BorderSide(color: burgundy),
            padding: const EdgeInsets.symmetric(vertical: 14)),
        child: const Text('Log out'),
      ),
    ]);
  }
}

class OfficerAccountView extends StatelessWidget {
  final User user;
  final String role;
  const OfficerAccountView({super.key, required this.user, this.role = ''});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(22), children: [
      const SizedBox(height: 22),
      const Center(
          child: CircleAvatar(
              radius: 34,
              backgroundColor: paleRose,
              child: Icon(Icons.admin_panel_settings_outlined,
                  size: 36, color: burgundy))),
      const SizedBox(height: 18),
      const Text('Officer Account',
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      const Text('Manage announcements for the campus community',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 26),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line)),
        child: Row(children: [
          const CircleAvatar(
              radius: 20,
              backgroundColor: paleRose,
              child: Icon(Icons.person_outline, color: burgundy, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('LOGGED IN AS',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: muted)),
              const SizedBox(height: 4),
              Text(user.email ?? 'Unknown account',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 2),
              Text(role.isEmpty ? 'Role not set' : role,
                  style: const TextStyle(fontSize: 11, color: muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5EC),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('APPROVED',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF27834A))),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => openAnnouncementForm(context, user, null),
        icon: const Icon(Icons.add),
        label: const Text('Publish announcement',
            style: TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(
            backgroundColor: burgundy,
            padding: const EdgeInsets.symmetric(vertical: 15)),
      ),
      const SizedBox(height: 12),
      const Text(
          'To edit or delete your announcements, go to Home. Your posts have Edit and Delete buttons.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: muted, height: 1.5)),
      const SizedBox(height: 22),
      OutlinedButton(
        onPressed: () => FirebaseAuth.instance.signOut(),
        style: OutlinedButton.styleFrom(
            foregroundColor: burgundy,
            side: const BorderSide(color: burgundy),
            padding: const EdgeInsets.symmetric(vertical: 14)),
        child: const Text('Log out'),
      ),
    ]);
  }
}

class AnnouncementFormScreen extends StatefulWidget {
  final User user;
  final Announcement? existing;
  const AnnouncementFormScreen(
      {super.key, required this.user, this.existing});

  @override
  State<AnnouncementFormScreen> createState() =>
      _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _office;
  late final TextEditingController _attachment;
  late final TextEditingController _tags;
  late String _category;
  late String _scope;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String _currentImageUrl = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _currentImageUrl = e?.imageUrl ?? '';
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _office = TextEditingController(text: e?.office ?? 'TUP Admin');
    _attachment = TextEditingController(text: e?.attachment ?? '');
    _tags = TextEditingController(text: e?.tags.join(', ') ?? '');
    _category = (e != null && kCategories.contains(e.category))
        ? e.category
        : kCategories.first;
    _scope = (e != null && kScopes.contains(e.scope)) ? e.scope : kScopes.first;
    _start = e?.start;
    _end = e?.end;
  }

  Future<void> _pickImage() async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose an image smaller than 5 MB.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
  _selectedImage = picked;
  _selectedImageBytes = bytes;
});
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select image: $e')),
      );
    }
  }
}

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _office.dispose();
    _attachment.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = (isStart ? _start : _end) ?? _start ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  String _dateLabel(DateTime? date) =>
      date == null ? 'Select date' : fmtDate(date);

  String _dateSummary() {
    final s = _start;
    final e = _end;
    if (s != null && e != null) return '${fmtDate(s)} – ${fmtDate(e)}';
    if (s != null) return fmtDate(s);
    if (e != null) return 'Until ${fmtDate(e)}';
    return 'No date set';
  }

  List<String> _parsedTags() => _tags.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  String _statusPreview() {
    final s = _start;
    if (hasEnded(s, _end)) {
      return 'This will show as EXPIRED because the date range has already passed.';
    }
    if (s != null && startsLater(s)) {
      return 'This will be SCHEDULED and go live on ${fmtDate(s)}. Only you can see it until then.';
    }
    return 'This will show as ACTIVE.';
  }

  Future<bool> _confirmPublish() async {
    final editing = widget.existing != null;
    final tags = _parsedTags();
    final office = _office.text.trim().isEmpty
        ? 'TUP Contributor'
        : _office.text.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review announcement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title.text.trim(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text('Category: $_category'),
              const SizedBox(height: 4),
              Text('Audience: $_scope'),
              const SizedBox(height: 4),
              Text('Issuing office: $office'),
              const SizedBox(height: 4),
              Text('Dates: ${_dateSummary()}'),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Tags: ${tags.map((t) => '#$t').join(' ')}'),
              ],
              const SizedBox(height: 10),
              Text(
                _statusPreview(),
                style: const TextStyle(
                  fontSize: 11,
                  color: burgundy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              editing ? 'Save' : 'Publish',
              style: const TextStyle(color: burgundy),
            ),
          ),
        ],
      ),
    );

    return ok == true && mounted;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty ||
        _description.text.trim().isEmpty) {
      showMsg(context, 'Enter a title and description first.');
      return;
    }

    final s = _start;
    final e = _end;

    if (s != null && e != null && e.isBefore(s)) {
      showMsg(context, 'The end date must be on or after the start date.');
      return;
    }

    final confirmed = await _confirmPublish();
    if (!confirmed) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category,
      'scope': _scope,
      'issuing_office': _office.text.trim().isEmpty
          ? 'TUP Contributor'
          : _office.text.trim(),
      'description': _description.text.trim(),
      'attachment_link': _attachment.text.trim(),
      'tags': _parsedTags(),
      'start_date': s == null ? null : Timestamp.fromDate(s),
      'end_date': e == null ? null : Timestamp.fromDate(e),
      'updatedAt': Timestamp.now(),
    };

    Reference? uploadedImageRef;

    try {
      // Preserve the existing image if no replacement is selected.
      String imageUrl = _currentImageUrl;

      if (_selectedImageBytes != null && _selectedImage != null) {
        final extension = _selectedImage!.name.split('.').last.toLowerCase();
        final safeExtension = extension == 'png' ? 'png' : 'jpg';
        final contentType = safeExtension == 'png' ? 'image/png' : 'image/jpeg';

        uploadedImageRef = FirebaseStorage.instance.ref().child(
          'announcement_images/${widget.user.uid}_'
          '${DateTime.now().millisecondsSinceEpoch}.$safeExtension',
        );

        final uploadTask = await uploadedImageRef!.putData(
          _selectedImageBytes!,
          SettableMetadata(contentType: contentType),
        );

        imageUrl = await uploadTask.ref.getDownloadURL();
      }

      data['imageUrl'] = imageUrl;

      final col = FirebaseFirestore.instance.collection('announcements');
      final existing = widget.existing;

      if (existing == null) {
        await col.add({
          ...data,
          'status': 'active',
          'createdAt': Timestamp.now(),
          'createdBy': widget.user.uid,
          'createdByEmail': widget.user.email,
        });
      } else {
        await col.doc(existing.id).update(data);
      }

      if (!mounted) return;

      Navigator.pop(
        context,
        existing == null
            ? 'Announcement published.'
            : 'Announcement updated.',
      );
    } catch (err) {
      if (uploadedImageRef != null) {
        try {
          await uploadedImageRef!.delete();
        } catch (_) {
          // Ignore cleanup errors.
        }
      }

      if (!mounted) return;

      setState(() => _saving = false);
      showMsg(context, 'Could not save: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Announcement' : 'New Announcement',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('Announcement Title',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            TextField(
                controller: _title,
                decoration: const InputDecoration(
                    hintText: 'Enter announcement title')),
            const SizedBox(height: 16),
            const Text('Category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: _category,
              items: kCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),
            const Text('Audience',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: _scope,
              items: kScopes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _scope = v ?? _scope),
            ),
            const SizedBox(height: 16),
            const Text('Issuing Office',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            TextField(
                controller: _office,
                decoration: const InputDecoration(
                    hintText: 'Office or organization')),
            const SizedBox(height: 16),
            const Text('Announcement Description',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            TextField(
                controller: _description,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                    hintText: 'Enter announcement details')),
            const SizedBox(height: 16),
            const Text('Event tags (optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            TextField(
                controller: _tags,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    hintText: 'Separate with commas, e.g. enrollment, sports',
                    prefixIcon: Icon(Icons.tag))),
            const SizedBox(height: 16),
            const Text('Effective Date Range',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'Shows from the start date and turns EXPIRED after the end date. Leave the end date blank for a one-day announcement, or leave both blank to keep it active.',
                style: TextStyle(fontSize: 10, color: muted)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today, size: 15),
                      label: Text(_dateLabel(_start),
                          style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: burgundy))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.event, size: 15),
                      label: Text(_dateLabel(_end),
                          style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: burgundy))),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: paleRose, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 15, color: burgundy),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_statusPreview(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: burgundy,
                            fontWeight: FontWeight.w600))),
              ]),
            ),
            if (_start != null || _end != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: () => setState(() {
                          _start = null;
                          _end = null;
                        }),
                    child: const Text('Clear dates',
                        style: TextStyle(color: burgundy, fontSize: 12))),
              ),
            const SizedBox(height: 12),
            const Text(
  'Announcement Photo (optional)',
  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
),
const SizedBox(height: 7),

if (_selectedImageBytes != null)
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(
      _selectedImageBytes!,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  )
else if (_currentImageUrl.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      _currentImageUrl,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Text('Could not load existing image.'),
    ),
  ),

if (_selectedImage != null) ...[
  const SizedBox(height: 5),
  Text(
    'Selected: ${_selectedImage!.name}',
    style: const TextStyle(fontSize: 11, color: muted),
  ),
],
OutlinedButton.icon(
  onPressed: _saving ? null : _pickImage,
  icon: const Icon(Icons.image_outlined),
  label: const Text('Choose Photo'),
  style: OutlinedButton.styleFrom(
    foregroundColor: burgundy,
  ),
),

const SizedBox(height: 16),
            const Text('Attachment link (optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            TextField(
                controller: _attachment,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    hintText: 'Paste a link to a PDF or Google Drive file',
                    prefixIcon: Icon(Icons.attach_file))),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.publish),
              label: Text(editing ? 'Save Changes' : 'Publish Announcement',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                  backgroundColor: burgundy,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ]),
    );
  }
}