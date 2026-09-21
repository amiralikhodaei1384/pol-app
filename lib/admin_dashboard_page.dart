import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/login_page.dart';
import 'package:pol_app/widgets/profile_menu_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Rewrites latin digits in [input] with their Persian equivalents.
String _fa(Object? input) {
  return (input ?? '').toString().replaceAllMapped(
        RegExp(r'[0-9]'),
        (m) => _persianDigits[int.parse(m[0]!)],
      );
}

// رنگ‌های مشترک با بقیه داشبوردها
const _brand = Color(0xFF1E6AFB);
const _sidebar = Color(0xFF114EC4);
const _ink = Color(0xFF1E293B);
const _inkMuted = Color(0xFF64748B);
const _inkFaint = Color(0xFF94A3B8);
const _line = Color(0xFFE2E8F0);
const _danger = Color(0xFFDC2626);
const _success = Color(0xFF10B981);

enum _Section { overview, users, projects, options, broadcast }

const _sectionTitles = {
  _Section.overview: 'نمای کلی سامانه',
  _Section.users: 'مدیریت کاربران',
  _Section.projects: 'مدیریت پروژه‌ها',
  _Section.options: 'اطلاعات پایه',
  _Section.broadcast: 'ارسال اعلان همگانی',
};

// فهرست‌های قابل ویرایش در بخش «اطلاعات پایه»
const _optionKinds = {
  'universities': 'دانشگاه‌ها',
  'majors': 'رشته‌ها',
  'degrees': 'مقاطع تحصیلی',
  'cities': 'شهرها',
  'categories': 'دسته‌بندی پروژه',
  'skills': 'مهارت‌ها',
  'project_types': 'نوع همکاری',
};

