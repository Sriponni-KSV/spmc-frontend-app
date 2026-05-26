import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../utils/password_policy.dart';
import '../controllers/auth_controller.dart';

import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ForceChangePasswordScreen extends StatefulWidget {
  final String email;
  const ForceChangePasswordScreen({Key? key, required this.email})
    : super(key: key);

  @override
  _ForceChangePasswordScreenState createState() =>
      _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen> {
  final AuthController _authController = AuthController();
  final PageController _pageController = PageController();

  // Current step: 0 = Verify OTP, 1 = Set New Password
  int _currentStep = 0;
  bool _isLoading = false;

  // OTP Fields
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  String? _otpErrorMessage;

  // Resend Timer
  int _resendCooldown = 60;
  Timer? _resendTimer;
  bool get _canResend => _resendCooldown == 0;

  // Password Fields
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() => _resendCooldown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _pageController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void focusOut() {
    FocusScope.of(context).unfocus();
  }

  void _handleResendOtp() async {
    if (!_canResend || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      await _authController.resendOtp(widget.email);
      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new OTP has been sent to your email.'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() async {
    if (_isLoading) return;
    focusOut();

    if (_currentStep == 0) {
      String fullOtp = _otpControllers.map((c) => c.text).join();
      if (fullOtp.length < 6) {
        setState(() => _otpErrorMessage = 'Please enter all 6 digits.');
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _authController.verifyOtp(widget.email, fullOtp);
        if (!mounted) return;
        setState(() {
          _otpErrorMessage = null;
          _currentStep = 1;
        });
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _otpErrorMessage = e.toString().replaceAll('Exception: ', '');
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (_currentStep == 1) {
      if (_passwordFormKey.currentState!.validate()) {
        setState(() => _isLoading = true);
        try {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.resetPassword(
            email: widget.email,
            newPassword: _newPasswordController.text,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password changed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go(AppRoutes.dashboard);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildOtpStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Image.asset(
              'assets/image/full_logo.png',
              height: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mandatory Update',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'For security, you must change your temporary password.\nEnter the 6-digit OTP sent to ${widget.email}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6,
              (index) => SizedBox(
                width: 50,
                height: 56,
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      if (index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else {
                        focusOut();
                        // Automatically verify OTP
                        String fullOtp = _otpControllers.map((c) => c.text).join();
                        if (fullOtp.length == 6) {
                          _nextStep();
                        }
                      }
                    } else if (value.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              ),
            ),
          ),
          if (_otpErrorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _otpErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _nextStep,
            style: AppTheme.primaryButton.copyWith(
              minimumSize: MaterialStateProperty.all(
                const Size(double.infinity, 56),
              ),
            ),
            child: _isLoading && _currentStep == 0
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Verify OTP'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive code? ",
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: _canResend ? _handleResendOtp : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _canResend ? 'Resend' : 'Resend in ${_resendCooldown}s',
                  style: TextStyle(
                    color: _canResend ? AppTheme.primaryColor : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Cancel & Return to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'assets/image/full_logo.png',
                height: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Create New Password',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your new password must be different from previous used passwords.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'New Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              maxLength: 16,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
              ),
              validator: PasswordPolicy.validatePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Enter New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Confirm Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              maxLength: 16,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _nextStep(),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: AppTheme.primaryButton.copyWith(
                minimumSize: MaterialStateProperty.all(
                  const Size(double.infinity, 56),
                ),
              ),
              child: _isLoading && _currentStep == 1
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              margin: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 650,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [_buildOtpStep(), _buildPasswordStep()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
