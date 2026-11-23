import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../core/routes/route_constants.dart';
import '../core/routes/app_router.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../utils/auth_nav_state.dart';
import '../utils/app_localizations.dart';
import '../providers/language_provider.dart';
import '../services/credential_storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  final LayerLink _emailLayerLink = LayerLink();
  final GlobalKey _emailFieldKey = GlobalKey();
  final LayerLink _passwordLayerLink = LayerLink();
  final GlobalKey _passwordFieldKey = GlobalKey();
  OverlayEntry? _savedAccountsOverlay;
  bool _isOverlayForPassword = false;
  bool _showAllAccountsInPasswordOverlay = false;
  List<SavedAccount> _savedAccounts = [];

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
    _emailFocus.addListener(_onEmailFocusChanged);
    _passwordFocus.addListener(_onPasswordFocusChanged);
    _emailController.addListener(_onEmailTextChanged);
    final email = AuthNavState.consumePendingEmail();
    if (email.isNotEmpty) {
      _emailController.text = email;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final langProvider = Provider.of<LanguageProvider>(context, listen: false);
        if (langProvider.isTamil) {
          langProvider.resetToDefault();
        }
      }
    });
  }

  void _onEmailTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocusChanged);
    _passwordFocus.removeListener(_onPasswordFocusChanged);
    _emailController.removeListener(_onEmailTextChanged);
    _hideSavedAccountsOverlay();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccounts() async {
    try {
      final accounts = await CredentialStorageService.getSavedAccounts();
      if (mounted) {
        setState(() {
          _savedAccounts = accounts;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved accounts: $e');
    }
  }

  void _onEmailFocusChanged() {
    if (_emailFocus.hasFocus) {
      if (_savedAccounts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _emailFocus.hasFocus) {
            _showSavedAccountsOverlay(isPasswordField: false);
          }
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_emailFocus.hasFocus && !_passwordFocus.hasFocus && _savedAccountsOverlay != null) {
          _hideSavedAccountsOverlay();
        }
      });
    }
  }

  void _onPasswordFocusChanged() {
    if (_passwordFocus.hasFocus) {
      if (_savedAccounts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _passwordFocus.hasFocus) {
            _showSavedAccountsOverlay(isPasswordField: true);
          }
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && !_passwordFocus.hasFocus && !_emailFocus.hasFocus && _savedAccountsOverlay != null) {
          _hideSavedAccountsOverlay();
        }
      });
    }
  }

  void _selectSavedAccount(SavedAccount account) {
    // 1. Hide overlay and unfocus first to dismiss soft keyboard / IME
    _hideSavedAccountsOverlay();
    FocusScope.of(context).unfocus();
    _emailFocus.unfocus();
    _passwordFocus.unfocus();

    // 2. Set email and password immediately
    _emailController.value = TextEditingValue(
      text: account.email,
      selection: TextSelection.collapsed(offset: account.email.length),
    );

    _passwordController.value = TextEditingValue(
      text: account.password,
      selection: TextSelection.collapsed(offset: account.password.length),
    );

    if (mounted) {
      _formKey.currentState?.validate();
      setState(() {});
    }

    // 3. Post-frame safeguard: ensures Android IME unfocus event does not revert text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_emailController.text != account.email) {
          _emailController.value = TextEditingValue(
            text: account.email,
            selection: TextSelection.collapsed(offset: account.email.length),
          );
        }
        if (_passwordController.text != account.password) {
          _passwordController.value = TextEditingValue(
            text: account.password,
            selection: TextSelection.collapsed(offset: account.password.length),
          );
        }
        _formKey.currentState?.validate();
      }
    });
  }

  void _showSavedAccountsOverlay({bool isPasswordField = false}) {
    if (_savedAccounts.isEmpty || !mounted) {
      return;
    }

    if (_savedAccountsOverlay != null) {
      if (_isOverlayForPassword == isPasswordField) {
        return;
      }
      _hideSavedAccountsOverlay();
    }

    _isOverlayForPassword = isPasswordField;
    _showAllAccountsInPasswordOverlay = false;

    final targetKey = isPasswordField ? _passwordFieldKey : _emailFieldKey;
    final targetLink = isPasswordField ? _passwordLayerLink : _emailLayerLink;

    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldSize = renderBox?.size ?? const Size(320, 50);

    final overlay = Overlay.of(context);
    _savedAccountsOverlay = OverlayEntry(
      builder: (ctx) {
        final currentEmail = _emailController.text.trim().toLowerCase();
        final matchedAccounts = isPasswordField && currentEmail.isNotEmpty && !_showAllAccountsInPasswordOverlay
            ? _savedAccounts.where((a) => a.email.toLowerCase() == currentEmail).toList()
            : <SavedAccount>[];

        final isFilteringByEmail = isPasswordField && currentEmail.isNotEmpty && matchedAccounts.isNotEmpty && !_showAllAccountsInPasswordOverlay;
        final displayList = isFilteringByEmail ? matchedAccounts : _savedAccounts;

        final title = isFilteringByEmail ? 'Saved Passwords' : 'Saved Credentials';
        final headerIcon = isFilteringByEmail ? Icons.vpn_key_outlined : Icons.manage_accounts_outlined;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideSavedAccountsOverlay,
              ),
            ),
            Positioned(
              width: fieldSize.width,
              child: CompositedTransformFollower(
                link: targetLink,
                showWhenUnlinked: false,
                offset: Offset(0, fieldSize.height + 4),
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            color: const Color(0xFFF8FAFC),
                            child: Row(
                              children: [
                                Icon(headerIcon, size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      if (isFilteringByEmail)
                                        Text(
                                          currentEmail,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${displayList.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: displayList.length,
                              separatorBuilder: (c, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (c, idx) {
                                final acc = displayList[idx];
                                final dateStr = DateFormat('dd MMM').format(acc.savedAt);
                                final isSelected = isFilteringByEmail && _passwordController.text == acc.password;

                                return InkWell(
                                  onTap: () => _selectSavedAccount(acc),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isFilteringByEmail ? Icons.vpn_key_rounded : Icons.person_rounded,
                                            size: 16,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                isFilteringByEmail ? 'Password ${idx + 1}' : acc.email,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF1E293B),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                '${acc.maskedPassword}  •  Saved $dateStr',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 6),
                                            child: Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryColor),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                          tooltip: 'Remove saved password',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () => _confirmRemoveAccount(acc),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (isFilteringByEmail && _savedAccounts.length > displayList.length) ...[
                            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                            InkWell(
                              onTap: () {
                                _showAllAccountsInPasswordOverlay = true;
                                _savedAccountsOverlay?.markNeedsBuild();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                color: const Color(0xFFF8FAFC),
                                child: const Text(
                                  'Show all saved accounts',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_savedAccounts.length > 1) ...[
                            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                            InkWell(
                              onTap: _confirmClearAllAccounts,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                color: const Color(0xFFF8FAFC),
                                child: const Text(
                                  'Clear all saved accounts',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );

    overlay.insert(_savedAccountsOverlay!);
    setState(() {});
  }

  void _hideSavedAccountsOverlay() {
    _savedAccountsOverlay?.remove();
    _savedAccountsOverlay = null;
    _showAllAccountsInPasswordOverlay = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _confirmRemoveAccount(SavedAccount account) async {
    final dateStr = DateFormat('dd MMM yyyy').format(account.savedAt);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove Saved Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Remove this saved password (${account.maskedPassword}, saved on $dateStr) for "${account.email}" from this device?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CredentialStorageService.removeAccountById(account.id);
      await _loadSavedAccounts();
      if (_savedAccounts.isEmpty) {
        _hideSavedAccountsOverlay();
      } else {
        _savedAccountsOverlay?.markNeedsBuild();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed saved password for "${account.email}"'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _confirmClearAllAccounts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Clear All Saved Accounts', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Are you sure you want to remove all saved accounts and passwords from this device?',
          style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CredentialStorageService.clearAllAccounts();
      await _loadSavedAccounts();
      _hideSavedAccountsOverlay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All saved accounts cleared'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<bool> _showSaveCredentialsDialog(BuildContext dialogContext, String email) async {
    final existingList = await CredentialStorageService.getAccountsForEmail(email);
    final isAdditional = existingList.isNotEmpty;

    final result = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAdditional ? 'Save Additional Password?' : 'Save Login Credentials?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdditional
                  ? 'Would you like to save this new password for "$email"? Both passwords will remain available to switch between.'
                  : 'Would you like to securely save the password for "$email" on this device?',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Protected by hardware-backed secure storage. You can switch or delete saved passwords anytime.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save Password', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _handleLogin() async {
    _hideSavedAccountsOverlay();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final success = await authProvider.login(email: email, password: password);

      if (mounted && success) {
        final user = authProvider.user!;
        final langProvider = Provider.of<LanguageProvider>(context, listen: false);
        // Explicitly sync language for this user from DB; other users default to English
        await langProvider.syncFromUserDb(user.preferredLanguage, userId: user.id);

        // Check if this exact (email, password) combination is already saved
        final isAlreadySaved = await CredentialStorageService.isAccountSaved(email, password);
        if (!isAlreadySaved) {
          final dialogContext = AppRouter.parentNavigatorKey.currentContext ?? context;
          if (dialogContext.mounted) {
            final shouldSave = await _showSaveCredentialsDialog(dialogContext, email);
            if (shouldSave) {
              await CredentialStorageService.saveAccount(email, password);
              await _loadSavedAccounts();
            }
          }
        }

        final toastContext = AppRouter.parentNavigatorKey.currentContext ?? context;
        if (toastContext.mounted) {
          ScaffoldMessenger.of(toastContext).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${user.fullname}!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      }
    } on RequiresPasswordChangeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
        );
        // Pass the email to the force change password screen
        context.go('${AppRoutes.forceChangePassword}?email=${Uri.encodeComponent(email)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLoading = Provider.of<AuthProvider>(context).isLoading;
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Localizations.override(
        context: context,
        locale: const Locale('en'),
        child: Stack(
          children: [
          LayoutBuilder(
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
                              Text(
                                context.tr('hospital_title', fallback: 'Sri Ponni\nMedical Dashboard'),
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.15,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('hospital_subtitle', fallback: 'Secure access for authorized clinical and administrative personnel.'),
                                style: const TextStyle(
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
                            decoration: AppTheme.getCardDecoration(context),
                            child: _buildForm(context, showMobileHeader: false, isLoading: isLoading),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final isDark = AppTheme.isDark(context);
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
                            color: AppTheme.getCardColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.getBorderColor(context)),
                            boxShadow: isDark
                                ? []
                                : [
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
        ],
      ),
    ),
  );
}

  Widget _buildForm(BuildContext context, {required bool showMobileHeader, bool isLoading = false}) {
    return AutofillGroup(
      child: Form(
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
          context.tr('welcome', fallback: 'Welcome Back'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: showMobileHeader ? 28 : 36,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('sign_in_dashboard', fallback: 'Sign in to access your dashboard'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
        const SizedBox(height: 48),

        CompositedTransformTarget(
          link: _emailLayerLink,
          child: Container(
            key: _emailFieldKey,
            child: _buildTextField(
              context: context,
              controller: _emailController,
              focusNode: _emailFocus,
              label: context.tr('email_address', fallback: 'Email Address'),
              hint: context.tr('enter_email_address', fallback: 'Enter Email Address'),
              icon: Icons.email_outlined,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              onTap: () {
                if (_savedAccounts.isNotEmpty) {
                  _showSavedAccountsOverlay(isPasswordField: false);
                }
              },
              suffixIcon: _savedAccounts.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        (_savedAccountsOverlay != null && !_isOverlayForPassword)
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 26,
                        color: AppTheme.primaryColor,
                      ),
                      tooltip: 'Saved credentials',
                      onPressed: () {
                        if (_savedAccountsOverlay != null && !_isOverlayForPassword) {
                          _hideSavedAccountsOverlay();
                        } else {
                          _showSavedAccountsOverlay(isPasswordField: false);
                        }
                      },
                    )
                  : null,
              onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('please_enter_email', fallback: 'Please enter Email Address');
                }
                if (value.trim().contains(RegExp(r'[A-Z]'))) {
                  return context.tr('valid_email', fallback: 'Please enter a valid email address');
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                  return context.tr('valid_email', fallback: 'Please enter a valid email address');
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        CompositedTransformTarget(
          link: _passwordLayerLink,
          child: Container(
            key: _passwordFieldKey,
            child: _buildTextField(
              context: context,
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: context.tr('password', fallback: 'Password'),
              hint: context.tr('enter_password', fallback: 'Enter Password'),
              icon: Icons.lock_outline,
              isPassword: true,
              maxLength: 16,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              onTap: () {
                if (_savedAccounts.isNotEmpty) {
                  _showSavedAccountsOverlay(isPasswordField: true);
                }
              },
              suffixIcon: _savedAccounts.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        (_savedAccountsOverlay != null && _isOverlayForPassword)
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 26,
                        color: AppTheme.primaryColor,
                      ),
                      tooltip: 'Saved passwords',
                      onPressed: () {
                        if (_savedAccountsOverlay != null && _isOverlayForPassword) {
                          _hideSavedAccountsOverlay();
                        } else {
                          _showSavedAccountsOverlay(isPasswordField: true);
                        }
                      },
                    )
                  : null,
              onToggleVisibility: () {
                Future.microtask(() {
                  if (mounted) {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  }
                });
              },
              onSubmitted: (_) => _handleLogin(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('please_enter_password', fallback: 'Please enter Password');
                }
                if (value.length < 8) {
                  return context.tr('password_min_length', fallback: 'Password must be at least 8 characters long');
                }
                return null;
              },
            ),
          ),
        ),

        // Multiple Passwords Switcher for the selected email
        Builder(
          builder: (context) {
            final currentEmail = _emailController.text.trim().toLowerCase();
            final matchedCredentials = _savedAccounts
                .where((a) => a.email.toLowerCase() == currentEmail)
                .toList();

            if (matchedCredentials.length <= 1) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${matchedCredentials.length} saved passwords for this email',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    PopupMenuButton<SavedAccount>(
                      tooltip: 'Switch saved password',
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Switch',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      itemBuilder: (ctx) {
                        return matchedCredentials.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final acc = entry.value;
                          final isSelected = _passwordController.text == acc.password;
                          final dateStr = DateFormat('dd MMM yyyy').format(acc.savedAt);
                          return PopupMenuItem<SavedAccount>(
                            value: acc,
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•••••••• (Password $idx • $dateStr)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      onSelected: (acc) {
                        _selectSavedAccount(acc);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              final email = _emailController.text.trim();
              AuthNavState.setPendingEmail(email);
              context.go(AppRoutes.forgotPassword);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(context.tr('forgot_password', fallback: 'Forgot Password?')),
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
            : Text(context.tr('sign_in', fallback: 'Sign In')),
        ),
        const SizedBox(height: 32),

      ],
      ),
    ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    bool isPassword = false,
    bool obscureText = false,
    int? maxLength,
    VoidCallback? onToggleVisibility,
    Widget? suffixIcon,
    VoidCallback? onTap,
    Key? fieldKey,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.getTextPrimaryColor(context),
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          onTap: onTap,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          obscureText: obscureText,
          onFieldSubmitted: onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
          ),
          validator: validator,
          maxLength: maxLength,
          inputFormatters: maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Color(0xFFCBD5E0),
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, size: 22),
            suffixIcon: isPassword
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?suffixIcon,
                      IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 22,
                        ),
                        onPressed: onToggleVisibility,
                      ),
                    ],
                  )
                : suffixIcon,
          ),
        ),
      ],
    );
  }
}
