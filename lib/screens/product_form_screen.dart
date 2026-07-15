import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product; // Null if creating

  const ProductFormScreen({super.key, this.brand, this.product});

  // Adding compatibility field just in case
  final Map<String, dynamic>? brand;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditMode = false;

  // Fields controllers
  final _nameController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _quantityController = TextEditingController();

  // Dropdown lists
  List<dynamic> _categories = [];
  List<dynamic> _allSubcategories = [];
  List<dynamic> _filteredSubcategories = [];
  List<dynamic> _brands = [];

  // Selected dropdown values
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  int? _selectedBrandId;

  // Images list
  final List<ProductImageInput> _images = [];
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.product != null;
    _initializeForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortDescController.dispose();
    _longDescController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _quantityController.dispose();
    for (var img in _images) {
      img.sortOrderController.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeForm() async {
    await _loadDropdownData();

    if (_isEditMode) {
      final p = widget.product!;
      _nameController.text = p['product_name']?.toString() ?? '';
      _shortDescController.text = p['product_short_description']?.toString() ?? '';
      _longDescController.text = p['product_long_description']?.toString() ?? '';
      _priceController.text = p['product_price']?.toString() ?? '';
      _discountPriceController.text = p['product_discount_price']?.toString() ?? '';
      _quantityController.text = p['product_quantity']?.toString() ?? '';

      // Parse selection IDs safely
      _selectedCategoryId = int.tryParse(p['product_category_id']?.toString() ?? '');
      _selectedSubcategoryId = int.tryParse(p['product_sub_category_id']?.toString() ?? '');
      _selectedBrandId = int.tryParse(p['product_brand_id']?.toString() ?? '');

      // Refresh subcategory list filter
      _filterSubcategories();

      // Prefill images
      final imagesList = p['images'] as List<dynamic>? ?? [];
      for (int i = 0; i < imagesList.length; i++) {
        final img = imagesList[i];
        final orderVal = int.tryParse(img['product_images_sort_order']?.toString() ?? '') ?? (i + 1);
        _images.add(
          ProductImageInput(
            id: img['id']?.toString(),
            remotePath: img['product_images'] as String?,
            sortOrder: orderVal,
          ),
        );
      }
    }

    if (_images.isEmpty) {
      // Start with 1 empty image selector
      _images.add(ProductImageInput(sortOrder: 1));
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDropdownData() async {
    try {
      final catsResp = await ApiService.fetchActiveCategories();
      if (catsResp['data'] != null) {
        _categories = catsResp['data'] as List<dynamic>;
      }

      final subsResp = await ApiService.fetchActiveSubCategories();
      if (subsResp['data'] != null) {
        _allSubcategories = subsResp['data'] as List<dynamic>;
      }

      final brandsResp = await ApiService.fetchActiveBrands();
      if (brandsResp['data'] != null) {
        _brands = brandsResp['data'] as List<dynamic>;
      }
    } catch (e) {
      _showSnackbar('Error loading dropdown data: $e');
    }
  }

  void _filterSubcategories() {
    if (_selectedCategoryId == null) {
      _filteredSubcategories = [];
      _selectedSubcategoryId = null;
    } else {
      _filteredSubcategories = _allSubcategories.where((sub) {
        final catId = int.tryParse(sub['category_id']?.toString() ?? '');
        return catId == _selectedCategoryId;
      }).toList();

      // If the currently selected subcategory isn't in the new list, reset it
      if (_selectedSubcategoryId != null) {
        final exists = _filteredSubcategories.any((sub) => sub['id'] == _selectedSubcategoryId);
        if (!exists) {
          _selectedSubcategoryId = null;
        }
      }
    }
  }

  Future<void> _pickImage(ProductImageInput img) async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        setState(() {
          img.localFile = File(picked.path);
        });
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  void _addImageInput() {
    setState(() {
      _images.add(ProductImageInput(sortOrder: _images.length + 1));
    });
  }

  void _removeImageInput(int index) {
    setState(() {
      _images[index].sortOrderController.dispose();
      _images.removeAt(index);
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      _showSnackbar('Please select a category.');
      return;
    }

    if (_selectedSubcategoryId == null) {
      _showSnackbar('Please select a subcategory.');
      return;
    }

    if (_selectedBrandId == null) {
      _showSnackbar('Please select a brand.');
      return;
    }

    // Must have at least one image uploaded
    final hasImages = _images.any((img) => img.localFile != null || (img.remotePath != null && img.remotePath!.isNotEmpty));
    if (!hasImages) {
      _showSnackbar('Please select at least one image.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      final user = await SessionService.getUserDetails();

      if (token == null || user == null) {
        _showSnackbar('Session expired. Please log in again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final vendorId = user['id']?.toString() ?? '';

      final Map<String, String> fields = {
        'product_vendor_id': vendorId,
        'product_category_id': _selectedCategoryId!.toString(),
        'product_sub_category_id': _selectedSubcategoryId!.toString(),
        'product_brand_id': _selectedBrandId!.toString(),
        'product_name': _nameController.text.trim(),
        'product_short_description': _shortDescController.text.trim(),
        'product_long_description': _longDescController.text.trim(),
        'product_price': _priceController.text.trim(),
        'product_discount_price': _discountPriceController.text.trim(),
        'product_quantity': _quantityController.text.trim(),
      };

      final Map<String, File> files = {};

      // Add image fields and files
      for (int i = 0; i < _images.length; i++) {
        final img = _images[i];
        fields['images[$i][product_images_sort_order]'] = '${i + 1}';

        if (img.id != null) {
          fields['images[$i][id]'] = img.id!;
        }

        if (img.localFile != null) {
          files['images[$i][product_images]'] = img.localFile!;
        } else if (img.remotePath != null) {
          // Send existing remote path string if no new file is uploaded
          fields['images[$i][product_images]'] = img.remotePath!;
        }
      }

      Map<String, dynamic> response;
      if (_isEditMode) {
        final productId = widget.product!['id'] as int;
        response = await ApiService.updateProduct(
          id: productId,
          token: token,
          fields: fields,
          files: files,
        );
      } else {
        response = await ApiService.createProduct(
          token: token,
          fields: fields,
          files: files,
        );
      }

      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar(_isEditMode ? 'Product updated successfully!' : 'Product created successfully!');
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Form submission failed');
      }
    } catch (e) {
      _showSnackbar('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resolveProductImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/product_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          _isEditMode ? 'Edit Product' : 'Add Product',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Product Details', Icons.inventory_2_outlined),
                    _buildCard([
                      _buildTextField(
                        controller: _nameController,
                        label: 'Product Name',
                        icon: Icons.label_outline,
                        validator: (v) => v!.isEmpty ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _priceController,
                              label: 'Regular Price (₹)',
                              icon: Icons.currency_rupee,
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _discountPriceController,
                              label: 'Discount Price (₹)',
                              icon: Icons.price_change_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _quantityController,
                        label: 'Stock Quantity',
                        icon: Icons.production_quantity_limits,
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Quantity is required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _shortDescController,
                        label: 'Short Description',
                        icon: Icons.short_text,
                        maxLines: 2,
                        validator: (v) => v!.isEmpty ? 'Short description is required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _longDescController,
                        label: 'Long Description',
                        icon: Icons.description_outlined,
                        maxLines: 4,
                      ),
                    ]),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Relationships', Icons.lan_outlined),
                    _buildCard([
                      // Category Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        dropdownColor: const Color(0xFF1E1B4B),
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Category', Icons.category_outlined),
                        items: _categories.map((c) {
                          return DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['categories_name']?.toString() ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                            _selectedSubcategoryId = null; // Reset subcategory
                            _filterSubcategories();
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Subcategory Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedSubcategoryId,
                        dropdownColor: const Color(0xFF1E1B4B),
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Subcategory', Icons.subdirectory_arrow_right),
                        items: _filteredSubcategories.map((s) {
                          return DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(s['categories_subs_name']?.toString() ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSubcategoryId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Brand Dropdown
                      DropdownButtonFormField<int>(
                        value: _selectedBrandId,
                        dropdownColor: const Color(0xFF1E1B4B),
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Brand', Icons.branding_watermark_outlined),
                        items: _brands.map((b) {
                          return DropdownMenuItem<int>(
                            value: b['id'] as int,
                            child: Text(b['brands_name']?.toString() ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedBrandId = val;
                          });
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Product Images', Icons.image_outlined),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.cyanAccent, size: 28),
                          tooltip: 'Add Image',
                          onPressed: _addImageInput,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return _buildImageInputCard(index);
                      },
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: const Color(0xFF1E1B4B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saveForm,
                        child: Text(
                          _isEditMode ? 'Update Product' : 'Create Product',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1),
      ),
    );
  }

  Widget _buildImageInputCard(int index) {
    final img = _images[index];
    final hasLocal = img.localFile != null;
    final hasRemote = img.remotePath != null && img.remotePath!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Image #${index + 1}',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (_images.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeImageInput(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Image picker container
          InkWell(
            onTap: () => _pickImage(img),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (hasLocal || hasRemote) ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10,
                  width: 1,
                ),
              ),
              child: (hasLocal)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(img.localFile!, fit: BoxFit.cover),
                    )
                  : (hasRemote)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(_resolveProductImageUrl(img.remotePath), fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.3), size: 36),
                            const SizedBox(height: 6),
                            Text(
                              'Upload product image',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            ),
                          ],
                        ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Sort Order field
          TextFormField(
            controller: img.sortOrderController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Sort Order',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              prefixIcon: Icon(Icons.sort_outlined, color: Colors.white.withOpacity(0.4), size: 18),
              filled: true,
              fillColor: Colors.white.withOpacity(0.01),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.cyanAccent, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductImageInput {
  String? id;
  File? localFile;
  String? remotePath;
  final TextEditingController sortOrderController;

  ProductImageInput({
    this.id,
    this.localFile,
    this.remotePath,
    int sortOrder = 1,
  }) : sortOrderController = TextEditingController(text: sortOrder.toString());
}
