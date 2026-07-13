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
        setState(() {
          _brands = response['data'] as List<dynamic>;
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text(
          'Brands Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.cyanAccent, size: 28),
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
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search brands...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
            ),
          ),

          // Main List / Loader
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _filteredBrands.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.branding_watermark_outlined, color: Colors.white24, size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'No brands found',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBrands,
                        color: Colors.cyanAccent,
                        backgroundColor: const Color(0xFF1E293B),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
    );
  }

  Widget _buildBrandCard(Map<String, dynamic> brand) {
    final name = brand['brands_name']?.toString() ?? 'Unnamed Brand';
    final imagePath = brand['brands_image'] as String?;
    final status = brand['brands_status']?.toString() ?? 'Active';
    final isActive = status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white.withOpacity(0.08),
          backgroundImage: imagePath != null && imagePath.isNotEmpty
              ? NetworkImage(_resolveBrandImageUrl(imagePath))
              : null,
          child: imagePath == null || imagePath.isEmpty
              ? const Icon(Icons.branding_watermark, color: Colors.cyanAccent, size: 24)
              : null,
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 6.0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          alignment: Alignment.centerLeft,
          child: Container(
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
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isActive,
              activeColor: Colors.cyanAccent,
              inactiveTrackColor: Colors.white10,
              onChanged: (val) => _toggleBrandStatus(brand, val),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
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
      ),
    );
  }
}
