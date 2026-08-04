import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart' show LiveClock;
import '../utils/logout_helper.dart';
import '../widgets/user_profile_dialog.dart';
import 'pharmacy_management_view.dart';
import 'inventory_management_view.dart';
import 'billing_management_view.dart';

class PharmacyDashboardScreen extends StatefulWidget {
  final int initialIndex;
  const PharmacyDashboardScreen({super.key, this.initialIndex = 0});

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
    if (!mounted) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.pharmacyDashboard);
        break;
      case 1:
        context.go(AppRoutes.pharmacyInventory);
        break;
      case 2:
        context.go(AppRoutes.pharmacyProfile);
        break;
      case 3:
        context.go(AppRoutes.pharmacyBilling);
        break;
      default:
        context.go(AppRoutes.pharmacyDashboard);
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
          margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Logo Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Image.asset(
                  'assets/image/full_logo.png',
                  width: 110,
                  height: 90,
                ),
              ),

              // Navigation
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSidebarItem(0, Icons.local_pharmacy_outlined, 'Pharmacy Management'),
                      _buildSidebarItem(1, Icons.inventory_2_outlined, 'Inventory Management'),
                      _buildSidebarItem(3, Icons.receipt_long_outlined, 'Pharmacy Billing'),
                      _buildSidebarItem(2, Icons.person_outline, 'My Profile'),
                    ],
                  ),
                ),
              ),

              // Footer Profile
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: user == null
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => UserProfileDialog.show(context, user),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    radius: 18,
                                    child: Text(
                                      user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullname,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          user.role,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout,
                              size: 18,
                              color: AppTheme.textSecondaryColor,
                            ),
                            onPressed: () =>
                                LogoutHelper.showLogoutConfirmation(
                                  context,
                                  auth,
                                ),
                          ),
                        ],
                      ),
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF4A5568),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2D3748),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: EdgeInsets.only(
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        top: 20,
        bottom: 0,
      ),
      child: _buildBannerTopBar(isMobile),
    );
  }

  Widget _buildBannerTopBar(bool isMobile) {
    return Row(
      children: [
        if (isMobile) ...[
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.menu,
                color: Color(0xFF4A5568),
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
        ],

        Expanded(
          child: Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'SPMC Pharmacy Portal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_outlined,
              color: Color(0xFF4A5568),
              size: 22,
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53E3E),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),
        const Icon(Icons.settings_outlined, color: Color(0xFF4A5568), size: 22),
        const SizedBox(width: 16),
        const LiveClock(isDark: false),
      ],
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
      case 3:
        return const BillingManagementView();
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
