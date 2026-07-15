import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class BannerFormScreen extends StatefulWidget {
  final Map<String, dynamic>? banner; // Null if creating

  const BannerFormScreen({super.key, this.banner});

  @override
  State<BannerFormScreen> createState() => _BannerFormScreenState();
}

class _BannerFormScreenState extends State<BannerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  final _nameController = TextEditingController();
  final _linkController = TextEditingController();
  final _sortController = TextEditingController(text: '1');
  String _selectedStatus = 'Active';

  File? _imageFile;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.banner != null;
    if (_isEditMode) {
      final b = widget.banner!;
      _nameController.text = b['banner']?.toString() ?? '';
      _linkController.text = b['banner_link']?.toString() ?? '';
      _sortController.text = b['banner_sort_order']?.toString() ?? '1';
      _selectedStatus = b['banner_status']?.toString() ?? 'Active';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
    _sortController.dispose();
    super.dispose();
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
    if (!_isEditMode && _imageFile == null) {
      _showSnackbar('Please select a banner image.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final Map<String, String> fields = {
        'banner': _nameController.text.trim(),
        'banner_link': _linkController.text.trim(),
        'banner_sort_order': _sortController.text.trim(),
        'banner_status': _selectedStatus,
        'status': _selectedStatus,
      };

      final Map<String, File> files = {};
      if (_imageFile != null) {
        files['banner'] = _imageFile!;
        files['banner_image'] = _imageFile!;
      } else {
        // Send 'null' string if no new file is added (for updates)
        fields['banner_image'] = 'null';
      }

      Map<String, dynamic> response;
      if (_isEditMode) {
        final id = widget.banner!['id'] as int;
        response = await ApiService.updateBanner(
          id: id,
          token: token,
          fields: fields,
          files: files,
        );
      } else {
        response = await ApiService.createBanner(
          token: token,
          fields: fields,
          files: files,
        );
      }

      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar(_isEditMode ? 'Banner updated successfully!' : 'Banner created successfully!');
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _resolveBannerImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return 'https://agsdemo.in/singlemartapi/public/assets/images/banner_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          _isEditMode ? 'Edit Banner' : 'Add Banner',
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
                          // Name Input
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Banner Name', Icons.label_outline),
                            validator: (v) => v!.isEmpty ? 'Banner name is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Link Input
                          TextFormField(
                            controller: _linkController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Banner Link (URL)', Icons.link_outlined),
                          ),
                          const SizedBox(height: 16),

                          // Sort Order
                          TextFormField(
                            controller: _sortController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: _buildInputDecoration('Sort Order', Icons.sort_outlined),
                            validator: (v) => v!.isEmpty ? 'Sort order is required' : null,
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
                      'Banner Image',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (_imageFile != null || (_isEditMode && widget.banner?['banner_image'] != null))
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
                            : (_isEditMode && widget.banner?['banner_image'] != null && widget.banner!['banner_image'].toString().isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      _resolveBannerImageUrl(widget.banner!['banner_image'].toString()),
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
                          _isEditMode ? 'Update Banner' : 'Create Banner',
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
