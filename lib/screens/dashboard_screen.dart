import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'category_list_screen.dart';
import 'brand_list_screen.dart';
import 'product_list_screen.dart';
import 'address_list_screen.dart';
import 'vendor_order_list_screen.dart';
import 'attribute_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _userDetails;
  bool _isLoading = false;
  int _currentIndex = 0;

  // Stats State
  List<dynamic> _allOrders = [];
  List<dynamic> _filteredOrders = [];
  List<dynamic> _products = [];
  DateTimeRange? _selectedDateRange;

  double _totalSales = 0.0;
  int _totalOrdersCount = 0;
  int _pendingOrdersCount = 0;
  int _completedOrdersCount = 0;
  int _todayOrdersCount = 0;
  int _totalProductsCount = 0;

  // Color System
  static const Color primaryColor = Color(0xFFF97316); // orange-500
  static const Color primaryDark = Color(0xFFEA580C);  // orange-600
  static const Color accentColor = Color(0xFFFFF7ED); // orange-50
  static const Color bgColor = Color(0xFFF8FAFC);     // slate-50
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);  // slate-900
  static const Color textSecondary = Color(0xFF475569); // slate-600
  static const Color borderColor = Color(0xFFE2E8F0);  // slate-200

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  String _formatDate(DateTime dt) {
    return "${dt.day} ${_getMonthName(dt.month)} ${dt.year}";
  }

  String _getMonthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  void _calculateStats() {
    _filteredOrders = List.from(_allOrders);
    
    // Apply calendar range filter if selected
    if (_selectedDateRange != null) {
      _filteredOrders = _allOrders.where((ord) {
        final dateStr = ord['order_date']?.toString() ?? '';
        try {
          final date = DateTime.parse(dateStr);
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
          return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end.add(const Duration(seconds: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    _totalSales = 0.0;
    _totalOrdersCount = _filteredOrders.length;
    _pendingOrdersCount = 0;
    _completedOrdersCount = 0;
    _todayOrdersCount = 0;

    final today = DateTime.now();

    for (var ord in _filteredOrders) {
      final dateStr = ord['order_date']?.toString() ?? '';
      try {
        final orderDate = DateTime.parse(dateStr);
        if (orderDate.year == today.year && orderDate.month == today.month && orderDate.day == today.day) {
          _todayOrdersCount++;
        }
      } catch (_) {}

      final subs = ord['subs'] as List<dynamic>? ?? [];
      for (var item in subs) {
        final amountStr = item['order_amount']?.toString() ?? '0.00';
        final amount = double.tryParse(amountStr) ?? 0.0;

        final orderStatus = item['order_status']?.toString().toLowerCase() ?? '';

        if (orderStatus != 'cancelled') {
          _totalSales += amount;
        }

        if (orderStatus == 'pending') {
          _pendingOrdersCount++;
        } else if (orderStatus == 'confirmed' || orderStatus == 'delivered') {
          _completedOrdersCount++;
        }
      }
    }
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
    });

    final details = await SessionService.getUserDetails();
    if (details != null) {
      setState(() {
        _userDetails = details;
      });
    }

    final token = await SessionService.getToken();
    final rawId = details?['id'];
    final id = rawId != null ? int.tryParse(rawId.toString()) : null;

    if (details != null && id != null && token != null) {
      try {
        int currentId = id;
        final response = await ApiService.fetchVendorById(id, token);
        if (response['code'] == 200 && response['data'] != null) {
          final freshUser = response['data'] as Map<String, dynamic>;
          await SessionService.saveSession(token, freshUser);
          if (mounted) {
            setState(() {
              _userDetails = freshUser;
            });
          }
          final freshId = int.tryParse(freshUser['id']?.toString() ?? '');
          if (freshId != null) {
            currentId = freshId;
          }
        }

        // Fetch products count
        final prodResp = await ApiService.fetchProducts(token);
        if (prodResp['code'] == 200 && prodResp['data'] != null) {
          final pList = prodResp['data'] as List<dynamic>;
          _products = pList.where((p) => p['product_vendor_id']?.toString() == currentId.toString()).toList();
          _totalProductsCount = _products.length;
        }

        // Fetch orders count & stats
        final orderResp = await ApiService.fetchOrders(token);
        if (orderResp['code'] == 200 && orderResp['data'] != null) {
          final oList = orderResp['data'] as List<dynamic>;
          
          final vendorOrders = <dynamic>[];
          for (var ord in oList) {
            final subs = ord['subs'] as List<dynamic>? ?? [];
            final mySubs = subs.where((s) => s['order_vendor_id']?.toString() == currentId.toString()).toList();
            if (mySubs.isNotEmpty) {
              final ordCopy = Map<String, dynamic>.from(ord);
              ordCopy['subs'] = mySubs;
              vendorOrders.add(ordCopy);
            }
          }
          
          _allOrders = vendorOrders;
          _calculateStats();
        }
      } catch (e) {
        debugPrint('Error loading fresh data: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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

  String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.contains('/')) {
      return 'https://agsdemo.in/singlemartapi/public/$path';
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/user_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    final name = _userDetails?['name'] ?? 'Single Mart Vendor';
    final ownerName = _userDetails?['owner_name'] ?? 'Vendor Owner';
    final mobile = _userDetails?['mobile'] ?? 'N/A';
    final email = _userDetails?['email'] ?? 'N/A';
    final gender = _userDetails?['gender'] ?? 'N/A';
    final dob = _userDetails?['dob'] ?? 'N/A';
    final position = _userDetails?['user_position'] ?? 'Vendor';
    final gst = _userDetails?['gst_number'] ?? 'N/A';
    final pan = _userDetails?['pan_number'] ?? 'N/A';
    final upi = _userDetails?['upi_id'] ?? 'N/A';
    final avatarPath = _userDetails?['user_image'] as String?;
    final qrPath = _userDetails?['qr_code'] as String?;
    final docPath = _userDetails?['business_document'] as String?;

    final addresses = _userDetails?['addresses'] as List<dynamic>?;

    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          _currentIndex == 0 ? 'Vendor Dashboard' : 'My Profile',
          style: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryColor),
            tooltip: 'Refresh Data',
            onPressed: _loadUserDetails,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading && _userDetails == null
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadUserDetails,
              color: primaryColor,
              backgroundColor: Colors.white,
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _currentIndex == 0
                        ? _buildDashboardTab(name, ownerName, position, mobile, email, upi, gst, pan, avatarPath, width)
                        : _buildProfileTab(name, ownerName, position, mobile, email, gender, dob, upi, gst, pan, addresses, avatarPath, qrPath, docPath, width),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary.withOpacity(0.6),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard, color: primaryColor),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded, color: primaryColor),
            label: 'My Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(
    String name,
    String ownerName,
    String position,
    String mobile,
    String email,
    String upi,
    String gst,
    String pan,
    String? avatarPath,
    double screenWidth,
  ) {
    final statsCrossAxisCount = screenWidth > 1200 ? 6 : (screenWidth > 700 ? 3 : 2);
    final actionCrossAxisCount = screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Card Header (Light Orange Gradient)
        Container(
          padding: const EdgeInsets.all(20),
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
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarPath != null && avatarPath.isNotEmpty
                      ? NetworkImage(resolveImageUrl(avatarPath))
                      : null,
                  child: avatarPath == null || avatarPath.isEmpty
                      ? const Icon(Icons.storefront_rounded, size: 36, color: primaryColor)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: $ownerName',
                      style: const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        position.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Statistics Header & Date Picker Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sales & Statistics',
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: _selectedDateRange,
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: primaryColor,
                          onPrimary: Colors.white,
                          onSurface: textPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (range != null) {
                  setState(() {
                    _selectedDateRange = range;
                    _calculateStats();
                  });
                }
              },
              icon: const Icon(Icons.calendar_month_rounded, color: primaryColor, size: 18),
              label: Text(
                _selectedDateRange == null
                    ? 'All Time'
                    : '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}',
                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Stats Cards Grid
        GridView.count(
          crossAxisCount: statsCrossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard('Total Sales', '₹${_totalSales.toStringAsFixed(2)}', Icons.payments_outlined, Colors.green),
            _buildStatCard('Total Orders', '$_totalOrdersCount', Icons.shopping_bag_outlined, Colors.blue),
            _buildStatCard('Pending Orders', '$_pendingOrdersCount', Icons.pending_actions_outlined, Colors.orange),
            _buildStatCard('Completed Orders', '$_completedOrdersCount', Icons.task_alt_outlined, Colors.teal),
            _buildStatCard('Today\'s Orders', '$_todayOrdersCount', Icons.today_outlined, Colors.pink),
            _buildStatCard('Total Products', '$_totalProductsCount', Icons.inventory_2_outlined, Colors.purple),
          ],
        ),
        const SizedBox(height: 28),

        // Store Management Section
        const Text(
          'Store Operations',
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Quick Actions Grid
        GridView.count(
          crossAxisCount: actionCrossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: screenWidth > 900 ? 2.5 : 3.0,
          children: [
            _buildActionCard(
              title: 'Manage Categories',
              subtitle: 'Add/edit categories and subs',
              icon: Icons.category_outlined,
              color: Colors.cyan,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryListScreen()));
              },
            ),
            _buildActionCard(
              title: 'Manage Brands',
              subtitle: 'Manage your active brands',
              icon: Icons.branding_watermark_outlined,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BrandListScreen()));
              },
            ),
            _buildActionCard(
              title: 'Manage Products',
              subtitle: 'View and upload products',
              icon: Icons.inventory_2_outlined,
              color: primaryColor,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
              },
            ),
            _buildActionCard(
              title: 'Manage Orders',
              subtitle: 'Fulfill customer vendor orders',
              icon: Icons.assignment_outlined,
              color: Colors.teal,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const VendorOrderListScreen()));
                _loadUserDetails();
              },
            ),
            _buildActionCard(
              title: 'Manage Attributes',
              subtitle: 'Customize product properties',
              icon: Icons.tune_rounded,
              color: Colors.blueGrey,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AttributeListScreen()));
              },
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Business Information Overview
        const Text(
          'Business Details',
          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildDetailCard([
          _buildDetailRow('Mobile Number', mobile, Icons.phone_android),
          _buildDetailRow('Email Address', email, Icons.email_outlined),
          _buildDetailRow('UPI ID', upi, Icons.payment_outlined),
          _buildDetailRow('GST Number', gst, Icons.receipt_long_outlined),
          _buildDetailRow('PAN Number', pan, Icons.credit_card_outlined),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProfileTab(
    String name,
    String ownerName,
    String position,
    String mobile,
    String email,
    String gender,
    String dob,
    String upi,
    String gst,
    String pan,
    List<dynamic>? addresses,
    String? avatarPath,
    String? qrPath,
    String? docPath,
    double screenWidth,
  ) {
    final bool isWide = screenWidth > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Info Header
        Center(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarPath != null && avatarPath.isNotEmpty
                      ? NetworkImage(resolveImageUrl(avatarPath))
                      : null,
                  child: avatarPath == null || avatarPath.isEmpty
                      ? const Icon(Icons.person, size: 54, color: primaryColor)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                ownerName,
                style: const TextStyle(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor,
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  position,
                  style: const TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Edit Profile Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () async {
              if (_userDetails != null) {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(userDetails: _userDetails!),
                  ),
                );
                if (updated == true) {
                  _loadUserDetails();
                }
              }
            },
            icon: const Icon(Icons.edit_rounded, color: primaryColor, size: 16),
            label: const Text(
              'Edit Profile Settings',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Sections Layout (Grid on desktop, vertical on mobile)
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildProfileSectionHeader('Personal details'),
                        const SizedBox(height: 12),
                        _buildDetailCard([
                          _buildDetailRow('Mobile Number', mobile, Icons.phone_android_outlined),
                          _buildDetailRow('Email Address', email, Icons.email_outlined),
                          _buildDetailRow('Gender', gender, Icons.wc_outlined),
                          _buildDetailRow('Date of Birth', dob, Icons.calendar_month_outlined),
                        ]),
                        const SizedBox(height: 24),
                        _buildProfileSectionHeader('Business credentials'),
                        const SizedBox(height: 12),
                        _buildDetailCard([
                          _buildDetailRow('UPI ID', upi, Icons.payment_outlined),
                          _buildDetailRow('GST Number', gst, Icons.receipt_long_outlined),
                          _buildDetailRow('PAN Number', pan, Icons.credit_card_outlined),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _buildProfileSectionHeader('Address locations')),
                            TextButton.icon(
                              onPressed: () async {
                                if (_userDetails != null) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddressListScreen(userDetails: _userDetails!),
                                    ),
                                  );
                                  _loadUserDetails();
                                }
                              },
                              icon: const Icon(Icons.settings_outlined, color: primaryColor, size: 14),
                              label: const Text('Manage', style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildAddressList(addresses),
                        const SizedBox(height: 24),
                        _buildProfileSectionHeader('Uploaded Certificates'),
                        const SizedBox(height: 16),
                        _buildDocumentPreview('Payment QR Code', qrPath),
                        const SizedBox(height: 16),
                        _buildDocumentPreview('Business Registration', docPath),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSectionHeader('Personal details'),
                  const SizedBox(height: 12),
                  _buildDetailCard([
                    _buildDetailRow('Mobile Number', mobile, Icons.phone_android_outlined),
                    _buildDetailRow('Email Address', email, Icons.email_outlined),
                    _buildDetailRow('Gender', gender, Icons.wc_outlined),
                    _buildDetailRow('Date of Birth', dob, Icons.calendar_month_outlined),
                  ]),
                  const SizedBox(height: 24),
                  _buildProfileSectionHeader('Business credentials'),
                  const SizedBox(height: 12),
                  _buildDetailCard([
                    _buildDetailRow('UPI ID', upi, Icons.payment_outlined),
                    _buildDetailRow('GST Number', gst, Icons.receipt_long_outlined),
                    _buildDetailRow('PAN Number', pan, Icons.credit_card_outlined),
                  ]),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildProfileSectionHeader('Address locations')),
                      TextButton.icon(
                        onPressed: () async {
                          if (_userDetails != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddressListScreen(userDetails: _userDetails!),
                              ),
                            );
                            _loadUserDetails();
                          }
                        },
                        icon: const Icon(Icons.settings_outlined, color: primaryColor, size: 14),
                        label: const Text('Manage', style: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAddressList(addresses),
                  const SizedBox(height: 24),
                  _buildProfileSectionHeader('Uploaded Certificates'),
                  const SizedBox(height: 16),
                  _buildDocumentPreview('Payment QR Code', qrPath),
                  const SizedBox(height: 16),
                  _buildDocumentPreview('Business Registration', docPath),
                ],
              ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAddressList(List<dynamic>? addresses) {
    if (addresses == null || addresses.isEmpty) {
      return _buildDetailCard([
        _buildDetailRow('Complete Address', 'N/A', Icons.location_on_outlined),
      ]);
    }
    return Column(
      children: addresses.map((addr) {
        final isDefault = (addr['is_default'] == 1 || addr['is_default'] == '1');
        final type = addr['address_type']?.toString() ?? 'Shop';
        final parts = [
          addr['address_line_1'],
          addr['address_line_2'],
          addr['landmark'],
          addr['city'],
          addr['district'],
          addr['state'],
          addr['country'],
          addr['pincode'],
        ].where((p) => p != null && p.toString().trim().isNotEmpty).toList();
        final text = parts.isEmpty ? 'N/A' : parts.join(', ');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildDetailCard([
            _buildDetailRow(
              '${type.toUpperCase()}${isDefault ? ' (DEFAULT)' : ''}',
              text,
              isDefault ? Icons.stars_rounded : Icons.location_on_outlined,
              valueColor: isDefault ? primaryColor : textPrimary,
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildProfileSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: borderColor)),
      ],
    );
  }

  Widget _buildDocumentPreview(String title, String? path) {
    final imageUrl = resolveImageUrl(path);
    final hasImage = path != null && path.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: bgColor,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 36),
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor.withOpacity(0.5)),
                  ),
                  child: const Text('No Document Uploaded', style: TextStyle(color: textSecondary, fontSize: 12)),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: rows.expand((r) => [r, const Divider(color: borderColor, height: 16)]).toList()..removeLast(),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: valueColor ?? textSecondary.withOpacity(0.6), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: textSecondary.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: TextStyle(color: valueColor ?? textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
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
