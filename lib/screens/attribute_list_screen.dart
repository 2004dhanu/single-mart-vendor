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
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Manage Attributes',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
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
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 4 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isDesktop ? 2.2 : 1.4,
                              ),
                              itemCount: _filteredAttributes.length,
                              itemBuilder: (context, index) {
                                final attr = _filteredAttributes[index];
                                return _buildAttributeCard(attr);
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

  Widget _buildAttributeCard(Map<String, dynamic> attr) {
    final name = attr['attribute_name'] ?? 'N/A';
    final status = attr['attribute_status'] ?? 'Active';
    final isActive = status == 'Active';

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
            child: const Center(
              child: Icon(Icons.tune_rounded, color: Color(0xFFF97316), size: 24),
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
                const SizedBox(height: 8),
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
                          onChanged: (val) => _toggleAttributeStatus(attr, val),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
