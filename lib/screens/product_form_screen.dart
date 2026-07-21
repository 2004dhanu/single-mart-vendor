import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product; // Null if creating

  const ProductFormScreen({super.key, this.brand, this.product});

  // Compatibility field
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
  String _productStatus = 'In Stock';

  // Dropdown lists
  List<dynamic> _categories = [];
  List<dynamic> _allSubcategories = [];
  List<dynamic> _filteredSubcategories = [];
  List<dynamic> _brands = [];
  List<dynamic> _attributes = []; // List of active attributes with nested values

  // Selected dropdown values
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  int? _selectedBrandId;

  // Images list
  final List<ProductImageInput> _images = [];
  final _imagePicker = ImagePicker();

  // Variants state
  bool _hasVariants = false;
  final List<ProductVariantInput> _variants = [];

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
    for (var v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeForm() async {
    final token = await SessionService.getToken();
    if (token != null) {
      await _loadDropdownData(token);
    }

    if (_isEditMode) {
      final p = widget.product!;
      _nameController.text = p['product_name']?.toString() ?? '';
      _shortDescController.text = p['product_short_description']?.toString() ?? '';
      _longDescController.text = p['product_long_description']?.toString() ?? '';
      _priceController.text = p['product_price']?.toString() ?? '';
      _discountPriceController.text = p['product_discount_price']?.toString() ?? '';
      _quantityController.text = p['product_quantity']?.toString() ?? '';
      _productStatus = p['product_status']?.toString() ?? 'In Stock';

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

      // Prefill variants if any
      _hasVariants = p['has_variants'] == 1 || p['has_variants']?.toString() == '1';
      final varList = p['variants'] as List<dynamic>? ?? [];
      for (var v in varList) {
        final Map<int, int?> attrValues = {};

        // Parse from attributes array (as returned by GET /product/{id})
        final attrsList = v['attributes'] as List<dynamic>? ?? [];
        for (var attrObj in attrsList) {
          final attrId = int.tryParse(attrObj['attribute_id']?.toString() ?? '');
          final valId = int.tryParse(attrObj['id']?.toString() ?? '');
          if (attrId != null && valId != null) {
            attrValues[attrId] = valId;
          }
        }

        // Fallback to value IDs
        final valueIds = (v['attribute_value_ids'] as List<dynamic>? ?? [])
            .map((id) => int.tryParse(id.toString()))
            .where((id) => id != null)
            .cast<int>()
            .toList();
        if (valueIds.isNotEmpty) {
          for (var attr in _attributes) {
            final attrId = attr['id'] as int;
            final vals = attr['values'] as List<dynamic>? ?? [];
            for (var val in vals) {
              final valId = val['id'] as int;
              if (valueIds.contains(valId)) {
                attrValues[attrId] = valId;
                break;
              }
            }
          }
        }

        final List<ProductVariantImageInput> variantImages = [];
        final vImgs = v['images'] as List<dynamic>? ?? [];
        for (int i = 0; i < vImgs.length; i++) {
          final img = vImgs[i];
          final orderVal = int.tryParse(img['product_variant_images_sort_order']?.toString() ?? '') ?? (i + 1);
          variantImages.add(
            ProductVariantImageInput(
              id: img['id']?.toString(),
              remotePath: img['product_variant_images'] as String?,
              sortOrder: orderVal,
            ),
          );
        }

        _variants.add(
          ProductVariantInput(
            id: v['id']?.toString(),
            barcode: v['product_barcode']?.toString() ?? '',
            price: v['product_price']?.toString() ?? '',
            discountPrice: v['product_discount_price']?.toString() ?? '',
            tax: v['product_tax_percentage']?.toString() ?? '18',
            quantity: v['product_quantity']?.toString() ?? '',
            weight: v['product_weight']?.toString() ?? '0.3',
            length: v['product_length']?.toString() ?? '25',
            width: v['product_width']?.toString() ?? '20',
            height: v['product_height']?.toString() ?? '2',
            attrValues: attrValues,
            variantImages: variantImages,
          ),
        );
      }
    }

    if (_images.isEmpty) {
      _images.add(ProductImageInput(sortOrder: 1));
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDropdownData(String token) async {
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

      // Fetch attributes and their detailed values in parallel
      final attrListResp = await ApiService.fetchAttributes(token);
      if (attrListResp['data'] != null) {
        final rawAttrs = attrListResp['data'] as List<dynamic>;
        final futures = rawAttrs.map((attr) async {
          try {
            final id = attr['id'] as int;
            final detail = await ApiService.fetchAttributeById(id, token);
            if (detail['data'] != null) {
              return detail['data'];
            }
          } catch (_) {}
          return null;
        });
        final results = await Future.wait(futures);
        _attributes = results.where((a) => a != null).toList();
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

  Future<void> _pickVariantImage(ProductVariantImageInput img) async {
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
      final removed = _images.removeAt(index);
      removed.sortOrderController.dispose();
    });
  }

  void _addVariantInput() {
    setState(() {
      final Map<int, int?> attrValues = {};
      for (var attr in _attributes) {
        attrValues[attr['id'] as int] = null;
      }
      _variants.add(ProductVariantInput(attrValues: attrValues));
    });
  }

  void _removeVariantInput(int index) {
    setState(() {
      final removed = _variants.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null || _selectedSubcategoryId == null || _selectedBrandId == null) {
      _showSnackbar('Please select Category, Subcategory, and Brand.');
      return;
    }

    final hasImages = _images.any((img) => img.localFile != null || (img.remotePath != null && img.remotePath!.isNotEmpty));
    if (!hasImages) {
      _showSnackbar('Please select at least one main product image.');
      return;
    }

    // Verify variants validation
    if (_hasVariants) {
      if (_variants.isEmpty) {
        _showSnackbar('At least one variant is required when variants are enabled.');
        return;
      }
      for (int i = 0; i < _variants.length; i++) {
        final v = _variants[i];
        if (v.priceController.text.trim().isEmpty) {
          _showSnackbar('Price is required for Variant #${i + 1}');
          return;
        }
        if (v.quantityController.text.trim().isEmpty) {
          _showSnackbar('Quantity is required for Variant #${i + 1}');
          return;
        }
        final selectedIds = v.selectedAttributeValues.values.where((id) => id != null).toList();
        if (selectedIds.isEmpty) {
          _showSnackbar('Select at least one attribute value for Variant #${i + 1}');
          return;
        }
      }
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
        'has_variants': _hasVariants ? '1' : '0',
        'product_price': _hasVariants ? '' : _priceController.text.trim(),
        'product_discount_price': _hasVariants ? '' : _discountPriceController.text.trim(),
        'product_quantity': _hasVariants ? '' : _quantityController.text.trim(),
        'product_status': _productStatus,
      };

      final Map<String, File> files = {};

      // Add main images
      for (int i = 0; i < _images.length; i++) {
        final img = _images[i];
        fields['images[$i][product_images_sort_order]'] = img.sortOrderController.text.trim();
        fields['images[$i][product_status]'] = 'Active';
        if (img.id != null) {
          fields['images[$i][id]'] = img.id!;
        }
        if (img.localFile != null) {
          files['images[$i][product_images]'] = img.localFile!;
        }
      }

      // Add variants fields and files
      if (_hasVariants) {
        for (int i = 0; i < _variants.length; i++) {
          final v = _variants[i];
          if (v.id != null) {
            fields['variants[$i][id]'] = v.id!;
          }
          fields['variants[$i][product_barcode]'] = v.barcodeController.text.trim();
          fields['variants[$i][product_price]'] = v.priceController.text.trim();
          fields['variants[$i][product_discount_price]'] = v.discountPriceController.text.trim();
          fields['variants[$i][product_tax_percentage]'] = v.taxController.text.trim();
          fields['variants[$i][product_quantity]'] = v.quantityController.text.trim();
          fields['variants[$i][product_weight]'] = v.weightController.text.trim();
          fields['variants[$i][product_length]'] = v.lengthController.text.trim();
          fields['variants[$i][product_width]'] = v.widthController.text.trim();
          fields['variants[$i][product_height]'] = v.heightController.text.trim();
          fields['variants[$i][variant_status]'] = 'Active';

          final selectedIds = v.selectedAttributeValues.values.where((id) => id != null).toList();
          for (int j = 0; j < selectedIds.length; j++) {
            fields['variants[$i][attribute_value_ids][$j]'] = selectedIds[j]!.toString();
          }

          for (int j = 0; j < v.images.length; j++) {
            final img = v.images[j];
            fields['variants[$i][images][$j][product_variant_images_sort_order]'] = img.sortOrderController.text.trim();
            fields['variants[$i][images][$j][product_variant_status]'] = 'Active';
            if (img.id != null) {
              fields['variants[$i][images][$j][id]'] = img.id!;
            }
            if (img.localFile != null) {
              files['variants[$i][images][$j][product_variant_images]'] = img.localFile!;
            }
          }
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
    if (!mounted) return;
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

  String _resolveVariantImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/product_variant_images/$path';
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF97316), size: 20),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
      style: const TextStyle(color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF0F172A).withOpacity(0.4), size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: const Color(0xFFF97316), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.5), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF0F172A).withOpacity(0.4), size: 20),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: const Color(0xFFF97316), width: 1),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Image #${index + 1}',
                style: const TextStyle(color: const Color(0xFFF97316), fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (_images.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _removeImageInput(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          InkWell(
            onTap: () => _pickImage(img),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (hasLocal || hasRemote) ? const Color(0xFFF97316).withOpacity(0.5) : const Color(0xFFE2E8F0),
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
                            Icon(Icons.image_outlined, color: const Color(0xFF0F172A).withOpacity(0.3), size: 36),
                            const SizedBox(height: 6),
                            Text(
                              'Upload product image',
                              style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 12),
                            ),
                          ],
                        ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          TextFormField(
            controller: img.sortOrderController,
            style: const TextStyle(color: const Color(0xFF0F172A)),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Sort Order',
              labelStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.5), fontSize: 13),
              prefixIcon: Icon(Icons.sort_outlined, color: const Color(0xFF0F172A).withOpacity(0.4), size: 18),
              filled: true,
              fillColor: Colors.white.withOpacity(0.01),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: const Color(0xFFF97316), width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantCard(int index) {
    final v = _variants[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              Text(
                'Variant #${index + 1}',
                style: const TextStyle(color: const Color(0xFFF97316), fontSize: 15, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _removeVariantInput(index),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: v.barcodeController,
            label: 'Barcode / SKU',
            icon: Icons.qr_code_scanner_outlined,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: v.priceController,
                  label: 'Price (₹)',
                  icon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: v.discountPriceController,
                  label: 'Discount Price (₹)',
                  icon: Icons.price_change_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: v.quantityController,
                  label: 'Quantity',
                  icon: Icons.production_quantity_limits,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: v.taxController,
                  label: 'Tax (%)',
                  icon: Icons.percent,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: v.weightController,
                  label: 'Weight (kg)',
                  icon: Icons.scale_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: v.lengthController,
                  label: 'Length (cm)',
                  icon: Icons.straighten_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: v.widthController,
                  label: 'Width (cm)',
                  icon: Icons.straighten_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: v.heightController,
                  label: 'Height (cm)',
                  icon: Icons.straighten_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Attributes selectors
          const Text(
            'Variant Attributes',
            style: TextStyle(color: const Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          if (_attributes.isEmpty)
            const Text(
              'No active attributes loaded. Add them in Manage Attributes first.',
              style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 12),
            )
          else
            ..._attributes.map((attr) {
              final attrId = attr['id'] as int;
              final attrName = attr['attribute_name'] ?? 'Attribute';
              final values = attr['values'] as List<dynamic>? ?? [];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<int>(
                  value: v.selectedAttributeValues[attrId],
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: const Color(0xFF0F172A)),
                  decoration: _buildInputDecoration(attrName, Icons.tune_rounded),
                  items: values.map((val) {
                    return DropdownMenuItem<int>(
                      value: val['id'] as int,
                      child: Text(val['attribute_value']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      v.selectedAttributeValues[attrId] = val;
                    });
                  },
                ),
              );
            }),

          const SizedBox(height: 12),
          
          // Variant images header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Variant Images',
                style: TextStyle(color: const Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    v.images.add(ProductVariantImageInput(sortOrder: v.images.length + 1));
                  });
                },
                icon: const Icon(Icons.add, color: const Color(0xFFF97316), size: 16),
                label: const Text('Add Image', style: TextStyle(color: const Color(0xFFF97316), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: v.images.length,
            itemBuilder: (context, vImgIndex) {
              final img = v.images[vImgIndex];
              final hasLocal = img.localFile != null;
              final hasRemote = img.remotePath != null && img.remotePath!.isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.01),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Image #${vImgIndex + 1}', style: const TextStyle(color: const Color(0xFF64748B), fontSize: 11)),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              v.images.removeAt(vImgIndex);
                              img.sortOrderController.dispose();
                            });
                          },
                          child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickVariantImage(img),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 80,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.01),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: hasLocal
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(img.localFile!, fit: BoxFit.cover),
                              )
                            : hasRemote
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(_resolveVariantImageUrl(img.remotePath), fit: BoxFit.cover),
                                  )
                                : const Center(child: Icon(Icons.add_a_photo_outlined, color: const Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: img.sortOrderController,
                      style: const TextStyle(color: const Color(0xFF0F172A)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Sort Order',
                        labelStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 11),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.005),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: const Color(0xFFF97316)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;

    Widget leftColumn = Column(
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
          
          // Product Status Dropdown
          DropdownButtonFormField<String>(
            value: _productStatus,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: _buildInputDecoration('Product Status', Icons.info_outline),
            items: const [
              DropdownMenuItem(value: 'In Stock', child: Text('In Stock')),
              DropdownMenuItem(value: 'Out of Stock', child: Text('Out of Stock')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _productStatus = val;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Has Variants Toggle Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF97316).withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Color(0xFFF97316), size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Has Variants / Multi-attributes',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Checkbox(
                  value: _hasVariants,
                  activeColor: const Color(0xFFF97316),
                  checkColor: Colors.white,
                  onChanged: (val) {
                    setState(() {
                      _hasVariants = val ?? false;
                      if (_hasVariants && _variants.isEmpty) {
                        _addVariantInput();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!_hasVariants) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: 'Regular Price (₹)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (_hasVariants) return null;
                      return v!.isEmpty ? 'Required' : null;
                    },
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
              validator: (v) {
                if (_hasVariants) return null;
                return v!.isEmpty ? 'Quantity is required' : null;
              },
            ),
            const SizedBox(height: 16),
          ],

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
        
        // On mobile, show right column widgets below the left column cards
        if (!isDesktop) ..._buildRightColumnWidgets(),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
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
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          _isEditMode ? 'Edit Product' : 'Add Product',
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : double.infinity),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: leftColumn,
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _buildRightColumnWidgets(),
                                ),
                              ),
                            ],
                          )
                        : leftColumn,
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _buildRightColumnWidgets() {
    return [
      _buildSectionHeader('Relationships', Icons.lan_outlined),
      _buildCard([
        DropdownButtonFormField<int>(
          value: _selectedCategoryId,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF0F172A)),
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
              _selectedSubcategoryId = null;
              _filterSubcategories();
            });
          },
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<int>(
          value: _selectedSubcategoryId,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF0F172A)),
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

        DropdownButtonFormField<int>(
          value: _selectedBrandId,
          dropdownColor: Colors.white,
          style: const TextStyle(color: Color(0xFF0F172A)),
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

      if (_hasVariants) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Product Variants', Icons.grid_view_rounded),
            TextButton.icon(
              onPressed: _addVariantInput,
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFF97316), size: 20),
              label: const Text('Add Variant', style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _variants.length,
          itemBuilder: (context, index) {
            return _buildVariantCard(index);
          },
        ),
        const SizedBox(height: 24),
      ],

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSectionHeader('Product Images', Icons.image_outlined),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFFF97316), size: 28),
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
      const SizedBox(height: 24),
    ];
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

