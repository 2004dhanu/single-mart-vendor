import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  bool _isLoading = false;
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  String _categoryImageUrlPrefix = 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/';
  String _subcategoryImageUrlPrefix = 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired. Please log in again.');
        return;
      }

      final response = await ApiService.fetchCategories(token);
      final code = response['code'] as int? ?? 200;

      if (code == 200) {
        List<dynamic> rawList = [];
        if (response['data'] != null) {
          if (response['data'] is List) {
            rawList = response['data'] as List<dynamic>;
          } else if (response['data'] is Map && response['data']['data'] is List) {
            rawList = response['data']['data'] as List<dynamic>;
          }
        }

        // Try to read image prefix configs if available
        if (response['image_url'] is List) {
          for (var imgUrlConfig in response['image_url']) {
            if (imgUrlConfig['image_for'] == 'Category') {
              _categoryImageUrlPrefix = imgUrlConfig['image_url']?.toString() ?? _categoryImageUrlPrefix;
              _subcategoryImageUrlPrefix = imgUrlConfig['image_url']?.toString() ?? _subcategoryImageUrlPrefix;
            }
          }
        }

        final details = await SessionService.getUserDetails();
        final isAdmin = details?['user_type'] == 3 || details?['user_position'] == 'Admin';
        final vendorName = details?['name']?.toString() ?? '';
        final ownerName = details?['owner_name']?.toString() ?? '';

        List<dynamic> filtered = [];
        if (isAdmin) {
          filtered = rawList;
        } else {
          final futures = rawList.map((cat) async {
            try {
              final id = cat['id'] as int;
              final detailRes = await ApiService.fetchCategoryById(id, token);
              if (detailRes['data'] != null) {
                final createdBy = detailRes['data']['created_by']?.toString().toLowerCase();
                if (createdBy == vendorName.toLowerCase() || createdBy == ownerName.toLowerCase()) {
                  return cat;
                }
              }
            } catch (_) {}
            return null;
          });
          final results = await Future.wait(futures);
          filtered = results.where((c) => c != null).toList();
        }

        setState(() {
          _categories = filtered;
          _filterCategories(_searchQuery);
        });
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to load categories');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterCategories(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCategories = List.from(_categories);
      } else {
        _filteredCategories = _categories.where((c) {
          final catName = c['categories_name']?.toString().toLowerCase() ?? '';
          return catName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _toggleCategoryStatus(Map<String, dynamic> category, bool isNowActive) async {
    final originalStatus = category['categories_status']?.toString() ?? 'Active';
    final newStatus = isNowActive ? 'Active' : 'Inactive';
    final catId = category['id'] as int;

    // Optimistically update UI
    setState(() {
      category['categories_status'] = newStatus;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired.');
        setState(() {
          category['categories_status'] = originalStatus;
        });
        return;
      }

      final result = await ApiService.updateCategoryStatus(
        id: catId,
        token: token,
        status: newStatus,
      );

      final code = result['code'] as int? ?? 200;
      if (code != 200 && code != 201) {
        _showSnackbar(result['message']?.toString() ?? 'Status update failed.');
        setState(() {
          category['categories_status'] = originalStatus;
        });
      } else {
        _showSnackbar('Category status updated to $newStatus.');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
      setState(() {
        category['categories_status'] = originalStatus;
      });
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _resolveCategoryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$_categoryImageUrlPrefix$path';
  }

  String _resolveSubcategoryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$_subcategoryImageUrlPrefix$path';
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
          'Manage Categories',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: const Color(0xFFF97316)),
            onPressed: _loadCategories,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
          );
          if (result == true) {
            _loadCategories();
          }
        },
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterCategories,
                  style: const TextStyle(color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.search, color: const Color(0xFFF97316)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: const Color(0xFF0F172A)),
                            onPressed: () {
                              _searchController.clear();
                              _filterCategories('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: const Color(0xFFF97316)),
                    ),
                  ),
                ),
              ),

              // Category List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: const Color(0xFFF97316)))
                    : _filteredCategories.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.category_outlined, color: const Color(0xFFCBD5E1), size: 64),
                                const SizedBox(height: 16),
                                const Text(
                                  'No categories found',
                                  style: TextStyle(color: Color(0xFF475569), fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCategories,
                            color: const Color(0xFFF97316),
                            backgroundColor: Colors.white,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 4 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isDesktop ? 2.2 : 1.4,
                              ),
                              itemCount: _filteredCategories.length,
                              itemBuilder: (context, index) {
                                final category = _filteredCategories[index] as Map<String, dynamic>;
                                return _buildCategoryCard(category);
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

  Future<void> _loadCategoryDetails(Map<String, dynamic> category) async {
    final catId = category['id'] as int;
    setState(() {
      category['is_loading_subs'] = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token != null) {
        final response = await ApiService.fetchCategoryById(catId, token);
        final code = response['code'] as int? ?? 200;
        if (code == 200 && response['data'] != null) {
          setState(() {
            category['subs'] = response['data']['subs'] ?? [];
          });
        }
      }
    } catch (e) {
      _showSnackbar('Error loading subcategories: $e');
    } finally {
      setState(() {
        category['is_loading_subs'] = false;
      });
    }
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final name = category['categories_name']?.toString() ?? 'Unnamed Category';
    final imagePath = category['categories_image'] as String?;
    final status = category['categories_status']?.toString() ?? 'Active';
    final isActive = status.toLowerCase() == 'active';
    final subcategories = category['subs'] as List<dynamic>? ?? [];

    // Parse subcategory names list for count
    final String subCategoriesStr = category['sub_categories']?.toString() ?? '';
    final List<String> subNames = subCategoriesStr.isNotEmpty
        ? subCategoriesStr.split(',').map((s) => s.trim()).toList()
        : [];
    final int subCount = subNames.isNotEmpty ? subNames.length : subcategories.length;

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
              child: imagePath != null && imagePath.isNotEmpty
                  ? Image.network(
                      _resolveCategoryImageUrl(imagePath),
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.category_rounded, color: Color(0xFFCBD5E1), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
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
                  '$subCount subcategories',
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
                        status,
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
                          onChanged: (val) => _toggleCategoryStatus(category, val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 16),
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });
                        try {
                          final token = await SessionService.getToken();
                          if (token != null) {
                            final detailResp = await ApiService.fetchCategoryById(category['id'] as int, token);
                            if (detailResp['data'] != null) {
                              final fullCategory = detailResp['data'] as Map<String, dynamic>;
                              if (mounted) {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryFormScreen(category: fullCategory),
                                  ),
                                );
                                if (result == true) {
                                  _loadCategories();
                                }
                              }
                            } else {
                              _showSnackbar('Failed to load category details.');
                            }
                          }
                        } catch (e) {
                          _showSnackbar('Error: $e');
                        } finally {
                          setState(() {
                            _isLoading = false;
                          });
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
