import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _userDetails;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final details = await SessionService.getUserDetails();
    if (mounted) {
      setState(() {
        _userDetails = details;
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isLoading = true;
    });

    final mobile = await SessionService.getMobile();
    if (mobile == null || mobile.isEmpty) {
      _showSnackbar('Session error: mobile number not found.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // 1. Fetch password from check-mobile
    final checkResult = await ApiService.checkMobile(mobile);
    final checkCode = checkResult['code'] as int? ?? 500;

    if (checkCode == 200) {
      final password = checkResult['data'] as String? ?? '';
      
      // 2. Perform Login to get latest user status
      final loginResult = await ApiService.login(mobile, password);
      final loginCode = loginResult['code'] as int? ?? 500;

      if (loginCode == 200 && loginResult['data'] != null) {
        final token = loginResult['data']['token'] as String;
        final userMap = loginResult['data']['user'] as Map<String, dynamic>;
        
        await SessionService.saveSession(token, userMap);
        _loadUserDetails();

        final isVerified = userMap['is_verified'] as int? ?? 0;

        if (isVerified == 1) {
          _showSnackbar('Congratulations! Your application has been approved.');
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
            );
          }
          return;
        } else {
          _showSnackbar('Your application is still under review.');
        }
      } else {
        _showSnackbar('Unable to fetch status: ${loginResult['message'] ?? 'Login failed'}');
      }
    } else {
      _showSnackbar('Server error checking status: ${checkResult['message'] ?? 'Check failed'}');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    final token = await SessionService.getToken();
    if (token != null && token != 'offline_placeholder_token') {
      await ApiService.logout(token);
    }

    await SessionService.clearSession();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
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

  @override
  Widget build(BuildContext context) {
    final displayName = _userDetails?['owner_name'] ?? _userDetails?['name'] ?? 'Vendor';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Warning / Pending Icon with glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.06),
                  border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    size: 64,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Hello, $displayName!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Application Pending Approval',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Your registration has been submitted successfully. The administrator is currently reviewing your business documents and details. You will gain access to your vendor dashboard once approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF0F172A).withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Refresh Status button
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
                  onPressed: _isLoading ? null : _refreshStatus,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded),
                            SizedBox(width: 8),
                            Text(
                              'Refresh Application Status',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const Spacer(),
              // Logout Button
              TextButton.icon(
                onPressed: _isLoading ? null : _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'Logout & Sign In as Different User',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
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
