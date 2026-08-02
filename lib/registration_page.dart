import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'student_profile_builder_page.dart'; // <--- صفحه پروفایل‌ساز اضافه شد
import 'api_service.dart';
import 'widgets/rotating_border.dart';
import 'background.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();
  int _currentStep = 0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _companyAddressController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCompany = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    _nationalIdController.dispose();
    _companyAddressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKeyStep1.currentState!.validate()) {
        if (_isCompany) {
          setState(() => _currentStep = 1);
        } else {
          setState(() => _currentStep = 2);
        }
      }
    } else if (_currentStep == 1) {
      if (_formKeyStep2.currentState!.validate()) {
        setState(() => _currentStep = 2);
      }
    }
  }

  void _previousStep() {
    if (_currentStep == 2 && !_isCompany) {
      setState(() => _currentStep = 0);
    } else {
      setState(() => _currentStep = _currentStep - 1);
    }
  }

  void _handleRegister() async {
    if (_formKeyStep3.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رمز عبور و تکرار آن با هم مطابقت ندارند')),
        );
        return;
      }

      setState(() => _isLoading = true);

      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // ۱. ثبت‌نام در بک‌اند
      final registerSuccess = await ApiService.register(
        email: email,
        password: password,
        isCompany: _isCompany,
        companyName: _isCompany ? _companyNameController.text.trim() : null,
        nationalId: _isCompany ? _nationalIdController.text.trim() : null,
        companyAddress: _isCompany ? _companyAddressController.text.trim() : null,
      );

      if (registerSuccess) {
        // ۲. ورود خودکار پس از ثبت‌نام برای گرفتن توکن واقعی JWT
        final loginData = await ApiService.login(email, password);
        setState(() => _isLoading = false);

        if (loginData != null && loginData['access_token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', loginData['access_token']);
          await prefs.setBool('is_company', _isCompany);

          if (mounted) {
            if (!_isCompany) {
              // 🎓 اگر دانشجو است -> هدایت خودکار به صفحه پروفایل‌ساز ۳ مرحله‌ای
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const StudentProfileBuilderPage()),
                    (route) => false,
              );
            } else {
              // 🏢 اگر شرکت است -> هدایت به داشبورد کارفرما
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const DashboardPage(isCompany: true)),
                    (route) => false,
              );
            }
          }
        } else {
          // اگر ورود خودکار ناموفق بود، کاربر به صفحه لاگین هدایت می‌شود
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در ثبت‌نام یا ایمیل تکراری')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ElegantBackground(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Image.asset(
                        'assets/Untitled_design-removebg-preview.png',
                        height: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, size: 80, color: Color(0xFF0072FF)),
                      ),
                    ),
                    const SizedBox(height: 5),

                    RotatingGradientBorder(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeInOut,
                            switchOutCurve: Curves.easeInOut,
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.15, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _currentStep == 0
                                ? _buildStep1(key: const ValueKey(0))
                                : _currentStep == 1
                                ? _buildStep2(key: const ValueKey(1))
                                : _buildStep3(key: const ValueKey(2)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (_currentStep == 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('قبلاً عضو شده‌اید؟', style: TextStyle(color: Color(0xFF64748B))),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())),
                            child: const Text('وارد شوید', style: TextStyle(color: Color(0xFF0072FF), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1({required Key key}) {
    return Form(
      key: _formKeyStep1,
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ایجاد حساب جدید', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),

          Row(
            children: [
              ChoiceChip(
                label: const Text('دانشجو'),
                selected: !_isCompany,
                onSelected: (val) => setState(() => _isCompany = !val),
                selectedColor: const Color(0xFF0072FF).withOpacity(0.1),
                checkmarkColor: const Color(0xFF0072FF),
                labelStyle: TextStyle(color: !_isCompany ? const Color(0xFF0072FF) : Colors.black54),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('شرکت / سازمان'),
                selected: _isCompany,
                onSelected: (val) => setState(() => _isCompany = val),
                selectedColor: const Color(0xFF0072FF).withOpacity(0.1),
                checkmarkColor: const Color(0xFF0072FF),
                labelStyle: TextStyle(color: _isCompany ? const Color(0xFF0072FF) : Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _emailController,
            hint: _isCompany ? 'ایمیل سازمانی' : 'ایمیل دانشجویی',
            icon: _isCompany ? Icons.email_outlined : Icons.school_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          _buildButton(text: 'مرحله بعد', onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildStep2({required Key key}) {
    return Form(
      key: _formKeyStep2,
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Text('اطلاعات سازمانی', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _companyNameController,
            hint: 'نام رسمی شرکت',
            icon: Icons.business_rounded,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _nationalIdController,
            hint: 'شناسه ملی شرکت (اختیاری)',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            validator: (value) => null, // اختیاری برای تست سریع
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _companyAddressController,
            hint: 'آدرس رسمی شرکت یا سازمان',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 24),
          _buildButton(text: 'مرحله بعد', onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildStep3({required Key key}) {
    return Form(
      key: _formKeyStep3,
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Text('تعیین رمز عبور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _passwordController,
            hint: 'رمز عبور',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscure: _obscurePassword,
            toggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: _confirmPasswordController,
            hint: 'تکرار رمز عبور',
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            obscure: _obscureConfirmPassword,
            toggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          const SizedBox(height: 24),
          _buildButton(text: 'تکمیل ثبت‌نام', onPressed: _isLoading ? null : _handleRegister, isLoading: _isLoading),
        ],
      ),
    );
  }

  Widget _buildButton({required String text, required VoidCallback? onPressed, bool isLoading = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF0072FF), Color(0xFF10B981)]),
        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? toggleVisibility,
    TextInputType? keyboardType,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && obscure,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFF1E293B)),
      validator: validator ??
              (value) {
            if (value == null || value.isEmpty) return 'این فیلد اجباری است';
            return null;
          },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 22),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20),
          onPressed: toggleVisibility,
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF0072FF), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }
}