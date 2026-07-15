import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'banner_form_screen.dart';

class BannerListScreen extends StatefulWidget {
  const BannerListScreen({super.key});

  @override
  State<BannerListScreen> createState() => _BannerListScreenState();
}

class _BannerListScreenState extends State<BannerListScreen> {
  List<dynamic> _banners = [];
  List<dynamic> _filteredBanners = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBanners();
    _searchController.addListener(_filterBanners);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final response = await ApiService.fetchBanners(token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 && response['data'] != null) {
        setState(() {
          _banners = response['data'] as List<dynamic>;
          _filteredBanners = List.from(_banners);
        });
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to load banners');
      }
    } catch (e) {
      _showSnackbar('Error loading banners: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterBanners() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBanners = _banners.where((banner) {
        final name = banner['banner']?.toString().toLowerCase() ?? '';
        final link = banner['banner_link']?.toString().toLowerCase() ?? '';
        return name.contains(query) || link.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleStatus(Map<String, dynamic> banner, bool currentActive) async {
    final newStatus = currentActive ? 'Inactive' : 'Active';
    final bannerId = banner['id'] as int;

    // Optimistic UI update
    setState(() {
      banner['banner_status'] = newStatus;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final response = await ApiService.updateBannerStatus(
        id: bannerId,
        token: token,
        status: newStatus,
      );

      final code = response['code'] as int? ?? 200;
      if (code != 200 && response['message']?.toString().contains('Successfully') != true) {
        setState(() {
          banner['banner_status'] = currentActive ? 'Active' : 'Inactive';
        });
        _showSnackbar('Failed to update status on server: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        banner['banner_status'] = currentActive ? 'Active' : 'Inactive';
      });
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _resolveBannerImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'https://agsdemo.in/singlemartapi/public/assets/images/banner_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text(
          'Banners Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.cyanAccent, size: 28),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BannerFormScreen()),
              );
              if (result == true) {
                _loadBanners();
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
                hintText: 'Search banners...',
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
                : _filteredBanners.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.view_carousel_outlined, color: Colors.white24, size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'No banners found',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBanners,
                        color: Colors.cyanAccent,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _filteredBanners.length,
                          itemBuilder: (context, index) {
                            final banner = _filteredBanners[index] as Map<String, dynamic>;
                            final name = banner['banner']?.toString() ?? 'Unnamed Banner';
                            final link = banner['banner_link']?.toString() ?? '';
                            final sort = banner['banner_sort_order']?.toString() ?? '1';
                            final status = banner['banner_status']?.toString() ?? 'Active';
                            final isActive = status == 'Active';
                            final imgPath = banner['banner_image'] as String?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Banner Image Preview Box
                                  Container(
                                    height: 140,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: imgPath != null && imgPath.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(16),
                                              topRight: Radius.circular(16),
                                            ),
                                            child: Image.network(
                                              _resolveBannerImageUrl(imgPath),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            ),
                                          )
                                        : const Center(
                                            child: Icon(Icons.image_outlined, color: Colors.white30, size: 40),
                                          ),
                                  ),
                                  
                                  ListTile(
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (link.isNotEmpty) ...[
                                            Row(
                                              children: [
                                                const Icon(Icons.link_outlined, color: Colors.cyanAccent, size: 14),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    link,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          Text(
                                            'Sort Order: $sort',
                                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: isActive,
                                          activeColor: Colors.cyanAccent,
                                          inactiveThumbColor: Colors.white54,
                                          onChanged: (val) => _toggleStatus(banner, isActive),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => BannerFormScreen(banner: banner),
                                              ),
                                            );
                                            if (result == true) {
                                              _loadBanners();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
