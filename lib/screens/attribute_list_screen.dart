import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'attribute_form_screen.dart';

class AttributeListScreen extends StatefulWidget {
  const AttributeListScreen({super.key});

  @override
  State<AttributeListScreen> createState() => _AttributeListScreenState();
}

class _AttributeListScreenState extends State<AttributeListScreen> {
  List<dynamic> _attributes = [];
  List<dynamic> _filteredAttributes = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAttributes();
    _searchController.addListener(_filterAttributes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAttributes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired. Please log in again.');
        return;
      }

      final response = await ApiService.fetchAttributes(token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 && response['data'] != null) {
        final rawAttributes = response['data'] as List<dynamic>;

        final details = await SessionService.getUserDetails();
        final isAdmin = details?['user_type'] == 3 || details?['user_position'] == 'Admin';
        final vendorName = details?['name']?.toString() ?? '';
        final ownerName = details?['owner_name']?.toString() ?? '';

        List<dynamic> filtered = [];
        if (isAdmin) {
          filtered = rawAttributes;
        } else {
          final futures = rawAttributes.map((attr) async {
            try {
              final id = attr['id'] as int;
              final detailRes = await ApiService.fetchAttributeById(id, token);
              if (detailRes['data'] != null) {
                final createdBy = detailRes['data']['created_by']?.toString().toLowerCase();
                if (createdBy == vendorName.toLowerCase() || createdBy == ownerName.toLowerCase()) {
                  return attr;
                }
              }
            } catch (_) {}
            return null;
          });
          final results = await Future.wait(futures);
          filtered = results.where((a) => a != null).toList();
        }

        setState(() {
          _attributes = filtered;
          _filteredAttributes = List.from(_attributes);
        });
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to load attributes');
      }
    } catch (e) {
      _showSnackbar('Error loading attributes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterAttributes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAttributes = _attributes.where((attr) {
        final name = attr['attribute_name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _toggleAttributeStatus(Map<String, dynamic> attr, bool newStatusVal) async {
    final id = attr['id'] as int;
    final newStatusString = newStatusVal ? 'Active' : 'Inactive';
    final oldStatusString = attr['attribute_status']?.toString() ?? 'Active';

    // Optimistic UI update
    setState(() {
      attr['attribute_status'] = newStatusString;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired.');
        setState(() {
          attr['attribute_status'] = oldStatusString;
        });
        return;
      }

      final response = await ApiService.updateAttributeStatus(
        id: id,
        token: token,
        status: newStatusString,
      );

      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Attribute status updated successfully');
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to update status');
        setState(() {
          attr['attribute_status'] = oldStatusString;
        });
      }
    } catch (e) {
      _showSnackbar('Error: $e');
      setState(() {
        attr['attribute_status'] = oldStatusString;
      });
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Manage Attributes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search Bar & Add Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search attributes...',
                      hintStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4)),
                      prefixIcon: const Icon(Icons.search, color: const Color(0xFFF97316)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [const Color(0xFFF97316), const Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttributeFormScreen()),
                      );
                      if (result == true) {
                        _loadAttributes();
                      }
                    },
                    child: const Icon(Icons.add, color: Colors.black, size: 24),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: const Color(0xFFF97316)))
                : _filteredAttributes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tune_rounded, size: 64, color: const Color(0xFF0F172A).withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text(
                              'No attributes found',
                              style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAttributes,
                        color: const Color(0xFFF97316),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredAttributes.length,
                          itemBuilder: (context, index) {
                            final attr = _filteredAttributes[index];
                            final id = attr['id'] as int;
                            final name = attr['attribute_name'] ?? 'N/A';
                            final status = attr['attribute_status'] ?? 'Active';
                            final isActive = status == 'Active';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFF97316).withOpacity(0.1),
                                    child: const Icon(Icons.tune_rounded, color: const Color(0xFFF97316)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            color: isActive ? Colors.greenAccent : Colors.redAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isActive,
                                    activeColor: const Color(0xFFF97316),
                                    activeTrackColor: const Color(0xFFF97316).withOpacity(0.2),
                                    inactiveThumbColor: const Color(0xFFCBD5E1),
                                    inactiveTrackColor: const Color(0xFFE2E8F0),
                                    onChanged: (val) => _toggleAttributeStatus(attr, val),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: const Color(0xFF334155)),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AttributeFormScreen(attribute: attr),
                                        ),
                                      );
                                      if (result == true) {
                                        _loadAttributes();
                                      }
                                    },
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
