import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../controllers/auth_provider.dart';
import '../widgets/nurse_widgets.dart';
import 'login_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddUserDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      floatingActionButton: CustomSpeedDial(
        children: [
          SpeedDialChild(
            label: 'Register New Staff',
            icon: Icons.person_add_outlined,
            color: AppTheme.primaryColor,
            onTap: () => _showAddUserDialog(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar (only on desktop)
          if (!isMobile) _buildSidebar(context),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, isMobile),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(),
                        const SizedBox(height: 24),
                        _buildStatsRow(isMobile),
                        const SizedBox(height: 24),
                        if (isMobile) ...[
                          _buildAlertsSection(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          const SizedBox(height: 24),
                          _buildUserManagementInfo(),
                          const SizedBox(height: 24),
                          _buildSystemStatus(),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    _buildAlertsSection(),
                                    const SizedBox(height: 24),
                                    _buildUserManagementInfo(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    _buildQuickActions(),
                                    const SizedBox(height: 24),
                                    _buildSystemStatus(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.only(left: 24, top: 32, bottom: 24, right: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset('image/sriPonniLogo.png', width: 32, height: 32),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SRI PONNI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                    Text('ADMIN PORTAL', style: TextStyle(fontSize: 10, letterSpacing: 1, color: AppTheme.textSecondaryColor)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 48),
          
          // Navigation Items
          _buildSidebarItem(0, Icons.admin_panel_settings_outlined, 'Control Panel'),
          _buildSidebarItem(1, Icons.people_outline, 'Staff Management'),
          _buildSidebarItem(2, Icons.analytics_outlined, 'System Analytics'),
          _buildSidebarItem(3, Icons.settings_outlined, 'Settings'),
          
          const Spacer(),
          
          // User Profile Area
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final user = auth.user;
                if (user == null) return const SizedBox.shrink();
                return Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      radius: 18,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                          Text(user.role, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18, color: AppTheme.textSecondaryColor),
                      onPressed: () {
                        auth.logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor, size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      height: isMobile ? 80 : 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Row(
        children: [
          if (isMobile) ...[
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.textSecondaryColor),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextFormField(
                decoration: InputDecoration(
                  hintText: isMobile ? 'Search...' : 'Search system...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          
          if (!isMobile) ...[
            const SizedBox(width: 24),
            const Icon(Icons.notifications_none_outlined, color: AppTheme.textSecondaryColor),
            const SizedBox(width: 24),
          ] else
            const SizedBox(width: 12),
          
          // Date & Time
          const LiveClock(), // Using the simplified clock
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(user != null ? 'Hello, ${user.fullname}' : 'Admin Dashboard', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Manage system operations and staff provisioning', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard('Total Staff', '24', '+2', Icons.badge_outlined, Colors.blueGrey, isMobile),
          _buildStatCard('Active Sessions', '5', 'Live', Icons.online_prediction, Colors.green, isMobile),
          _buildStatCard('System Health', '98%', 'Optimal', Icons.speed, Colors.indigo, isMobile),
          _buildStatCard('Security Alerts', '0', 'Safe', Icons.security, Colors.teal, isMobile),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Staff', '24', '+2', Icons.badge_outlined, Colors.blueGrey, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Active Sessions', '5', 'Live', Icons.online_prediction, Colors.green, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('System Health', '98%', 'Optimal', Icons.speed, Colors.indigo, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Security Alerts', '0', 'Safe', Icons.security, Colors.teal, isMobile)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String sub, IconData icon, Color color, bool isMobile) {
    return StatCard(
      title: title,
      value: value,
      subLabel: sub,
      icon: icon,
      color: color,
      isMobile: isMobile,
    );
  }

  Widget _buildAlertsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text('System Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(Colors.orange.shade50, Colors.orange.shade900, 'Database backup planned for tonight at 02:00 AM', 'System'),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Color bg, Color textColor, String text, String type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13))),
          Text(type, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.primaryColor, Color(0xFF0D4D7A)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Administrative Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildActionButton(Icons.person_add_outlined, 'Register New Staff', () => _showAddUserDialog(context)),
          _buildActionButton(Icons.settings_suggest_outlined, 'System Configuration', () {}),
          _buildActionButton(Icons.backup_outlined, 'Manual Database Backup', () {}),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return QuickActionButton(
      icon: icon,
      label: label,
      onTap: onTap,
    );
  }

  Widget _buildUserManagementInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Staff Performance Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 16),
          Text('User statistics, audit logs, and system access history will be integrated here.', style: TextStyle(color: AppTheme.textSecondaryColor)),
          SizedBox(height: 120), // Placeholder space
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          _buildStatusRow('Backend API', 'Online', Colors.green),
          _buildStatusRow('PostgreSQL DB', 'Connected', Colors.green),
          _buildStatusRow('Storage Service', 'Active', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.labelColor)),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({Key? key}) : super(key: key);

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseController = TextEditingController();
  
  String _selectedRole = 'Doctor';
  final List<String> _roles = ['Doctor', 'Nurse'];
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.signup(
        fullname: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        medicalLicense: _licenseController.text.trim().isNotEmpty ? _licenseController.text.trim() : null,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User created successfully!'),
              backgroundColor: Colors.green.shade600,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authProvider.errorMessage ?? 'Signup failed'), backgroundColor: Colors.redAccent),
          );
        }
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
    return AlertDialog(
      title: const Text('Register New User', style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (val) => val == null || val.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || val.isEmpty || !val.contains('@') ? 'Please enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                  items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedRole == 'Doctor')
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(labelText: 'Medical License (Optional)', prefixIcon: Icon(Icons.medical_services_outlined)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Create User'),
        ),
      ],
    );
  }
}
