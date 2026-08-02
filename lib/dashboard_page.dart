import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/create_project_modal.dart';
import 'package:pol_app/student_profile_builder_page.dart';
import 'package:pol_app/student_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'package:pol_app/project_details_page.dart';
class DashboardPage extends StatefulWidget {
  final bool isCompany;

  const DashboardPage({super.key, this.isCompany = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return widget.isCompany ? const CompanyDashboardView() : const StudentDashboardView();
  }
}

// ==========================================
// ۱. نمای داشبورد دانشجویی (Student View)
// ==========================================
class StudentDashboardView extends StatefulWidget {
  const StudentDashboardView({super.key});

  @override
  State<StudentDashboardView> createState() => _StudentDashboardViewState();
}

class _StudentDashboardViewState extends State<StudentDashboardView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> _projectsList = [];
  bool _isLoadingProjects = true;

  // اطلاعات پروفایل کاربر
  String _studentName = 'دانشجوی کارمَچ';
  String _university = 'دانشگاه تهران';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingProjects = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    // ارسال توکن جهت دریافت لیست پروژه‌ها
    final projects = await ApiService.fetchAllProjects(token);

    if (token.isNotEmpty) {
      final userData = await ApiService.getMe(token);
      if (userData != null) {
        _email = userData['email'] ?? '';
        if (userData['profile'] != null) {
          _studentName = userData['profile']['full_name'] ?? _studentName;
          _university = userData['profile']['university'] ?? _university;
        }
      }
    }

