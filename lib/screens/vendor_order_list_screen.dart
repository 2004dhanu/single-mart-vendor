import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class VendorOrderListScreen extends StatefulWidget {
  const VendorOrderListScreen({super.key});

  @override
  State<VendorOrderListScreen> createState() => _VendorOrderListScreenState();
}

class _VendorOrderListScreenState extends State<VendorOrderListScreen> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  List<String> _orderStatuses = [];
  int? _vendorId;
  String _searchQuery = '';
  
  final List<String> _paymentStatuses = ['Pending', 'Received', 'Cancel'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadOrderStatusList() async {
    try {
      final res = await ApiService.fetchOrderStatus();
      if (res['data'] != null) {
        final list = res['data'] as List<dynamic>;
        setState(() {
          _orderStatuses = list.map((item) => item['orderStatus']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading status list: $e');
    }

    if (_orderStatuses.isEmpty) {
      // Fallback defaults
      _orderStatuses = [
        'Pending',
        'Confirmed',
        'Processing',
        'Packed',
        'Shipped',
        'Out for Delivery',
        'Delivered',
        'Cancelled',
        'Returned',
        'Refunded'
      ];
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    await _loadOrderStatusList();

    try {
      final details = await SessionService.getUserDetails();
      if (details != null && details['id'] != null) {
        _vendorId = int.tryParse(details['id'].toString());
      }

      final token = await SessionService.getToken();
      if (token != null && _vendorId != null) {
        final res = await ApiService.fetchOrders(token);
        if (res['data'] != null) {
          final allOrders = res['data'] as List<dynamic>;
          
          // Filter orders to only keep ones containing items of this vendor
          final vendorOrders = <dynamic>[];
          for (var ord in allOrders) {
            final subs = ord['subs'] as List<dynamic>? ?? [];
            final mySubs = subs.where((s) => s['order_vendor_id']?.toString() == _vendorId.toString()).toList();
            if (mySubs.isNotEmpty) {
              // Copy order map and override subs with only this vendor's sub-items
              final orderCopy = Map<String, dynamic>.from(ord);
              orderCopy['subs'] = mySubs;
              vendorOrders.add(orderCopy);
            }
          }
          
          setState(() {
            _orders = vendorOrders;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
      _showSnackbar('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePaymentStatus(int subId, String status) async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final res = await ApiService.updateOrderPaymentStatus(subId, status, token);
      final code = res['code'] as int? ?? 500;
      if (code == 200 || code == 201 || res['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Payment status updated successfully!');
        _loadInitialData(); // Refresh list to get fresh server calculations/data
      } else {
        _showSnackbar('Update failed: ${res['message']}');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    }
  }

  Future<void> _updateOrderStatus(int subId, String status) async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final res = await ApiService.updateOrderStatus(subId, status, token);
      final code = res['code'] as int? ?? 500;
      if (code == 200 || code == 201 || res['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Order status updated successfully!');
        _loadInitialData(); // Refresh list
      } else {
        _showSnackbar('Update failed: ${res['message']}');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  double _calculateVendorTotal(List<dynamic> subs) {
    double total = 0.0;
    for (var item in subs) {
      final amountStr = item['order_amount']?.toString() ?? '0.00';
      total += double.tryParse(amountStr) ?? 0.0;
    }
    return total;
  }

  void _viewOrderDetails(Map<String, dynamic> summary) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollController) {
                return FutureBuilder<Map<String, dynamic>>(
                  future: SessionService.getToken().then((token) => ApiService.fetchOrderById(summary['id'] as int, token!)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: const Color(0xFFF97316)));
                    }
                    
                    final fullData = snapshot.data?['data'] as Map<String, dynamic>?;
                    final order = fullData ?? summary;
                    final subs = order['subs'] as List<dynamic>? ?? [];
                    final mySubs = subs.where((s) => s['order_vendor_id']?.toString() == _vendorId.toString()).toList();

                    final orderRef = order['order_ref'] ?? 'N/A';
                    final date = order['order_date'] ?? 'N/A';
                    final userName = order['user_name'] ?? 'N/A';
                    final mobile = order['user_mobile'] ?? 'N/A';
                    final email = order['user_email'] ?? 'N/A';
                    final address = order['order_address']?.toString() ?? 'N/A';

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title / Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderRef,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ordered: $date',
                                  style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.5), fontSize: 12),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹${_calculateVendorTotal(mySubs).toStringAsFixed(2)}',
                                style: const TextStyle(color: const Color(0xFFF97316), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Customer Details
                        _buildSectionTitle('Customer Information'),
                        const SizedBox(height: 12),
                        _buildDetailRow('Name', userName),
                        _buildDetailRow('Mobile Number', mobile),
                        _buildDetailRow('Email Address', email),
                        _buildDetailRow('Delivery Address', address.replaceAll('"', '')),
                        const SizedBox(height: 24),

                        // Items
                        _buildSectionTitle('Ordered items'),
                        const SizedBox(height: 12),
                        ...mySubs.map((item) {
                          final subId = item['id'] as int;
                          final prodName = item['product_name'] ?? 'Product';
                          final quantity = item['order_quantity']?.toString() ?? '1';
                          final price = item['order_price']?.toString() ?? '0.00';
                          final discPrice = item['order_discount_price']?.toString() ?? '0.00';
                          final amount = item['order_amount']?.toString() ?? '0.00';
                          final payStatus = item['payment_status']?.toString() ?? 'Pending';
                          final ordStatus = item['order_status']?.toString() ?? 'Pending';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prodName,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                if (item['variant_attributes'] != null && (item['variant_attributes'] as List<dynamic>).isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: (item['variant_attributes'] as List<dynamic>).map((attr) {
                                      final attrName = attr['attribute_name'] ?? '';
                                      final attrVal = attr['attribute_value'] ?? '';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF97316).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          '$attrName: $attrVal',
                                          style: const TextStyle(color: const Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.w500),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Quantity: $quantity', style: const TextStyle(color: const Color(0xFF475569), fontSize: 12)),
                                    Text('Price: ₹$price', style: const TextStyle(color: const Color(0xFF475569), fontSize: 12)),
                                    Text('Amount: ₹$amount', style: const TextStyle(color: const Color(0xFFF97316), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (item['order_payment_utr_no'] != null && item['order_payment_utr_no'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('UTR Number', style: TextStyle(color: const Color(0xFF475569), fontSize: 12)),
                                      SelectableText(
                                        item['order_payment_utr_no'].toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                                if (item['order_payment_screenshot'] != null && item['order_payment_screenshot'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text('Payment Screenshot', style: TextStyle(color: const Color(0xFF475569), fontSize: 12)),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          insetPadding: const EdgeInsets.all(16),
                                          child: Stack(
                                            alignment: Alignment.topRight,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: InteractiveViewer(
                                                  child: Image.network(
                                                    'https://agsdemo.in/singlemartapi/public/assets/images/payment_images/${item['order_payment_screenshot']}',
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        color: const Color(0xFF1E293B),
                                                        height: 200,
                                                        width: double.infinity,
                                                        child: const Center(
                                                          child: Text(
                                                            'Failed to load screenshot image',
                                                            style: TextStyle(color: Colors.redAccent),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 8,
                                                top: 8,
                                                child: CircleAvatar(
                                                  backgroundColor: Colors.black54,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.close, color: const Color(0xFF0F172A)),
                                                    onPressed: () => Navigator.pop(context),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        height: 120,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              'https://agsdemo.in/singlemartapi/public/assets/images/payment_images/${item['order_payment_screenshot']}',
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: const Color(0xFF1E293B),
                                                  child: const Center(
                                                    child: Icon(Icons.image_not_supported_rounded, color: const Color(0xFFCBD5E1), size: 36),
                                                  ),
                                                );
                                              },
                                            ),
                                            Container(
                                              color: Colors.black.withOpacity(0.4),
                                              child: const Center(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.zoom_in, color: const Color(0xFFF97316), size: 20),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Tap to View Screenshot',
                                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Divider(color: const Color(0xFFE2E8F0)),
                                const SizedBox(height: 8),

                                // Status Dropdowns
                                Row(
                                  children: [
                                    // Order Status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('ORDER STATUS', style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 9, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: _orderStatuses.contains(ordStatus) ? ordStatus : _orderStatuses.first,
                                                dropdownColor: const Color(0xFF1E293B),
                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                                isExpanded: true,
                                                icon: const Icon(Icons.arrow_drop_down, color: const Color(0xFFF97316), size: 18),
                                                items: _orderStatuses.map((String val) {
                                                  return DropdownMenuItem<String>(
                                                    value: val,
                                                    child: Text(val),
                                                  );
                                                }).toList(),
                                                onChanged: (newVal) async {
                                                  if (newVal != null) {
                                                    setModalState(() {
                                                      item['order_status'] = newVal;
                                                    });
                                                    await _updateOrderStatus(subId, newVal);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Payment Status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('PAYMENT STATUS', style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 9, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: _paymentStatuses.contains(payStatus) ? payStatus : _paymentStatuses.first,
                                                dropdownColor: const Color(0xFF1E293B),
                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                                isExpanded: true,
                                                icon: const Icon(Icons.arrow_drop_down, color: const Color(0xFFF97316), size: 18),
                                                items: _paymentStatuses.map((String val) {
                                                  return DropdownMenuItem<String>(
                                                    value: val,
                                                    child: Text(val),
                                                  );
                                                }).toList(),
                                                onChanged: (newVal) async {
                                                  if (newVal != null) {
                                                    setModalState(() {
                                                      item['payment_status'] = newVal;
                                                    });
                                                    await _updatePaymentStatus(subId, newVal);
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: const Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: const Color(0xFFE2E8F0))),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.5), fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    final filtered = _orders.where((ord) {
      final ref = ord['order_ref']?.toString().toLowerCase() ?? '';
      final cust = ord['user_name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return ref.contains(query) || cust.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Customer Orders',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFF97316)),
            onPressed: _loadInitialData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFFF8FAFC),
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search by Order Ref or Customer...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFF97316)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No orders found.', style: TextStyle(color: Color(0xFF475569))))
                          : isDesktop
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 2.5,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final ord = filtered[index] as Map<String, dynamic>;
                                    return _buildOrderCard(ord);
                                  },
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final ord = filtered[index] as Map<String, dynamic>;
                                    return _buildOrderCard(ord);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> ord) {
    final ref = ord['order_ref'] ?? 'N/A';
    final date = ord['order_date'] ?? 'N/A';
    final customer = ord['user_name'] ?? 'N/A';
    final subs = ord['subs'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFF97316).withOpacity(0.1),
            child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFFF97316), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ref,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: $customer',
                  style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Date: $date | Items: ${subs.length}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹${_calculateVendorTotal(subs).toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF16A34A), fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFF97316),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: const Color(0xFFF97316).withOpacity(0.2)),
                  ),
                ),
                onPressed: () => _viewOrderDetails(ord),
                child: const Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
