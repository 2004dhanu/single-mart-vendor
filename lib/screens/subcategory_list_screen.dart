import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'subcategory_form_screen.dart';

class SubcategoryListScreen extends StatefulWidget {
  const SubcategoryListScreen({super.key});

  @override
  State<SubcategoryListScreen> createState() => _SubcategoryListScreenState();
}

class _SubcategoryListScreenState extends State<SubcategoryListScreen> {
  List<SubcategoryItem> _subcategories = [];
  List<SubcategoryItem> _filteredSubcategories = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
    _searchController.addListener(_filterSubcategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubcategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      // 1. Fetch all categories
      final catsResp = await ApiService.fetchCategories(token);
      final List<dynamic> categories = catsResp['data'] as List<dynamic>? ?? [];

      List<SubcategoryItem> tempItems = [];

      // 2. Fetch subcategories for each category
      for (var cat in categories) {
        final catId = cat['id'] as int;
        final catName = cat['categories_name']?.toString() ?? 'Unknown Category';
        
        final detailResp = await ApiService.fetchCategoryById(catId, token);
        if (detailResp['data'] != null) {
          final catData = detailResp['data'] as Map<String, dynamic>;
          final subs = catData['subs'] as List<dynamic>? ?? [];
          for (var sub in subs) {
            tempItems.add(
              SubcategoryItem(
                id: sub['id'] as int,
                categoryId: catId,
                categoryName: catName,
                name: sub['categories_subs_name']?.toString() ?? 'Unnamed Subcategory',
                image: sub['categories_subs_image'] as String?,
                status: sub['categories_subs_status']?.toString() ?? 'Active',
              ),
            );
          }
        }
      }

      setState(() {
        _subcategories = tempItems;
        _filteredSubcategories = List.from(_subcategories);
      });
    } catch (e) {
      _showSnackbar('Error loading subcategories: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterSubcategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubcategories = _subcategories.where((sub) {
        return sub.name.toLowerCase().contains(query) ||
            sub.categoryName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _toggleStatus(SubcategoryItem sub, bool isCurrentActive) async {
    final newStatus = isCurrentActive ? 'Inactive' : 'Active';
    
    // Optimistic UI update
    setState(() {
      sub.status = newStatus;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      // To update subcategory status, we must update it via the parent category update API.
      // 1. Fetch parent category details
      final detailResp = await ApiService.fetchCategoryById(sub.categoryId, token);
      if (detailResp['data'] == null) {
        _revertStatus(sub, isCurrentActive);
        return;
      }

      final catData = detailResp['data'] as Map<String, dynamic>;
      final subs = catData['subs'] as List<dynamic>? ?? [];

      // 2. Prepare payload fields
      final Map<String, String> fields = {
        'categories_name': catData['categories_name']?.toString() ?? '',
        'status': catData['categories_status']?.toString() ?? 'Active',
        'categories_status': catData['categories_status']?.toString() ?? 'Active',
      };

      for (int i = 0; i < subs.length; i++) {
        final item = subs[i];
        final itemId = item['id'] as int;
        fields['subs[$i][id]'] = itemId.toString();
        fields['subs[$i][categories_subs_id]'] = itemId.toString();
        fields['subs[$i][categories_subs_name]'] = item['categories_subs_name']?.toString() ?? '';
        
        // Update matching subcategory status
        if (itemId == sub.id) {
          fields['subs[$i][categories_subs_status]'] = newStatus;
        } else {
          fields['subs[$i][categories_subs_status]'] = item['categories_subs_status']?.toString() ?? 'Active';
        }
      }

      // 3. Send update request
      final response = await ApiService.updateCategory(
        id: sub.categoryId,
        token: token,
        fields: fields,
        files: {},
      );

      final code = response['code'] as int? ?? 200;
      if (code != 200 && response['message']?.toString().contains('Successfully') != true) {
        _revertStatus(sub, isCurrentActive);
        _showSnackbar('Failed to update status on server: ${response['message']}');
      }
    } catch (e) {
      _revertStatus(sub, isCurrentActive);
      _showSnackbar('Error updating subcategory: $e');
    }
  }

  void _revertStatus(SubcategoryItem sub, bool originalState) {
    setState(() {
      sub.status = originalState ? 'Active' : 'Inactive';
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _resolveSubcategoryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Subcategories Management',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: const Color(0xFFF97316), size: 28),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubcategoryFormScreen()),
              );
              if (result == true) {
                _loadSubcategories();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search subcategories...',
                    hintStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.search, color: const Color(0xFF475569)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: const Color(0xFFF97316)),
                    ),
                  ),
                ),
              ),

              // Main List / Loader
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: const Color(0xFFF97316)))
                    : _filteredSubcategories.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lan_outlined, color: const Color(0xFFCBD5E1), size: 64),
                                const SizedBox(height: 16),
                                 const Text(
                                  'No subcategories found',
                                  style: TextStyle(color: Color(0xFF475569), fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSubcategories,
                            color: const Color(0xFFF97316),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 4 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isDesktop ? 2.2 : 1.4,
                              ),
                              itemCount: _filteredSubcategories.length,
                              itemBuilder: (context, index) {
                                final sub = _filteredSubcategories[index];
                                return _buildSubcategoryCard(sub);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubcategoryCard(SubcategoryItem sub) {
    final isActive = sub.status == 'Active';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: sub.image != null && sub.image!.isNotEmpty
                  ? Image.network(
                      _resolveSubcategoryImageUrl(sub.image),
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.folder_open_outlined, color: Color(0xFFCBD5E1), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sub.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Category: ${sub.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sub.status,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 18,
                      width: 32,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Switch(
                          value: isActive,
                          activeColor: const Color(0xFFF97316),
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          onChanged: (val) => _toggleStatus(sub, isActive),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 16),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubcategoryFormScreen(sub: sub),
                          ),
                        );
                        if (result == true) {
                          _loadSubcategories();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubcategoryItem {
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? image;
  String status;

  SubcategoryItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    this.image,
    required this.status,
  });
}
