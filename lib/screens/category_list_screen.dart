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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Manage Categories',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      body: Column(
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
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCategories,
                        color: const Color(0xFFF97316),
                        backgroundColor: const Color(0xFF1E293B),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
    final isLoadingSubs = category['is_loading_subs'] as bool? ?? false;

    // Parse subcategory names list for count
    final String subCategoriesStr = category['sub_categories']?.toString() ?? '';
    final List<String> subNames = subCategoriesStr.isNotEmpty
        ? subCategoriesStr.split(',').map((s) => s.trim()).toList()
        : [];
    final int subCount = subNames.isNotEmpty ? subNames.length : subcategories.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            onExpansionChanged: (expanded) {
              if (expanded && subcategories.isEmpty) {
                _loadCategoryDetails(category);
              }
            },
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              backgroundImage: imagePath != null && imagePath.isNotEmpty
                  ? NetworkImage(_resolveCategoryImageUrl(imagePath))
                  : null,
              child: imagePath == null || imagePath.isEmpty
                  ? const Icon(Icons.category_rounded, color: const Color(0xFFF97316), size: 24)
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4.0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isActive ? Colors.greenAccent : Colors.redAccent,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$subCount subcategories',
                  style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.all(16),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  activeColor: const Color(0xFFF97316),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  onChanged: (val) => _toggleCategoryStatus(category, val),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: const Color(0xFF334155)),
                  onPressed: () async {
                    // Fetch full category details (with subs) before navigating to form
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
                          _showSnackbar('Failed to load category details for editing.');
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
            children: [
              const Divider(color: const Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subcategories:',
                    style: TextStyle(color: const Color(0xFFF97316), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      // Fetch full category details first
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
                    icon: const Icon(Icons.add, size: 16, color: const Color(0xFFF97316)),
                    label: const Text(
                      'Manage Subs',
                      style: TextStyle(color: const Color(0xFFF97316), fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isLoadingSubs)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: CircularProgressIndicator(color: const Color(0xFFF97316), strokeWidth: 2),
                  ),
                )
              else
                subcategories.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No subcategories added yet.',
                          style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.3), fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subcategories.length,
                        itemBuilder: (context, sIndex) {
                          final sub = subcategories[sIndex] as Map<String, dynamic>;
                          final subName = sub['categories_subs_name']?.toString() ?? 'Unnamed Sub';
                          final subImage = sub['categories_subs_image'] as String?;
                          final subStatus = sub['categories_subs_status']?.toString() ?? 'Active';
                          final subIsActive = subStatus.toLowerCase() == 'active';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white,
                                  backgroundImage: subImage != null && subImage.isNotEmpty
                                      ? NetworkImage(_resolveSubcategoryImageUrl(subImage))
                                      : null,
                                  child: subImage == null || subImage.isEmpty
                                      ? const Icon(Icons.subdirectory_arrow_right, color: const Color(0xFFF97316), size: 16)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    subName,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: subIsActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    subStatus,
                                    style: TextStyle(
                                      color: subIsActive ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
