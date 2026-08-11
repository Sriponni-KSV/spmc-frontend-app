import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../core/routes/route_constants.dart';
import '../utils/password_policy.dart';
import 'package:flutter/services.dart';
import '../widgets/otp_input_widget.dart';

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
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// GlobalKey to access the OTP widget's state (read digits, clear, etc.)
  final GlobalKey<OtpInputWidgetState> _otpKey =
      GlobalKey<OtpInputWidgetState>();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  /// Focus node to move cursor from new password to confirm password on Enter.
  final FocusNode _confirmPasswordFocus = FocusNode();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _emailErrorMessage;
  String? _otpErrorMessage;

  final AuthController _authController = AuthController();

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _nextStep() async {
    if (_isLoading) return;
    focusOut();
    if (_currentStep == 0) {
      if (_emailFormKey.currentState!.validate()) {
        setState(() {
          _isLoading = true;
          _emailErrorMessage = null;
        });
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
          final errorText = e.toString().replaceAll('Exception: ', '');
          setState(() {
            _isLoading = false;
            _emailErrorMessage = errorText;
          });
        }
      }
    } else if (_currentStep == 1) {
      String fullOtp = _otpKey.currentState?.otp ?? '';
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
      if (_confirmPasswordController.text.trim().isEmpty) {
        FocusScope.of(context).requestFocus(_confirmPasswordFocus);
      }
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
      } else {
        if (_confirmPasswordController.text.trim().isEmpty ||
            _confirmPasswordController.text != _newPasswordController.text) {
          FocusScope.of(context).requestFocus(_confirmPasswordFocus);
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
          if (_emailErrorMessage != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final isWarning = _emailErrorMessage!.toLowerCase().contains('inactive');
                final alertColor = isWarning ? Colors.orange : Colors.red;
                final bgColor = isWarning ? Colors.orange.shade50 : Colors.red.shade50;
                final borderColor = isWarning ? Colors.orange.shade200 : Colors.red.shade200;
                final icon = isWarning ? Icons.info_outline : Icons.error_outline;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: alertColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _emailErrorMessage!,
                          style: TextStyle(
                            color: alertColor.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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
          OtpInputWidget(
            key: _otpKey,
            errorMessage: _otpErrorMessage,
            onChanged: () {
              if (_otpErrorMessage != null) {
                setState(() => _otpErrorMessage = null);
              }
            },
            onCompleted: (_) => _nextStep(),
          ),
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
          const SizedBox(height: 12),
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
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
            ),
            validator: PasswordPolicy.validatePassword,
            maxLength: 16,
            inputFormatters: [LengthLimitingTextInputFormatter(16)],
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_confirmPasswordFocus),
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
            focusNode: _confirmPasswordFocus,
            obscureText: _obscureConfirmPassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textInputAction: TextInputAction.done,
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
