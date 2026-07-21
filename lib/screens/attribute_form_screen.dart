import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class AttributeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? attribute;

  const AttributeFormScreen({super.key, this.attribute});

  @override
  State<AttributeFormScreen> createState() => _AttributeFormScreenState();
}

class _AttributeFormScreenState extends State<AttributeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String _status = 'Active';
  bool _isLoading = false;
  bool _isEditMode = false;

  // List of sub-attribute values
  // Each entry is a Map: {'id': int?, 'controller': TextEditingController}
  final List<Map<String, dynamic>> _values = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.attribute != null;
    if (_isEditMode) {
      _nameController.text = widget.attribute!['attribute_name'] ?? '';
      _status = widget.attribute!['attribute_status'] ?? 'Active';
      _loadAttributeDetails();
    } else {
      // Start with one empty value text field by default
      _addValueField();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var val in _values) {
      (val['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _loadAttributeDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      final id = widget.attribute!['id'] as int;
      final response = await ApiService.fetchAttributeById(id, token);
      final code = response['code'] as int? ?? 200;
      if (code == 200 && response['data'] != null) {
        final detail = response['data'] as Map<String, dynamic>;
        final list = detail['values'] as List<dynamic>? ?? [];
        
        setState(() {
          _values.clear();
          for (var item in list) {
            _values.add({
              'id': item['id'],
              'controller': TextEditingController(text: item['attribute_value'] ?? ''),
            });
          }
          // If empty, add at least one empty field
          if (_values.isEmpty) {
            _addValueField();
          }
        });
      }
    } catch (e) {
      _showSnackbar('Error loading details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addValueField() {
    setState(() {
      _values.add({
        'id': null,
        'controller': TextEditingController(),
      });
    });
  }

  void _removeValueField(int index) {
    if (_values.length <= 1) {
      _showSnackbar('At least one sub attribute value is required.');
      return;
    }
    setState(() {
      final removed = _values.removeAt(index);
      (removed['controller'] as TextEditingController).dispose();
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if there's at least one non-empty value
    final nonKeys = _values.where((v) => (v['controller'] as TextEditingController).text.trim().isNotEmpty).toList();
    if (nonKeys.isEmpty) {
      _showSnackbar('At least one non-empty sub-attribute value is required.');
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

      // Build JSON request body
      final valuesPayload = _values.map((v) {
        final map = <String, dynamic>{
          'attribute_value': (v['controller'] as TextEditingController).text.trim(),
        };
        if (v['id'] != null) {
          map['id'] = v['id'];
        }
        return map;
      }).toList();

      final body = <String, dynamic>{
        'attribute_name': _nameController.text.trim(),
        'attribute_status': _status,
        'values': valuesPayload,
      };

      Map<String, dynamic> response;
      if (_isEditMode) {
        final id = widget.attribute!['id'] as int;
        response = await ApiService.updateAttribute(id, token, body);
      } else {
        response = await ApiService.createAttribute(token, body);
      }

      final code = response['code'] as int? ?? 200;
      if (code == 200 || code == 201 || response['message']?.toString().contains('Successfully') == true) {
        _showSnackbar(_isEditMode ? 'Attribute updated successfully!' : 'Attribute created successfully!');
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showSnackbar(response['message']?.toString() ?? 'Failed to submit form');
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
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: const Color(0xFF0F172A)),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.6)),
        prefixIcon: Icon(icon, color: const Color(0xFFF97316), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: const Color(0xFFF97316)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.01),
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
        title: Text(
          _isEditMode ? 'Edit Attribute' : 'Add Attribute',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check, color: const Color(0xFFF97316)),
              onPressed: _saveForm,
            ),
        ],
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
                    _buildSectionHeader('General Info', Icons.info_outline),
                    _buildCard([
                      _buildTextField(
                        controller: _nameController,
                        label: 'Attribute Name',
                        icon: Icons.label_outline,
                        validator: (v) => v!.isEmpty ? 'Attribute name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _status,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.6)),
                          prefixIcon: const Icon(Icons.info_outline, color: const Color(0xFFF97316), size: 20),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: const Color(0xFFF97316)),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Active', child: Text('Active')),
                          DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _status = val;
                            });
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Sub Attribute Values', Icons.tune_rounded),
                        TextButton.icon(
                          onPressed: _addValueField,
                          icon: const Icon(Icons.add, color: const Color(0xFFF97316), size: 18),
                          label: const Text('Add Value', style: TextStyle(color: const Color(0xFFF97316))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _values.length,
                      itemBuilder: (context, index) {
                        final valCtrl = _values[index]['controller'] as TextEditingController;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: valCtrl,
                                  label: 'Value (e.g. Red, 8GB, Medium)',
                                  icon: Icons.subdirectory_arrow_right_rounded,
                                  validator: (v) => v!.isEmpty ? 'Value is required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () => _removeValueField(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [const Color(0xFFF97316), const Color(0xFFF97316)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saveForm,
                        child: Text(
                          _isEditMode ? 'Update Attribute' : 'Create Attribute',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
