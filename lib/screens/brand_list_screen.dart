import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'brand_form_screen.dart';

class BrandListScreen extends StatefulWidget {
  const BrandListScreen({super.key});

  @override
  State<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends State<BrandListScreen> {
  List<dynamic> _brands = [];
  List<dynamic> _filteredBrands = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _searchController.addListener(_filterBrands);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired. Please log in again.');
        return;
      }

      final response = await ApiService.fetchBrands(token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 && response['data'] != null) {
        final rawBrands = response['data'] as List<dynamic>;

        final details = await SessionService.getUserDetails();
        final isAdmin = details?['user_type'] == 3 || details?['user_position'] == 'Admin';
        final vendorName = details?['name']?.toString() ?? '';
        final ownerName = details?['owner_name']?.toString() ?? '';

        List<dynamic> filtered = [];
        if (isAdmin) {
          filtered = rawBrands;
        } else {
          final futures = rawBrands.map((brand) async {
            try {
              final id = brand['id'] as int;
              final detailRes = await ApiService.fetchBrandById(id, token);
              if (detailRes['data'] != null) {
                final createdBy = detailRes['data']['created_by']?.toString().toLowerCase();
                if (createdBy == vendorName.toLowerCase() || createdBy == ownerName.toLowerCase()) {
                  return brand;
                }
              }
            } catch (_) {}
            return null;
          });
          final results = await Future.wait(futures);
          filtered = results.where((b) => b != null).toList();
        }

        setState(() {
          _brands = filtered;
          _filteredBrands = List.from(_brands);
        });
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to load brands');
      }
    } catch (e) {
      _showSnackbar('Error loading brands: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterBrands() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBrands = _brands.where((brand) {
        final name = brand['brands_name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleBrandStatus(Map<String, dynamic> brand, bool newStatusVal) async {
    final id = brand['id'] as int;
    final newStatusString = newStatusVal ? 'Active' : 'Inactive';
    final oldStatusString = brand['brands_status']?.toString() ?? 'Active';

    // Optimistic UI update
    setState(() {
      brand['brands_status'] = newStatusString;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired.');
        setState(() {
          brand['brands_status'] = oldStatusString;
        });
        return;
      }

      final response = await ApiService.updateBrandStatus(
        id: id,
        token: token,
        status: newStatusString,
      );

      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Brand status updated to $newStatusString');
      } else {
        // Rollback
        setState(() {
          brand['brands_status'] = oldStatusString;
        });
        _showSnackbar(response['message']?.toString() ?? 'Failed to update brand status');
      }
    } catch (e) {
      // Rollback
      setState(() {
        brand['brands_status'] = oldStatusString;
      });
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resolveBrandImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/brand_images/$path';
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
          'Brands Management',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: const Color(0xFFF97316), size: 28),
            tooltip: 'Add Brand',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrandFormScreen()),
              );
              if (result == true) {
                _loadBrands();
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
                    hintText: 'Search brands...',
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
                    : _filteredBrands.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.branding_watermark_outlined, color: const Color(0xFFCBD5E1), size: 64),
                                const SizedBox(height: 16),
                                const Text(
                                  'No brands found',
                                  style: TextStyle(color: Color(0xFF475569), fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBrands,
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
                              itemCount: _filteredBrands.length,
                              itemBuilder: (context, index) {
                                final brand = _filteredBrands[index] as Map<String, dynamic>;
                                return _buildBrandCard(brand);
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

  Widget _buildBrandCard(Map<String, dynamic> brand) {
    final name = brand['brands_name']?.toString() ?? 'Unnamed Brand';
    final imagePath = brand['brands_image'] as String?;
    final status = brand['brands_status']?.toString() ?? 'Active';
    final isActive = status.toLowerCase() == 'active';

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
                      _resolveBrandImageUrl(imagePath),
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.branding_watermark, color: Color(0xFFCBD5E1), size: 24),
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
                const SizedBox(height: 8),
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
                          onChanged: (val) => _toggleBrandStatus(brand, val),
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
                            builder: (_) => BrandFormScreen(brand: brand),
                          ),
                        );
                        if (result == true) {
                          _loadBrands();
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
