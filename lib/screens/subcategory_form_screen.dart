import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'subcategory_list_screen.dart';

class SubcategoryFormScreen extends StatefulWidget {
  final SubcategoryItem? sub; // Null if creating

  const SubcategoryFormScreen({super.key, this.sub});

  @override
  State<SubcategoryFormScreen> createState() => _SubcategoryFormScreenState();
}

class _SubcategoryFormScreenState extends State<SubcategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditMode = false;

  final _nameController = TextEditingController();
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String _selectedStatus = 'Active';

  File? _imageFile;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.sub != null;
    if (_isEditMode) {
      _nameController.text = widget.sub!.name;
      _selectedCategoryId = widget.sub!.categoryId;
      _selectedStatus = widget.sub!.status;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final catsResp = await ApiService.fetchCategories(token);
      if (catsResp['data'] != null) {
        setState(() {
          _categories = catsResp['data'] as List<dynamic>;
          if (!_isEditMode && _categories.isNotEmpty) {
            _selectedCategoryId = _categories.first['id'] as int;
          }
        });
      }
    } catch (e) {
      _showSnackbar('Error loading categories: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showSnackbar('Please select a parent category.');
      return;
    }

    if (!_isEditMode && _imageFile == null) {
      _showSnackbar('Please pick an image for the subcategory.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      if (_isEditMode) {
        final originalCategoryId = widget.sub!.categoryId;
        
        // Scenario A: Parent category didn't change
        if (originalCategoryId == _selectedCategoryId) {
          await _updateInParentCategory(originalCategoryId, token);
        } else {
          // Scenario B: Parent category changed!
          // 1. Remove from old parent category
          await _removeFromParentCategory(originalCategoryId, token);
          // 2. Add to new parent category
          await _addToParentCategory(_selectedCategoryId!, token, isMove: true);
        }
      } else {
        // Scenario C: Creating a new subcategory
        await _addToParentCategory(_selectedCategoryId!, token, isMove: false);
      }

      _showSnackbar(_isEditMode ? 'Subcategory updated successfully!' : 'Subcategory created successfully!');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackbar('Error saving subcategory: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateInParentCategory(int catId, String token) async {
    final detailResp = await ApiService.fetchCategoryById(catId, token);
    if (detailResp['data'] == null) throw Exception('Parent category detail not found.');

    final catData = detailResp['data'] as Map<String, dynamic>;
    final subs = catData['subs'] as List<dynamic>? ?? [];

    final Map<String, String> fields = {
      'categories_name': catData['categories_name']?.toString() ?? '',
      'status': catData['categories_status']?.toString() ?? 'Active',
      'categories_status': catData['categories_status']?.toString() ?? 'Active',
    };

    final Map<String, File> files = {};

    for (int i = 0; i < subs.length; i++) {
      final item = subs[i];
      final itemId = item['id'] as int;
      fields['subs[$i][id]'] = itemId.toString();
      fields['subs[$i][categories_subs_id]'] = itemId.toString();

      if (itemId == widget.sub!.id) {
        fields['subs[$i][categories_subs_name]'] = _nameController.text.trim();
        fields['subs[$i][categories_subs_status]'] = _selectedStatus;
        if (_imageFile != null) {
          files['subs[$i][categories_subs_image]'] = _imageFile!;
        }
      } else {
        fields['subs[$i][categories_subs_name]'] = item['categories_subs_name']?.toString() ?? '';
        fields['subs[$i][categories_subs_status]'] = item['categories_subs_status']?.toString() ?? 'Active';
      }
    }

    final response = await ApiService.updateCategory(
      id: catId,
      token: token,
      fields: fields,
      files: files,
    );

    final code = response['code'] as int? ?? 200;
    if (code != 200 && response['message']?.toString().contains('Successfully') != true) {
      throw Exception(response['message'] ?? 'Failed to update parent category.');
    }
  }

  Future<void> _removeFromParentCategory(int catId, String token) async {
    final detailResp = await ApiService.fetchCategoryById(catId, token);
    if (detailResp['data'] == null) return; // already deleted/missing

    final catData = detailResp['data'] as Map<String, dynamic>;
    final subs = catData['subs'] as List<dynamic>? ?? [];

    final Map<String, String> fields = {
      'categories_name': catData['categories_name']?.toString() ?? '',
      'status': catData['categories_status']?.toString() ?? 'Active',
      'categories_status': catData['categories_status']?.toString() ?? 'Active',
    };

    int index = 0;
    for (int i = 0; i < subs.length; i++) {
      final item = subs[i];
      final itemId = item['id'] as int;
      if (itemId == widget.sub!.id) continue; // Skip to remove it!

      fields['subs[$index][id]'] = itemId.toString();
      fields['subs[$index][categories_subs_id]'] = itemId.toString();
      fields['subs[$index][categories_subs_name]'] = item['categories_subs_name']?.toString() ?? '';
      fields['subs[$index][categories_subs_status]'] = item['categories_subs_status']?.toString() ?? 'Active';
      index++;
    }

    // Call update to remove it from this parent category
    await ApiService.updateCategory(
      id: catId,
      token: token,
      fields: fields,
      files: {},
    );
  }

  Future<void> _addToParentCategory(int catId, String token, {required bool isMove}) async {
    final detailResp = await ApiService.fetchCategoryById(catId, token);
    if (detailResp['data'] == null) throw Exception('Parent category detail not found.');

    final catData = detailResp['data'] as Map<String, dynamic>;
    final subs = catData['subs'] as List<dynamic>? ?? [];

    final Map<String, String> fields = {
      'categories_name': catData['categories_name']?.toString() ?? '',
      'status': catData['categories_status']?.toString() ?? 'Active',
      'categories_status': catData['categories_status']?.toString() ?? 'Active',
    };

    final Map<String, File> files = {};

    // 1. Copy all existing subcategories
    int i = 0;
    for (; i < subs.length; i++) {
      final item = subs[i];
      fields['subs[$i][id]'] = item['id']?.toString() ?? '';
      fields['subs[$i][categories_subs_id]'] = item['id']?.toString() ?? '';
      fields['subs[$i][categories_subs_name]'] = item['categories_subs_name']?.toString() ?? '';
      fields['subs[$i][categories_subs_status]'] = item['categories_subs_status']?.toString() ?? 'Active';
    }

    // 2. Append the new subcategory at the end of the array
    if (isMove && widget.sub?.id != null) {
      fields['subs[$i][id]'] = widget.sub!.id.toString();
      fields['subs[$i][categories_subs_id]'] = widget.sub!.id.toString();
    }
    fields['subs[$i][categories_subs_name]'] = _nameController.text.trim();
    fields['subs[$i][categories_subs_status]'] = _selectedStatus;
    
    if (_imageFile != null) {
      files['subs[$i][categories_subs_image]'] = _imageFile!;
    }

    final response = await ApiService.updateCategory(
      id: catId,
      token: token,
      fields: fields,
      files: files,
    );

    final code = response['code'] as int? ?? 200;
    if (code != 200 && response['message']?.toString().contains('Successfully') != true) {
      throw Exception(response['message'] ?? 'Failed to add subcategory to parent.');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _resolveSubcategoryImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'https://agsdemo.in/singlemartapi/public/assets/images/category_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          _isEditMode ? 'Edit Subcategory' : 'Add Subcategory',
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          // Category Dropdown Selection
                          DropdownButtonFormField<int>(
                            value: _selectedCategoryId,
                            dropdownColor: const Color(0xFF1E1B4B),
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Parent Category', Icons.category_outlined),
                            items: _categories.map((c) {
                              return DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(c['categories_name']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Name Input
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Subcategory Name', Icons.label_outline),
                            validator: (v) => v!.isEmpty ? 'Subcategory name is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Status Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            dropdownColor: const Color(0xFF1E1B4B),
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Status', Icons.check_circle_outline),
                            items: const [
                              DropdownMenuItem(value: 'Active', child: Text('Active')),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedStatus = val!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Subcategory Image',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (_imageFile != null || (_isEditMode && widget.sub?.image != null))
                                ? Colors.cyanAccent.withOpacity(0.5)
                                : Colors.white10,
                            width: 1,
                          ),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_imageFile!, fit: BoxFit.cover),
                              )
                            : (_isEditMode && widget.sub?.image != null && widget.sub!.image!.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      _resolveSubcategoryImageUrl(widget.sub!.image),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.3), size: 40),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Select image from gallery',
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                                      ),
                                    ],
                                  ),
                      ),
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
                          _isEditMode ? 'Update Subcategory' : 'Create Subcategory',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
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
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
    );
  }
}
