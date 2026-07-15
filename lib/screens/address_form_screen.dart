import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic> userDetails;
  final List<dynamic> addressesList;
  final Map<String, dynamic>? addressToEdit; // Null if adding

  const AddressFormScreen({
    super.key,
    required this.userDetails,
    required this.addressesList,
    this.addressToEdit,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;

  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _pincodeController = TextEditingController();

  String _selectedType = 'Shop';
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.addressToEdit != null;
    if (_isEditMode) {
      final addr = widget.addressToEdit!;
      _line1Controller.text = addr['address_line_1']?.toString() ?? '';
      _line2Controller.text = addr['address_line_2']?.toString() ?? '';
      _landmarkController.text = addr['landmark']?.toString() ?? '';
      _cityController.text = addr['city']?.toString() ?? '';
      _districtController.text = addr['district']?.toString() ?? '';
      _stateController.text = addr['state']?.toString() ?? '';
      _countryController.text = addr['country']?.toString() ?? 'India';
      _pincodeController.text = addr['pincode']?.toString() ?? '';
      
      final rawType = addr['address_type']?.toString() ?? 'Shop';
      if (['Shop', 'Work', 'Home'].contains(rawType)) {
        _selectedType = rawType;
      }
      _isDefault = (addr['is_default'] == 1 || addr['is_default'] == '1');
    } else {
      // If first address, default to true
      _isDefault = widget.addressesList.isEmpty;
    }
  }

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      final userId = widget.userDetails['id'] as int?;
      if (token == null || userId == null) return;

      // Compile current user profile fields
      final Map<String, String> fields = {
        'name': widget.userDetails['name']?.toString() ?? '',
        'owner_name': widget.userDetails['owner_name']?.toString() ?? '',
        'mobile': widget.userDetails['mobile']?.toString() ?? '',
        'email': widget.userDetails['email']?.toString() ?? '',
        'gender': (widget.userDetails['gender']?.toString() ?? 'male').toLowerCase(),
        'dob': widget.userDetails['dob']?.toString() ?? '',
        'upi_id': widget.userDetails['upi_id']?.toString() ?? '',
        'gst_number': widget.userDetails['gst_number']?.toString() ?? '',
        'pan_number': widget.userDetails['pan_number']?.toString() ?? '',
        'user_type': widget.userDetails['user_type']?.toString() ?? '2',
        'user_position': widget.userDetails['user_position']?.toString() ?? 'Vendor',
        'status': widget.userDetails['status']?.toString() ?? 'Active',
      };

      // Create a copy of the addresses list
      final List<Map<String, dynamic>> finalAddresses = [];

      if (_isEditMode) {
        // Mode A: Editing an existing address in the list
        for (var item in widget.addressesList) {
          final addr = Map<String, dynamic>.from(item as Map);
          if (addr['id'] == widget.addressToEdit!['id']) {
            addr['address_line_1'] = _line1Controller.text.trim();
            addr['address_line_2'] = _line2Controller.text.trim();
            addr['landmark'] = _landmarkController.text.trim();
            addr['city'] = _cityController.text.trim();
            addr['district'] = _districtController.text.trim();
            addr['state'] = _stateController.text.trim();
            addr['country'] = _countryController.text.trim();
            addr['pincode'] = _pincodeController.text.trim();
            addr['address_type'] = _selectedType;
            addr['is_default'] = _isDefault ? 1 : 0;
          } else {
            // If the edited address was set to default, set others to 0
            if (_isDefault) {
              addr['is_default'] = 0;
            }
          }
          finalAddresses.add(addr);
        }
      } else {
        // Mode B: Adding a new address to the list
        for (var item in widget.addressesList) {
          final addr = Map<String, dynamic>.from(item as Map);
          if (_isDefault) {
            addr['is_default'] = 0;
          }
          finalAddresses.add(addr);
        }

        // Add the new address record
        finalAddresses.add({
          'address_line_1': _line1Controller.text.trim(),
          'address_line_2': _line2Controller.text.trim(),
          'landmark': _landmarkController.text.trim(),
          'city': _cityController.text.trim(),
          'district': _districtController.text.trim(),
          'state': _stateController.text.trim(),
          'country': _countryController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'address_type': _selectedType,
          'is_default': _isDefault ? 1 : 0,
        });
      }

      // Add addresses array fields
      for (int i = 0; i < finalAddresses.length; i++) {
        final addr = finalAddresses[i];
        if (addr['id'] != null) {
          fields['addresses[$i][id]'] = addr['id'].toString();
        }
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

      final response = await ApiService.updateVendor(
        id: userId,
        token: token,
        fields: fields,
        files: {},
      );

      final code = response['code'] as int? ?? 500;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar(_isEditMode ? 'Address updated!' : 'Address added!');
        if (mounted) {
          Navigator.pop(context, finalAddresses);
        }
      } else {
        _showSnackbar('Submission failed: ${response['message']}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        title: Text(
          _isEditMode ? 'Edit Address' : 'Add Address',
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
                          DropdownButtonFormField<String>(
                            value: _selectedType,
                            dropdownColor: const Color(0xFF1E1B4B),
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Address Type', Icons.home_work_outlined),
                            items: const [
                              DropdownMenuItem(value: 'Shop', child: Text('Shop')),
                              DropdownMenuItem(value: 'Work', child: Text('Work')),
                              DropdownMenuItem(value: 'Home', child: Text('Home')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedType = val!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _line1Controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Address Line 1', Icons.location_on_outlined),
                            validator: (v) => v!.isEmpty ? 'Address Line 1 is required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _line2Controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Address Line 2', Icons.location_on_outlined),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _landmarkController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Landmark', Icons.pin_drop_outlined),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cityController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _buildInputDecoration('City', Icons.location_city_outlined),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _districtController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _buildInputDecoration('District', Icons.map_outlined),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _stateController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _buildInputDecoration('State', Icons.explore_outlined),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _pincodeController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration('Pincode', Icons.pin_outlined),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _countryController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration('Country', Icons.public_outlined),
                            validator: (v) => v!.isEmpty ? 'Country is required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Set as Default Address', style: TextStyle(color: Colors.white, fontSize: 15)),
                      subtitle: Text(
                        'This will make this address the primary shop address.',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                      ),
                      value: _isDefault,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) {
                        // If it's the first or only address, it must stay default
                        if (!val && widget.addressesList.isEmpty) return;
                        setState(() {
                          _isDefault = val;
                        });
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
                          _isEditMode ? 'Update Address' : 'Save Address',
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
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
      filled: true,
      fillColor: Colors.white.withOpacity(0.02),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
    );
  }
}
