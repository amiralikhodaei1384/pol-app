import 'package:flutter/material.dart';
import 'package:pol_app/api_service.dart';
import 'package:pol_app/project_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExploreProjectsPage extends StatefulWidget {
  const ExploreProjectsPage({super.key});

  @override
  State<ExploreProjectsPage> createState() => _ExploreProjectsPageState();
}

class _ExploreProjectsPageState extends State<ExploreProjectsPage> {
  List<dynamic> _projects = [];
  bool _isLoading = true;

  final _searchController = TextEditingController();

  String _selectedType = 'همه';
  List<String> _selectedCities = [];
  List<String> _selectedCategories = [];
  List<String> _selectedMajors = [];
  List<String> _selectedUniversities = [];

  List<String> _typeOptions = ['همه', 'کارآموزی', 'پروژه', 'امریه'];
  List<String> _cityOptions = [];
  List<String> _categoryOptions = [];
  List<String> _majorOptions = [];
  List<String> _universityOptions = [];

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadOptions();
    await _loadProjects();
  }

  Future<void> _loadOptions() async {
    final options = await ApiService.fetchOptions();
    if (options != null && mounted) {
      setState(() {
        if (options['cities'] != null) _cityOptions = (options['cities'] as List).cast<String>();
        if (options['categories'] != null) _categoryOptions = (options['categories'] as List).cast<String>();
        if (options['majors'] != null) _majorOptions = (options['majors'] as List).cast<String>();
        if (options['universities'] != null) _universityOptions = (options['universities'] as List).cast<String>();
      });
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final results = await ApiService.fetchFilteredProjects(
      token: token,
      projectType: _selectedType,
      cities: _selectedCities,
      categories: _selectedCategories,
      relatedMajors: _selectedMajors,
      universities: _selectedUniversities,
      searchQuery: _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _projects = results;
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedType = 'همه';
      _selectedCities.clear();
      _selectedCategories.clear();
      _selectedMajors.clear();
      _selectedUniversities.clear();
    });
    _loadProjects();
  }

  // دیالوگ هوشمند انتخاب چندتایی دارای نوار سرچ زنده
  void _showMultiSelectModal({
    required String title,
    required List<String> options,
    required List<String> currentSelections,
    required Function(List<String>) onApply,
  }) {
    List<String> tempSelections = List.from(currentSelections);
    final modalSearchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // فیلتر زنده گزینه‌ها متناسب با تایپ کاربر
            final query = modalSearchCtrl.text.trim();
            final filteredOptions = query.isEmpty
                ? options
                : options.where((opt) => opt.contains(query)).toList();

            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    // هدر مدال
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('فیلتر $title', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 🔎 نوار جستجوی زنده درون مدال (با تایپ «ت» شهرها زنده فیلتر می‌شوند)
                    TextField(
                      controller: modalSearchCtrl,
                      onChanged: (_) {
                        setModalState(() {}); // به‌روزرسانی آنی لیست
                      },
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'جستجو در $title (مثال: تایپ «ت»)...',
                        hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF1E6AFB)),
                        suffixIcon: modalSearchCtrl.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            modalSearchCtrl.clear();
                            setModalState(() {});
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),

                    // لیست گزینه‌های فیلترشده
                    Expanded(
                      child: filteredOptions.isEmpty
                          ? const Center(child: Text('هیچ گزینه‌ای پیدا نشد.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                          : ListView.builder(
                        itemCount: filteredOptions.length,
                        itemBuilder: (context, index) {
                          final opt = filteredOptions[index];
                          final isChecked = tempSelections.contains(opt);

                          return CheckboxListTile(
                            title: Text(opt, style: const TextStyle(fontSize: 12)),
                            value: isChecked,
                            activeColor: const Color(0xFF1E6AFB),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  tempSelections.add(opt);
                                } else {
                                  tempSelections.remove(opt);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() => tempSelections.clear());
                          },
                          child: const Text('پاک کردن', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            onApply(tempSelections);
                            Navigator.pop(context);
                            _loadProjects();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                          child: Text('اعمال فیلتر (${tempSelections.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // مدال انتخاب نوع همکاری
  void _showTypeSelectModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('فیلتر نوع همکاری', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                ..._typeOptions.map((type) {
                  return RadioListTile<String>(
                    title: Text(type, style: const TextStyle(fontSize: 12)),
                    value: type,
                    groupValue: _selectedType,
                    activeColor: const Color(0xFF1E6AFB),
                    onChanged: (val) {
                      setState(() => _selectedType = val!);
                      Navigator.pop(context);
                      _loadProjects();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 750;

    final bool hasActiveFilters = _selectedCities.isNotEmpty ||
        _selectedCategories.isNotEmpty ||
        _selectedMajors.isNotEmpty ||
        _selectedUniversities.isNotEmpty ||
        _selectedType != 'همه' ||
        _searchController.text.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          title: const Text('جستجو و کشف فرصت‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF1E6AFB)),
              onPressed: _loadProjects,
            ),
          ],
        ),
        body: Column(
          children: [
            // باکس سرچ و ۵ دکمه فیلتر کشیده شده که ۱۰۰٪ عرض را پر می‌کنند
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // نوار سرچ اصلی
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => _loadProjects(),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'جستجو در عنوان فرصت شغلی، مهارت یا نام شرکت...',
                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF1E6AFB), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _loadProjects();
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 📏 ۵ دکمه فیلتر کشیده شده که جمعاً کل عرض صفحه را پر می‌کنند
                  Row(
                    children: [
                      Expanded(
                        child: _buildMultiFilterButton(
                          label: 'نوع',
                          selectedCount: _selectedType == 'همه' ? 0 : 1,
                          onTap: _showTypeSelectModal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildMultiFilterButton(
                          label: 'شهرها',
                          selectedCount: _selectedCities.length,
                          onTap: () => _showMultiSelectModal(
                            title: 'شهرها',
                            options: _cityOptions,
                            currentSelections: _selectedCities,
                            onApply: (list) => setState(() => _selectedCities = list),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildMultiFilterButton(
                          label: 'حوزه کاری',
                          selectedCount: _selectedCategories.length,
                          onTap: () => _showMultiSelectModal(
                            title: 'دسته‌بندی شغلی',
                            options: _categoryOptions,
                            currentSelections: _selectedCategories,
                            onApply: (list) => setState(() => _selectedCategories = list),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildMultiFilterButton(
                          label: 'رشته‌ها',
                          selectedCount: _selectedMajors.length,
                          onTap: () => _showMultiSelectModal(
                            title: 'رشته‌ها',
                            options: _majorOptions,
                            currentSelections: _selectedMajors,
                            onApply: (list) => setState(() => _selectedMajors = list),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildMultiFilterButton(
                          label: 'دانشگاه‌ها',
                          selectedCount: _selectedUniversities.length,
                          onTap: () => _showMultiSelectModal(
                            title: 'دانشگاه‌ها',
                            options: _universityOptions,
                            currentSelections: _selectedUniversities,
                            onApply: (list) => setState(() => _selectedUniversities = list),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (hasActiveFilters) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 14, color: Colors.redAccent),
                        label: const Text('حذف همه فیلترها', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // لیست پروژه‌های فیلترشده
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6AFB)))
                  : _projects.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _loadProjects,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text('${_projects.length} فرصت شغلی پیدا شد', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      isMobile
                          ? ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _projects.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) => _buildProjectCard(_projects[index], width: double.infinity),
                      )
                          : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _projects.length,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisExtent: 260,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          return _buildProjectCard(_projects[index]);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiFilterButton({required String label, required int selectedCount, required VoidCallback onTap}) {
    final bool hasSelection = selectedCount > 0;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: hasSelection ? const Color(0xFFE3F2FD) : const Color(0xFFF1F5F9),
        side: BorderSide(color: hasSelection ? const Color(0xFF1E6AFB) : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              hasSelection ? '$label ($selectedCount)' : label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: hasSelection ? FontWeight.bold : FontWeight.normal,
                color: hasSelection ? const Color(0xFF1E6AFB) : const Color(0xFF475569),
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('هیچ فرصت شغلی با این فیلترها پیدا نشد.', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resetFilters,
            child: const Text('حذف فیلترها و نمایش همه پروژه‌ها', style: TextStyle(color: Color(0xFF1E6AFB), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(dynamic item, {double? width}) {
    final companyName = item['company_name'] ?? 'شرکت فناوری';
    final city = item['city'] ?? 'نامشخص';
    final skills = (item['required_skills'] as List<dynamic>?)?.cast<String>() ?? [];
    final deadline = item['deadline'] != null ? item['deadline'].toString().split('T')[0] : 'نامشخص';
    final matchScore = item['match_score'] ?? 75;

    return Container(
      width: width,
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                child: Text('$matchScore٪ تطابق', style: const TextStyle(color: Color(0xFF047857), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(
                  companyName,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E6AFB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.4, color: Color(0xFF1E293B))),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                child: Text(item['project_type'] ?? 'پروژه', style: const TextStyle(color: Colors.black54, fontSize: 9)),
              ),
              const SizedBox(width: 8),
              Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 2),
              Text(city, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
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
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailsPage(project: item, isCompany: false),
                  ),
                ).then((_) => _loadProjects());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6AFB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('مشاهده جزئیات پروژه', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}