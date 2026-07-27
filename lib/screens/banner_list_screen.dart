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
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Banners Management',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: const Color(0xFFF97316), size: 28),
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
                    hintText: 'Search banners...',
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
                    : _filteredBanners.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.view_carousel_outlined, color: const Color(0xFFCBD5E1), size: 64),
                                const SizedBox(height: 16),
                                 const Text(
                                  'No banners found',
                                  style: TextStyle(color: Color(0xFF475569), fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBanners,
                            color: const Color(0xFFF97316),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 4 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isDesktop ? 2.2 : 1.4,
                              ),
                              itemCount: _filteredBanners.length,
                              itemBuilder: (context, index) {
                                final banner = _filteredBanners[index] as Map<String, dynamic>;
                                return _buildBannerCard(banner);
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

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    final name = banner['banner']?.toString() ?? 'Unnamed Banner';
    final link = banner['banner_link']?.toString() ?? '';
    final sort = banner['banner_sort_order']?.toString() ?? '1';
    final status = banner['banner_status']?.toString() ?? 'Active';
    final isActive = status == 'Active';
    final imgPath = banner['banner_image'] as String?;

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
              child: imgPath != null && imgPath.isNotEmpty
                  ? Image.network(
                      _resolveBannerImageUrl(imgPath),
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.image_outlined, color: Color(0xFFCBD5E1), size: 24),
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
                if (link.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.link_outlined, color: Color(0xFFF97316), size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: const Color(0xFF64748B), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  'Sort Order: $sort',
                  style: const TextStyle(color: Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.bold),
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
                          onChanged: (val) => _toggleStatus(banner, isActive),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
