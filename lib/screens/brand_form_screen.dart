import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/square_image_cropper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BrandFormScreen extends StatefulWidget {
  final Map<String, dynamic>? brand; // Null if creating

  const BrandFormScreen({super.key, this.brand});

  @override
  State<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends State<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  final _nameController = TextEditingController();
  String _status = 'Active';

  // Brand Image
  File? _brandImageFile;
  String? _remoteBrandImagePath;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.brand != null;
    if (_isEditMode) {
      final b = widget.brand!;
      _nameController.text = b['brands_name']?.toString() ?? '';
      _status = b['brands_status']?.toString() ?? 'Active';
      _remoteBrandImagePath = b['brands_image'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBrandImage() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) {
        if (mounted) {
          final cropped = await SquareImageCropper.crop(context, File(picked.path));
          if (cropped != null) {
            setState(() {
              _brandImageFile = cropped;
            });
          }
        }
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isEditMode && _brandImageFile == null) {
      _showSnackbar('Please upload a brand image.');
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
        'brands_name': _nameController.text.trim(),
        'brands_status': _status,
        'status': _status, // Send both keys to bypass backend null constraints
      };

      final Map<String, File> files = {};

      // Add brand image file if selected
      if (_brandImageFile != null) {
        files['brands_image'] = _brandImageFile!;
      }

      Map<String, dynamic> response;
      if (_isEditMode) {
        final brandId = widget.brand!['id'] as int;
        response = await ApiService.updateBrand(
          id: brandId,
          token: token,
          fields: fields,
          files: files,
        );
      } else {
        response = await ApiService.createBrand(
          token: token,
          fields: fields,
          files: files,
        );
      }

      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar(_isEditMode ? 'Brand updated successfully!' : 'Brand created successfully!');
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

  String _resolveBrandImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/brand_images/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          _isEditMode ? 'Edit Brand' : 'Add Brand',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: const Color(0xFFF97316)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Brand Details', Icons.branding_watermark_outlined),
                    _buildCard([
                      _buildTextField(
                        controller: _nameController,
                        label: 'Brand Name',
                        icon: Icons.label_outline,
                        validator: (v) => v!.isEmpty ? 'Brand name is required' : null,
                      ),
                      if (_isEditMode) ...[
                        const SizedBox(height: 12),
                        _buildStatusDropdown(),
                      ],
                      const SizedBox(height: 16),
                      _buildImageSelector(
                        label: 'Brand Image',
                        localFile: _brandImageFile,
                        remotePath: _remoteBrandImagePath,
                        onTap: _pickBrandImage,
                      ),
                    ]),
                    
                    const SizedBox(height: 32),
                    
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
                          _isEditMode ? 'Update Brand' : 'Create Brand',
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
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      dropdownColor: Colors.white,
      style: const TextStyle(color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: 'Brand Status',
        labelStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(Icons.info_outline, color: const Color(0xFF0F172A).withOpacity(0.4), size: 20),
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
          style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
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
                    child: kIsWeb
                        ? Image.network(localFile.path, fit: BoxFit.cover)
                        : Image.file(localFile, fit: BoxFit.cover),
                  )
                : (hasRemote)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(_resolveBrandImageUrl(remotePath), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, color: const Color(0xFF0F172A).withOpacity(0.3), size: 36),
                          const SizedBox(height: 6),
                          Text(
                            'Upload image',
                            style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 12),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
