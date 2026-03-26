import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/custom_app_bar.dart';
import '../controllers/auth_controller.dart';

import 'dashboard_page.dart';
import 'nurse_dashboard.dart';
import 'admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = AuthController();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authController.login(email: email, password: password);
      if (mounted && user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome back, ${user.fullname}!'), backgroundColor: AppTheme.primaryColor),
        );
        
        Widget nextScreen;
        if (user.role == 'Nurse' || user.role == 'Head Nurse') {
          nextScreen = NurseDashboardScreen(user: user);
        } else if (user.role == 'Admin' || user.role == 'Supervisor') {
          nextScreen = AdminDashboardScreen(user: user);
        } else {
          nextScreen = DashboardScreen(user: user); // Doctor dashboard
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
         );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              'image/sriPonniLogo.png',
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
                        child: _buildForm(context, showMobileHeader: false),
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
                      child: _buildForm(context, showMobileHeader: true),
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

  Widget _buildForm(BuildContext context, {required bool showMobileHeader}) {
    return Column(
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
                'image/sriPonniLogo.png',
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
        ),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
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

        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading 
            ? const SizedBox(
                width: 24, height: 24, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
            : const Text('Sign In'),
        ),
        const SizedBox(height: 32),


      ],
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
          style: Theme.of(context).textTheme.bodyLarge,
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
