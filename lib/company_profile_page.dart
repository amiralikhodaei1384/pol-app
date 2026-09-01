import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({super.key});

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
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final ok = await ApiService.saveCompanyProfile(
      token: token,
      name: _nameController.text.trim(),
      about: _aboutController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات شرکت با موفقیت ثبت شد.'), backgroundColor: Color(0xFF10B981)),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('پروفایل و معرفی شرکت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نام رسمی شرکت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'مثال: شرکت داده‌پردازان')),
              const SizedBox(height: 16),

              const Text('درباره شرکت (معرفی، تاریخچه و اهداف)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(controller: _aboutController, maxLines: 4, decoration: const InputDecoration(hintText: 'توضیحات جامعی درباره حوزه فعالیت شرکت بنویسید...')),
              const SizedBox(height: 16),

              const Text('وب‌سایت شرکت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(controller: _websiteController, decoration: const InputDecoration(hintText: 'https://company.com')),
              const SizedBox(height: 16),

              const Text('آدرس دفتر اصلی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(controller: _addressController, decoration: const InputDecoration(hintText: 'تهران، خیابان آزادی...')),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6AFB), foregroundColor: Colors.white),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('ذخیره تغییرات شرکت', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}