/// Admin panel: platform statistics and management of users, projects, option lists and announcements.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  _Section _section = _Section.overview;
  String _token = '';
  String _adminEmail = '';

  // نمای کلی
  Map<String, dynamic>? _stats;
  bool _loadingStats = true;

  // کاربران
  List<dynamic> _users = [];
  bool _loadingUsers = false;
  String _userRole = 'all';
  final _userSearch = TextEditingController();

  // پروژه‌ها
  List<dynamic> _projects = [];
  bool _loadingProjects = false;
  String _projectStatus = 'all';
  final _projectSearch = TextEditingController();

  // اطلاعات پایه
  Map<String, dynamic> _options = {};
  bool _loadingOptions = false;
  String _optionKind = 'universities';
  final _optionCtrl = TextEditingController();

  // اعلان همگانی
  String _audience = 'all';
  final _broadcastTitle = TextEditingController();
  final _broadcastMessage = TextEditingController();
  bool _sending = false;

  // شناسه ردیف‌هایی که عملیاتشان در جریان است
  final Set<String> _busy = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _userSearch.dispose();
    _projectSearch.dispose();
    _optionCtrl.dispose();
    _broadcastTitle.dispose();
    _broadcastMessage.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token') ?? '';
    final me = await ApiService.getMe(_token);
    if (mounted && me != null) setState(() => _adminEmail = me['email'] ?? '');
    await _loadSection(_section);
  }

  Future<void> _loadSection(_Section section) {
    switch (section) {
      case _Section.overview:
        return _loadStats();
      case _Section.users:
        return _loadUsers();
      case _Section.projects:
        return _loadProjects();
      case _Section.options:
        return _loadOptions();
      case _Section.broadcast:
        return Future.value();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final stats = await ApiService.fetchAdminStats(_token);
    if (mounted) setState(() { _stats = stats; _loadingStats = false; });
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    final users = await ApiService.fetchAdminUsers(_token, role: _userRole, search: _userSearch.text);
    if (mounted) setState(() { _users = users; _loadingUsers = false; });
  }

  Future<void> _loadProjects() async {
    setState(() => _loadingProjects = true);
    final projects = await ApiService.fetchAdminProjects(_token, status: _projectStatus, search: _projectSearch.text);
    if (mounted) setState(() { _projects = projects; _loadingProjects = false; });
  }

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    final options = await ApiService.fetchAdminOptions(_token);
    if (mounted) setState(() { _options = options ?? {}; _loadingOptions = false; });
  }

  void _select(_Section section) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
    setState(() => _section = section);
    _loadSection(section);
  }

  void _onSearchChanged(VoidCallback reload) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), reload);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // ---------------- helpers ----------------

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? _danger : _success),
    );
  }

  Future<bool> _confirm({required String title, required String message, required String confirmLabel, bool danger = true}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded, color: danger ? _danger : _brand),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink))),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF475569))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف', style: TextStyle(color: _inkMuted))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? _danger : _brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  /// Runs an admin write for row [id], showing a spinner on it and the result as a snackbar.
  Future<bool> _runRowAction(String id, Future<String?> Function() action, String successMessage) async {
    setState(() => _busy.add(id));
    final error = await action();
    if (!mounted) return false;
    setState(() => _busy.remove(id));
    _toast(error ?? successMessage, error: error != null);
    return error == null;
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      );

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) {
    return Container(width: double.infinity, padding: padding, decoration: _cardDecoration, child: child);
  }

  Widget _cardHeader(String title, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: _brand),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink))),
        ?trailing,
      ],
    );
  }

  Widget _pill(String text, {Color color = _inkMuted, Color? bg, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg ?? color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _brand : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _brand : _line),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white : const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _searchField(TextEditingController controller, String hint, VoidCallback reload) {
    return TextField(
      controller: controller,
      onChanged: (_) => _onSearchChanged(reload),
      onSubmitted: (_) => reload(),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: _inkFaint),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _inkMuted),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand, width: 1.2)),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: _inkFaint),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand, width: 1.2)),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 40, color: _inkFaint),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _inkMuted)),
        ],
      ),
    );
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: _brand)),
      );

  // نقش کاربر ← برچسب، آیکون و رنگ
  (String, IconData, Color) _roleStyle(String role) {
    switch (role) {
      case 'student':
        return ('دانشجو', Icons.school_outlined, _success);
      case 'company_rep':
        return ('کارفرما', Icons.business_outlined, const Color(0xFF7C3AED));
      default:
        return ('مدیر', Icons.admin_panel_settings_outlined, _brand);
    }
  }

  Widget _roleAvatar(String role, {double size = 40}) {
    final (_, icon, color) = _roleStyle(role);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // The fixed sidebar needs room next to it; below this the panel uses a drawer.
    final showSidebar = screenWidth >= 900;
    final isMobile = screenWidth < 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF3F5FA),
        drawer: showSidebar ? null : Drawer(child: _buildSidebar()),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSidebar) SizedBox(width: 250, child: _buildSidebar()),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(showMenuButton: !showSidebar),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _loadSection(_section),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: KeyedSubtree(
                              key: ValueKey(_section),
                              child: _buildSection(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Each section lays itself out from the width it actually gets, not the screen width,
  // so it also works in the narrow space next to the sidebar.
  Widget _buildSection() {
    switch (_section) {
      case _Section.overview:
        return LayoutBuilder(builder: (context, box) => _buildOverview(width: box.maxWidth));
      case _Section.users:
        return _buildUsers();
      case _Section.projects:
        return _buildProjects();
      case _Section.options:
        return _buildOptions();
      case _Section.broadcast:
        return _buildBroadcast();
    }
  }

  Widget _buildTopBar({required bool showMenuButton}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              _sectionTitles[_section]!,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
            ),
          ),
          IconButton(
            tooltip: 'به‌روزرسانی',
            icon: const Icon(Icons.refresh_rounded, color: _brand),
            onPressed: () => _loadSection(_section),
          ),
          const SizedBox(width: 8),
          ProfileMenuButton(
            name: 'مدیر سامانه',
            roleLabel: _adminEmail.isNotEmpty ? _adminEmail : 'حساب مدیر',
            onLogout: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: _sidebar,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Image.asset(
              'assets/Untitled_design-removebg-preview.png',
              height: 85,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.domain, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text('پنل مدیریت', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _navItem(Icons.space_dashboard_outlined, 'نمای کلی', _Section.overview),
                _navItem(Icons.people_alt_outlined, 'مدیریت کاربران', _Section.users),
                _navItem(Icons.work_outline_rounded, 'مدیریت پروژه‌ها', _Section.projects),
                _navItem(Icons.tune_rounded, 'اطلاعات پایه', _Section.options),
                _navItem(Icons.campaign_outlined, 'ارسال اعلان همگانی', _Section.broadcast),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                _navTile(Icons.exit_to_app, 'خروج از حساب', onTap: _logout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String title, _Section section) {
    return _navTile(icon, title, isActive: _section == section, onTap: () => _select(section));
  }

  Widget _navTile(IconData icon, String title, {bool isActive = false, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(title, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        dense: true,
        onTap: onTap,
      ),
    );
  }

  // ---------------- نمای کلی ----------------

  Widget _buildOverview({required double width}) {
    if (_loadingStats && _stats == null) return _loading();
    final stats = _stats;
    if (stats == null) {
      return Column(
        children: [
          _emptyState(Icons.cloud_off_rounded, 'دریافت آمار از سرور ممکن نشد.'),
          const SizedBox(height: 12),
          TextButton.icon(onPressed: _loadStats, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
        ],
      );
    }

    final users = stats['users'] as Map<String, dynamic>;
    final projects = stats['projects'] as Map<String, dynamic>;
    final apps = stats['applications'] as Map<String, dynamic>;
    final chats = stats['chats'] as Map<String, dynamic>;

    final tiles = [
      _StatTile('کل کاربران', users['total'], Icons.people_alt_outlined, _brand, '${_fa(users['new_this_week'])} عضو جدید در این هفته'),
      _StatTile('دانشجویان', users['students'], Icons.school_outlined, _success, 'حساب دانشجویی'),
      _StatTile('کارفرمایان', users['companies'], Icons.business_outlined, const Color(0xFF7C3AED), '${_fa(stats['companies'])} شرکت ثبت‌شده'),
      _StatTile('پروژه‌ها', projects['total'], Icons.work_outline_rounded, const Color(0xFFF59E0B), '${_fa(projects['active'])} پروژه فعال'),
      _StatTile('درخواست‌ها', apps['total'], Icons.assignment_outlined, const Color(0xFF0EA5E9), '${_fa(apps['shortlisted'])} دعوت به مصاحبه'),
      _StatTile('گفتگوها', chats['threads'], Icons.chat_bubble_outline_rounded, const Color(0xFFEC4899), '${_fa(chats['messages'])} پیام ردوبدل‌شده'),
      _StatTile('کاربران مسدود', users['blocked'], Icons.block_rounded, _danger, 'دسترسی قطع‌شده'),
    ];

    final signupChart = _card(child: _SignupChart(days: (stats['signups_last_7_days'] as List).cast<Map<String, dynamic>>()));
    final statusBars = _card(child: _ApplicationStatusBars(apps: apps));
    final topProjects = _buildTopProjects((stats['top_projects'] as List?) ?? []);
    final latestUsers = _buildLatestUsers((stats['latest_users'] as List?) ?? []);

    // Two cards side by side only when each still gets a comfortable width.
    final sideBySide = width >= 760;
    Widget pair(Widget a, Widget b) => sideBySide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)])
        : Column(children: [a, const SizedBox(height: 16), b]);

    const tileGap = 12.0;
    final columns = width >= 1100 ? 4 : width >= 720 ? 3 : width >= 330 ? 2 : 1;
    final tileWidth = (width - tileGap * (columns - 1)) / columns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdminBanner(compact: width < 600),
        const SizedBox(height: 20),
        Wrap(
          spacing: tileGap,
          runSpacing: tileGap,
          children: tiles.map((t) => SizedBox(width: tileWidth, child: _buildStatTile(t, compact: tileWidth < 200))).toList(),
        ),
        const SizedBox(height: 16),
        pair(signupChart, statusBars),
        const SizedBox(height: 16),
        pair(topProjects, latestUsers),
      ],
    );
  }

  Widget _buildAdminBanner({required bool compact}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F52BA), _brand], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.all(compact ? 20 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('پنل مدیریت پل 🛡️', style: TextStyle(color: Colors.white, fontSize: compact ? 17 : 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'کاربران، پروژه‌ها و اطلاعات پایه سامانه را از اینجا مدیریت کنید.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _select(_Section.users),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black87),
                child: const Text('مدیریت کاربران', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              OutlinedButton(
                onPressed: () => _select(_Section.broadcast),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                child: const Text('ارسال اعلان همگانی', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(_StatTile t, {bool compact = false}) {
    final iconBox = compact ? 36.0 : 44.0;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(color: t.color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(compact ? 10 : 12)),
            child: Icon(t.icon, color: t.color, size: iconBox / 2),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _inkMuted)),
                const SizedBox(height: 2),
                Text(_fa(t.value ?? 0), maxLines: 1, style: TextStyle(fontSize: compact ? 18 : 22, fontWeight: FontWeight.bold, color: _ink)),
                Text(t.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _inkFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProjects(List<dynamic> items) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('پرطرفدارترین پروژه‌ها', icon: Icons.local_fire_department_outlined),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('هنوز پروژه‌ای ثبت نشده است.', style: TextStyle(fontSize: 11, color: _inkMuted)),
            )
          else
            ...items.asMap().entries.map((e) {
              final p = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Text(_fa(e.key + 1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink)),
                          Text(p['company_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _inkMuted)),
                        ],
                      ),
                    ),
                    _pill('${_fa(p['applications'])} درخواست', color: _brand),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLatestUsers(List<dynamic> items) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            'آخرین کاربران ثبت‌نام‌شده',
            icon: Icons.person_add_alt_outlined,
            trailing: TextButton(onPressed: () => _select(_Section.users), child: const Text('همه کاربران', style: TextStyle(fontSize: 11))),
          ),
          const SizedBox(height: 4),
          ...items.map((u) {
            final name = (u['name'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _roleAvatar(u['role'] ?? '', size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isNotEmpty ? name : 'بدون نام', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ink)),
                        Text(u['email'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _inkMuted)),
                      ],
                    ),
                  ),
                  Text(_fa(u['created_at_fa']), style: const TextStyle(fontSize: 10, color: _inkFaint)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------- کاربران ----------------

  Widget _buildUsers() {
    const roles = {'all': 'همه', 'student': 'دانشجویان', 'company_rep': 'کارفرمایان', 'admin': 'مدیران'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchField(_userSearch, 'جستجو بر اساس نام، ایمیل یا نام شرکت...', _loadUsers),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: roles.entries.map((r) => _filterChip(r.value, _userRole == r.key, () {
                            setState(() => _userRole = r.key);
                            _loadUsers();
                          })).toList(),
                    ),
                  ),
                  _pill('${_fa(_users.length)} کاربر', bg: const Color(0xFFF1F5F9), color: const Color(0xFF475569)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingUsers && _users.isEmpty)
          _loading()
        else if (_users.isEmpty)
          _emptyState(Icons.person_search_outlined, 'کاربری با این مشخصات پیدا نشد.')
        else
          ..._users.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LayoutBuilder(builder: (context, box) => _buildUserCard(u, stacked: box.maxWidth < 560)),
              )),
      ],
    );
  }

  Widget _buildUserCard(dynamic u, {required bool stacked}) {
    final id = u['id'].toString();
    final role = (u['role'] ?? '').toString();
    final (roleLabel, _, roleColor) = _roleStyle(role);
    final isActive = u['is_active'] == true;
    final isAdmin = role == 'admin';
    final busy = _busy.contains(id);
    final name = (u['name'] ?? '').toString();
    final detail = (u['detail'] ?? '').toString();
    final activity = role == 'student'
        ? '${_fa(u['activity_count'])} درخواست ارسالی'
        : role == 'company_rep'
            ? '${_fa(u['activity_count'])} پروژه ثبت‌شده'
            : null;

    final actions = isAdmin
        ? _pill('حساب مدیر', icon: Icons.lock_outline_rounded)
        : busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _brand))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(
                    icon: isActive ? Icons.block_rounded : Icons.lock_open_rounded,
                    label: isActive ? 'مسدود کردن' : 'رفع مسدودیت',
                    color: isActive ? const Color(0xFFB45309) : _success,
                    onTap: () => _toggleUser(u),
                  ),
                  const SizedBox(width: 6),
                  _actionButton(icon: Icons.delete_outline_rounded, label: 'حذف', color: _danger, onTap: () => _deleteUser(u)),
                ],
              );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration.copyWith(
        border: Border.all(color: isActive ? _line : _danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _roleAvatar(role),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isNotEmpty ? name : 'بدون نام', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _ink)),
                    const SizedBox(height: 2),
                    Text(u['email'] ?? '', style: const TextStyle(fontSize: 11, color: _inkMuted)),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _inkFaint)),
                    ],
                  ],
                ),
              ),
              if (!stacked) actions,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(roleLabel, color: roleColor),
              isActive
                  ? _pill('فعال', color: _success, icon: Icons.check_circle_outline_rounded)
                  : _pill('مسدود', color: _danger, icon: Icons.block_rounded),
              _pill('عضویت: ${_fa(u['created_at_fa'])}', icon: Icons.calendar_today_outlined),
              if (activity != null) _pill(activity, icon: Icons.insights_outlined),
            ],
          ),
          if (stacked) ...[
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerEnd, child: actions),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUser(dynamic u) async {
    final id = u['id'].toString();
    final block = u['is_active'] == true;
    final who = (u['name'] ?? '').toString().isNotEmpty ? u['name'] : u['email'];

    final ok = await _confirm(
      title: block ? 'مسدود کردن کاربر' : 'رفع مسدودیت کاربر',
      message: block
          ? '«$who» دیگر نمی‌تواند وارد حساب خود شود و نشست فعلی او نیز بلافاصله از کار می‌افتد. اطلاعات او حذف نمی‌شود.'
          : '«$who» دوباره می‌تواند وارد حساب خود شود.',
      confirmLabel: block ? 'مسدود شود' : 'رفع مسدودیت',
      danger: block,
    );
    if (!ok) return;

    final done = await _runRowAction(
      id,
      () => ApiService.setUserActive(_token, id, !block),
      block ? 'کاربر مسدود شد.' : 'مسدودیت کاربر برداشته شد.',
    );
    if (done && mounted) setState(() => u['is_active'] = !block);
  }

  Future<void> _deleteUser(dynamic u) async {
    final id = u['id'].toString();
    final who = (u['name'] ?? '').toString().isNotEmpty ? u['name'] : u['email'];
    final consequence = u['role'] == 'company_rep'
        ? 'اگر این کاربر تنها نماینده شرکت باشد، شرکت و تمام پروژه‌ها و درخواست‌های آن هم حذف می‌شود.'
        : 'تمام درخواست‌ها، گفتگوها، اعلان‌ها و فایل رزومه این کاربر هم حذف می‌شود.';

    final ok = await _confirm(
      title: 'حذف دائمی کاربر',
      message: 'حساب «$who» برای همیشه حذف می‌شود و قابل بازگشت نیست.\n$consequence',
      confirmLabel: 'حذف دائمی',
    );
    if (!ok) return;

    final done = await _runRowAction(id, () => ApiService.deleteUserAsAdmin(_token, id), 'کاربر حذف شد.');
    if (done && mounted) setState(() => _users.removeWhere((x) => x['id'].toString() == id));
  }

  // ---------------- پروژه‌ها ----------------

  Widget _buildProjects() {
    const statuses = {'all': 'همه', 'active': 'فعال', 'inactive': 'غیرفعال'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchField(_projectSearch, 'جستجو بر اساس عنوان پروژه یا نام شرکت...', _loadProjects),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statuses.entries.map((s) => _filterChip(s.value, _projectStatus == s.key, () {
                            setState(() => _projectStatus = s.key);
                            _loadProjects();
                          })).toList(),
                    ),
                  ),
                  _pill('${_fa(_projects.length)} پروژه', bg: const Color(0xFFF1F5F9), color: const Color(0xFF475569)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingProjects && _projects.isEmpty)
          _loading()
        else if (_projects.isEmpty)
          _emptyState(Icons.work_off_outlined, 'پروژه‌ای با این مشخصات پیدا نشد.')
        else
          ..._projects.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LayoutBuilder(builder: (context, box) => _buildProjectCard(p, stacked: box.maxWidth < 560)),
              )),
      ],
    );
  }

  Widget _buildProjectCard(dynamic p, {required bool stacked}) {
    final id = p['id'].toString();
    final isActive = p['is_active'] == true;
    final busy = _busy.contains(id);

    final controls = busy
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _brand))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: isActive ? 'پنهان کردن از دانشجویان' : 'نمایش به دانشجویان',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isActive ? 'فعال' : 'غیرفعال', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isActive ? _success : _inkMuted)),
                    Switch(
                      value: isActive,
                      activeTrackColor: _success,
                      onChanged: (_) => _toggleProject(p),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _actionButton(icon: Icons.delete_outline_rounded, label: 'حذف', color: _danger, onTap: () => _deleteProject(p)),
            ],
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isActive ? _brand : _inkFaint).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work_outline_rounded, size: 20, color: isActive ? _brand : _inkFaint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['title'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? _ink : _inkMuted)),
                    const SizedBox(height: 2),
                    Text(p['company_name'] ?? '', style: const TextStyle(fontSize: 11, color: _brand, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (!stacked) controls,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if ((p['project_type'] ?? '').toString().isNotEmpty) _pill(p['project_type'], color: const Color(0xFF7C3AED)),
              if ((p['city'] ?? '').toString().isNotEmpty) _pill(p['city'], icon: Icons.location_on_outlined),
              if ((p['category'] ?? '').toString().isNotEmpty) _pill(p['category'], icon: Icons.category_outlined),
              _pill('${_fa(p['applications'])} درخواست', color: _brand, icon: Icons.assignment_outlined),
              _pill('ثبت: ${_fa(p['created_at_fa'])}', icon: Icons.calendar_today_outlined),
              if ((p['deadline'] ?? '').toString().isNotEmpty) _pill('مهلت: ${_fa(p['deadline'])}', icon: Icons.hourglass_bottom_rounded),
            ],
          ),
          if (stacked) ...[
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerEnd, child: controls),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleProject(dynamic p) async {
    final id = p['id'].toString();
    final activate = p['is_active'] != true;
    if (!activate) {
      final ok = await _confirm(
        title: 'غیرفعال کردن پروژه',
        message: 'پروژه «${p['title']}» از فهرست دانشجویان پنهان می‌شود و به کارفرما اطلاع داده می‌شود. درخواست‌های قبلی حفظ می‌شوند.',
        confirmLabel: 'غیرفعال شود',
      );
      if (!ok) return;
    }
    final done = await _runRowAction(
      id,
      () => ApiService.setProjectActive(_token, id, activate),
      activate ? 'پروژه دوباره فعال شد.' : 'پروژه غیرفعال شد.',
    );
    if (done && mounted) setState(() => p['is_active'] = activate);
  }

  Future<void> _deleteProject(dynamic p) async {
    final id = p['id'].toString();
    final ok = await _confirm(
      title: 'حذف دائمی پروژه',
      message: 'پروژه «${p['title']}» همراه با ${_fa(p['applications'])} درخواست و گفتگوهای مربوط به آن برای همیشه حذف می‌شود. به کارفرما اطلاع داده می‌شود.',
      confirmLabel: 'حذف دائمی',
    );
    if (!ok) return;
    final done = await _runRowAction(id, () => ApiService.deleteProjectAsAdmin(_token, id), 'پروژه حذف شد.');
    if (done && mounted) setState(() => _projects.removeWhere((x) => x['id'].toString() == id));
  }

  // ---------------- اطلاعات پایه ----------------

  Widget _buildOptions() {
    if (_loadingOptions && _options.isEmpty) return _loading();
    final items = ((_options[_optionKind] as List?) ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _optionKinds.entries.map((k) {
              final count = ((_options[k.key] as List?) ?? []).length;
              return _filterChip('${k.value} (${_fa(count)})', _optionKind == k.key, () {
                setState(() {
                  _optionKind = k.key;
                  _optionCtrl.clear();
                });
              });
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader(_optionKinds[_optionKind]!, icon: Icons.list_alt_rounded, trailing: _pill('${_fa(items.length)} گزینه')),
              const SizedBox(height: 6),
              const Text(
                'این فهرست‌ها در فرم‌های پروفایل و ثبت پروژه نمایش داده می‌شوند. حذف یک گزینه اطلاعات ثبت‌شده قبلی را تغییر نمی‌دهد.',
                style: TextStyle(fontSize: 10.5, color: _inkMuted, height: 1.6),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionCtrl,
                      onSubmitted: (_) => _addOption(),
                      style: const TextStyle(fontSize: 12),
                      decoration: _inputDecoration('افزودن مورد جدید به «${_optionKinds[_optionKind]}»...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _busy.contains('option-add') ? null : _addOption,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('افزودن', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Text('این فهرست خالی است.', style: TextStyle(fontSize: 11, color: _inkMuted))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items.map<Widget>((o) {
                    final busy = _busy.contains(o['id'].toString());
                    return Container(
                      padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Long names (e.g. full university names) wrap instead of overflowing on phones.
                          Flexible(
                            child: Text(
                              o['name'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: _ink),
                            ),
                          ),
                          const SizedBox(width: 2),
                          busy
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : IconButton(
                                  tooltip: 'حذف',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  icon: const Icon(Icons.close_rounded, size: 15, color: _inkMuted),
                                  onPressed: () => _deleteOption(o),
                                ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addOption() async {
    final name = _optionCtrl.text.trim();
    if (name.isEmpty) return;
    final done = await _runRowAction('option-add', () => ApiService.addOption(_token, _optionKind, name), '«$name» اضافه شد.');
    if (done) {
      _optionCtrl.clear();
      await _loadOptions();
    }
  }

  Future<void> _deleteOption(dynamic o) async {
    final ok = await _confirm(
      title: 'حذف گزینه',
      message: '«${o['name']}» از فهرست «${_optionKinds[_optionKind]}» حذف می‌شود. کاربران و پروژه‌هایی که قبلاً آن را انتخاب کرده‌اند تغییری نمی‌کنند.',
      confirmLabel: 'حذف',
    );
    if (!ok) return;
    final id = o['id'].toString();
    final done = await _runRowAction(id, () => ApiService.deleteOption(_token, _optionKind, id), 'گزینه حذف شد.');
    if (done && mounted) {
      setState(() => (_options[_optionKind] as List).removeWhere((x) => x['id'].toString() == id));
    }
  }

  // ---------------- اعلان همگانی ----------------

  Widget _buildBroadcast() {
    const audiences = {'all': 'همه کاربران', 'students': 'فقط دانشجویان', 'companies': 'فقط کارفرمایان'};

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: _card(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader('ارسال اعلان به کاربران', icon: Icons.campaign_outlined),
              const SizedBox(height: 6),
              const Text(
                'پیام شما در بخش اعلان‌های کاربران نمایش داده می‌شود. کاربران مسدود این پیام را دریافت نمی‌کنند.',
                style: TextStyle(fontSize: 11, color: _inkMuted, height: 1.6),
              ),
              const SizedBox(height: 18),
              const Text('گیرندگان', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: audiences.entries.map((a) => _filterChip(a.value, _audience == a.key, () => setState(() => _audience = a.key))).toList(),
              ),
              const SizedBox(height: 18),
              const Text('عنوان اعلان *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(controller: _broadcastTitle, style: const TextStyle(fontSize: 12), decoration: _inputDecoration('مثلاً: به‌روزرسانی سامانه')),
              const SizedBox(height: 14),
              const Text('متن پیام *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: _broadcastMessage,
                maxLines: 5,
                minLines: 4,
                style: const TextStyle(fontSize: 12, height: 1.6),
                decoration: _inputDecoration('متن کامل اعلان را اینجا بنویسید...'),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _sendBroadcast,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('ارسال اعلان', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendBroadcast() async {
    final title = _broadcastTitle.text.trim();
    final message = _broadcastMessage.text.trim();
    if (title.length < 2 || message.length < 2) {
      _toast('عنوان و متن اعلان را کامل وارد کنید.', error: true);
      return;
    }
    const names = {'all': 'همه کاربران', 'students': 'همه دانشجویان', 'companies': 'همه کارفرمایان'};
    final ok = await _confirm(
      title: 'ارسال اعلان همگانی',
      message: 'اعلان «$title» برای ${names[_audience]} ارسال شود؟ این کار قابل بازگشت نیست.',
      confirmLabel: 'ارسال',
      danger: false,
    );
    if (!ok) return;

    setState(() => _sending = true);
    try {
      final count = await ApiService.sendBroadcast(_token, title: title, message: message, audience: _audience);
      if (!mounted) return;
      _broadcastTitle.clear();
      _broadcastMessage.clear();
      _toast('اعلان برای ${_fa(count)} کاربر ارسال شد.');
    } catch (e) {
      if (mounted) _toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _StatTile {
  final String label;
  final Object? value;
  final IconData icon;
  final Color color;
  final String caption;

  const _StatTile(this.label, this.value, this.icon, this.color, this.caption);
}

/// Bar chart of sign-ups per day for the last seven days (one series, so one hue and no legend).
class _SignupChart extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const _SignupChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final counts = days.map((d) => (d['count'] as num?)?.toInt() ?? 0).toList();
    final total = counts.fold<int>(0, (a, b) => a + b);
    final maxCount = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up_rounded, size: 18, color: _brand),
            const SizedBox(width: 8),
            const Expanded(child: Text('ثبت‌نام‌های ۷ روز اخیر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink))),
            Text('مجموع: ${_fa(total)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _inkMuted)),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(days.length, (i) {
              final count = counts[i];
              final ratio = maxCount == 0 ? 0.0 : count / maxCount;
              final date = (days[i]['date_fa'] ?? '').toString();
              final shortDate = date.length >= 10 ? date.substring(5) : date; // MM/DD
              final isPeak = count > 0 && count == maxCount;

              return Expanded(
                child: Tooltip(
                  message: '${_fa(date)}: ${_fa(count)} ثبت‌نام',
                  // The whole column is the hover target, not just the bar.
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        // Plot area takes whatever height the axis label leaves, and the
                        // bar is sized from it, so the chart can't overflow at any size.
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              const valueLabelSpace = 18.0;
                              final barMax = (box.maxHeight - valueLabelSpace).clamp(0.0, double.infinity);
                              final barHeight = count == 0 ? 2.0 : (barMax * ratio).clamp(4.0, barMax < 4 ? 4.0 : barMax);
                              final barWidth = (box.maxWidth * 0.6).clamp(4.0, 22.0);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPeak)
                                    SizedBox(
                                      height: valueLabelSpace,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.bottomCenter,
                                        child: Text(_fa(count), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _ink)),
                                      ),
                                    ),
                                  Container(
                                    width: barWidth,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: count == 0 ? _line : _brand,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Container(height: 1, color: _line),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(_fa(shortDate), maxLines: 1, style: const TextStyle(fontSize: 9, color: _inkFaint)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Applications per status as labelled horizontal bars; the label and count carry the meaning, not the colour.
class _ApplicationStatusBars extends StatelessWidget {
  final Map<String, dynamic> apps;

  const _ApplicationStatusBars({required this.apps});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('applied', 'در انتظار بررسی'),
      ('shortlisted', 'دعوت به مصاحبه'),
      ('accepted', 'پذیرفته‌شده'),
      ('rejected', 'ردشده'),
    ];
    final total = (apps['total'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.donut_small_outlined, size: 18, color: _brand),
            const SizedBox(width: 8),
            const Expanded(child: Text('وضعیت درخواست‌ها', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink))),
            Text('کل: ${_fa(total)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _inkMuted)),
          ],
        ),
        const SizedBox(height: 18),
        ...rows.map((r) {
          final count = (apps[r.$1] as num?)?.toInt() ?? 0;
          final share = total == 0 ? 0.0 : count / total;
          final percent = (share * 100).round();
          return Tooltip(
            message: '${r.$2}: ${_fa(count)} درخواست (${_fa(percent)}٪)',
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)))),
                      Text('${_fa(count)}  ·  ${_fa(percent)}٪', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _ink)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                        Container(
                          height: 8,
                          width: count == 0 ? 0 : (constraints.maxWidth * share).clamp(6.0, constraints.maxWidth),
                          decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