class ProductVariantInput {
  String? id;
  final barcodeController = TextEditingController();
  final priceController = TextEditingController();
  final discountPriceController = TextEditingController();
  final taxController = TextEditingController(text: '18');
  final quantityController = TextEditingController();
  final weightController = TextEditingController(text: '0.3');
  final lengthController = TextEditingController(text: '25');
  final widthController = TextEditingController(text: '20');
  final heightController = TextEditingController(text: '2');
  
  // Selected value ID for each attribute: {attributeId: selectedValueId}
  final Map<int, int?> selectedAttributeValues;

  // Local variant images
  final List<ProductVariantImageInput> images;

  ProductVariantInput({
    this.id,
    String barcode = '',
    String price = '',
    String discountPrice = '',
    String tax = '18',
    String quantity = '',
    String weight = '0.3',
    String length = '25',
    String width = '20',
    String height = '2',
    Map<int, int?>? attrValues,
    List<ProductVariantImageInput>? variantImages,
  })  : selectedAttributeValues = attrValues ?? {},
        images = variantImages ?? [] {
    barcodeController.text = barcode;
    priceController.text = price;
    discountPriceController.text = discountPrice;
    taxController.text = tax;
    quantityController.text = quantity;
    weightController.text = weight;
    lengthController.text = length;
    widthController.text = width;
    heightController.text = height;
  }

  void dispose() {
    barcodeController.dispose();
    priceController.dispose();
    discountPriceController.dispose();
    taxController.dispose();
    quantityController.dispose();
    weightController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    for (var img in images) {
      img.sortOrderController.dispose();
    }
  }
}

class ProductVariantImageInput {
  String? id;
  File? localFile;
  String? remotePath;
  final TextEditingController sortOrderController;

  ProductVariantImageInput({
    this.id,
    this.localFile,
    this.remotePath,
    int sortOrder = 1,
  }) : sortOrderController = TextEditingController(text: sortOrder.toString());
}
