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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Subcategories Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      body: Column(
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
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSubcategories,
                        color: const Color(0xFFF97316),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _filteredSubcategories.length,
                          itemBuilder: (context, index) {
                            final sub = _filteredSubcategories[index];
                            final isActive = sub.status == 'Active';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: sub.image != null && sub.image!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            _resolveSubcategoryImageUrl(sub.image),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(Icons.folder_open_outlined, color: const Color(0xFFCBD5E1)),
                                ),
                                title: Text(
                                  sub.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Container(
                                  margin: const EdgeInsets.only(top: 4.0),
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Text(
                                    'Category: ${sub.categoryName}',
                                    style: const TextStyle(
                                      color: const Color(0xFFF97316),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: isActive,
                                      activeColor: const Color(0xFFF97316),
                                      inactiveThumbColor: Colors.white54,
                                      onChanged: (val) => _toggleStatus(sub, isActive),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: const Color(0xFF334155)),
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
                              ),
                            );
                          },
                        ),
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
