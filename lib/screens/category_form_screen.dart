import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class CategoryFormScreen extends StatefulWidget {
  final Map<String, dynamic>? category; // Null if creating

  const CategoryFormScreen({super.key, this.category});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  final _nameController = TextEditingController();
  String _status = 'Active';

  // Category Image
  File? _categoryImageFile;
  String? _remoteCategoryImagePath;
  final _imagePicker = ImagePicker();

  // Subcategories List
  List<SubcategoryInput> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.category != null;
    if (_isEditMode) {
      final cat = widget.category!;
      _nameController.text = cat['categories_name']?.toString() ?? '';
      _status = cat['categories_status']?.toString() ?? 'Active';
      _remoteCategoryImagePath = cat['categories_image'] as String?;

      // Prefill subcategories
      final subs = cat['subs'] as List<dynamic>? ?? [];
      for (var sub in subs) {
        _subcategories.add(
          SubcategoryInput(
            id: sub['id']?.toString(),
            name: sub['categories_subs_name']?.toString() ?? '',
            status: sub['categories_subs_status']?.toString() ?? 'Active',
            remoteImagePath: sub['categories_subs_image'] as String?,
          ),
        );
      }
    } else {
      // Start with 1 empty subcategory input by default for a nice UX
      _subcategories.add(SubcategoryInput());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var sub in _subcategories) {
      sub.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCategoryImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) {
        setState(() {
          _categoryImageFile = File(picked.path);
        });
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  Future<void> _pickSubcategoryImage(SubcategoryInput sub) async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) {
        setState(() {
          sub.localImageFile = File(picked.path);
        });
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  void _addSubcategory() {
    setState(() {
      _subcategories.add(SubcategoryInput());
    });
  }

  void _removeSubcategory(int index) {
    setState(() {
      _subcategories[index].controller.dispose();
      _subcategories.removeAt(index);
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isEditMode && _categoryImageFile == null) {
      _showSnackbar('Please upload a category image.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) {
        _showSnackbar('Session expired. Please log in again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Map<String, String> fields = {
        'categories_name': _nameController.text.trim(),
      };

      if (_isEditMode) {
        fields['categories_status'] = _status;
        fields['status'] = _status;
      }

      final Map<String, File> files = {};

      // Add category image file if selected
      if (_categoryImageFile != null) {
        files['categories_image'] = _categoryImageFile!;
      }

      // Add subcategories fields and files
      for (int i = 0; i < _subcategories.length; i++) {
        final sub = _subcategories[i];
        final subName = sub.controller.text.trim();
        
        fields['subs[$i][categories_subs_name]'] = subName;
        fields['subs[$i][categories_subs_status]'] = sub.status;

        if (sub.id != null) {
          fields['subs[$i][id]'] = sub.id!;
        }

        if (sub.localImageFile != null) {
          files['subs[$i][categories_subs_image]'] = sub.localImageFile!;
        }
      }

      Map<String, dynamic> response;
      if (_isEditMode) {
        final catId = widget.category!['id'] as int;
        response = await ApiService.updateCategory(
          id: catId,
          token: token,
          fields: fields,
          files: files,
        );
      } else {
        response = await ApiService.createCategory(
          token: token,
          fields: fields,
          files: files,
        );
      }

      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar(_isEditMode ? 'Category updated successfully!' : 'Category created successfully!');
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

  String _resolveCategoryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          _isEditMode ? 'Edit Category' : 'Add Category',
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
                    _buildSectionHeader('Category Details', Icons.category_outlined),
                    _buildCard([
                      _buildTextField(
                        controller: _nameController,
                        label: 'Category Name',
                        icon: Icons.store,
                        validator: (v) => v!.isEmpty ? 'Category name is required' : null,
                      ),
                      if (_isEditMode) ...[
                        const SizedBox(height: 12),
                        _buildStatusDropdown(),
                      ],
                      const SizedBox(height: 16),
                      _buildImageSelector(
                        label: 'Category Image',
                        localFile: _categoryImageFile,
                        remotePath: _remoteCategoryImagePath,
                        onTap: _pickCategoryImage,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Subcategories', Icons.subdirectory_arrow_right),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.cyanAccent, size: 28),
                          tooltip: 'Add Subcategory',
                          onPressed: _addSubcategory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (_subcategories.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Click the + button to add a subcategory.',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontStyle: FontStyle.italic),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _subcategories.length,
                        itemBuilder: (context, index) {
                          return _buildSubcategoryInputCard(index);
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
                          _isEditMode ? 'Update Category' : 'Create Category',
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
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

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      dropdownColor: const Color(0xFF1E1B4B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Category Status',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(Icons.info_outline, color: Colors.white.withOpacity(0.4), size: 20),
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
      items: ['Active', 'Inactive']
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _status = val;
          });
        }
      },
    );
  }

  Widget _buildImageSelector({
    required String label,
    required File? localFile,
    required String? remotePath,
    required VoidCallback onTap,
  }) {
    final hasLocal = localFile != null;
    final hasRemote = remotePath != null && remotePath.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
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
                    child: Image.file(localFile, fit: BoxFit.cover),
                  )
                : (hasRemote)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(_resolveCategoryImageUrl(remotePath), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.3), size: 36),
                          const SizedBox(height: 6),
                          Text(
                            'Upload image',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubcategoryInputCard(int index) {
    final sub = _subcategories[index];

    return Container(
      margin: const EdgeInsets.only(bottom :16),
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
                'Subcategory #${index + 1}',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _removeSubcategory(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: sub.controller,
            label: 'Subcategory Name',
            icon: Icons.label_outline,
            validator: (v) => v!.isEmpty ? 'Subcategory name is required' : null,
          ),
          if (_isEditMode) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: sub.status,
              dropdownColor: const Color(0xFF1E1B4B),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                prefixIcon: Icon(Icons.info_outline, color: Colors.white.withOpacity(0.4), size: 20),
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
              items: ['Active', 'Inactive']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    sub.status = val;
                  });
                }
              },
            ),
          ],
          const SizedBox(height: 12),
          _buildImageSelector(
            label: 'Subcategory Image',
            localFile: sub.localImageFile,
            remotePath: sub.remoteImagePath,
            onTap: () => _pickSubcategoryImage(sub),
          ),
        ],
      ),
    );
  }
}

class SubcategoryInput {
  String? id;
  final TextEditingController controller;
  String status;
  File? localImageFile;
  String? remoteImagePath;

  SubcategoryInput({
    this.id,
    String name = '',
    this.status = 'Active',
    this.remoteImagePath,
  }) : controller = TextEditingController(text: name);
}
