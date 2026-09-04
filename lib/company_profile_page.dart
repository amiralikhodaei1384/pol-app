import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyProfilePage extends StatefulWidget {
  final bool isWizard; // اگر true باشد یعنی از مسیر ثبت‌نام آمده است

  const CompanyProfilePage({super.key, this.isWizard = false});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (token.isNotEmpty) {
      final userData = await ApiService.getMe(token);
      if (userData != null && userData['company'] != null) {
        final c = userData['company'];
        _nameController.text = c['name'] ?? '';
        _aboutController.text = c['about'] ?? '';
        _websiteController.text = c['website'] ?? '';
        _addressController.text = c['address'] ?? '';
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام رسمی شرکت را وارد کنید.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final success = await ApiService.saveCompanyProfile(
      token: token,
      name: _nameController.text.trim(),
      about: _aboutController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اطلاعات شرکت با موفقیت ذخیره شد'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      if (widget.isWizard) {
        // هدایت به داشبورد کارفرما پس از ثبت‌نام
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage(isCompany: true)),
        );
      } else {
        Navigator.pop(context, true);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در ذخیره اطلاعات شرکت'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          title: Text(
            widget.isWizard ? 'تکمیل اطلاعات اولیه شرکت' : 'پروفایل و معرفی شرکت',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: widget.isWizard
              ? null
              : IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // کارت هدر بالایی با تم گرادیانت
              _buildTopHeaderCard(),
              const SizedBox(height: 20),

              // ۱. مشخصات ثبتی و نام
              _buildSectionContainer(
                title: 'مشخصات رسمی شرکت',
                icon: Icons.business_rounded,
                accentColor: const Color(0xFF1E6AFB),
                children: [
                  _buildMinimalField(
                    label: 'نام رسمی شرکت یا سازمان *',
                    controller: _nameController,
                    hint: 'مثال: شرکت داده‌پردازان',
                    icon: Icons.badge_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ۲. درباره شرکت (توضیحات و معرفی)
              _buildSectionContainer(
                title: 'معرفی و درباره شرکت',
                icon: Icons.description_outlined,
                accentColor: const Color(0xFF10B981),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'درباره شرکت (معرفی، تاریخچه، زمینه فعالیت و فرهنگ سازمانی)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _aboutController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          hintText: 'توضیحات جامعی درباره حوزه فعالیت شرکت بنویسید تا دانشجویان بیشتر با شما آشنا شوند...',
                          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                          contentPadding: const EdgeInsets.all(12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E6AFB), width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ۳. اینترنت و آدرس دفتر
              _buildSectionContainer(
                title: 'اطلاعات اینترنتی و آدرس',
                icon: Icons.location_on_outlined,
                accentColor: const Color(0xFF1E6AFB),
                children: [
                  _buildMinimalField(
                    label: 'وب‌سایت رسمی شرکت',
                    controller: _websiteController,
                    hint: 'https://company.com',
                    icon: Icons.language_rounded,
                  ),
                  const SizedBox(height: 14),
                  _buildMinimalField(
                    label: 'آدرس دفتر اصلی',
                    controller: _addressController,
                    hint: 'مثال: تهران، خیابان آزادی، پلاک ۱۲',
                    icon: Icons.map_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // دکمه ذخیره
              _buildSaveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderCard() {
    final companyName = _nameController.text.isNotEmpty ? _nameController.text : 'شرکت جدید';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F52BA), Color(0xFF1E6AFB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E6AFB).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.business_rounded, color: Color(0xFF1E6AFB), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'حساب کارفرمایی تایید شده',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('کارفرما', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMinimalField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E6AFB), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E6AFB), Color(0xFF10B981)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              widget.isWizard ? 'تکمیل اطلاعات و ورود به داشبورد' : 'ذخیره تغییرات شرکت',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}