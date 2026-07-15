import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'auth_screen.dart';
import 'category_list_screen.dart';
import 'subcategory_list_screen.dart';
import 'brand_list_screen.dart';
import 'product_list_screen.dart';
import 'banner_list_screen.dart';
import 'vendor_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userDetails;

  // Stats Counters
  int _totalCategories = 0;
  int _activeCategories = 0;

  int _totalBrands = 0;
  int _activeBrands = 0;

  int _totalProducts = 0;
  int _activeProducts = 0;

  int _totalBanners = 0;
  int _activeBanners = 0;

  int _totalSubcategories = 0;
  int _activeSubcategories = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await SessionService.getUserDetails();
      setState(() {
        _userDetails = details;
      });

      final token = await SessionService.getToken();
      if (token == null || token == 'offline_placeholder_token') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch all stats concurrently
      final responses = await Future.wait([
        ApiService.fetchCategories(token),
        ApiService.fetchBrands(token),
        ApiService.fetchProducts(token),
        ApiService.fetchBanners(token),
      ]);

      final catsResp = responses[0];
      final brandsResp = responses[1];
      final productsResp = responses[2];
      final bannersResp = responses[3];

      // 1. Process Categories
      if (catsResp['data'] != null) {
        final List<dynamic> catsList = catsResp['data'] as List<dynamic>;
        _totalCategories = catsList.length;
        _activeCategories = catsList.where((c) => c['categories_status'] == 'Active').length;
      }

      // 2. Process Brands
      if (brandsResp['data'] != null) {
        final List<dynamic> brandsList = brandsResp['data'] as List<dynamic>;
        _totalBrands = brandsList.length;
        _activeBrands = brandsList.where((b) => b['brands_status'] == 'Active').length;
      }

      // 3. Process Products
      if (productsResp['data'] != null) {
        final List<dynamic> productsList = productsResp['data'] as List<dynamic>;
        _totalProducts = productsList.length;
        _activeProducts = productsList.where((p) => p['product_status'] != 'Inactive').length; // Assuming active by default
      }

      // 4. Process Banners
      if (bannersResp['data'] != null) {
        final List<dynamic> bannersList = bannersResp['data'] as List<dynamic>;
        _totalBanners = bannersList.length;
        _activeBanners = bannersList.where((b) => b['banner_status'] == 'Active').length;
      }

      // 5. Load and process subcategories
      int subCount = 0;
      int activeSubCount = 0;
      if (catsResp['data'] != null) {
        final List<dynamic> catsList = catsResp['data'] as List<dynamic>;
        for (var cat in catsList) {
          final catId = cat['id'] as int;
          final detail = await ApiService.fetchCategoryById(catId, token);
          if (detail['data'] != null) {
            final subs = detail['data']['subs'] as List<dynamic>? ?? [];
            subCount += subs.length;
            activeSubCount += subs.where((s) => s['categories_subs_status'] == 'Active').length;
          }
        }
      }
      _totalSubcategories = subCount;
      _activeSubcategories = activeSubCount;

    } catch (e) {
      debugPrint('Error loading admin statistics: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    final token = await SessionService.getToken();
    if (token != null && token != 'offline_placeholder_token') {
      await ApiService.logout(token);
    }

    await SessionService.clearSession();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userDetails?['name']?.toString() ?? 'Admin';
    final email = _userDetails?['email']?.toString() ?? 'admin@gmail.com';
    final mobile = _userDetails?['mobile']?.toString() ?? '9999999999';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text(
          'Single Mart Admin Panel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: Colors.cyanAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Header Profile Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E1B4B), Color(0xFF311B92)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.cyanAccent.withOpacity(0.1),
                            child: const Icon(Icons.admin_panel_settings, color: Colors.cyanAccent, size: 36),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mobile: $mobile',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Overview Section
                    const Text(
                      'Overview Statistics',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Grid Layout of statistics
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: [
                        _buildStatCard('Categories', _totalCategories, '$_activeCategories Active', Icons.category_outlined, Colors.cyanAccent),
                        _buildStatCard('Subcategories', _totalSubcategories, '$_activeSubcategories Active', Icons.lan_outlined, Colors.purpleAccent),
                        _buildStatCard('Brands', _totalBrands, '$_activeBrands Active', Icons.branding_watermark_outlined, Colors.orangeAccent),
                        _buildStatCard('Products', _totalProducts, '$_activeProducts Active', Icons.inventory_2_outlined, Colors.greenAccent),
                        _buildStatCard('Banners', _totalBanners, '$_activeBanners Active', Icons.view_carousel_outlined, Colors.pinkAccent),
                        _buildStatCard('Orders', 0, '0 Pending', Icons.shopping_bag_outlined, Colors.blueAccent),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Store Management Navigation Cards
                    const Text(
                      'System Management',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    _buildManagementCard(
                      title: 'Manage Vendors',
                      subtitle: 'Approve pending registrations, toggle vendor status',
                      icon: Icons.people_alt_rounded,
                      color: Colors.blueAccent,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorListScreen()));
                        _loadDashboardData();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildManagementCard(
                      title: 'Manage Categories',
                      subtitle: 'Add, edit, view & toggle status of categories',
                      icon: Icons.category,
                      color: Colors.cyanAccent,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryListScreen()));
                        _loadDashboardData();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildManagementCard(
                      title: 'Manage Subcategories',
                      subtitle: 'Add, edit, view & toggle status of subcategories',
                      icon: Icons.lan,
                      color: Colors.purpleAccent,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SubcategoryListScreen()));
                        _loadDashboardData();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildManagementCard(
                      title: 'Manage Brands',
                      subtitle: 'Add, edit, view & toggle status of brands',
                      icon: Icons.branding_watermark,
                      color: Colors.orangeAccent,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const BrandListScreen()));
                        _loadDashboardData();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildManagementCard(
                      title: 'Manage Products',
                      subtitle: 'Add, edit, view & manage system products',
                      icon: Icons.inventory_2,
                      color: Colors.greenAccent,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
                        _loadDashboardData();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildManagementCard(
                      title: 'Manage Banners',
                      subtitle: 'Add, edit, view & manage carousel banners',
                      icon: Icons.view_carousel,
                      color: Colors.pinkAccent,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const BannerListScreen()));
                        _loadDashboardData();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, int total, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              Text(
                total.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
