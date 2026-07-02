import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart' show LiveClock;
import '../utils/logout_helper.dart';
import 'pharmacy_management_view.dart';
import 'inventory_management_view.dart';

class PharmacyDashboardScreen extends StatefulWidget {
  final int initialIndex;
  const PharmacyDashboardScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<PharmacyDashboardScreen> createState() => _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant PharmacyDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  void _changePage(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, isMobile),
                Expanded(child: _buildMainContent(isMobile)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Container(
          width: 260,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: AppTheme.borderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Logo Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/image/full_logo.png',
                      width: 100,
                      height: 89,
                    ),
                  ],
                ),
              ),

              // Navigation
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      _buildSidebarItem(0, Icons.local_pharmacy_outlined, 'Pharmacy Management'),
                      _buildSidebarItem(1, Icons.inventory_2_outlined, 'Inventory Management'),
                      _buildSidebarItem(2, Icons.person_outline, 'My Profile'),
                    ],
                  ),
                ),
              ),

              // Footer Profile
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(color: AppTheme.borderColor, height: 1, thickness: 1),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: user == null
                        ? const SizedBox.shrink()
                        : Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.getAvatarColors(user.fullname)['bg'],
                                radius: 18,
                                child: Text(
                                  user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: AppTheme.getAvatarColors(user.fullname)['text'],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullname,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      user.role,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout, size: 18, color: AppTheme.textSecondaryColor),
                                onPressed: () => LogoutHelper.showLogoutConfirmation(context, auth),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _changePage(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      height: isMobile ? 80 : 90,
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
          const Text(
            'SPMC Pharmacy Portal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          const LiveClock(),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    switch (_selectedIndex) {
      case 0:
        return PharmacyManagementView(isMobile: isMobile);
      case 1:
        return InventoryManagementView(isMobile: isMobile);
      case 2:
        return _buildProfileView(isMobile);
      default:
        return PharmacyManagementView(isMobile: isMobile);
    }
  }

  Widget _buildProfileView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context).user;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      radius: 40,
                      child: Text(
                        user?.fullname.isNotEmpty == true ? user!.fullname[0].toUpperCase() : 'P',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullname ?? 'Pharmacist',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.role ?? 'Pharmacist',
                          style: const TextStyle(fontSize: 14, color: AppTheme.logoRed, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                _buildProfileRow('Staff Unique ID', user?.staffUniqueId ?? '-', Icons.badge_outlined),
                _buildProfileRow('Email Address', user?.email ?? '-', Icons.alternate_email),
                _buildProfileRow('Mobile Number', user?.mobile ?? '-', Icons.phone_android_outlined),
                _buildProfileRow('Status', user?.status ?? '-', Icons.check_circle_outline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
