import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
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
    required Map<String, File> files,
  }) async {
    final url = Uri.parse('$baseUrl/createvendor');
    try {
      final request = http.MultipartRequest('POST', url);
      
      // Set accept headers
      request.headers['Accept'] = 'application/json';
      
      // Add text fields
      request.fields.addAll(fields);
      
      // Add files using fromPath (matching backend suggestion)
      for (var entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
          ),
        );
      }
      
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

  /// Updates a vendor in the system using multipart form-data.
  static Future<Map<String, dynamic>> updateVendor({
    required int id,
    required String token,
    required Map<String, String> fields,
    required Map<String, File> files,
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
      
      // Add files using fromPath
      for (var entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
          ),
        );
      }
      
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
    required Map<String, File> files,
  }) async {
    final url = Uri.parse('$baseUrl/category');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      for (var entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
          ),
        );
      }

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
    required Map<String, File> files,
  }) async {
    final url = Uri.parse('$baseUrl/category/$id');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.fields['_method'] = 'PUT'; // Laravel method spoofing

      for (var entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
          ),
        );
      }

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
    required Map<String, File> files,
  }) async {
    final url = Uri.parse('$baseUrl/brand');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      for (var entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
          ),
        );
      }

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
    required Map<String, File> files,
  }) async {
    final url = Uri.parse('$baseUrl/brand/$id');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.fields['_method'] = 'PUT'; // Laravel method spoofing

      for (var entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
          ),
        );
      }

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
}
