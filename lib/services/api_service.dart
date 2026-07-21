import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<void> _attachFiles(http.MultipartRequest request, Map<String, dynamic> files) async {
    for (var entry in files.entries) {
      final fileVal = entry.value;
      if (fileVal == null) continue;

      if (kIsWeb) {
        try {
          final bytes = await (fileVal as dynamic).readAsBytes();
          final String name = (fileVal as dynamic).name ?? 'image.jpg';
          request.files.add(
            http.MultipartFile.fromBytes(
              entry.key,
              bytes,
              filename: name,
            ),
          );
        } catch (e) {
          debugPrint('Error attaching file in web: $e');
        }
      } else {
        final String path = fileVal is File ? fileVal.path : (fileVal as dynamic).path;
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            path,
          ),
        );
      }
    }
  }

  static const String baseUrl = 'https://agsdemo.in/singlemartapi/public/api';

  /// Checks if the mobile number is registered.
  /// Returns a Map containing the API response keys like 'code', 'message', 'data', etc.
  static Future<Map<String, dynamic>> checkMobile(String mobile) async {
    final url = Uri.parse('$baseUrl/check-mobile');
    try {
      final response = await http.post(
        url,
        body: {'mobile': mobile},
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Logs in the vendor using the mobile number and password (OTP).
  static Future<Map<String, dynamic>> login(String mobile, String password, {String deviceId = ''}) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        body: {
          'mobile': mobile,
          'password': password,
          'device_id': deviceId,
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }


  /// Registers a new vendor in the system using multipart form-data.
  static Future<Map<String, dynamic>> createVendor({
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/createvendor');
    try {
      final request = http.MultipartRequest('POST', url);
      
      // Set accept headers
      request.headers['Accept'] = 'application/json';
      
      // Add text fields
      request.fields.addAll(fields);
      
      await _attachFiles(request, files);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          decoded['code'] ??= response.statusCode;
          return decoded;
        } else {
          return {
            'code': response.statusCode,
            'message': 'Unexpected response format',
            'data': decoded
          };
        }
      } catch (e) {
        return {
          'code': response.statusCode,
          'message': 'Failed to parse response: $e',
          'body': response.body
        };
      }
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches a vendor by their ID.
  static Future<Map<String, dynamic>> fetchVendorById(int id, String token) async {
    final url = Uri.parse('$baseUrl/vendor/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches approved vendors list. Fallback to activeVendors if the endpoint is crashed on the server.
  static Future<Map<String, dynamic>> fetchApprovedVendors(String token) async {
    final url = Uri.parse('$baseUrl/vendor');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // If the primary route crashes on the server, try fallback route /activeVendors
      if (response.statusCode != 200) {
        final fallbackUrl = Uri.parse('$baseUrl/activeVendors');
        final fallbackResponse = await http.get(
          fallbackUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        if (fallbackResponse.statusCode == 200) {
          final decoded = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
          return {
            'code': 200,
            'message': 'Loaded from fallback activeVendors.',
            'data': decoded['data'] ?? []
          };
        }
      }
      
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      decoded['code'] ??= response.statusCode;
      return decoded;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches pending vendors list.
  static Future<Map<String, dynamic>> fetchPendingVendors(String token) async {
    final url = Uri.parse('$baseUrl/pendingVendor');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      decoded['code'] ??= response.statusCode;
      return decoded;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Approves a pending vendor.
  static Future<Map<String, dynamic>> approveVendor(int id, String token) async {
    final url = Uri.parse('$baseUrl/update-vendor-approve/$id');
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      decoded['code'] ??= response.statusCode;
      return decoded;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a vendor's status.
  static Future<Map<String, dynamic>> updateVendorStatus(int id, String status, String token) async {
    final url = Uri.parse('$baseUrl/vendors/$id/status');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          'status': status,
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      decoded['code'] ??= response.statusCode;
      return decoded;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a vendor in the system using multipart form-data.
  static Future<Map<String, dynamic>> updateVendor({
    required int id,
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/vendor/$id');
    try {
      final request = http.MultipartRequest('POST', url);
      
      // Authorization and accept headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      
      // Add text fields
      request.fields.addAll(fields);
      request.fields['_method'] = 'PUT'; // Laravel method spoofing for multipart PUT
      
      await _attachFiles(request, files);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          decoded['code'] ??= response.statusCode;
          return decoded;
        } else {
          return {
            'code': response.statusCode,
            'message': 'Unexpected response format',
            'data': decoded
          };
        }
      } catch (e) {
        return {
          'code': response.statusCode,
          'message': 'Failed to parse response: $e',
          'body': response.body
        };
      }
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Logs out the user using their Bearer token.
  static Future<Map<String, dynamic>> logout(String token) async {
    final url = Uri.parse('$baseUrl/app-logout');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches the category list.
  static Future<Map<String, dynamic>> fetchCategories(String token) async {
    final url = Uri.parse('$baseUrl/category');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches a category by its ID.
  static Future<Map<String, dynamic>> fetchCategoryById(int id, String token) async {
    final url = Uri.parse('$baseUrl/category/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Creates a new category with subcategories.
  static Future<Map<String, dynamic>> createCategory({
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/category');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a category using multipart form-data.
  static Future<Map<String, dynamic>> updateCategory({
    required int id,
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/category/$id');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.fields['_method'] = 'PUT'; // Laravel method spoofing

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a category's status (Active/Inactive).
  static Future<Map<String, dynamic>> updateCategoryStatus({
    required int id,
    required String token,
    required String status,
  }) async {
    final url = Uri.parse('$baseUrl/categorys/$id/status');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'categories_status': status}),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches active categories.
  static Future<Map<String, dynamic>> fetchActiveCategories() async {
    final url = Uri.parse('$baseUrl/activeCategories');
    try {
      final response = await http.get(url);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches active subcategories.
  static Future<Map<String, dynamic>> fetchActiveSubCategories() async {
    final url = Uri.parse('$baseUrl/activeSubCategories');
    try {
      final response = await http.get(url);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches all brands.
  static Future<Map<String, dynamic>> fetchBrands(String token) async {
    final url = Uri.parse('$baseUrl/brand');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches a brand by ID.
  static Future<Map<String, dynamic>> fetchBrandById(int id, String token) async {
    final url = Uri.parse('$baseUrl/brand/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Creates a new brand using multipart form-data.
  static Future<Map<String, dynamic>> createBrand({
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/brand');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a brand using multipart form-data (POST with PUT method spoofing).
  static Future<Map<String, dynamic>> updateBrand({
    required int id,
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/brand/$id');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.fields['_method'] = 'PUT'; // Laravel method spoofing

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a brand's status (Active/Inactive).
  static Future<Map<String, dynamic>> updateBrandStatus({
    required int id,
    required String token,
    required String status,
  }) async {
    final url = Uri.parse('$baseUrl/brands/$id/status');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'brands_status': status,
          'status': status,
        }),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches active brands.
  static Future<Map<String, dynamic>> fetchActiveBrands() async {
    final url = Uri.parse('$baseUrl/activeBrands');
    try {
      final response = await http.get(url);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches all products.
  static Future<Map<String, dynamic>> fetchProducts(String token) async {
    final url = Uri.parse('$baseUrl/product');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches a product by ID.
  static Future<Map<String, dynamic>> fetchProductById(int id, String token) async {
    final url = Uri.parse('$baseUrl/product/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Creates a new product using multipart form-data.
  static Future<Map<String, dynamic>> createProduct({
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/product');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a product using multipart form-data (POST with PUT method spoofing).
  static Future<Map<String, dynamic>> updateProduct({
    required int id,
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/product/$id');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.fields['_method'] = 'PUT'; // Laravel method spoofing

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches all banners.
  static Future<Map<String, dynamic>> fetchBanners(String token) async {
    final url = Uri.parse('$baseUrl/banner');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches a banner by ID.
  static Future<Map<String, dynamic>> fetchBannerById(int id, String token) async {
    final url = Uri.parse('$baseUrl/banner/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Creates a banner using multipart form-data.
  static Future<Map<String, dynamic>> createBanner({
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/banner');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a banner using multipart form-data (POST with PUT spoofing).
  static Future<Map<String, dynamic>> updateBanner({
    required int id,
    required String token,
    required Map<String, String> fields,
    required Map<String, dynamic> files,
  }) async {
    final url = Uri.parse('$baseUrl/banner/$id');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.fields['_method'] = 'PUT';

      await _attachFiles(request, files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded['code'] ??= response.statusCode;
        return decoded;
      }
      return {'code': response.statusCode, 'message': 'Success', 'data': decoded};
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates a banner's status.
  static Future<Map<String, dynamic>> updateBannerStatus({
    required int id,
    required String token,
    required String status,
  }) async {
    final url = Uri.parse('$baseUrl/banners/$id/status');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'banner_status': status,
          'status': status,
        }),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Deletes an address by ID.
  static Future<Map<String, dynamic>> deleteAddress({
    required int id,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/delete-address/$id');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches the list of orders.
  static Future<Map<String, dynamic>> fetchOrders(String token) async {
    final url = Uri.parse('$baseUrl/order');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches an order by its ID.
  static Future<Map<String, dynamic>> fetchOrderById(int id, String token) async {
    final url = Uri.parse('$baseUrl/order/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches the list of possible order statuses.
  static Future<Map<String, dynamic>> fetchOrderStatus() async {
    final url = Uri.parse('$baseUrl/fetchOrderStatus');
    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates the payment status of an order sub-item.
  static Future<Map<String, dynamic>> updateOrderPaymentStatus(int subId, String paymentStatus, String token) async {
    final url = Uri.parse('$baseUrl/orders/$subId/payment-status');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'payment_status': paymentStatus,
        }),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates the order status of an order sub-item.
  static Future<Map<String, dynamic>> updateOrderStatus(int subId, String orderStatus, String token) async {
    final url = Uri.parse('$baseUrl/orders/$subId/status');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'order_status': orderStatus,
        }),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches all product reviews.
  static Future<Map<String, dynamic>> fetchProductReviews(String token) async {
    final url = Uri.parse('$baseUrl/product-review');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Deletes a product review by ID.
  static Future<Map<String, dynamic>> deleteProductReview(int id, String token) async {
    final url = Uri.parse('$baseUrl/product-review/$id');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches all attributes.
  static Future<Map<String, dynamic>> fetchAttributes(String token) async {
    final url = Uri.parse('$baseUrl/attribute');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Fetches attribute by ID.
  static Future<Map<String, dynamic>> fetchAttributeById(int id, String token) async {
    final url = Uri.parse('$baseUrl/attribute/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Creates a new attribute.
  static Future<Map<String, dynamic>> createAttribute(String token, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl/attribute');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates an attribute.
  static Future<Map<String, dynamic>> updateAttribute(int id, String token, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl/attribute/$id');
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }

  /// Updates status of an attribute.
  static Future<Map<String, dynamic>> updateAttributeStatus({
    required int id,
    required String token,
    required String status,
  }) async {
    final url = Uri.parse('$baseUrl/attributes/$id/status');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'attribute_status': status,
        }),
      );
      if (response.body.isEmpty) {
        return {'code': response.statusCode, 'message': 'No response body'};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'code': 500, 'message': 'Connection error: $e'};
    }
  }
}
