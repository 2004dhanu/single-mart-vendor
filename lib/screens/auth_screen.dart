import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'register_screen.dart';
import 'pending_screen.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  final String _countryCode = '+91';
  bool _isLoading = false;
  bool _showOtpInput = false;
  String? _verificationId;
  int _timerSeconds = 60;
  Timer? _timer;

  bool _isRegistered = false;
  int _checkMobileCode = 200;
  String _backendOtp = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _timerSeconds--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    final mobileNum = _phoneController.text.trim();
    if (mobileNum.length != 10 || int.tryParse(mobileNum) == null) {
      _showSnackbar('Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final checkResult = await ApiService.checkMobile(mobileNum);
    _checkMobileCode = checkResult['code'] as int? ?? 500;

    if (_checkMobileCode == 200) {
      _isRegistered = true;
      _backendOtp = checkResult['data'] as String? ?? '';
    } else if (_checkMobileCode == 401) {
      _isRegistered = false;
      _backendOtp = '';
    } else {
      _showSnackbar('Server Error: ${checkResult['message'] ?? 'Unknown error'}');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final fullPhone = '$_countryCode$mobileNum';

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          _showFirebaseErrorDialog(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
            _showOtpInput = true;
          });
          _startTimer();
          _showSnackbar('Verification code sent successfully.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showFirebaseErrorDialog(
        FirebaseAuthException(
          code: 'exception',
          message: 'Firebase Auth is not fully configured. Exception: $e',
        ),
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      _showSnackbar('Please enter a valid 6-digit verification code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_verificationId == null) {
      _showSnackbar('Verification session expired. Please resend code.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackbar('Invalid verification code. Please try again.');
    }
  }

  Future<void> _signInWithCredential(AuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _handlePostVerificationFlow();
      } else {
        throw Exception('Firebase login failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackbar('Firebase Authentication failed: $e');
    }
  }

  Future<void> _handlePostVerificationFlow() async {
    final mobileNum = _phoneController.text.trim();
    
    if (_isRegistered) {
      String fcmToken = '';
     
      try {
        
        fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
         debugPrint("====================");
debugPrint("FCM TOKEN:");
debugPrint(fcmToken);
debugPrint("====================");
      } catch (e) {
        debugPrint('FCM Token error: $e');
      }
      final loginResult = await ApiService.login(mobileNum, _backendOtp, deviceId: fcmToken);
      final code = loginResult['code'] as int? ?? 500;
      
      if (code == 200 && loginResult['data'] != null) {
        final token = loginResult['data']['token'] as String;
        final userMap = loginResult['data']['user'] as Map<String, dynamic>;
        
        final addressList = loginResult['address'] as List<dynamic>? ?? [];
        userMap['addresses'] = addressList;
        
        await SessionService.saveSession(token, userMap);
        
        final isVerified = userMap['is_verified'] as int? ?? 0;
        final isAdmin = userMap['user_type'] == 3 || userMap['user_position'] == 'Admin';
        
        if (mounted) {
          if (isAdmin) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              (route) => false,
            );
          } else if (isVerified == 1) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const PendingScreen()),
              (route) => false,
            );
          }
        }
      } else {
        _showSnackbar('Failed to log in to API: ${loginResult['message'] ?? 'Login failed'}');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RegisterScreen(mobileNumber: mobileNum),
          ),
        );
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showFirebaseErrorDialog(FirebaseAuthException e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Firebase Configuration'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Firebase Phone Authentication is not configured or failed.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),
              Text('Error details: ${e.message ?? e.code}'),
              const SizedBox(height: 15),
              const Text(
                'To use live Firebase OTP: Make sure SHA-1/SHA-256 fingerprint is added in Firebase console, and Phone Auth is enabled.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              if (_backendOtp.isNotEmpty || _checkMobileCode == 401)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isRegistered
                        ? 'Backend verification code for this number is: $_backendOtp'
                        : 'This number is NOT registered. You can proceed directly to the registration page.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _bypassFirebaseForTesting();
            },
            child: const Text('Use Test Bypass'),
          ),
        ],
      ),
    );
  }

  void _bypassFirebaseForTesting() {
    _showSnackbar('Bypassing Firebase Auth for local API testing...');
    setState(() {
      _isLoading = true;
    });
    _handlePostVerificationFlow();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width > 900;
    
    final Widget formCard = Container(
      width: isDesktop ? 450 : double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        crossFadeState: _showOtpInput
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: _buildPhoneInputWidget(theme),
        secondChild: _buildOtpInputWidget(theme),
      ),
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Row(
          children: [
            // Left Side Panel: Branding & Marketing info
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFEA580C),
                      Color(0xFFF97316),
                      Color(0xFFFF9D43),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 48,
                        color: Color(0xFFF97316),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'SINGLE MART',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      'Vendor Management Portal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildBenefitItem(
                      Icons.inventory_2_outlined,
                      'Easy Catalog Management',
                      'Add and update products, categories, subcategories and attributes in real-time.',
                    ),
                    const SizedBox(height: 24),
                    _buildBenefitItem(
                      Icons.analytics_outlined,
                      'Sales & Statistics Overview',
                      'Monitor store health, inventory levels and user statistics directly from the dashboard.',
                    ),
                    const SizedBox(height: 24),
                    _buildBenefitItem(
                      Icons.shopping_bag_outlined,
                      'Seamless Order Processing',
                      'Manage pending registrations and approved vendor orders without hassles.',
                    ),
                  ],
                ),
              ),
            ),
            
            // Right Side Panel: Interactive Form
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        formCard,
                        const SizedBox(height: 24),
                        Text(
                          '© 2026 Single Mart. All rights reserved.',
                          style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.4), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet layout
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFBEB),
              Color(0xFFFFF7ED),
              Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withOpacity(0.1),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 40,
                      color: Color(0xFFF97316),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SINGLE MART',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Vendor Portal',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFF97316),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  formCard,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInputWidget(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mobile Authentication',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your 10-digit mobile number to verify your identity and access your dashboard.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: const Text(
                '+91',
                style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            hintText: 'Enter Phone Number',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Send OTP Code',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInputWidget(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF475569)),
              onPressed: () {
                setState(() {
                  _showOtpInput = false;
                });
              },
            ),
            const Text(
              'Enter OTP Code',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Text(
            'We sent a 6-digit verification code to $_countryCode ${_phoneController.text}.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: const TextStyle(color: Color(0xFFCBD5E1), letterSpacing: 8),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _timerSeconds > 0
              ? Text(
                  'Resend code in $_timerSeconds seconds',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                )
              : TextButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: const Text(
                    'Resend Verification Code',
                    style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Verify & Proceed',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
