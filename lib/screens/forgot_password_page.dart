import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../core/routes/route_constants.dart';
import '../utils/password_policy.dart';
import 'package:flutter/services.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PageController _pageController = PageController();

  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  int _currentStep = 0;
  bool _isLoading = false;
  String? _otpErrorMessage;

  final AuthController _authController = AuthController();

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
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

  void _nextStep() async {
    if (_isLoading) return;
    focusOut();
    if (_currentStep == 0) {
      if (_emailFormKey.currentState!.validate()) {
        setState(() => _isLoading = true);
        try {
          await _authController.forgotPassword(_emailController.text.trim());
          if (!mounted) return;
          setState(() {
            _currentStep = 1;
            _isLoading = false;
          });
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent to your email.'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else if (_currentStep == 1) {
      String fullOtp = _otpControllers.map((c) => c.text).join();
      if (fullOtp.length < 6) {
        setState(() => _otpErrorMessage = 'Please enter all 6 digits.');
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _authController.verifyOtp(_emailController.text.trim(), fullOtp);
        if (!mounted) return;
        setState(() {
          _otpErrorMessage = null;
          _currentStep = 2;
          _isLoading = false;
        });
        _pageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _otpErrorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } else if (_currentStep == 2) {
      if (_passwordFormKey.currentState!.validate()) {
        setState(() => _isLoading = true);
        try {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.resetPassword(
            email: _emailController.text.trim(),
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

  void focusOut() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 900;

          Widget formContent = Container(
            width: 550,
            padding: const EdgeInsets.all(48.0),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SizedBox(
              height: 520,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildEmailStep(),
                  _buildOtpStep(),
                  _buildPasswordStep(),
                ],
              ),
            ),
          );

          if (isDesktop) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    color: AppTheme.primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/image/sriPonniLogo.png',
                              width: 80,
                              height: 80,
                            ),
                          ),
                          const SizedBox(height: 48),
                          const Text(
                            'Sri Ponni\nMedical Dashboard',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Reset your password securely to regain access to your dashboard.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 20,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 48.0,
                      ),
                      child: formContent,
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 24.0,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 520,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildEmailStep(),
                            _buildOtpStep(),
                            _buildPasswordStep(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/image/sriPonniLogo.png',
                width: 48,
                height: 48,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Enter Email',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please enter your registered email id to receive an OTP.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Email Address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter Email Address';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            onFieldSubmitted: (_) => _nextStep(),
            maxLength: 50,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'Enter Email Address',
              hintStyle: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: Color(0xFFCBD5E0),
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _nextStep,
            style: AppTheme.primaryButton.copyWith(
              minimumSize: MaterialStateProperty.all(const Size(double.infinity, 56)),
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
                : const Text('Send OTP'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondaryColor,
              overlayColor: Colors.transparent,
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Form(
      key: _otpFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/image/sriPonniLogo.png',
                width: 48,
                height: 48,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Enter OTP',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please enter the 6-digit OTP sent to your email.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 48,
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _otpErrorMessage != null
                            ? Colors.redAccent
                            : Colors.grey.shade400,
                        width: _otpErrorMessage != null ? 2 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _otpErrorMessage != null
                            ? Colors.redAccent
                            : AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (_otpErrorMessage != null) {
                      setState(() => _otpErrorMessage = null);
                    }
                    if (value.isNotEmpty && index < 5) {
                      _otpFocusNodes[index + 1].requestFocus();
                    }
                    if (value.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  },
                  onFieldSubmitted: index == 5 ? (_) => _nextStep() : null,
                ),
              );
            }),
          ),
          if (_otpErrorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _otpErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _nextStep,
            style: AppTheme.primaryButton.copyWith(
              minimumSize: MaterialStateProperty.all(const Size(double.infinity, 56)),
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
                : const Text('Verify OTP'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/image/sriPonniLogo.png',
                width: 48,
                height: 48,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your new password. Must be different from the previous one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'New Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
            ),
            validator: PasswordPolicy.validatePassword,
            maxLength: 16,
            inputFormatters: [LengthLimitingTextInputFormatter(16)],
            onFieldSubmitted: (_) => _nextStep(),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Enter New Password',
              hintStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: Color(0xFFCBD5E0),
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Confirm Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter Confirm Password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            onFieldSubmitted: (_) => _nextStep(),
            maxLength: 16,
            inputFormatters: [LengthLimitingTextInputFormatter(16)],
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Enter Confirm Password',
              hintStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: Color(0xFFCBD5E0),
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _isLoading ? null : _nextStep,
            style: AppTheme.primaryButton.copyWith(
              minimumSize: MaterialStateProperty.all(const Size(double.infinity, 56)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Reset Password'),
          ),
        ],
      ),
    );
  }
}