    if (mounted) {
      setState(() {
        _projectsList = projects;
        _isLoadingProjects = false;
      });
    }
  }

  void _openProfileBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudentProfilePage()),
    ).then((_) => _loadDashboardData()); // رفرش خودکار اطلاعات داشبورد پس از ویرایش
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1150;
    final bool isMobile = screenWidth < 700;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF3F5FA),
        drawer: isMobile ? Drawer(child: _buildSidebarContent(context)) : null,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                SizedBox(
                  width: 250,
                  child: _buildSidebarContent(context),
                ),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(context, isMobile: isMobile),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadDashboardData,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildBanner(context, isMobile: isMobile),
                                    const SizedBox(height: 28),
                                    _buildRecommendedProjectsHeader(),
                                    const SizedBox(height: 16),
                                    _buildRecommendedProjectsList(isMobile: isMobile),
                                    const SizedBox(height: 28),
                                    _buildRecentRequestsSection(isMobile: isMobile),

                                    if (!isDesktop) ...[
                                      const SizedBox(height: 32),
                                      _buildLeftColumnContent(context),
                                    ],
                                  ],
                                ),
                              ),
                              if (isDesktop) ...[
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 290,
                                  child: _buildLeftColumnContent(context),
                                ),
                              ],
                            ],
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

  Widget _buildTopBar(BuildContext context, {required bool isMobile}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'جستجو برای پروژه، مهارت یا شرکت...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // پروفایل با منوی کشویی و بازکردن صفحه ویرایش
          PopupMenuButton<String>(
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (value) {
              if (value == 'profile') _openProfileBuilder();
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: Colors.black87),
                    SizedBox(width: 8),
                    Text('ویرایش پروفایل من', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('خروج از حساب', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, color: Color(0xFF1E6AFB), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F52BA), Color(0xFF1E6AFB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20.0 : 36.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سلام $_studentName 👋\nبدون سابقه کار، روی پروژه‌های واقعی کار کن',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'با شرکت‌های معتبر آشنا شو، حضوری پروژه بگیر و مسیر شغلی‌ات را بساز.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedProjectsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('پروژه‌های پیشنهادی برای شما', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF1E6AFB)),
          onPressed: _loadDashboardData,
        ),
      ],
    );
  }

  Widget _buildRecommendedProjectsList({required bool isMobile}) {
    if (_isLoadingProjects) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB))),
      );
    }

    if (_projectsList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: const Center(child: Text('هنوز هیچ پروژه‌ای ثبت نشده است.', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    if (isMobile) {
      return SizedBox(
        height: 265, // ارتفاع کارت‌ها برای جاگیری دکمه‌ها تنظیم شد
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _projectsList.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) => _buildProjectCard(_projectsList[index], width: 280),
        ),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _projectsList.map((item) => SizedBox(width: 320, child: _buildProjectCard(item))).toList(),
    );
  }

  Widget _buildProjectCard(dynamic item, {double? width}) {
    final companyName = item['company_name'] ?? (item['company'] != null ? item['company']['name'] : 'شرکت فناوری');
    final skills = (item['required_skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final deadline = item['deadline'] != null ? item['deadline'].toString().split('T')[0] : 'نامشخص';
    final matchScore = item['match_score'] ?? 80;

    return Container(
      width: width,
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                child: Text('$matchScore٪ تطابق هوشمند', style: const TextStyle(color: Color(0xFF047857), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E6AFB))),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.4, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
            child: Text(item['project_type'] ?? 'پروژه', style: const TextStyle(color: Colors.black54, fontSize: 9)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text('مهلت: $deadline', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.grey))),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: skills.take(3).map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Text(skill, style: const TextStyle(fontSize: 9, color: Colors.black87)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // تک‌دکمه کامل «مشاهده جزئیات پروژه» برای دانشجو
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailsPage(project: item, isCompany: false),
                  ),
                ).then((_) => _loadDashboardData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6AFB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('مشاهده جزئیات پروژه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestsSection({required bool isMobile}) {
    return Container();
  }

  Widget _buildLeftColumnContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(
            children: [
              const Row(children: [Text('تکمیل پروفایل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
              const SizedBox(height: 16),
              const Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
                    ),
                  ),
                  Text('۱۰۰٪', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))
                ],
              ),
              const SizedBox(height: 14),
              const Text('پروفایل شما کامل است و بیشترین شانس تطبیق را دارید.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4)),
              const SizedBox(height: 14),

              // دکمه ویرایش پروفایل
              OutlinedButton(
                onPressed: _openProfileBuilder,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1E6AFB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), minimumSize: const Size(double.infinity, 36)),
                child: const Text('ویرایش و مشاهده پروفایل', style: TextStyle(fontSize: 11, color: Color(0xFF1E6AFB))),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('وضعیت احراز هویت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                    child: const Text('تأیید شده', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Row(children: [const Icon(Icons.person_outline, size: 18, color: Colors.grey), const SizedBox(width: 8), Text(_studentName, style: const TextStyle(fontSize: 12, color: Colors.black87))]),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.school_outlined, size: 18, color: Colors.grey), const SizedBox(width: 8), Text(_university, style: const TextStyle(fontSize: 12, color: Colors.black87))]),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.mail_outline, size: 18, color: Colors.grey), const SizedBox(width: 8), Text(_email, style: const TextStyle(fontSize: 12, color: Colors.black87))]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Container(
      color: const Color(0xFF114EC4),
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildLogo(),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(Icons.dashboard, 'داشبورد', isActive: true),
                _buildNavItem(Icons.star_outline, 'پروژه‌های پیشنهادی'),
                _buildNavItem(Icons.person_outline, 'پروفایل من', onTap: _openProfileBuilder), // <--- متصل شد
                _buildNavItem(Icons.settings_outlined, 'تنظیمات'),
                _buildNavItem(
                  Icons.exit_to_app,
                  'خروج از حساب',
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/Untitled_design-removebg-preview.png',
        height: 85,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.domain, color: Colors.white, size: 48),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, {bool isActive = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
        dense: true,
        onTap: onTap ?? () {},
      ),
    );
  }
}

// ==========================================
// ۲. نمای داشبورد شرکت/کارفرما (Company View)
// ==========================================
class CompanyDashboardView extends StatefulWidget {
  const CompanyDashboardView({super.key});

  @override
  State<CompanyDashboardView> createState() => _CompanyDashboardViewState();
}

class _CompanyDashboardViewState extends State<CompanyDashboardView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> _myProjects = [];
  bool _isLoadingMyProjects = true;

  @override
  void initState() {
    super.initState();
    _loadMyProjects();
  }

  Future<void> _loadMyProjects() async {
    setState(() => _isLoadingMyProjects = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final projects = await ApiService.fetchMyProjects(token);

    if (mounted) {
      setState(() {
        _myProjects = projects;
        _isLoadingMyProjects = false;
      });
    }
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

  void _openCreateProjectModal(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateProjectModal(),
    );

    if (result == true) {
      _loadMyProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF3F5FA),
        drawer: isMobile ? Drawer(child: _buildSidebarContent(context)) : null,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                SizedBox(
                  width: 250,
                  child: _buildSidebarContent(context),
                ),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(context, isMobile: isMobile),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadMyProjects,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCompanyBanner(context, isMobile: isMobile),
                              const SizedBox(height: 28),
                              _buildActiveProjectsHeader(),
                              const SizedBox(height: 16),
                              _buildActiveProjectsList(isMobile: isMobile),
                            ],
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

  Widget _buildTopBar(BuildContext context, {required bool isMobile}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _openCreateProjectModal(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('پروژه جدید', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6AFB), foregroundColor: Colors.white),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('خروج از حساب', style: TextStyle(color: Colors.red))),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade50,
              child: const Text('د', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyBanner(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F52BA), Color(0xFF1E6AFB)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20.0 : 36.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('استعدادهای نخبگان دانشگاهی را برای پروژه‌های خود جذب کنید', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openCreateProjectModal(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black87),
              child: const Text('تعریف پروژه یا کارآموزی جدید', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveProjectsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('پروژه‌های ثبت‌شده شما', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1E6AFB)), onPressed: _loadMyProjects),
      ],
    );
  }

  Widget _buildActiveProjectsList({required bool isMobile}) {
    if (_isLoadingMyProjects) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myProjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Text('شما هنوز پروژه‌ای ثبت نکرده‌اید.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _myProjects.map((item) => SizedBox(width: 300, child: _buildCompanyProjectCard(item))).toList(),
    );
  }

  Widget _buildCompanyProjectCard(dynamic item, {double? width}) {
    final deadline = item['deadline'] != null ? item['deadline'].toString().split('T')[0] : 'نامشخص';
    final skills = (item['required_skills'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      width: width,
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6)),
                child: Text(item['project_type'] ?? 'پروژه', style: const TextStyle(color: Color(0xFF1976D2), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: item['is_active'] == true ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(4)),
                child: Text(item['is_active'] == true ? 'فعال' : 'غیرفعال', style: TextStyle(color: item['is_active'] == true ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text('مهلت: $deadline', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          if (skills.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: skills.take(3).map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Text(skill, style: const TextStyle(fontSize: 9, color: Colors.black87)),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),

          // دکمه «مشاهده جزئیات پروژه» برای کارفرما
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailsPage(project: item, isCompany: true),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E6AFB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('مشاهده جزئیات پروژه', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Container(
      color: const Color(0xFF114EC4),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.domain, color: Colors.white, size: 48),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _buildNavItem(Icons.dashboard, 'داشبورد کارفرما', isActive: true),
                _buildNavItem(Icons.add_box_outlined, 'ثبت پروژه جدید', onTap: () => _openCreateProjectModal(context)),
                _buildNavItem(Icons.exit_to_app, 'خروج از حساب', onTap: _logout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, {bool isActive = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
        dense: true,
        onTap: onTap ?? () {},
      ),
    );
  }
}