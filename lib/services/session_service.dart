import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String keyToken = 'auth_token';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyIsVerified = 'is_verified';
  static const String keyMobile = 'user_mobile';
  static const String keyUserDetails = 'user_details';

  /// Saves the user details and token to shared preferences.
  static Future<void> saveSession(String token, Map<String, dynamic> userDetails) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyToken, token);
    await prefs.setBool(keyIsLoggedIn, true);
    await prefs.setInt(keyIsVerified, userDetails['is_verified'] as int? ?? 0);
    await prefs.setString(keyMobile, userDetails['mobile'] as String? ?? '');
    await prefs.setString(keyUserDetails, jsonEncode(userDetails));
  }

  /// Updates the verification status in the session.
  static Future<void> updateVerificationStatus(int isVerified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyIsVerified, isVerified);
    
    // Also update the nested userDetails JSON if it exists
    final detailsStr = prefs.getString(keyUserDetails);
    if (detailsStr != null) {
      try {
        final details = jsonDecode(detailsStr) as Map<String, dynamic>;
        details['is_verified'] = isVerified;
        await prefs.setString(keyUserDetails, jsonEncode(details));
      } catch (_) {}
    }
  }

  /// Clears the session.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
    await prefs.remove(keyIsLoggedIn);
    await prefs.remove(keyIsVerified);
    await prefs.remove(keyMobile);
    await prefs.remove(keyUserDetails);
  }

  /// Returns the stored token.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyToken);
  }

  /// Checks if the user is logged in.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsLoggedIn) ?? false;
  }

  /// Returns the verification status. (1 = Verified, 0 = Pending/Unverified)
  static Future<int> getVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyIsVerified) ?? 0;
  }

  /// Returns the stored mobile number.
  static Future<String?> getMobile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyMobile);
  }

  /// Returns the parsed user details Map.
  static Future<Map<String, dynamic>?> getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final detailsStr = prefs.getString(keyUserDetails);
    if (detailsStr == null) return null;
    try {
      return jsonDecode(detailsStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
