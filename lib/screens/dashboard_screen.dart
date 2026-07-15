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
        final paymentStatus = item['payment_status']?.toString().toLowerCase() ?? '';

        // Calculate sales only when payment status is "received"
        if (paymentStatus == 'received') {
          _totalSales += amount;
        }

        if (orderStatus == 'pending') {
          _pendingOrdersCount++;
        } else if (orderStatus == 'delivered') {
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
          _products = pList;
          _totalProductsCount = pList.length;
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          _currentIndex == 0 ? 'Vendor Dashboard' : 'My Profile',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            tooltip: 'Refresh Data',
            onPressed: _loadUserDetails,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading && _userDetails == null
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : RefreshIndicator(
              onRefresh: _loadUserDetails,
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF1E293B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: _currentIndex == 0
                    ? _buildDashboardTab(name, ownerName, position, mobile, email, upi, gst, pan, avatarPath)
                    : _buildProfileTab(name, ownerName, position, mobile, email, gender, dob, upi, gst, pan, addresses, avatarPath, qrPath, docPath),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E1B4B),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white60,
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
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vendor Profile Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF311B92), Color(0xFF1A237E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                backgroundImage: avatarPath != null && avatarPath.isNotEmpty
                    ? NetworkImage(resolveImageUrl(avatarPath))
                    : null,
                child: avatarPath == null || avatarPath.isEmpty
                    ? const Icon(Icons.storefront_rounded, size: 40, color: Colors.cyanAccent)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: $ownerName',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        position.toUpperCase(),
                        style: const TextStyle(color: Color(0xFF1E1B4B), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Statistics Header & Date Range Picker
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sales Performance',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(
                _selectedDateRange == null ? Icons.calendar_today_rounded : Icons.calendar_month_rounded,
                color: Colors.cyanAccent,
                size: 20,
              ),
              tooltip: 'Filter by Date Range',
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: _selectedDateRange,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.cyanAccent,
                          onPrimary: Colors.black,
                          surface: Color(0xFF1E1B4B),
                          onSurface: Colors.white,
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
            ),
          ],
        ),
        if (_selectedDateRange != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.cyanAccent, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Filtered: ${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDateRange = null;
                      _calculateStats();
                    });
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Statistics Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard('Total Sales', '₹${_totalSales.toStringAsFixed(2)}', Icons.currency_rupee, Colors.greenAccent),
            _buildStatCard('Total Orders', '$_totalOrdersCount', Icons.shopping_bag_outlined, Colors.blueAccent),
            _buildStatCard('Pending Orders', '$_pendingOrdersCount', Icons.pending_actions_rounded, Colors.orangeAccent),
            _buildStatCard('Completed Orders', '$_completedOrdersCount', Icons.task_alt_rounded, Colors.cyanAccent),
            _buildStatCard('Today\'s Orders', '$_todayOrdersCount', Icons.today_rounded, Colors.purpleAccent),
            _buildStatCard('Total Products', '$_totalProductsCount', Icons.inventory_2_outlined, Colors.amberAccent),
          ],
        ),
        const SizedBox(height: 24),

        // Store Management Header
        const Text(
          'Store Management',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Quick Actions Card
        _buildActionCard(
          title: 'Manage Categories & Subs',
          subtitle: 'Add/edit categories and manage subcategories',
          icon: Icons.category_rounded,
          color: Colors.cyanAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryListScreen()),
            );
          },
        ),
        const SizedBox(height: 12),

        _buildActionCard(
          title: 'Manage Brands',
          subtitle: 'Add, edit, view & toggle status of brands',
          icon: Icons.branding_watermark_rounded,
          color: Colors.purpleAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BrandListScreen()),
            );
          },
        ),
        const SizedBox(height: 12),

        _buildActionCard(
          title: 'Manage Products',
          subtitle: 'Add, edit, view & manage store products',
          icon: Icons.inventory_2_rounded,
          color: Colors.orangeAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductListScreen()),
            );
          },
        ),
        const SizedBox(height: 12),

        _buildActionCard(
          title: 'Manage Orders',
          subtitle: 'View customer orders, update payment and status',
          icon: Icons.shopping_bag_rounded,
          color: Colors.greenAccent,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorOrderListScreen()),
            );
            _loadUserDetails();
          },
        ),
        const SizedBox(height: 24),

        // Business Information
        const Text(
          'Business Overview',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        _buildDetailCard([
          _buildDetailRow('Mobile Number', mobile, Icons.phone_android),
          _buildDetailRow('Email Address', email, Icons.email_outlined),
          _buildDetailRow('UPI ID', upi, Icons.payment),
          _buildDetailRow('GST Number', gst, Icons.receipt_long),
          _buildDetailRow('PAN Number', pan, Icons.credit_card),
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Header Details
        Center(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.cyanAccent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.white10,
                  backgroundImage: avatarPath != null && avatarPath.isNotEmpty
                      ? NetworkImage(resolveImageUrl(avatarPath))
                      : null,
                  child: avatarPath == null || avatarPath.isEmpty
                      ? const Icon(Icons.person, size: 60, color: Colors.cyanAccent)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                ownerName,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  position,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Edit Profile Button
        SizedBox(
          width: double.infinity,
          height: 48,
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
            icon: const Icon(Icons.edit_rounded, color: Colors.cyanAccent, size: 18),
            label: const Text(
              'Edit Profile Settings',
              style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.cyanAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Section: Personal
        _buildProfileSectionHeader('Personal details'),
        const SizedBox(height: 12),
        _buildDetailCard([
          _buildDetailRow('Mobile Number', mobile, Icons.phone_android),
          _buildDetailRow('Email Address', email, Icons.email_outlined),
          _buildDetailRow('Gender', gender, Icons.wc_outlined),
          _buildDetailRow('Date of Birth', dob, Icons.calendar_month_outlined),
        ]),
        const SizedBox(height: 24),

        // Section: Business
        _buildProfileSectionHeader('Business details'),
        const SizedBox(height: 12),
        _buildDetailCard([
          _buildDetailRow('UPI ID', upi, Icons.payment),
          _buildDetailRow('GST Number', gst, Icons.receipt_long),
          _buildDetailRow('PAN Number', pan, Icons.credit_card),
        ]),
        const SizedBox(height: 24),

        // Section: Address
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildProfileSectionHeader('Address details')),
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
              icon: const Icon(Icons.settings, color: Colors.cyanAccent, size: 14),
              label: const Text('Manage', style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (addresses == null || addresses.isEmpty)
          _buildDetailCard([
            _buildDetailRow('Complete Address', 'N/A', Icons.location_on_outlined),
          ])
        else
          ...addresses.map((addr) {
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
                  isDefault ? Icons.stars : Icons.location_on_outlined,
                  valueColor: isDefault ? Colors.cyanAccent : Colors.white70,
                ),
              ]),
            );
          }),
        const SizedBox(height: 24),

        // Section: Documents
        _buildProfileSectionHeader('Verification Documents'),
        const SizedBox(height: 16),
        _buildDocumentPreview('Payment QR Code', qrPath),
        const SizedBox(height: 16),
        _buildDocumentPreview('Business Registration Document', docPath),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProfileSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.08))),
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
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white.withOpacity(0.02),
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 40),
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No Document Uploaded', style: TextStyle(color: Colors.white24, fontSize: 13)),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: rows.expand((r) => [r, const Divider(color: Colors.white10, height: 16)]).toList()..removeLast(),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: valueColor ?? Colors.white.withOpacity(0.4), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: valueColor?.withOpacity(0.7) ?? Colors.white.withOpacity(0.5), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'N/A' : value,
                style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0x8AFFFFFF), size: 16),
          ],
        ),
      ),
    );
  }
}
