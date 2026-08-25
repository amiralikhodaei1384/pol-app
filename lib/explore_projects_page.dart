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

  // جستجو و فیلترها
  final _searchController = TextEditingController();

  String _selectedType = 'همه';
  String _selectedCity = 'همه';
  String _selectedCategory = 'همه';
  String _selectedMajor = 'همه';
  String _selectedUniversity = 'همه';

  List<String> _typeOptions = ['همه', 'کارآموزی', 'پروژه', 'امریه'];
  List<String> _cityOptions = ['همه'];
  List<String> _categoryOptions = ['همه'];
  List<String> _majorOptions = ['همه'];
  List<String> _universityOptions = ['همه'];

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
        if (options['cities'] != null) {
          _cityOptions = ['همه', ...(options['cities'] as List).cast<String>()];
        }
        if (options['categories'] != null) {
          _categoryOptions = ['همه', ...(options['categories'] as List).cast<String>()];
        }
        if (options['majors'] != null) {
          _majorOptions = ['همه', ...(options['majors'] as List).cast<String>()];
        }
        if (options['universities'] != null) {
          _universityOptions = ['همه', ...(options['universities'] as List).cast<String>()];
        }
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
      city: _selectedCity,
      category: _selectedCategory,
      relatedMajor: _selectedMajor,
      university: _selectedUniversity,
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
      _selectedCity = 'همه';
      _selectedCategory = 'همه';
      _selectedMajor = 'همه';
      _selectedUniversity = 'همه';
    });
    _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 750;

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
              tooltip: 'بروزرسانی',
              onPressed: _loadProjects,
            ),
          ],
        ),
        body: Column(
          children: [
            // هدر فیلترهای بالای صفحه
            _buildFilterHeader(isMobile: isMobile),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // لیست یا گرید نتایج جستجو
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
                        child: Text(
                          '${_projects.length} فرصت شغلی پیدا شد',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
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

  Widget _buildFilterHeader({required bool isMobile}) {
    final bool hasActiveFilters = _selectedCity != 'همه' ||
        _selectedCategory != 'همه' ||
        _selectedMajor != 'همه' ||
        _selectedUniversity != 'همه' ||
        _selectedType != 'همه' ||
        _searchController.text.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ۱. نوار جستجوی متنی
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

          // ۲. چیپ‌های نوع همکاری
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _typeOptions.map((type) {
                final isSelected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1E6AFB),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    onSelected: (selected) {
                      setState(() => _selectedType = type);
                      _loadProjects();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ۳. دراپ‌داون‌های فیلتر (شهر، دسته‌بندی، رشته، دانشگاه)
          isMobile
              ? Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildDropdownFilter('شهر / مکان', _selectedCity, _cityOptions, (v) => setState(() => _selectedCity = v!))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDropdownFilter('دسته‌بندی شغلی', _selectedCategory, _categoryOptions, (v) => setState(() => _selectedCategory = v!))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDropdownFilter('رشته مرتبط', _selectedMajor, _majorOptions, (v) => setState(() => _selectedMajor = v!))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDropdownFilter('دانشگاه مورد قبول', _selectedUniversity, _universityOptions, (v) => setState(() => _selectedUniversity = v!))),
                ],
              ),
            ],
          )
              : Row(
            children: [
              Expanded(child: _buildDropdownFilter('شهر / مکان', _selectedCity, _cityOptions, (v) => setState(() => _selectedCity = v!))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdownFilter('دسته‌بندی شغلی', _selectedCategory, _categoryOptions, (v) => setState(() => _selectedCategory = v!))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdownFilter('رشته مرتبط', _selectedMajor, _majorOptions, (v) => setState(() => _selectedMajor = v!))),
              const SizedBox(width: 8),
              Expanded(child: _buildDropdownFilter('دانشگاه مورد قبول', _selectedUniversity, _universityOptions, (v) => setState(() => _selectedUniversity = v!))),
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
    );
  }

  Widget _buildDropdownFilter(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: options.contains(value) ? value : options.first,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      items: options.map((opt) {
        return DropdownMenuItem<String>(
          value: opt,
          child: Text(opt, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B))),
        );
      }).toList(),
      onChanged: (val) {
        onChanged(val);
        _loadProjects();
      },
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
          Text(
            item['title'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.4, color: Color(0xFF1E293B)),
          ),
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