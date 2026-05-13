import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/custom_app_bar.dart';
import '../providers/auth_provider.dart';

import 'dashboard_page.dart';
import 'nurse_dashboard.dart';
import 'admin_dashboard.dart';
import 'forgot_password_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(email: email, password: password);

    if (mounted && success) {
      final user = authProvider.user!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome back, ${user.fullname}!'), backgroundColor: AppTheme.primaryColor),
      );
      
      Widget nextScreen;
      if (user.role == 'Nurse' || user.role == 'Head Nurse') {
        nextScreen = const NurseDashboardScreen();
      } else if (user.role == 'Admin' || user.role == 'Supervisor' || user.role == 'Super Admin') {
        nextScreen = const AdminDashboardScreen();
      } else {
        nextScreen = const DashboardScreen(); // Doctor dashboard
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLoading = Provider.of<AuthProvider>(context).isLoading;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 900;

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
                            decoration: BoxDecoration(
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
                            'Welcome back! Log in to access your personalized medical dashboard designed for maximum efficiency.',
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
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                      child: Container(
                        width: 550,
                        padding: const EdgeInsets.all(48.0),
                        decoration: AppTheme.cardDecoration,
                        child: _buildForm(context, showMobileHeader: false, isLoading: isLoading),
                      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
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
                      child: _buildForm(context, showMobileHeader: true, isLoading: isLoading),
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

  Widget _buildForm(BuildContext context, {required bool showMobileHeader, bool isLoading = false}) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (showMobileHeader) ...[
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
        ],

        Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: showMobileHeader ? 28 : 36,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to access your dashboard',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
        const SizedBox(height: 48),

        _buildTextField(
          context: context,
          controller: _emailController,
          label: 'Email Address',
          hint: 'name@example.com',
          icon: Icons.email_outlined,
          onSubmitted: (_) => _handleLogin(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        _buildTextField(
          context: context,
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          isPassword: true,
          obscureText: _obscurePassword,
          onToggleVisibility: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          onSubmitted: (_) => _handleLogin(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
            if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
              return 'Must contain at least one lowercase letter';
            }
            if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
              return 'Must contain at least one uppercase letter';
            }
            if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
              return 'Must contain at least one number';
            }
            if (!RegExp(r'(?=.*[\W_])').hasMatch(value)) {
              return 'Must contain at least one special character';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Forgot Password?'),
          ),
        ),
        const SizedBox(height: 32),

        const SizedBox(height: 16),
        Consumer<AuthProvider>(
          builder: (context, auth, child) {
            if (auth.errorMessage == null) return const SizedBox.shrink();
            
            final isWarning = auth.errorCode == 'inactive';
            final alertColor = isWarning ? Colors.orange : Colors.red;
            final bgColor = isWarning ? Colors.orange.shade50 : Colors.red.shade50;
            final borderColor = isWarning ? Colors.orange.shade200 : Colors.red.shade200;
            final icon = isWarning ? Icons.info_outline : Icons.error_outline;

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
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
                      auth.errorMessage!,
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
        ElevatedButton(
          onPressed: isLoading ? null : _handleLogin,
          style: AppTheme.primaryButton.copyWith(
            minimumSize: MaterialStateProperty.all(const Size(double.infinity, 56)),
          ),
          child: isLoading 
            ? const SizedBox(
                width: 24, height: 24, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
            : const Text('Sign In'),
        ),
        const SizedBox(height: 32),

      ],
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).inputDecorationTheme.labelStyle,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          onFieldSubmitted: onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: Theme.of(context).textTheme.bodyLarge,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 22,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
