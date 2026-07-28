import 'package:flutter/material.dart';
import 'package:pol_app/create_project_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
class DashboardPage extends StatefulWidget {
  final bool isCompany; // مشخص‌کننده نقش کاربر (دانشجو یا شرکت)

  const DashboardPage({super.key, this.isCompany = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    // بر اساس نقش کاربر، داشبورد مربوطه نمایش داده می‌شود
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
          if (!isMobile) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('جستجوی پیشرفته', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E6AFB),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
          const SizedBox(width: 16),
          _buildTopBarIcon(Icons.chat_bubble_outline, hasBadge: true),
          const SizedBox(width: 10),
          _buildTopBarIcon(Icons.notifications_none, hasBadge: true, badgeCount: '3'),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            child: ClipOval(
              child: Image.network(
                'https://i.pravatar.cc/150?u=ali_ut',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.grey, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIcon(IconData icon, {bool hasBadge = false, String badgeCount = ''}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: Colors.black54, size: 24),
        if (hasBadge)
          Positioned(
            top: -2,
            right: -2,
            child: CircleAvatar(
              radius: 7,
              backgroundColor: Colors.red,
              child: Text(
                badgeCount.isEmpty ? '●' : badgeCount,
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          )
      ],
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
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 20.0 : 36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بدون سابقه کار،\nروی پروژه‌های واقعی کار کن',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: isMobile ? double.infinity : 350,
                  child: const Text(
                    'با شرکت‌های معتبر آشنا شو، حضوری پروژه بگیر و مسیر شغلی‌ات را بساز.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('جستجو برای پروژه‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_back_ios, size: 12, textDirection: TextDirection.ltr),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Positioned(
              left: 40,
              bottom: 0,
              top: 0,
              child: Center(
                child: Icon(
                  Icons.laptop_mac_outlined,
                  size: 140,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildRecommendedProjectsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('پروژه‌های پیشنهادی برای شما', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        TextButton(
          onPressed: () {},
          child: const Row(
            children: [
              Text('مشاهده همه', style: TextStyle(fontSize: 12, color: Color(0xFF1E6AFB))),
              Icon(Icons.keyboard_arrow_left, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedProjectsList({required bool isMobile}) {
    final List<Map<String, dynamic>> projects = [
      {
        'company': 'دیجی‌کالا',
        'companyColor': Colors.red,
        'match': '۹۲٪',
        'matchText': 'تطابق عالی',
        'title': 'توسعه قابلیت‌های جدید در اپلیکیشن موبایل',
        'badge': 'کارآموزی',
        'deadline': '۳۱ خرداد ۱۴۰۵',
        'location': 'تهران، حضوری',
        'skills': ['React Native', 'JavaScript'],
      },
      {
        'company': 'همراه اول',
        'companyColor': Colors.teal,
        'match': '۸۵٪',
        'matchText': 'تطابق خوب',
        'title': 'تحلیل داده‌های مشتریان و ارائه داشبورد',
        'badge': 'کارآموزی',
        'deadline': '۲۰ خرداد ۱۴۰۵',
        'location': 'تهران، حضوری',
        'skills': ['Python', 'SQL', 'Power BI'],
      },
      {
        'company': 'اسنپ',
        'companyColor': Colors.green,
        'match': '۷۸٪',
        'matchText': 'تطابق خوب',
        'title': 'طراحی تجربه کاربری در پنل رانندگان',
        'badge': 'پروژه کوتاه‌مدت',
        'deadline': '۱۵ خرداد ۱۴۰۵',
        'location': 'تهران، حضوری',
        'skills': ['Figma', 'UI/UX', 'Research'],
      }
    ];

    if (isMobile) {
      return SizedBox(
        height: 230,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: projects.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) => _buildProjectCard(projects[index], width: 260),
        ),
      );
    }

    return Row(
      children: projects.map((item) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: _buildProjectCard(item)))).toList(),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> item, {double? width}) {
    return Container(
      width: width,
      height: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                child: Text('${item['matchText']} ${item['match']}', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Text(item['company'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: (item['companyColor'] as Color).withOpacity(0.1),
                    child: Text(item['company'][0], style: TextStyle(color: item['companyColor'], fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(item['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.4)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFECEFF1), borderRadius: BorderRadius.circular(4)),
            child: Text(item['badge'], style: const TextStyle(color: Colors.black54, fontSize: 9)),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text('مهلت: ${item['deadline']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.grey))),
              const Icon(Icons.location_on_outlined, size: 11, color: Colors.grey),
              const SizedBox(width: 4),
              Text(item['location'], style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: (item['skills'] as List<String>).map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Text(skill, style: const TextStyle(fontSize: 9, color: Colors.black87)),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildRecentRequestsSection({required bool isMobile}) {
    final List<Map<String, String>> requests = [
      {'title': 'طراحی وبسایت سازمانی', 'company': 'پارس آنلاین', 'status': 'در انتظار بررسی', 'statusColor': 'orange', 'date': '۲۴ خرداد ۱۴۰۵'},
      {'title': 'توسعه API پرداخت', 'company': 'زرین پال', 'status': 'تعیین وقت شده', 'statusColor': 'green', 'date': '۲۲ خرداد ۱۴۰۵'}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('درخواست‌های اخیر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            TextButton(
              onPressed: () {},
              child: const Row(children: [Text('مشاهده همه', style: TextStyle(fontSize: 12, color: Color(0xFF1E6AFB))), Icon(Icons.keyboard_arrow_left, size: 16)]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final req = requests[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(req['company']!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                  _buildStatusBadge(req['status']!, req['statusColor']!),
                  if (!isMobile) ...[const SizedBox(width: 32), Text(req['date']!, style: const TextStyle(color: Colors.grey, fontSize: 11))]
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, String colorName) {
    final Color bgColor = colorName == 'green' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final Color textColor = colorName == 'green' ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
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
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: 0.72,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C853)),
                    ),
                  ),
                  const Text('۷۲٪', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))
                ],
              ),
              const SizedBox(height: 14),
              const Text('پروفایل کامل شانس دریافت پروژه‌های بهتر را افزایش می‌دهد.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4)),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1E6AFB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), minimumSize: const Size(double.infinity, 36)),
                child: const Text('ادامه تکمیل پروفایل', style: TextStyle(fontSize: 11, color: Color(0xFF1E6AFB))),
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
              const Row(children: [Icon(Icons.school_outlined, size: 18, color: Colors.grey), SizedBox(width: 8), Text('دانشجوی دانشگاه تهران', style: TextStyle(fontSize: 12, color: Colors.black87))]),
              const SizedBox(height: 8),
              const Row(children: [Icon(Icons.mail_outline, size: 18, color: Colors.grey), SizedBox(width: 8), Text('ali@ut.ac.ir', style: TextStyle(fontSize: 12, color: Colors.black87))]),
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
              const Text('میانبر‌ها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              _buildShortcutItem(Icons.edit_outlined, 'ویرایش پروفایل'),
              _buildShortcutItem(Icons.bookmark_border, 'پروژه‌های ذخیره شده'),
              _buildShortcutItem(Icons.description_outlined, 'نمونه قراردادها'),
              _buildShortcutItem(Icons.quiz_outlined, 'سوالات متداول'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          const Spacer(),
          const Icon(Icons.arrow_back_ios, size: 10, color: Colors.grey),
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
          _buildLogo(),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(Icons.dashboard, 'داشبورد', isActive: true),
                _buildNavItem(Icons.star_outline, 'پروژه‌های پیشنهادی'),
                _buildNavItem(Icons.search, 'جستجو و کشف'),
                _buildNavItem(Icons.business_center_outlined, 'پروژه‌های من'),
                _buildNavItem(Icons.send_outlined, 'درخواست‌ها', badge: '2'),
                _buildNavItem(Icons.chat_bubble_outline, 'پیام‌ها', badge: '1'),
                _buildNavItem(Icons.business_outlined, 'شرکت‌ها'),
                _buildNavItem(Icons.person_outline, 'پروفایل من'),
                _buildNavItem(Icons.settings_outlined, 'تنظیمات'),
                _buildNavItem(Icons.help_outline, 'راهنما'),
                _buildNavItem(
                  Icons.exit_to_app,
                  'خروج از حساب',
                  onTap: () async {
                    // پاک کردن توکن از حافظه
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();

                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                            (route) => false,
                      );
                    }
                  },
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

  Widget _buildNavItem(IconData icon, String title, {bool isActive = false, String? badge, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
        trailing: badge != null
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(badge, style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
        )
            : null,
        dense: true,
        onTap: onTap ?? () {}, // دریافت onTap برای خروج از حساب
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
                                  _buildCompanyBanner(context, isMobile: isMobile),
                                  const SizedBox(height: 28),
                                  _buildActiveProjectsHeader(),
                                  const SizedBox(height: 16),
                                  _buildActiveProjectsList(isMobile: isMobile),
                                  const SizedBox(height: 28),
                                  _buildRecentApplicantsSection(isMobile: isMobile),

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
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'جستجو بین دانشجویان، مهارت‌ها یا پروژه‌ها...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _openCreateProjectModal(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('پروژه جدید', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6AFB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
          const SizedBox(width: 16),
          _buildTopBarIcon(Icons.chat_bubble_outline, hasBadge: true, badgeCount: '۴'),
          const SizedBox(width: 10),
          _buildTopBarIcon(Icons.notifications_none, hasBadge: true, badgeCount: '۵'),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue.shade50,
            child: const Text('د', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIcon(IconData icon, {bool hasBadge = false, String badgeCount = ''}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: Colors.black54, size: 24),
        if (hasBadge)
          Positioned(
            top: -2,
            right: -2,
            child: CircleAvatar(
              radius: 7,
              backgroundColor: Colors.red,
              child: Text(
                badgeCount.isEmpty ? '●' : badgeCount,
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          )
      ],
    );
  }

  Widget _buildCompanyBanner(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F52BA), Color(0xFF1E6AFB)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 20.0 : 36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'استعدادهای نخبگان دانشگاهی را\nبرای پروژه‌های خود جذب کنید',
                  style: TextStyle(color: Colors.white, fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, height: 1.4),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: isMobile ? double.infinity : 380,
                  child: const Text(
                    'پروژه‌های تعریف‌شده را به دانشجویان برتر بسپارید و تیم آینده شرکت خود را شکل دهید.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _openCreateProjectModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, size: 16),
                      SizedBox(width: 8),
                      Text('تعریف پروژه یا کارآموزی جدید', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Positioned(
              left: 40,
              bottom: 0,
              top: 0,
              child: Center(
                child: Icon(Icons.business_center_outlined, size: 140, color: Colors.white.withOpacity(0.15)),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildActiveProjectsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('پروژه‌های فعال شما', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        TextButton(
          onPressed: () {},
          child: const Row(children: [Text('مدیریت پروژه‌ها', style: TextStyle(fontSize: 12, color: Color(0xFF1E6AFB))), Icon(Icons.keyboard_arrow_left, size: 16)]),
        ),
      ],
    );
  }

  Widget _buildActiveProjectsList({required bool isMobile}) {
    final List<Map<String, dynamic>> companyProjects = [
      {'title': 'توسعه رابط کاربری اپلیکیشن موبایل', 'type': 'کارآموزی', 'applicants': 12, 'views': 140, 'status': 'فعال', 'deadline': '۱۰ تیر ۱۴۰۵'},
      {'title': 'بهینه‌سازی پایگاه داده SQL', 'type': 'پروژه کوتاه‌مدت', 'applicants': 8, 'views': 95, 'status': 'فعال', 'deadline': '۰۵ تیر ۱۴۰۵'},
      {'title': 'تولید محتوا و اسکرام مستری', 'type': 'پاره وقت', 'applicants': 5, 'views': 60, 'status': 'در حال بررسی', 'deadline': '۲۸ خرداد ۱۴۰۵'}
    ];

    if (isMobile) {
      return SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: companyProjects.length,
          separatorBuilder: (context, index) => const SizedBox(width: 16),
          itemBuilder: (context, index) => _buildCompanyProjectCard(companyProjects[index], width: 260),
        ),
      );
    }

    return Row(
      children: companyProjects.map((item) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: _buildCompanyProjectCard(item)))).toList(),
    );
  }

  Widget _buildCompanyProjectCard(Map<String, dynamic> item, {double? width}) {
    return Container(
      width: width,
      height: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6)),
                child: Text(item['type'], style: const TextStyle(color: Color(0xFF1976D2), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: item['status'] == 'فعال' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(4)),
                child: Text(item['status'], style: TextStyle(color: item['status'] == 'فعال' ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 14),
          Text(item['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF1E6AFB)),
              const SizedBox(width: 4),
              Text('${item['applicants']} متقاضی', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E6AFB))),
              const SizedBox(width: 12),
              const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${item['views']} بازدید', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 11, color: Colors.grey),
              const SizedBox(width: 4),
              Text('مهلت: ${item['deadline']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentApplicantsSection({required bool isMobile}) {
    final List<Map<String, String>> applicants = [
      {'name': 'علی محمدی', 'university': 'دانشگاه تهران - علوم کامپیوتر', 'project': 'توسعه رابط کاربری', 'match': '۹۵٪ تطابق'},
      {'name': 'سارینا رستمی', 'university': 'دانشگاه شریف - مهندسی صنایع', 'project': 'اسکرام مستری', 'match': '۸۸٪ تطابق'}
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('متقاضیان اخیر (رزومه‌ها)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            TextButton(
              onPressed: () {},
              child: const Row(children: [Text('مشاهده همه', style: TextStyle(fontSize: 12, color: Color(0xFF1E6AFB))), Icon(Icons.keyboard_arrow_left, size: 16)]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: applicants.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final app = applicants[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Row(
                children: [
                  CircleAvatar(radius: 18, backgroundColor: Colors.grey.shade100, child: Text(app['name']![0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(app['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                              child: Text(app['match']!, style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${app['university']} • برای ${app['project']}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1E6AFB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('مشاهده رزومه', style: TextStyle(fontSize: 10, color: Color(0xFF1E6AFB))),
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLeftColumnContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('خلاصه عملکرد شرکت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('۳', 'پروژه فعال', Colors.blue),
                  _buildStatItem('۲۵', 'کل رزومه‌ها', Colors.green),
                  _buildStatItem('۲', 'مصاحبه‌ها', Colors.orange),
                ],
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
                  const Text('احراز هویت حقوقی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                    child: const Text('تأیید شده', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Row(children: [Icon(Icons.business_outlined, size: 18, color: Colors.grey), SizedBox(width: 8), Text('شرکت فناوری داده‌پردازان', style: TextStyle(fontSize: 11, color: Colors.black87))]),
              const SizedBox(height: 8),
              const Row(children: [Icon(Icons.badge_outlined, size: 18, color: Colors.grey), SizedBox(width: 8), Text('شناسه ملی: ۱۰۱۰۳۸۹۴۰۰', style: TextStyle(fontSize: 11, color: Colors.black87))]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String count, String label, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                _buildNavItem(Icons.dashboard, 'داشبورد کارفرما', isActive: true),
                _buildNavItem(
                  Icons.add_box_outlined,
                  'ثبت پروژه جدید',
                  onTap: () => _openCreateProjectModal(context), // <--- اینجا
                ),
                _buildNavItem(Icons.assignment_outlined, 'پروژه‌های ما'),
                _buildNavItem(Icons.people_outline, 'بانک رزومه‌ها'),
                _buildNavItem(Icons.chat_bubble_outline, 'پیام‌ها', badge: '4'),
                _buildNavItem(Icons.settings_outlined, 'پروفایل شرکت'),
                _buildNavItem(Icons.help_outline, 'راهنما'),
                _buildNavItem(
                  Icons.exit_to_app,
                  'خروج از حساب',
                  onTap: () async {
                    // پاک کردن توکن از حافظه
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();

                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                            (route) => false,
                      );
                    }
                  },
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

  Widget _buildNavItem(IconData icon, String title, {bool isActive = false, String? badge, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
        trailing: badge != null
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(badge, style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
        )
            : null,
        dense: true,
        onTap: onTap ?? () {}, // دریافت onTap برای خروج از حساب
      ),
    );
  }
  void _openCreateProjectModal(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateProjectModal(),
    );

    if (result == true) {
      // در صورت موفقیت‌آمیز بودن ثبت پروژه، لیست پروژه‌ها را رفرش کنید
      setState(() {});
    }
  }
}