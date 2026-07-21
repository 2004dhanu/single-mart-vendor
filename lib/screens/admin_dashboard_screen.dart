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
import 'review_list_screen.dart';
import 'attribute_list_screen.dart';

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

  int _totalOrders = 0;
  int _pendingOrders = 0;

  // Color System
  static const Color primaryColor = Color(0xFFF97316); // orange-500
  static const Color primaryDark = Color(0xFFEA580C);  // orange-600
  static const Color bgColor = Color(0xFFF8FAFC);     // slate-50
  static const Color textPrimary = Color(0xFF0F172A);  // slate-900
  static const Color textSecondary = Color(0xFF475569); // slate-600
  static const Color borderColor = Color(0xFFE2E8F0);  // slate-200

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
        ApiService.fetchOrders(token),
      ]);

      final catsResp = responses[0];
      final brandsResp = responses[1];
      final productsResp = responses[2];
      final bannersResp = responses[3];
      final ordersResp = responses[4];

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
        _activeProducts = productsList.where((p) => p['product_status'] != 'Inactive').length;
      }

      // 4. Process Banners
      if (bannersResp['data'] != null) {
        final List<dynamic> bannersList = bannersResp['data'] as List<dynamic>;
        _totalBanners = bannersList.length;
        _activeBanners = bannersList.where((b) => b['banner_status'] == 'Active').length;
      }

      // 4b. Process Orders
      if (ordersResp['data'] != null) {
        final List<dynamic> ordersList = ordersResp['data'] as List<dynamic>;
        _totalOrders = ordersList.length;
        int pendingCount = 0;
        for (var ord in ordersList) {
          final subs = ord['subs'] as List<dynamic>? ?? [];
          final isPending = subs.any((s) => s['order_status']?.toString().toLowerCase() == 'pending');
          if (isPending) {
            pendingCount++;
          }
        }
        _pendingOrders = pendingCount;
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

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    final statsCrossAxisCount = width > 1200 ? 6 : (width > 700 ? 3 : 2);
    final actionCrossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Single Mart Admin Panel',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
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
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: primaryColor,
              backgroundColor: Colors.white,
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Admin Header Profile Card (Light Orange Gradient)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF7ED), Color(0xFFFFE4E6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primaryColor, width: 2),
                                ),
                                child: const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.admin_panel_settings_rounded, color: primaryColor, size: 30),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.toUpperCase(),
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: const TextStyle(color: textSecondary, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mobile: $mobile',
                                      style: const TextStyle(color: textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Overview Section Title
                        const Text(
                          'System Statistics',
                          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Grid Layout of statistics
                        GridView.count(
                          crossAxisCount: statsCrossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          children: [
                            _buildStatCard('Categories', _totalCategories, '$_activeCategories Active', Icons.category_outlined, Colors.cyan),
                            _buildStatCard('Subcategories', _totalSubcategories, '$_activeSubcategories Active', Icons.lan_outlined, Colors.purple),
                            _buildStatCard('Brands', _totalBrands, '$_activeBrands Active', Icons.branding_watermark_outlined, Colors.orange),
                            _buildStatCard('Products', _totalProducts, '$_activeProducts Active', Icons.inventory_2_outlined, Colors.green),
                            _buildStatCard('Banners', _totalBanners, '$_activeBanners Active', Icons.view_carousel_outlined, Colors.pink),
                            _buildStatCard('Orders', _totalOrders, '$_pendingOrders Pending', Icons.shopping_bag_outlined, Colors.blue),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Store Management Section Title
                        const Text(
                          'Administration Controls',
                          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Quick Actions Grid
                        GridView.count(
                          crossAxisCount: actionCrossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isDesktop ? 2.5 : 3.0,
                          children: [
                            _buildManagementCard(
                              title: 'Manage Vendors',
                              subtitle: 'Approve & toggle vendor status',
                              icon: Icons.people_outline_rounded,
                              color: Colors.blue,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorListScreen()));
                                _loadDashboardData();
                              },
                            ),
                            _buildManagementCard(
                              title: 'Manage Categories',
                              subtitle: 'Categories settings & options',
                              icon: Icons.category_outlined,
                              color: Colors.cyan,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryListScreen()));
                                _loadDashboardData();
                              },
                            ),
                            _buildManagementCard(
                              title: 'Manage Subcategories',
                              subtitle: 'Manage nested subcategories',
                              icon: Icons.lan_outlined,
                              color: Colors.purple,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SubcategoryListScreen()));
                                _loadDashboardData();
                              },
                            ),
                            _buildManagementCard(
                              title: 'Manage Brands',
                              subtitle: 'System manufacturers & brands',
                              icon: Icons.branding_watermark_outlined,
                              color: Colors.orange,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BrandListScreen()));
                                _loadDashboardData();
                              },
                            ),
                            _buildManagementCard(
                              title: 'Manage Products',
                              subtitle: 'System stock products listing',
                              icon: Icons.inventory_2_outlined,
                              color: Colors.green,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
                                _loadDashboardData();
                              },
                            ),
                            _buildManagementCard(
                              title: 'Manage Banners',
                              subtitle: 'App banners & advertisements',
                              icon: Icons.view_carousel_outlined,
                              color: Colors.pink,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BannerListScreen()));
                                _loadDashboardData();
                              },
                            ),
                            _buildManagementCard(
                              title: 'Manage Reviews',
                              subtitle: 'Verify customer feedback & ratings',
                              icon: Icons.rate_review_outlined,
                              color: Colors.amber,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewListScreen()));
                                _loadDashboardData();
                              },
                            ),
                            _buildManagementCard(
                              title: 'Manage Attributes',
                              subtitle: 'Color, Size & configuration values',
                              icon: Icons.tune_outlined,
                              color: Colors.teal,
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AttributeListScreen()));
                                _loadDashboardData();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, int total, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Expanded(
                child: Text(
                  total.toString(),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: textSecondary.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
