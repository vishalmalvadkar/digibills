import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_helper.dart'; 
import '../utils/validators.dart'; 
import 'sign_up_screen.dart';
import 'settings/manage_users/staff_setup_screen.dart'; // NEW
import '../utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart'; // For Home Button navigation
import 'package:universal_html/html.dart' as html; // For robust web navigation
import 'package:flutter/foundation.dart'; // For kIsWeb check

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ... (Keep existing state variables)
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _stayLoggedIn = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stayLoggedIn = prefs.getBool('stayLoggedIn') ?? false;
    });
  }

  // ... (Keep existing _login, _forgotPassword methods) 
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    bool isEmailValid = email.isNotEmpty && RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    bool isPasswordValid = password.isNotEmpty;

    if (!isEmailValid || !isPasswordValid) {
      String errorMessage;
      if (!isEmailValid && !isPasswordValid) {
        errorMessage = 'Email ID and Password both are invalid';
      } else if (!isEmailValid) {
        errorMessage = 'Invalid Email ID';
      } else {
        errorMessage = 'Invalid Password';
      }
      SnackbarHelper.showError(context, errorMessage);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stayLoggedIn', _stayLoggedIn);

      await _authService.signIn(email, password);
    } on AuthException catch (e) {
      String message = e.message;
      // Handle server-side credential failure with the consolidated message
      if (e.message.toLowerCase().contains('invalid') || e.message.toLowerCase().contains('credentials')) {
        message = 'Email ID and Password both are invalid';
      }
      
      if (mounted) {
        SnackbarHelper.showError(context, message);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _forgotPassword() async {
      // ... Keep existing logic
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address first')),
      );
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Responsive(
            mobile: _buildMobileLayout(),
            tablet: _buildDesktopLayout(),
            desktop: _buildDesktopLayout(),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: TextButton.icon(
                onPressed: () async {
                  if (kIsWeb) {
                    // ROBUST WEB NAVIGATION
                    // Use universal_html to force navigation to the landing page
                    final String landingPageUrl = 'landing_page/index.html';
                    
                    // Option 1: Open in same tab (acts like a redirect)
                    html.window.open(landingPageUrl, '_self');
                    
                    // Option 2 (Alternative if popups blocked):
                    // html.window.location.href = landingPageUrl;
                  } else {
                    // Mobile Fallback (Requires absolute URL or local file handling)
                    final Uri url = Uri.parse('https://digibills-c97a9.web.app/landing_page/index.html'); 
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                       debugPrint('Could not launch $url');
                    }
                  }
                },
                icon: const Icon(Icons.home_rounded, color: AppColors.primary),
                label: const Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 2,
                  shadowColor: Colors.black12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/icon/splash_logo.png', height: 120),
              const SizedBox(height: 24),
              const Text(
                'Sign in to manage your bills',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textGrey),
              ),
              const SizedBox(height: 48),
              _buildLoginForm(),
              const SizedBox(height: 48),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Side: Image Section (Indian Theme)
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Indian-themed business image
                Image.asset(
                  'assets/images/lsdi.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, Color(0xFF1E40AF)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.business_center, color: Colors.white24, size: 120),
                    ),
                  ),
                ),
                // Overlay for better text readability if needed
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.4),
                        ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Side: Form
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(64),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, // Center-align section
                  children: [
                    // DigiInvi Logo atop the Welcome message
                    Image.asset('assets/icon/splash_logo.png', height: 100),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.textDark, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please enter your details to sign in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 48),
                    _buildLoginForm(),
                    const SizedBox(height: 48),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildLoginForm() {
    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _stayLoggedIn,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) => setState(() => _stayLoggedIn = val ?? false),
            ),
            const Text('Stay Logged In', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500)),
            const Spacer(),
            TextButton(
              onPressed: _forgotPassword,
              child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'DigiInvi v1.0 . DigiWebia. Made in India ',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(width: 4),
            _buildIndiaFlag(),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ", style: TextStyle(color: AppColors.textGrey)),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
              },
              child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        /*
        TextButton.icon(
          onPressed: () {
             Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StaffSetupScreen()));
          },
          icon: const Icon(Icons.verified_user_outlined, size: 18),
          label: const Text('Staff First Time Login'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
        */
      ],
    );
  }


  Widget _buildIndiaFlag() {
    return Container(
      width: 16,
      height: 12,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, width: 0.5)),
      child: Column(
        children: [
          Expanded(child: Container(color: const Color(0xFFFF9933))),
          Expanded(
            child: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(color: Color(0xFF000080), shape: BoxShape.circle),
              ),
            ),
          ),
          Expanded(child: Container(color: const Color(0xFF138808))),
        ],
      ),
    );
  }
}
