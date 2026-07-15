import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({super.key});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _AddressDetailCard extends StatelessWidget {
  final Map<String, dynamic> addr;
  const _AddressDetailCard({required this.addr});

  @override
  Widget build(BuildContext context) {
    final type = addr['address_type']?.toString() ?? 'Shop';
    final isDefault = (addr['is_default'] == 1 || addr['is_default'] == '1');
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
    final addressText = parts.isEmpty ? 'N/A' : parts.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDefault ? Colors.cyanAccent.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type.toUpperCase(),
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              if (isDefault)
                const Text(
                  'DEFAULT',
                  style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(addressText, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
        ],
      ),
    );
  }
}

class _VendorListScreenState extends State<VendorListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  List<dynamic> _approvedVendors = [];
  List<dynamic> _pendingVendors = [];
  
  String? _approvedError;
  String? _pendingError;

  // Direct approve state
  final _directApproveController = TextEditingController();
  bool _directApproving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVendors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _directApproveController.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    setState(() {
      _isLoading = true;
      _approvedError = null;
      _pendingError = null;
    });

    final token = await SessionService.getToken();
    if (token == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // 1. Fetch Approved vendors list
    try {
      final approvedResp = await ApiService.fetchApprovedVendors(token);
      if (approvedResp['code'] == 200 && approvedResp['data'] != null) {
        _approvedVendors = approvedResp['data'] as List<dynamic>;
      } else {
        _approvedError = approvedResp['message']?.toString() ?? 'Failed to load approved vendors.';
      }
    } catch (e) {
      _approvedError = e.toString();
    }

    // 2. Fetch Pending vendors list
    try {
      final pendingResp = await ApiService.fetchPendingVendors(token);
      if (pendingResp['code'] == 200 && pendingResp['data'] != null) {
        _pendingVendors = pendingResp['data'] as List<dynamic>;
      } else {
        _pendingError = pendingResp['message']?.toString() ?? 'Failed to load pending vendors.';
      }
    } catch (e) {
      _pendingError = e.toString();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _approveVendorById(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final res = await ApiService.approveVendor(id, token);
      final code = res['code'] as int? ?? 500;
      if (code == 200 || code == 201 || res['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Vendor (ID $id) approved successfully!');
        _loadVendors();
      } else {
        _showSnackbar('Failed to approve vendor: ${res['message']}');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleVendorStatus(int id, String currentStatus) async {
    final nextStatus = currentStatus == 'Active' ? 'Inactive' : 'Active';
    
    // Optimistic status update in the UI
    setState(() {
      for (var v in _approvedVendors) {
        if (v['id'] == id) {
          v['status'] = nextStatus;
        }
      }
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final res = await ApiService.updateVendorStatus(id, nextStatus, token);
      final code = res['code'] as int? ?? 500;
      if (code == 200 || code == 201 || res['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Vendor status updated to $nextStatus.');
      } else {
        // Rollback
        setState(() {
          for (var v in _approvedVendors) {
            if (v['id'] == id) {
              v['status'] = currentStatus;
            }
          }
        });
        _showSnackbar('Failed to update status: ${res['message']}');
      }
    } catch (e) {
      // Rollback
      setState(() {
        for (var v in _approvedVendors) {
          if (v['id'] == id) {
            v['status'] = currentStatus;
          }
        }
      });
      _showSnackbar('Error: $e');
    }
  }

  Future<void> _directApprove() async {
    final text = _directApproveController.text.trim();
    if (text.isEmpty) return;

    final id = int.tryParse(text);
    if (id == null) {
      _showSnackbar('Please enter a valid numeric vendor ID.');
      return;
    }

    setState(() {
      _directApproving = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final res = await ApiService.approveVendor(id, token);
      final code = res['code'] as int? ?? 500;
      if (code == 200 || code == 201 || res['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Vendor $id approved successfully!');
        _directApproveController.clear();
        _loadVendors();
      } else {
        _showSnackbar(res['message']?.toString() ?? 'Approve failed.');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    } finally {
      setState(() {
        _directApproving = false;
      });
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _viewVendorDetails(Map<String, dynamic> summary) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: SessionService.getToken().then((token) => ApiService.fetchVendorById(summary['id'] as int, token!)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }
                
                final details = snapshot.data?['data'] as Map<String, dynamic>?;
                if (details == null) {
                  return _buildDetailsContent(summary, scrollController);
                }
                return _buildDetailsContent(details, scrollController);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsContent(Map<String, dynamic> vendor, ScrollController sc) {
    final name = vendor['name'] ?? 'N/A';
    final owner = vendor['owner_name'] ?? 'N/A';
    final mobile = vendor['mobile'] ?? 'N/A';
    final email = vendor['email'] ?? 'N/A';
    final gender = vendor['gender'] ?? 'N/A';
    final dob = vendor['dob'] ?? 'N/A';
    final status = vendor['status'] ?? 'Active';
    final upi = vendor['upi_id'] ?? 'N/A';
    final gst = vendor['gst_number'] ?? 'N/A';
    final pan = vendor['pan_number'] ?? 'N/A';
    
    final avatar = vendor['user_image']?.toString();
    final qr = vendor['qr_code']?.toString();
    final doc = vendor['business_document']?.toString();

    final addresses = vendor['addresses'] as List<dynamic>? ?? [];

    return ListView(
      controller: sc,
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 24),
        
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white10,
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage('https://agsdemo.in/singlemartapi/public/assets/images/user_images/$avatar')
                  : null,
              child: avatar == null || avatar.isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.cyanAccent)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(owner, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'Active' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: status == 'Active' ? Colors.green : Colors.red),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: status == 'Active' ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        _buildSectionTitle('Personal details'),
        const SizedBox(height: 12),
        _buildDetailRow('Mobile Number', mobile),
        _buildDetailRow('Email Address', email),
        _buildDetailRow('Gender', gender),
        _buildDetailRow('Date of Birth', dob),
        const SizedBox(height: 24),

        _buildSectionTitle('Business details'),
        const SizedBox(height: 12),
        _buildDetailRow('UPI ID', upi),
        _buildDetailRow('GST Number', gst),
        _buildDetailRow('PAN Number', pan),
        const SizedBox(height: 24),

        _buildSectionTitle('Address list'),
        const SizedBox(height: 12),
        if (addresses.isEmpty)
          const Text('No addresses saved.', style: TextStyle(color: Colors.white38, fontSize: 13))
        else
          ...addresses.map((a) => _AddressDetailCard(addr: a as Map<String, dynamic>)),
        const SizedBox(height: 24),

        _buildSectionTitle('Documents & Codes'),
        const SizedBox(height: 16),
        _buildDocumentBox('Payment QR Code', qr),
        const SizedBox(height: 16),
        _buildDocumentBox('Business Document', doc),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: Colors.white10)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentBox(String title, String? filename) {
    final hasFile = filename != null && filename.isNotEmpty;
    final imageUrl = hasFile
        ? 'https://agsdemo.in/singlemartapi/public/assets/images/user_images/$filename'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: hasFile
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Document Image Link Offline', style: TextStyle(color: Colors.white30, fontSize: 12)),
                    ),
                  ),
                )
              : const Center(
                  child: Icon(Icons.description_outlined, color: Colors.white24, size: 36),
                ),
        ),
      ],
    );
  }

  Widget _buildApprovedTab() {
    if (_approvedVendors.isEmpty) {
      if (_approvedError != null) {
        return _buildErrorState('Approved List Error', _approvedError!);
      }
      return const Center(child: Text('No approved vendors found.', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _approvedVendors.length,
      itemBuilder: (context, index) {
        final vendor = _approvedVendors[index] as Map<String, dynamic>;
        final id = vendor['id'] as int;
        final name = vendor['name'] ?? 'Vendor ${vendor['id']}';
        final mobile = vendor['mobile'] ?? 'N/A';
        final status = vendor['status'] ?? 'Active';
        final isActive = status == 'Active';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                child: const Icon(Icons.storefront, color: Colors.blueAccent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $id | Mobile: $mobile',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        status,
                        style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: isActive,
                        activeColor: Colors.greenAccent,
                        inactiveThumbColor: Colors.redAccent,
                        onChanged: (_) => _toggleVendorStatus(id, status),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _viewVendorDetails(vendor),
                    child: const Text('View Profile', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _directApproveController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Approve Vendor by ID (e.g. 9)',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              _directApproving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _directApprove,
                      child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),

        Expanded(
          child: _pendingVendors.isEmpty
              ? (_pendingError != null
                  ? _buildErrorState('Pending List Error', _pendingError!)
                  : const Center(child: Text('No pending approval requests.', style: TextStyle(color: Colors.white54))))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pendingVendors.length,
                  itemBuilder: (context, index) {
                    final vendor = _pendingVendors[index] as Map<String, dynamic>;
                    final id = vendor['id'] as int;
                    final name = vendor['name'] ?? 'Vendor $id';
                    final mobile = vendor['mobile'] ?? 'N/A';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                            child: const Icon(Icons.pending_actions_rounded, color: Colors.orangeAccent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $id | Mobile: $mobile',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _approveVendorById(id),
                                child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              TextButton(
                                onPressed: () => _viewVendorDetails(vendor),
                                child: const Text('View Profile', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String title, String error) {
    final showTracebackMsg = error.contains('getCollection') || error.contains('Collection');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bug_report_outlined, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            if (showTracebackMsg) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.yellowAccent.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'This is a backend server bug (UserController.php). You can still approve vendors by entering their ID in the input box above.',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text(
          'Vendor Registrations',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: _loadVendors,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Approved'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApprovedTab(),
                _buildPendingTab(),
              ],
            ),
    );
  }
}
