import 'package:flutter/material.dart';

/// منوی پروفایل نوار بالا؛ مشترک بین داشبورد دانشجو، کارفرما و مدیر.
class ProfileMenuButton extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String? profileLabel;
  final VoidCallback? onProfile;
  final VoidCallback onLogout;

  const ProfileMenuButton({
    super.key,
    required this.name,
    required this.roleLabel,
    this.profileLabel,
    this.onProfile,
    required this.onLogout,
  });

  Widget _avatar({double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1E6AFB), Color(0xFF0F52BA)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person, color: Colors.white, size: size * 0.55),
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'حساب کاربری',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 52),
      elevation: 12,
      color: Colors.white,
      shadowColor: Colors.black26,
      constraints: const BoxConstraints(minWidth: 235, maxWidth: 290),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: (value) {
        if (value == 'profile') onProfile?.call();
        if (value == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        // سربرگ: نام و نقش کاربر
        PopupMenuItem<String>(
          enabled: false,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _avatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 2),
                    Text(roleLabel, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        if (onProfile != null)
          PopupMenuItem<String>(
            value: 'profile',
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _menuRow(Icons.person_outline_rounded, profileLabel ?? 'پروفایل من', const Color(0xFF1E6AFB)),
          ),
        PopupMenuItem<String>(
          value: 'logout',
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _menuRow(Icons.logout_rounded, 'خروج از حساب', const Color(0xFFDC2626)),
        ),
      ],

      // دکمه: آواتار به‌همراه فلش رو به پایین
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatar(size: 30),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
