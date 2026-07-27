import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/square_image_cropper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userDetails;

  const EditProfileScreen({super.key, required this.userDetails});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;
  late TextEditingController _upiController;
  late TextEditingController _gstController;
  late TextEditingController _panController;

  // Address controllers
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _landmarkController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _pincodeController;

  String _selectedGender = 'Male';
  String _addressType = 'Work';
  String? _addressId;
  bool _isLoading = false;

  // Selected files for update (null if keeping existing)
  File? _userImageFile;
  File? _qrCodeFile;
  File? _businessDocFile;

  @override
  void initState() {
    super.initState();
    final user = widget.userDetails;
    
    _nameController = TextEditingController(text: user['name'] ?? '');
    _ownerNameController = TextEditingController(text: user['owner_name'] ?? '');
    _mobileController = TextEditingController(text: user['mobile'] ?? '');
    _emailController = TextEditingController(text: user['email'] ?? '');
    _dobController = TextEditingController(text: user['dob'] ?? '');
    _upiController = TextEditingController(text: user['upi_id'] ?? '');
    _gstController = TextEditingController(text: user['gst_number'] ?? '');
    _panController = TextEditingController(text: user['pan_number'] ?? '');
    final String rawGender = user['gender']?.toString() ?? 'Male';
    if (rawGender.toLowerCase() == 'female') {
      _selectedGender = 'Female';
    } else if (rawGender.toLowerCase() == 'other') {
      _selectedGender = 'Other';
    } else {
      _selectedGender = 'Male';
    }

    // Prefill addresses
    final addresses = user['addresses'] as List<dynamic>?;
    if (addresses != null && addresses.isNotEmpty) {
      final addr = addresses[0] as Map<String, dynamic>;
      _addressId = addr['id']?.toString();
      _address1Controller = TextEditingController(text: addr['address_line_1'] ?? '');
      _address2Controller = TextEditingController(text: addr['address_line_2'] ?? '');
      _landmarkController = TextEditingController(text: addr['landmark'] ?? '');
      _cityController = TextEditingController(text: addr['city'] ?? '');
      _districtController = TextEditingController(text: addr['district'] ?? '');
      _stateController = TextEditingController(text: addr['state'] ?? '');
      _countryController = TextEditingController(text: addr['country'] ?? '');
      _pincodeController = TextEditingController(text: addr['pincode'] ?? '');
      
      final String rawAddrType = addr['address_type']?.toString() ?? 'Work';
      final List<String> validTypes = ['Work', 'Home', 'Warehouse', 'Other'];
      if (validTypes.contains(rawAddrType)) {
        _addressType = rawAddrType;
      } else {
        _addressType = 'Work';
      }
    } else {
      _address1Controller = TextEditingController();
      _address2Controller = TextEditingController();
      _landmarkController = TextEditingController();
      _cityController = TextEditingController();
      _districtController = TextEditingController();
      _stateController = TextEditingController();
      _countryController = TextEditingController();
      _pincodeController = TextEditingController();
      _addressType = 'Work';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _upiController.dispose();
    _gstController.dispose();
    _panController.dispose();
    
    _address1Controller.dispose();
    _address2Controller.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: const Color(0xFFF97316),
              onPrimary: Color(0xFFF8FAFC),
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        if (mounted) {
          final cropped = await SquareImageCropper.crop(context, File(pickedFile.path));
          if (cropped != null) {
            setState(() {
              if (type == 'user_image') {
                _userImageFile = cropped;
              } else if (type == 'qr_code') {
                _qrCodeFile = cropped;
              } else if (type == 'business_document') {
                _businessDocFile = cropped;
              }
            });
          }
        }
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  String resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.contains('/')) {
      return 'https://agsdemo.in/singlemartapi/public/$path';
    }
    return 'https://agsdemo.in/singlemartapi/public/assets/images/user_images/$path';
  }

  Widget _buildImageSelector(String title, String type, File? localFile, String? remotePath) {
    final hasLocal = localFile != null;
    final hasRemote = remotePath != null && remotePath.isNotEmpty;
    final remoteUrl = resolveImageUrl(remotePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: const Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickImage(type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: hasLocal
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        kIsWeb
                            ? Image.network(localFile.path, fit: BoxFit.cover)
                            : Image.file(localFile, fit: BoxFit.cover),
                        Container(color: Colors.black38),
                        const Center(
                          child: Icon(Icons.change_circle_rounded, color: const Color(0xFFF97316), size: 40),
                        ),
                      ],
                    ),
                  )
                : hasRemote
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              remoteUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 40),
                              ),
                            ),
                            Container(color: Colors.black38),
                            const Center(
                              child: Icon(Icons.change_circle_rounded, color: const Color(0xFFF97316), size: 40),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, color: const Color(0xFFCBD5E1), size: 40),
                            SizedBox(height: 8),
                            Text('Click to upload image', style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 12)),
                          ],
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      final userId = widget.userDetails['id'] as int? ?? 0;

      if (token == null || userId == 0) {
        _showSnackbar('Session expired. Please log in again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Populate text fields
      final Map<String, String> fields = {
        'name': _nameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'email': _emailController.text.trim(),
        'gender': _selectedGender.toLowerCase(),
        'dob': _dobController.text.trim(),
        'user_type': '2',
        'user_position': 'Vendor',
        'upi_id': _upiController.text.trim(),
        'gst_number': _gstController.text.trim(),
        'pan_number': _panController.text.trim(),
        'status': widget.userDetails['status']?.toString() ?? '1',
        'addresses[0][address_line_1]': _address1Controller.text.trim(),
        'addresses[0][address_line_2]': _address2Controller.text.trim(),
        'addresses[0][landmark]': _landmarkController.text.trim(),
        'addresses[0][city]': _cityController.text.trim(),
        'addresses[0][district]': _districtController.text.trim(),
        'addresses[0][state]': _stateController.text.trim(),
        'addresses[0][country]': _countryController.text.trim(),
        'addresses[0][pincode]': _pincodeController.text.trim(),
        'addresses[0][address_type]': _addressType,
        'addresses[0][is_default]': '1',
      };

      if (_addressId != null) {
        fields['addresses[0][id]'] = _addressId!;
      }

      // Preserve other addresses to prevent backend from deleting them
      final List<dynamic> existingAddresses = widget.userDetails['addresses'] as List<dynamic>? ?? [];
      for (int i = 1; i < existingAddresses.length; i++) {
        final addr = existingAddresses[i] as Map<String, dynamic>;
        fields['addresses[$i][id]'] = addr['id']?.toString() ?? '';
        fields['addresses[$i][address_line_1]'] = addr['address_line_1']?.toString() ?? '';
        fields['addresses[$i][address_line_2]'] = addr['address_line_2']?.toString() ?? '';
        fields['addresses[$i][landmark]'] = addr['landmark']?.toString() ?? '';
        fields['addresses[$i][city]'] = addr['city']?.toString() ?? '';
        fields['addresses[$i][district]'] = addr['district']?.toString() ?? '';
        fields['addresses[$i][state]'] = addr['state']?.toString() ?? '';
        fields['addresses[$i][country]'] = addr['country']?.toString() ?? '';
        fields['addresses[$i][pincode]'] = addr['pincode']?.toString() ?? '';
        fields['addresses[$i][address_type]'] = addr['address_type']?.toString() ?? 'Shop';
        fields['addresses[$i][is_default]'] = addr['is_default']?.toString() ?? '0';
      }

      // Populate files (only add files that were explicitly changed)
      final Map<String, File> files = {};
      if (_userImageFile != null) {
        files['user_image'] = _userImageFile!;
      }
      if (_qrCodeFile != null) {
        files['qr_code'] = _qrCodeFile!;
      }
      if (_businessDocFile != null) {
        files['business_document'] = _businessDocFile!;
      }

      final result = await ApiService.updateVendor(
        id: userId,
        token: token,
        fields: fields,
        files: files,
      );

      final code = result['code'] as int? ?? 500;

      if (code == 200 || result['message']?.toString().contains('Successfully') == true || result['data'] != null) {
        _showSnackbar('Profile updated successfully!');
        
        // Fetch updated details from server
        final updatedData = await ApiService.fetchVendorById(userId, token);
        if (updatedData['data'] != null) {
          await SessionService.saveSession(token, updatedData['data'] as Map<String, dynamic>);
        }
        
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        final errorMsg = result['message']?.toString() ?? 'Update failed';
        _showSnackbar('Update failed: $errorMsg');
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
        backgroundColor: message.contains('failed') || message.contains('Error') 
            ? Colors.redAccent 
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: const Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal section
                  _buildSectionTitle('Personal Details'),
                  const SizedBox(height: 16),
                  _buildTextField('Full Name', _nameController, Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField('Owner Name', _ownerNameController, Icons.storefront_rounded),
                  const SizedBox(height: 16),
                  _buildTextField('Mobile Number', _mobileController, Icons.phone_android, keyboardType: TextInputType.phone, enabled: false),
                  const SizedBox(height: 16),
                  _buildTextField('Email Address', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          child: IgnorePointer(
                            child: _buildTextField('Date of Birth', _dobController, Icons.calendar_month_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGender,
                          dropdownColor: const Color(0xFF1E293B),
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            labelStyle: const TextStyle(color: const Color(0xFFF97316)),
                            prefixIcon: const Icon(Icons.wc_outlined, color: const Color(0xFFF97316)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFF97316))),
                          ),
                          style: const TextStyle(color: const Color(0xFF0F172A)),
                          items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedGender = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Business info
                  _buildSectionTitle('Business Details'),
                  const SizedBox(height: 16),
                  _buildTextField('UPI ID', _upiController, Icons.payment),
                  const SizedBox(height: 16),
                  _buildTextField('GST Number', _gstController, Icons.receipt_long, textCapitalization: TextCapitalization.characters),
                  const SizedBox(height: 16),
                  _buildTextField('PAN Number', _panController, Icons.credit_card, textCapitalization: TextCapitalization.characters),
                  const SizedBox(height: 32),

                  // Address info
                  _buildSectionTitle('Address Details'),
                  const SizedBox(height: 16),
                  _buildTextField('Address Line 1', _address1Controller, Icons.location_on_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Address Line 2', _address2Controller, Icons.location_on_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Landmark', _landmarkController, Icons.flag_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('City', _cityController, Icons.location_city_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('District', _districtController, Icons.map_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('State', _stateController, Icons.map_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Country', _countryController, Icons.public_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Pincode', _pincodeController, Icons.pin_drop_outlined, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _addressType,
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: InputDecoration(
                      labelText: 'Address Type',
                      labelStyle: const TextStyle(color: const Color(0xFFF97316)),
                      prefixIcon: const Icon(Icons.home_work_outlined, color: const Color(0xFFF97316)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFF97316))),
                    ),
                    style: const TextStyle(color: const Color(0xFF0F172A)),
                    items: ['Work', 'Home', 'Warehouse', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _addressType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 32),

                  // Documents Upload
                  _buildSectionTitle('Profile & Verification Documents'),
                  const SizedBox(height: 20),
                  _buildImageSelector('User Image (Avatar)', 'user_image', _userImageFile, widget.userDetails['user_image']),
                  const SizedBox(height: 20),
                  _buildImageSelector('Payment QR Code', 'qr_code', _qrCodeFile, widget.userDetails['qr_code']),
                  const SizedBox(height: 20),
                  _buildImageSelector('Business Document', 'business_document', _businessDocFile, widget.userDetails['business_document']),
                  const SizedBox(height: 40),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Update Profile Details',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: const Color(0xFFF97316)),
                    SizedBox(height: 16),
                    Text('Updating profile details...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: const Color(0xFFF97316), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(width: 40, height: 3, decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(2))),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: TextStyle(color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: const Color(0xFFF97316)),
        prefixIcon: Icon(icon, color: const Color(0xFFF97316)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFF97316))),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFCBD5E1))),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }
}
