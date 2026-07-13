import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'pending_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String mobileNumber;

  const RegisterScreen({super.key, required this.mobileNumber});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Image Picker & Files
  final ImagePicker _imagePicker = ImagePicker();
  File? _userImageFile;
  File? _qrCodeFile;
  File? _businessDocFile;

  // Personal Info Controllers
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  String _selectedGender = 'Male';

  // Business Info Controllers
  final _upiController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();

  // Address Info Controllers
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _pincodeController = TextEditingController();
  String _addressType = 'Work';

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Color(0xFF1E1B4B),
              surface: Color(0xFF1E1B4B),
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

  /// Selects an image, compressing it to optimize network transmission
  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        // Compress files to ensure reliable network upload and lower memory footprint
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          if (type == 'user_image') {
            _userImageFile = file;
          } else if (type == 'qr_code') {
            _qrCodeFile = file;
          } else if (type == 'business_document') {
            _businessDocFile = file;
          }
        });
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verify required files are uploaded
    if (_userImageFile == null) {
      _showSnackbar('Please upload a Profile / User Image');
      return;
    }
    if (_qrCodeFile == null) {
      _showSnackbar('Please upload your Payment QR Code');
      return;
    }
    if (_businessDocFile == null) {
      _showSnackbar('Please upload your Business Document');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare form fields
      final Map<String, String> fields = {
        'name': _nameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'mobile': widget.mobileNumber,
        'email': _emailController.text.trim(),
        'gender': _selectedGender.toLowerCase(),
        'dob': _dobController.text.trim(),
        'user_type': '2',
        'user_position': 'Vendor',
        'upi_id': _upiController.text.trim(),
        'gst_number': _gstController.text.trim(),
        'pan_number': _panController.text.trim(),
        'is_verified': '0',
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

      // Prepare files
      final Map<String, File> files = {
        'user_image': _userImageFile!,
        'qr_code': _qrCodeFile!,
        'business_document': _businessDocFile!,
      };

      // Call the multipart API
      final result = await ApiService.createVendor(fields: fields, files: files);
      final code = result['code'] as int? ?? 500;

      if (code == 201 || code == 200 || result['message']?.toString().contains('Successfully') == true) {
        _showSnackbar('Registration successful! Setting up session...');
        await _autoLoginAfterRegistration();
      } else {
        final errorMessage = result['message']?.toString() ?? 'Registration failed';
        _showSnackbar('Registration failed: $errorMessage');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showSnackbar('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _autoLoginAfterRegistration() async {
    try {
      final checkResult = await ApiService.checkMobile(widget.mobileNumber);
      final checkCode = checkResult['code'] as int? ?? 500;

      if (checkCode == 200) {
        final backendOtp = checkResult['data'] as String? ?? '';
        
        final loginResult = await ApiService.login(widget.mobileNumber, backendOtp);
        final loginCode = loginResult['code'] as int? ?? 500;

        if (loginCode == 200 && loginResult['data'] != null) {
          final token = loginResult['data']['token'] as String;
          final userMap = loginResult['data']['user'] as Map<String, dynamic>;
          
          await SessionService.saveSession(token, userMap);
          
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const PendingScreen()),
              (route) => false,
            );
          }
          return;
        }
      }

      // If auto-login fails, still navigate to pending screen
      _showSnackbar('Registration complete. Please proceed to check your status.');
      final mockUser = {
        'name': _nameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'mobile': widget.mobileNumber,
        'email': _emailController.text.trim(),
        'user_type': 2,
        'user_position': 'Vendor',
        'is_verified': 0,
        'user_image': _userImageFile?.path ?? "",
        'upi_id': _upiController.text.trim(),
        'qr_code': _qrCodeFile?.path ?? "",
        'business_document': _businessDocFile?.path ?? "",
      };
      await SessionService.saveSession('offline_placeholder_token', mockUser);
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PendingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackbar('Error during auto-login: $e');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('failed') || message.contains('error') 
            ? Colors.redAccent 
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: const Text('Vendor Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.cyanAccent),
                  SizedBox(height: 16),
                  Text(
                    'Creating your account...',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Profile Image Picker
                    _buildProfileImagePicker(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('1. Personal Details', Icons.person_rounded),
                    _buildCard([
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name / Business Name',
                        icon: Icons.store,
                        validator: (v) => v!.isEmpty ? 'Business name is required' : null,
                      ),
                      _buildTextField(
                        controller: _ownerNameController,
                        label: 'Owner Name',
                        icon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? 'Owner name is required' : null,
                      ),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.isEmpty) return 'Email is required';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGenderDropdown(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: IgnorePointer(
                                child: _buildTextField(
                                  controller: _dobController,
                                  label: 'Date of Birth',
                                  icon: Icons.calendar_today,
                                  validator: (v) => v!.isEmpty ? 'Date of birth is required' : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _buildSectionHeader('2. Business Details', Icons.business_center_rounded),
                    _buildCard([
                      _buildTextField(
                        controller: _upiController,
                        label: 'UPI ID (For payments)',
                        icon: Icons.payment,
                        validator: (v) => v!.isEmpty ? 'UPI ID is required' : null,
                      ),
                      _buildTextField(
                        controller: _gstController,
                        label: 'GST Number',
                        icon: Icons.receipt_long,
                        validator: (v) => v!.isEmpty ? 'GST Number is required' : null,
                      ),
                      _buildTextField(
                        controller: _panController,
                        label: 'PAN Number',
                        icon: Icons.credit_card,
                        validator: (v) => v!.isEmpty ? 'PAN Number is required' : null,
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _buildSectionHeader('3. Required Verification Documents', Icons.document_scanner),
                    _buildCard([
                      _buildDocumentPicker(
                        label: 'Payment QR Code',
                        file: _qrCodeFile,
                        onTap: () => _pickImage('qr_code'),
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentPicker(
                        label: 'Business Registration Document',
                        file: _businessDocFile,
                        onTap: () => _pickImage('business_document'),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _buildSectionHeader('4. Address Information', Icons.location_on_rounded),
                    _buildCard([
                      _buildTextField(
                        controller: _address1Controller,
                        label: 'Address Line 1',
                        icon: Icons.location_city,
                        validator: (v) => v!.isEmpty ? 'Address Line 1 is required' : null,
                      ),
                      _buildTextField(
                        controller: _address2Controller,
                        label: 'Address Line 2',
                        icon: Icons.streetview,
                      ),
                      _buildTextField(
                        controller: _landmarkController,
                        label: 'Landmark',
                        icon: Icons.apartment,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cityController,
                              label: 'City',
                              icon: Icons.map,
                              validator: (v) => v!.isEmpty ? 'City is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _districtController,
                              label: 'District',
                              icon: Icons.terrain,
                              validator: (v) => v!.isEmpty ? 'District is required' : null,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _stateController,
                              label: 'State',
                              icon: Icons.flag,
                              validator: (v) => v!.isEmpty ? 'State is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _pincodeController,
                              label: 'Pincode',
                              icon: Icons.pin,
                              keyboardType: TextInputType.number,
                              validator: (v) => v!.isEmpty ? 'Pincode is required' : null,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _countryController,
                              label: 'Country',
                              icon: Icons.public,
                              validator: (v) => v!.isEmpty ? 'Country is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAddressTypeDropdown(),
                          ),
                        ],
                      ),
                    ]),
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
                        onPressed: _submitRegistration,
                        child: const Text(
                          'Submit Registration',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileImagePicker() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white.withOpacity(0.06),
            backgroundImage: _userImageFile != null ? FileImage(_userImageFile!) : null,
            child: _userImageFile == null
                ? const Icon(Icons.person_rounded, size: 56, color: Colors.white38)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.cyanAccent,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.camera_alt, size: 18, color: Color(0xFF1E1B4B)),
                onPressed: () => _pickImage('user_image'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPicker({
    required String label,
    required File? file,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file == null ? Colors.white24 : Colors.cyanAccent.withOpacity(0.5),
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, color: Colors.white.withOpacity(0.4), size: 32),
                  const SizedBox(height: 6),
                  Text(
                    'Upload $label',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PNG or JPG formats supported',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Preview
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                    // Dark Overlay
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black.withOpacity(0.4),
                    ),
                    // File name and Change Text
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.cyanAccent, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            '$label Uploaded',
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to change file',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
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
        children: children.expand((w) => [w, const SizedBox(height: 12)]).toList()..removeLast(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      dropdownColor: const Color(0xFF1E1B4B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(Icons.people, color: Colors.white.withOpacity(0.4), size: 20),
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
      items: ['Male', 'Female', 'Other']
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedGender = val!;
        });
      },
    );
  }

  Widget _buildAddressTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _addressType,
      dropdownColor: const Color(0xFF1E1B4B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Address Type',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(Icons.tag, color: Colors.white.withOpacity(0.4), size: 20),
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
      items: ['Work', 'Home', 'Warehouse', 'Other']
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (val) {
        setState(() {
          _addressType = val!;
        });
      },
    );
  }
}