import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_helper.dart';

enum LockScreenMode { setup, verify }

class LockScreen extends StatefulWidget {
  final LockScreenMode mode;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;
  final bool allowBiometric;

  const LockScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.onCancel,
    this.allowBiometric = true,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final _service = SecurityService();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String _currentPin = '';
  String? _firstPin;
  String _title = 'Enter PIN';
  bool _isBiometricAvailable = false;
  bool _showBiometricIcon = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _checkBiometrics();
    if (widget.mode == LockScreenMode.setup) {
      _title = 'Create PIN';
    } else {
      _title = 'Enter PIN';
      _attemptBiometric();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    if (!widget.allowBiometric) {
      // Disabled by parent
      setState(() {
        _isBiometricAvailable = false;
        _showBiometricIcon = false;
      });
      return;
    }

    final available = await _service.canCheckBiometrics();
    final enabled = await _service.isBiometricEnabled();
    setState(() {
      _isBiometricAvailable = available;
      _showBiometricIcon = available && enabled && widget.mode == LockScreenMode.verify;
    });
  }

  Future<void> _attemptBiometric() async {
    if (!widget.allowBiometric) return;

    if (await _service.isBiometricEnabled()) {
      final authenticated = await _service.authenticatedBiometric();
      if (authenticated) {
        widget.onSuccess?.call();
      }
    }
  }

  void _onNumberPress(String number) {
    if (_currentPin.length < 4) {
      setState(() {
        _currentPin += number;
      });
      if (_currentPin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onDeletePress() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  Future<void> _handlePinComplete() async {
    if (widget.mode == LockScreenMode.verify) {
      // Verify Mode
      final isValid = await _service.verifyPin(_currentPin);
      if (isValid) {
        widget.onSuccess?.call();
      } else {
        _shakeError();
        setState(() {
          _currentPin = '';
          _message = 'Incorrect PIN. Try again.';
        });
        SnackbarHelper.showError(context, 'Incorrect PIN');
      }
    } else {
      // Setup Mode
      if (_firstPin == null) {
        // First entry done, ask for confirmation
        setState(() {
          _firstPin = _currentPin;
          _currentPin = '';
          _title = 'Confirm PIN';
          _message = 'Re-enter your PIN to confirm';
        });
      } else {
        // Confirmation entry done
        if (_currentPin == _firstPin) {
          await _service.setPin(_currentPin);
          widget.onSuccess?.call();
        } else {
           _shakeError();
          setState(() {
            _currentPin = '';
            _firstPin = null;
            _title = 'Create PIN';
            _message = 'PINs did not match. Try again.';
          });
          SnackbarHelper.showError(context, 'PINs did not match');
        }
      }
    }
  }
  
  void _shakeError() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 60),
            _buildIcon(),
            const SizedBox(height: 24),
            _buildTitle(),
            if (_message != null) _buildMessage(),
            const SizedBox(height: 48),
            _buildPinDots(),
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          if (widget.onCancel != null)
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel', style: TextStyle(color: AppColors.primary, fontSize: 16)),
            )
          else
            const SizedBox(width: 48)
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        'assets/icon/splash_logo.png',
        height: 100,
        width: 100,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      _title,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _message!,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textGrey,
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _shakeAnimation.value * (1 - (_shakeController.value * 2)).abs() * 
            (_shakeController.value < 0.5 ? 1 : -1), 
            0
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return _PinDot(isFilled: index < _currentPin.length);
            }),
          ),
        );
      },
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildNumberRow(['1', '2', '3']),
          _buildNumberRow(['4', '5', '6']),
          _buildNumberRow(['7', '8', '9']),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: _showBiometricIcon ? Icons.fingerprint : null,
                  onPressed: _showBiometricIcon ? _attemptBiometric : null,
                ),
                _buildNumberButton('0'),
                _buildActionButton(
                  icon: Icons.backspace_outlined,
                  onPressed: _onDeletePress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({IconData? icon, VoidCallback? onPressed}) {
    return SizedBox(
      width: 80,
      height: 80,
      child: icon != null 
        ? IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 28, color: AppColors.textDark),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.all(20),
            ),
          )
        : null,
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: numbers.map((n) => _buildNumberButton(n)).toList(),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Container(
      width: 70,
      height: 70,
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell(
        onTap: () => _onNumberPress(number),
        borderRadius: BorderRadius.circular(35),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  final bool isFilled;

  const _PinDot({required this.isFilled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? AppColors.primary : const Color(0xFFF1F5F9),
        border: Border.all(
          color: isFilled ? AppColors.primary : const Color(0xFFCBD5E1),
          width: 2,
        ),
        boxShadow: isFilled ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ] : [],
      ),
    );
  }
}
