import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'category_list_screen.dart';
import 'brand_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _userDetails;
  bool _isLoading = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Load details from local session first
    final details = await SessionService.getUserDetails();
    if (details != null) {
      setState(() {
        _userDetails = details;
      });
    }

    // 2. Fetch fresh details from the API to stay synchronized
    final token = await SessionService.getToken();
    if (details != null && details['id'] != null && token != null && token != 'offline_placeholder_token') {
      try {
        final id = details['id'] as int;
        final response = await ApiService.fetchVendorById(id, token);
        if (response['code'] == 200 && response['data'] != null) {
          final freshUser = response['data'] as Map<String, dynamic>;
          await SessionService.saveSession(token, freshUser);
          if (mounted) {
            setState(() {
              _userDetails = freshUser;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading fresh profile: $e');
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

    // Extract address details
    String addressText = 'N/A';
    String addressType = 'Shop';
    final addresses = _userDetails?['addresses'] as List<dynamic>?;
    if (addresses != null && addresses.isNotEmpty) {
      final addr = addresses[0] as Map<String, dynamic>;
      addressType = addr['address_type'] ?? 'Shop';
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
      if (parts.isNotEmpty) {
        addressText = parts.join(', ');
      }
    }

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
                    : _buildProfileTab(name, ownerName, position, mobile, email, gender, dob, upi, gst, pan, addressType, addressText, avatarPath, qrPath, docPath),
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

        // Statistics Header
        const Text(
          'Sales Performance',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
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
            _buildStatCard('Total Sales', '₹45,230', Icons.currency_rupee, Colors.greenAccent),
            _buildStatCard('Orders', '189', Icons.shopping_bag, Colors.blueAccent),
            _buildStatCard('Products', '24', Icons.inventory_2, Colors.purpleAccent),
            _buildStatCard('Rating', '4.8 / 5', Icons.star, Colors.amberAccent),
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
    String addressType,
    String addressText,
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
        _buildProfileSectionHeader('Address details'),
        const SizedBox(height: 12),
        _buildDetailCard([
          _buildDetailRow('Address Type', addressType, Icons.home_work_outlined),
          _buildDetailRow('Complete Address', addressText, Icons.location_on_outlined),
        ]),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'N/A' : value,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
