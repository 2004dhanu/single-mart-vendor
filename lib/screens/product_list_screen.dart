import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired. Please log in again.');
        return;
      }

      final response = await ApiService.fetchProducts(token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 && response['data'] != null) {
        setState(() {
          _products = response['data'] as List<dynamic>;
          _filteredProducts = List.from(_brandsFilterWorkaround(_products));
        });
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to load products');
      }
    } catch (e) {
      _showSnackbar('Error loading products: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> _brandsFilterWorkaround(List<dynamic> list) {
    return list;
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final name = product['product_name']?.toString().toLowerCase() ?? '';
        final description = product['product_short_description']?.toString().toLowerCase() ?? '';
        return name.contains(query) || description.contains(query);
      }).toList();
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resolveProductImageUrl(String? path, {bool isVariant = false}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final subDir = isVariant ? 'product_variant_images' : 'product_images';
    return 'https://agsdemo.in/singlemartapi/public/assets/images/$subDir/$path';
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['product_name']?.toString() ?? 'Unnamed Product';
    final desc = product['product_short_description']?.toString() ?? '';
    
    final hasVariants = product['has_variants'] == 1 || product['has_variants']?.toString() == '1';
    double price = 0.0;
    double discountPrice = 0.0;
    int qty = 0;

    if (hasVariants) {
      final variants = product['variants'] as List<dynamic>? ?? [];
      if (variants.isNotEmpty) {
        double minPrice = double.maxFinite;
        double minDiscountPrice = double.maxFinite;
        int sumQty = 0;
        for (var v in variants) {
          final vp = double.tryParse(v['product_price']?.toString() ?? '') ?? 0.0;
          final vdp = double.tryParse(v['product_discount_price']?.toString() ?? '') ?? 0.0;
          final vq = int.tryParse(v['product_quantity']?.toString() ?? '') ?? 0;
          sumQty += vq;
          if (vp < minPrice) {
            minPrice = vp;
          }
          if (vdp > 0 && vdp < minDiscountPrice) {
            minDiscountPrice = vdp;
          }
        }
        price = minPrice == double.maxFinite ? 0.0 : minPrice;
        discountPrice = minDiscountPrice == double.maxFinite ? 0.0 : minDiscountPrice;
        qty = sumQty;
      }
    } else {
      price = double.tryParse(product['product_price']?.toString() ?? '') ?? 0.0;
      discountPrice = double.tryParse(product['product_discount_price']?.toString() ?? '') ?? 0.0;
      qty = int.tryParse(product['product_quantity']?.toString() ?? '') ?? 0;
    }

    String? thumbPath;
    bool isVariantThumb = false;
    final imagesList = product['images'] as List<dynamic>? ?? [];
    if (imagesList.isNotEmpty) {
      thumbPath = imagesList.first['product_images'] as String?;
    } else if (hasVariants) {
      final variants = product['variants'] as List<dynamic>? ?? [];
      for (var v in variants) {
        final vImgs = v['images'] as List<dynamic>? ?? [];
        if (vImgs.isNotEmpty) {
          thumbPath = vImgs.first['product_variant_images'] as String?;
          isVariantThumb = true;
          break;
        }
      }
    }

    final hasDiscount = discountPrice > 0.0 && discountPrice < price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: thumbPath != null && thumbPath.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(_resolveProductImageUrl(thumbPath, isVariant: isVariantThumb), fit: BoxFit.cover),
                )
              : const Icon(Icons.image_outlined, color: const Color(0xFFCBD5E1), size: 28),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: const Color(0xFF475569), fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasDiscount) ...[
                  Text(
                    '₹${discountPrice.toStringAsFixed(0)}',
                    style: const TextStyle(color: const Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ] else ...[
                  Text(
                    '₹${price.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: qty > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    qty > 0 ? '$qty in stock' : 'Out of stock',
                    style: TextStyle(
                      color: qty > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, color: Color(0xFF475569)),
          onPressed: () async {
            setState(() {
              _isLoading = true;
            });
            try {
              final token = await SessionService.getToken();
              if (token != null) {
                final detailResp = await ApiService.fetchProductById(product['id'] as int, token);
                if (detailResp['data'] != null) {
                  final fullProduct = detailResp['data'] as Map<String, dynamic>;
                  if (mounted) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(product: fullProduct),
                      ),
                    );
                    if (result == true) {
                      _loadProducts();
                    }
                  }
                } else {
                  _showSnackbar('Failed to load product details for editing.');
                }
              }
            } catch (e) {
              _showSnackbar('Error loading product: $e');
            } finally {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
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
          'Products Management',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFFF97316), size: 28),
            tooltip: 'Add Product',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              );
              if (result == true) {
                _loadProducts();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
          child: Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF475569)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF97316)),
                    ),
                  ),
                ),
              ),

              // Main List / Loader
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
                    : _filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: Color(0xFFCBD5E1), size: 64),
                                const SizedBox(height: 16),
                                const Text(
                                  'No products found',
                                  style: TextStyle(color: Color(0xFF475569), fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadProducts,
                            color: const Color(0xFFF97316),
                            backgroundColor: Colors.white,
                            child: isDesktop
                                ? GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 2.8,
                                    ),
                                    itemCount: _filteredProducts.length,
                                    itemBuilder: (context, index) {
                                      final product = _filteredProducts[index] as Map<String, dynamic>;
                                      return _buildProductCard(product);
                                    },
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    itemCount: _filteredProducts.length,
                                    itemBuilder: (context, index) {
                                      final product = _filteredProducts[index] as Map<String, dynamic>;
                                      return _buildProductCard(product);
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
}
