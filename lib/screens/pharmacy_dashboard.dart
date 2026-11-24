import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart' show LiveClock;
import '../utils/logout_helper.dart';
import '../utils/sidebar_state.dart';
import '../widgets/user_profile_dialog.dart';
import 'pharmacy_management_view.dart';
import 'inventory_management_view.dart';
import 'billing_management_view.dart';
import '../widgets/access_denied_widget.dart';
import '../utils/app_localizations.dart';
import '../widgets/app_top_bar_actions.dart';

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
      backgroundColor: AppTheme.getBackgroundColor(context),
      drawer: isMobile ? Drawer(child: _buildSidebar(context, isMobile: true)) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) _buildSidebar(context, isMobile: false),
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
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isMobile = false}) {
    final isDark = AppTheme.isDark(context);

    return ValueListenableBuilder<bool>(
      valueListenable: SidebarState.isCollapsed,
      builder: (context, isSidebarCollapsed, _) {
        final effectiveCollapsed = isMobile ? false : isSidebarCollapsed;
        final width = isMobile ? double.infinity : (effectiveCollapsed ? 76.0 : 275.0);

        return Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final user = auth.user;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: width,
              margin: isMobile
                  ? EdgeInsets.zero
                  : (effectiveCollapsed
                      ? const EdgeInsets.fromLTRB(10, 16, 6, 16)
                      : const EdgeInsets.fromLTRB(16, 16, 8, 16)),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(20),
                border: isMobile ? null : Border.all(color: AppTheme.getBorderColor(context)),
                boxShadow: isDark || isMobile
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, sidebarBox) {
                    final showCollapsed = effectiveCollapsed || (!isMobile && sidebarBox.maxWidth < 210);

                    return Column(
                      children: [
                        // Logo Section
                        Container(
                          constraints: const BoxConstraints(minHeight: 70),
                          padding: EdgeInsets.symmetric(
                            horizontal: showCollapsed ? 8 : 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppTheme.getBorderColor(context).withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                          ),
                          child: showCollapsed
                              ? Center(
                                  child: Tooltip(
                                    message: 'Expand Sidebar',
                                    preferBelow: false,
                                    child: InkWell(
                                      onTap: () => SidebarState.setCollapsed(false),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Image.asset(
                                          'assets/image/sriPonniLogo.png',
                                          width: 34,
                                          height: 34,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.local_hospital_rounded,
                                            color: AppTheme.primaryColor,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Image.asset(
                                          'assets/image/full_logo.png',
                                          width: 110,
                                          height: 80,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    if (!isMobile)
                                      IconButton(
                                        onPressed: () => SidebarState.setCollapsed(true),
                                        tooltip: 'Collapse Sidebar',
                                        icon: Icon(
                                          Icons.chevron_left_rounded,
                                          color: AppTheme.getTextSecondaryColor(context),
                                          size: 20,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                  ],
                                ),
                        ),

                        // Navigation
                        Expanded(
                          child: ListView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: showCollapsed ? 4 : 0,
                              vertical: 10,
                            ),
                            children: [
                              if (user?.hasPermission('pharmacy_dispensing') ?? false)
                                _buildSidebarItem(0, Icons.local_pharmacy_outlined, context.tr('pharmacy', fallback: 'Pharmacy Management'), isMobile: isMobile, isCollapsed: showCollapsed),
                              if (user?.hasPermission('pharmacy_inventory') ?? false)
                                _buildSidebarItem(1, Icons.inventory_2_outlined, context.tr('inventory', fallback: 'Inventory Management'), isMobile: isMobile, isCollapsed: showCollapsed),
                              if (user?.hasPermission('pharmacy_billing') ?? false)
                                _buildSidebarItem(3, Icons.receipt_long_outlined, context.tr('billing', fallback: 'Pharmacy Billing'), isMobile: isMobile, isCollapsed: showCollapsed),
                              _buildSidebarItem(2, Icons.person_outline, context.tr('profile', fallback: 'My Profile'), isMobile: isMobile, isCollapsed: showCollapsed),
                            ],
                          ),
                        ),

                        // Expand button when collapsed on desktop
                        if (showCollapsed && !isMobile)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppTheme.getBorderColor(context).withOpacity(0.6),
                                ),
                              ),
                            ),
                            child: Center(
                              child: IconButton(
                                onPressed: () => SidebarState.setCollapsed(false),
                                tooltip: 'Expand Sidebar',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),

                        // Footer Profile
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppTheme.getBorderColor(context), width: 1),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: showCollapsed ? 8 : 16,
                            vertical: 14,
                          ),
                          child: user == null
                              ? const SizedBox.shrink()
                              : showCollapsed
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Tooltip(
                                          message: '${user.fullname} (${context.translateRole(user.role)})',
                                          preferBelow: false,
                                          child: InkWell(
                                            onTap: () => UserProfileDialog.show(context, user),
                                            borderRadius: BorderRadius.circular(18),
                                            child: CircleAvatar(
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
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Tooltip(
                                          message: 'Logout',
                                          preferBelow: false,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.logout,
                                              size: 18,
                                              color: AppTheme.getTextSecondaryColor(context),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => LogoutHelper.showLogoutConfirmation(
                                              context,
                                              auth,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
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
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                          color: AppTheme.getTextPrimaryColor(context),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        context.translateRole(user.role),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme.getTextSecondaryColor(context),
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
                                          icon: Icon(
                                            Icons.logout,
                                            size: 18,
                                            color: AppTheme.getTextSecondaryColor(context),
                                          ),
                                          onPressed: () => LogoutHelper.showLogoutConfirmation(
                                            context,
                                            auth,
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label, {bool isMobile = false, bool isCollapsed = false}) {
    bool isSelected = _selectedIndex == index;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 200),
      preferBelow: false,
      verticalOffset: 20,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      child: InkWell(
        onTap: () => _changePage(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 8 : 12,
            vertical: isCollapsed ? 3 : 2,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 14,
            vertical: isCollapsed ? 10 : 11,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: isCollapsed
              ? Center(
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppTheme.getTextSecondaryColor(context),
                    size: 20,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? Colors.white : AppTheme.getTextSecondaryColor(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.getTextPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
        top: isMobile ? 14 : 20,
        bottom: isMobile ? 8 : 0,
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
              icon: Icon(
                Icons.menu,
                color: AppTheme.getTextPrimaryColor(context),
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
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.getBorderColor(context), width: 1.2),
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
            Icon(
              Icons.notifications_none_outlined,
              color: AppTheme.getTextPrimaryColor(context),
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
        AppTopBarActions(
          showClock: !isMobile,
          liveClockWidget: const LiveClock(isDark: false),
        ),
      ],
    );
  }

  Widget _buildMainContent(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    switch (_selectedIndex) {
      case 0:
        if (user?.hasPermission('pharmacy_dispensing') ?? false) {
          return PharmacyManagementView(isMobile: isMobile);
        }
        return const AccessDeniedWidget();
      case 1:
        if (user?.hasPermission('pharmacy_inventory') ?? false) {
          return InventoryManagementView(isMobile: isMobile);
        }
        return const AccessDeniedWidget();
      case 2:
        return _buildProfileView(isMobile);
      case 3:
        if (user?.hasPermission('pharmacy_billing') ?? false) {
          return const BillingManagementView();
        }
        return const AccessDeniedWidget();
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
