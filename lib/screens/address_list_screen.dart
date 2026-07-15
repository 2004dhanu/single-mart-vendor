import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'address_form_screen.dart';

class AddressListScreen extends StatefulWidget {
  final Map<String, dynamic> userDetails;

  const AddressListScreen({super.key, required this.userDetails});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  bool _isLoading = false;
  List<dynamic> _addresses = [];
  late Map<String, dynamic> _userDetailsState;

  @override
  void initState() {
    super.initState();
    _userDetailsState = widget.userDetails;
    _addresses = _userDetailsState['addresses'] as List<dynamic>? ?? [];
  }

  Future<void> _refreshUserDetails() async {
    final token = await SessionService.getToken();
    final userId = _userDetailsState['id'] as int?;
    if (token == null || userId == null) return;

    try {
      final response = await ApiService.fetchVendorById(userId, token);
      if (response['code'] == 200 && response['data'] != null) {
        final freshUser = response['data'] as Map<String, dynamic>;
        await SessionService.saveSession(token, freshUser);
        if (mounted) {
          setState(() {
            _userDetailsState = freshUser;
            _addresses = freshUser['addresses'] as List<dynamic>? ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Silent background refresh error: $e');
    }
  }

  Future<void> _setDefaultAddress(int selectedIndex) async {
    // 1. Optimistic UI update: update local list immediately
    final List<dynamic> originalAddresses = List<dynamic>.from(_addresses);
    setState(() {
      for (int i = 0; i < _addresses.length; i++) {
        final addr = Map<String, dynamic>.from(_addresses[i] as Map);
        addr['is_default'] = (i == selectedIndex) ? 1 : 0;
        _addresses[i] = addr;
      }
    });

    try {
      final token = await SessionService.getToken();
      final userId = _userDetailsState['id'] as int?;
      if (token == null || userId == null) {
        setState(() {
          _addresses = originalAddresses;
        });
        return;
      }

      // Compile current user profile fields
      final Map<String, String> fields = {
        'name': _userDetailsState['name']?.toString() ?? '',
        'owner_name': _userDetailsState['owner_name']?.toString() ?? '',
        'mobile': _userDetailsState['mobile']?.toString() ?? '',
        'email': _userDetailsState['email']?.toString() ?? '',
        'gender': (_userDetailsState['gender']?.toString() ?? 'male').toLowerCase(),
        'dob': _userDetailsState['dob']?.toString() ?? '',
        'upi_id': _userDetailsState['upi_id']?.toString() ?? '',
        'gst_number': _userDetailsState['gst_number']?.toString() ?? '',
        'pan_number': _userDetailsState['pan_number']?.toString() ?? '',
        'user_type': _userDetailsState['user_type']?.toString() ?? '2',
        'user_position': _userDetailsState['user_position']?.toString() ?? 'Vendor',
        'status': _userDetailsState['status']?.toString() ?? 'Active',
      };

      // Set the clicked address to 1, and all others to 0
      for (int i = 0; i < _addresses.length; i++) {
        final addr = _addresses[i] as Map<String, dynamic>;
        final isDefaultVal = i == selectedIndex ? '1' : '0';

        fields['addresses[$i][id]'] = addr['id']?.toString() ?? '';
        fields['addresses[$i][address_line_1]'] = addr['address_line_1']?.toString() ?? '';
        fields['addresses[$i][address_line_2]'] = addr['address_line_2']?.toString() ?? '';
        fields['addresses[$i][landmark]'] = addr['landmark']?.toString() ?? '';
        fields['addresses[$i][city]'] = addr['city']?.toString() ?? '';
        fields['addresses[$i][district]'] = addr['district']?.toString() ?? '';
        fields['addresses[$i][state]'] = addr['state']?.toString() ?? '';
        fields['addresses[$i][country]'] = addr['country']?.toString() ?? '';
        fields['addresses[$i][pincode]'] = addr['pincode']?.toString() ?? '';
        fields['addresses[$i][address_type]'] = addr['address_type']?.toString() ?? 'Shop';
        fields['addresses[$i][is_default]'] = isDefaultVal;
      }

      final response = await ApiService.updateVendor(
        id: userId,
        token: token,
        fields: fields,
        files: {},
      );

      final code = response['code'] as int? ?? 500;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Default address updated!');
        await _refreshUserDetails();
      } else {
        setState(() {
          _addresses = originalAddresses;
        });
        _showSnackbar('Failed to update: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        _addresses = originalAddresses;
      });
      _showSnackbar('Error updating default address: $e');
    }
  }

  Future<void> _deleteAddress(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Delete Address', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this address?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1. Optimistic UI update: remove deleted item immediately
    final List<dynamic> originalAddresses = List<dynamic>.from(_addresses);
    setState(() {
      _addresses.removeWhere((addr) => addr['id'] == id);
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        setState(() {
          _addresses = originalAddresses;
        });
        return;
      }

      final response = await ApiService.deleteAddress(id: id, token: token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Address deleted successfully!');
        await _refreshUserDetails();
      } else {
        setState(() {
          _addresses = originalAddresses;
        });
        _showSnackbar(response['message']?.toString() ?? 'Failed to delete address.');
      }
    } catch (e) {
      setState(() {
        _addresses = originalAddresses;
      });
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatAddress(Map<String, dynamic> addr) {
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
    return parts.isEmpty ? 'N/A' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text(
          'Manage Addresses',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.cyanAccent, size: 28),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddressFormScreen(
                    userDetails: _userDetailsState,
                    addressesList: _addresses,
                  ),
                ),
              );
              if (result is List<dynamic>) {
                setState(() {
                  _addresses = result;
                });
                _refreshUserDetails();
              } else if (result == true) {
                _refreshUserDetails();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off_outlined, color: Colors.white.withOpacity(0.2), size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'No addresses saved.',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final addr = _addresses[index] as Map<String, dynamic>;
                    final addrId = addr['id'] as int?;
                    final isDefault = (addr['is_default'] == 1 || addr['is_default'] == '1');
                    final type = addr['address_type']?.toString() ?? 'Shop';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDefault ? Colors.cyanAccent.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      type.toLowerCase() == 'home'
                                          ? Icons.home_outlined
                                          : type.toLowerCase() == 'work'
                                              ? Icons.work_outline
                                              : Icons.storefront_outlined,
                                      color: Colors.cyanAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      type.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purpleAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      color: Colors.purpleAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _formatAddress(addr),
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!isDefault)
                                TextButton.icon(
                                  onPressed: () => _setDefaultAddress(index),
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.purpleAccent, size: 18),
                                  label: const Text(
                                    'Set Default',
                                    style: TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddressFormScreen(
                                        userDetails: _userDetailsState,
                                        addressesList: _addresses,
                                        addressToEdit: addr,
                                      ),
                                    ),
                                  );
                                  if (result is List<dynamic>) {
                                    setState(() {
                                      _addresses = result;
                                    });
                                    _refreshUserDetails();
                                  } else if (result == true) {
                                    _refreshUserDetails();
                                  }
                                },
                              ),
                              if (addrId != null)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteAddress(addrId),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
