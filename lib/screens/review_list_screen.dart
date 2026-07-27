import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({super.key});

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  List<dynamic> _reviews = [];
  List<dynamic> _filteredReviews = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _searchController.addListener(_filterReviews);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired. Please log in again.');
        return;
      }

      final response = await ApiService.fetchProductReviews(token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 && response['data'] != null) {
        setState(() {
          _reviews = response['data'] as List<dynamic>;
          _filteredReviews = List.from(_reviews);
        });
      } else {
        setState(() {
          _reviews = [];
          _filteredReviews = [];
        });
      }
    } catch (e) {
      _showSnackbar('Error loading reviews: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterReviews() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReviews = _reviews.where((review) {
        final productName = review['product_name']?.toString().toLowerCase() ?? '';
        final customerName = review['customer_name']?.toString().toLowerCase() ?? '';
        final reviewText = review['product_review']?.toString().toLowerCase() ?? '';
        return productName.contains(query) ||
            customerName.contains(query) ||
            reviewText.contains(query);
      }).toList();
    });
  }

  Future<void> _deleteReview(int id) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Review', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to permanently delete this product review?',
          style: TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistic UI update
    setState(() {
      _filteredReviews.removeWhere((r) => r['id'] == id);
      _reviews.removeWhere((r) => r['id'] == id);
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired.');
        _loadReviews();
        return;
      }

      final response = await ApiService.deleteProductReview(id, token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Review deleted successfully');
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to delete review');
        _loadReviews();
      }
    } catch (e) {
      _showSnackbar('Error: $e');
      _loadReviews();
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

  Widget _buildStars(String? ratingStr) {
    final rating = int.tryParse(ratingStr ?? '5') ?? 5;
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.amberAccent,
          size: 18,
        );
      }),
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
          'Product Reviews',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search product, customer, or comment...',
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

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: const Color(0xFFF97316)))
                    : _filteredReviews.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rate_review_outlined, size: 64, color: const Color(0xFF0F172A).withOpacity(0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  'No reviews found',
                                  style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReviews,
                            color: const Color(0xFFF97316),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredReviews.length,
                              itemBuilder: (context, index) {
                                final review = _filteredReviews[index];
                                final id = review['id'] as int;
                                final prodName = review['product_name'] ?? 'Product';
                                final customerName = review['customer_name'] ?? 'Customer';
                                final date = review['product_rating_date'] ?? 'N/A';
                                final reviewText = review['product_review'] ?? '';
                                final rating = review['product_rating']?.toString() ?? '5';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prodName,
                                              style: const TextStyle(
                                                color: const Color(0xFFF97316),
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            onPressed: () => _deleteReview(id),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'By $customerName',
                                            style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.6), fontSize: 13),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A).withOpacity(0.3),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            date,
                                            style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildStars(rating),
                                      if (reviewText.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          reviewText,
                                          style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.87), fontSize: 14),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
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
