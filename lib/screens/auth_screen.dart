import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  final String _countryCode = '+91'; // Default country code
  bool _isLoading = false;
  bool _showOtpInput = false;
  String? _verificationId;
  int _timerSeconds = 60;
  Timer? _timer;

  // Session temp variables
  bool _isRegistered = false;
  int _checkMobileCode = 200;
  String _backendOtp = ''; // Store the OTP/password returned from backend check-mobile

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

    // 1. Check mobile via backend API
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

    // 2. Trigger Firebase Phone Authentication
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval or instant verification on Android
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
          message: 'Firebase Auth is not fully configured or initialized. Exception: $e',
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
      // 1. Sign in to Firebase
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        // Firebase verification succeeded!
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

  /// Flow after OTP is successfully verified (either Firebase or Fallback bypass)
  Future<void> _handlePostVerificationFlow() async {
    final mobileNum = _phoneController.text.trim();
    
    if (_isRegistered) {
      // Vendor exists, log them in using check-mobile's generated code/password
      final loginResult = await ApiService.login(mobileNum, _backendOtp);
      final code = loginResult['code'] as int? ?? 500;
      
      if (code == 200 && loginResult['data'] != null) {
        final token = loginResult['data']['token'] as String;
        final userMap = loginResult['data']['user'] as Map<String, dynamic>;
        
        // Merge root-level address list from the login response
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
      // Unregistered: Go to Registration Screen
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

  /// Show helpful dialog when Firebase auth is not configured, with test bypass.
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isRegistered
                        ? 'Backend verification code for this number is: $_backendOtp'
                        : 'This number is NOT registered. You can proceed directly to the registration page.',
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          // Demo bypass button so developer/client can test immediately without complete firebase configuration
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
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
    // Direct proceed to API login or registration
    _handlePostVerificationFlow();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1B4B), // Deep indigo
              Color(0xFF311B92), // Rich purple
              Color(0xFF0F172A), // Dark slate
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium App Logo Placeholder
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.cyan, Colors.purpleAccent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SINGLE MART',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Vendor Portal',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Interactive Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _showOtpInput
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: _buildPhoneInputWidget(theme),
                      secondChild: _buildOtpInputWidget(theme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInputWidget(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mobile Authentication',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your 10-digit mobile number to verify your identity and access your dashboard.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: const Text(
                '+91',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            hintText: 'Enter Phone Number',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
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
              elevation: 4,
            ),
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E1B4B)),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Send OTP Code',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
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
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _showOtpInput = false;
                });
              },
            ),
            const Text(
              'Enter OTP Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Text(
            'We sent a 6-digit verification code to $_countryCode ${_phoneController.text}.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 24, 
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), letterSpacing: 8),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _timerSeconds > 0
              ? Text(
                  'Resend code in $_timerSeconds seconds',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                )
              : TextButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: const Text(
                    'Resend Verification Code',
                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
        const SizedBox(height: 16),
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
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E1B4B)),
                    ),
                  )
                : const Text(
                    'Verify & Proceed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
