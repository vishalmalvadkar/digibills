import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../services/auth_service.dart';

class StaffSetupScreen extends StatefulWidget {
  const StaffSetupScreen({super.key});

  @override
  State<StaffSetupScreen> createState() => _StaffSetupScreenState();
}

class _StaffSetupScreenState extends State<StaffSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _isVerified = false; // Step 1: Email verified?
  bool _obscurePass = true;
  String? _staffName;

  final _supabase = Supabase.instance.client;

  // Step 1: Verify Email
  Future<void> _verifyEmail() async {
    if (_emailCtrl.text.trim().isEmpty) {
      SnackbarHelper.showError(context, 'Please enter your email.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if email exists in 'staff' table AND is pending
      final response = await _supabase
          .from('staff')
          .select()
          .eq('email', _emailCtrl.text.trim().toLowerCase()) // Enforce lowercase
          .maybeSingle();

      if (response == null) {
        throw 'No staff invitation found for this email.';
      }

      if (response['status'] == 'active') {
        throw 'Account already active. Please Sign In.';
      }

      setState(() {
        _isVerified = true;
        _staffName = response['name'];
      });

    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Step 2: Set Password & Activate
  Future<void> _activateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      // 1. Sign Up (Create User in Auth)
      final authService = AuthService();
      final response = await authService.signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      final user = response;
      if (user != null) {
        // EXPLICITLY CREATE 'users' RECORD TO LINK STAFF
        // This ensures they are not treated as a new Owner.
        
        // Fetch original staff data again to be safe
        final staffData = await _supabase
          .from('staff')
          .select()
          .eq('email', _emailCtrl.text.trim().toLowerCase())
          .single();

        final staffMap = {
            'uid': user.id,
            'role': 'staff',
            'tenant_id': staffData['tenant_id'], // CRITICAL: Link to Owner
            'name': staffData['name'],
            'email': user.email,
            'created_at': DateTime.now().toIso8601String(),
            'permissions': staffData['permissions'] ?? [],
        };
          
        await _supabase.from('users').upsert(staffMap); // Register as Staff User
        await _supabase.from('staff').update({'status': 'active'}).eq('email', user.email!);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Logging you in...'), 
            backgroundColor: Colors.green
          )
        );
        // Navigate to Home/Check Auth
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Activation Failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Activation'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Image.asset('assets/icon/splash_logo.png', height: 80),
                   const SizedBox(height: 32),
                   
                   if (!_isVerified) ...[
                     const Text(
                       'Verify Invitation',
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                     ),
                     const SizedBox(height: 8),
                     const Text(
                       'Enter the email address your employer used to invite you.',
                       textAlign: TextAlign.center,
                       style: TextStyle(color: AppColors.textGrey),
                     ),
                     const SizedBox(height: 32),
                     TextFormField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                     ),
                     const SizedBox(height: 24),
                     ElevatedButton(
                       onPressed: _isLoading ? null : _verifyEmail,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppColors.primary,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Verify Email', style: TextStyle(fontSize: 16)),
                     ),
                   ] else ...[
                     Text(
                       'Welcome, $_staffName!',
                       textAlign: TextAlign.center,
                       style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       'Set a password to activate your account for ${_emailCtrl.text}',
                       textAlign: TextAlign.center,
                       style: const TextStyle(color: AppColors.textGrey),
                     ),
                     const SizedBox(height: 32),
                     
                     TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Create Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                     ),
                     const SizedBox(height: 16),
                     TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.check_circle_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
                     ),
                     const SizedBox(height: 24),
                     ElevatedButton(
                       onPressed: _isLoading ? null : _activateAccount,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppColors.success, // Green for activation
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Activate Account', style: TextStyle(fontSize: 16)),
                     ),
                   ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
