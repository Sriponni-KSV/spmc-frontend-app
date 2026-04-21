import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../controllers/admin_controller.dart';
import '../widgets/nurse_widgets.dart';
import 'login_page.dart';
import 'package:http/http.dart' as http;  
import 'dart:convert';                     
import '../widgets/rbac_management.dart';
import '../widgets/access_denied_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  String _selectedRoleFilter = 'All';
  final AdminController _adminController = AdminController();
  Future<List<UserModel>>? _staffFuture;
  Future<Map<String, dynamic>>? _rbacFuture;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _loadRbacData();
  }

  void _loadStaff() {
    setState(() {
      _staffFuture = _adminController.fetchStaff();
    });
  }

  void _loadRbacData() {
    setState(() {
      _rbacFuture = _adminController.fetchRbacData();
    });
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddUserDialog(),
    ).then((_) => _loadStaff()); // Refresh list after dialog closes
  }

  void _showEditDialog(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.fullname);
    final emailCtrl = TextEditingController(text: user.email);
    final editFormKey = GlobalKey<FormState>();
    String selectedRole = user.role;
    int? selectedSpecializationId = user.specializationId;
    List<Map<String, dynamic>> specializations = [];
    bool isSaving = false;
    bool isLoadingSpecializations = false;

    List<String> availableRoles = [];
    bool isLoadingRoles = false;
    
    // Initial sync
    if (!availableRoles.contains(selectedRole)) {
      availableRoles.add(selectedRole);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Initialize specializations once if needed
          if (specializations.isEmpty && !isLoadingSpecializations) {
            setDialogState(() => isLoadingSpecializations = true);
            _adminController.fetchSpecializations().then((specs) {
              setDialogState(() {
                specializations = specs;
                isLoadingSpecializations = false;
              });
            }).catchError((e) {
              setDialogState(() => isLoadingSpecializations = false);
            });
          }

          // Initialize roles dynamically
          if (availableRoles.length <= 1 && !isLoadingRoles) {
            setDialogState(() => isLoadingRoles = true);
            _adminController.fetchRbacData().then((rbacData) {
              setDialogState(() {
                final rolesList = rbacData['roles'] as List<dynamic>? ?? [];
                final currentUserRole = Provider.of<AuthProvider>(ctx, listen: false).user?.role;
                
                // Allow Super Admin to assign any role. Admin can only assign Doctor/Nurse
                availableRoles = rolesList.map((r) => r['role_name'].toString()).where((r) {
                   if (currentUserRole == 'Super Admin') return true;
                   return r == 'Doctor' || r == 'Nurse' || r == selectedRole;
                }).toList();
                
                if (!availableRoles.contains(selectedRole)) {
                  availableRoles.add(selectedRole);
                }
                isLoadingRoles = false;
              });
            }).catchError((e) {
              setDialogState(() => isLoadingRoles = false);
            });
          }
          return AlertDialog(
          title: const Text('Edit Staff', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.staffUniqueId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          initialValue: user.staffUniqueId,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Staff ID',
                            prefixIcon: Icon(Icons.pin_outlined),
                            fillColor: Color(0xFFF3F4F6),
                            filled: true,
                            helperText: 'Auto-generated ID',
                          ),
                        ),
                      ),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => val == null || val.trim().isEmpty || !val.contains('@') ? 'Please enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    if (isLoadingRoles)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                        items: availableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                              if (selectedRole != 'Doctor') {
                                selectedSpecializationId = null;
                              }
                            });
                          }
                        },
                      ),
                    if (selectedRole == 'Doctor') ...[
                      const SizedBox(height: 16),
                      if (isLoadingSpecializations)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<int>(
                          value: selectedSpecializationId,
                          decoration: const InputDecoration(labelText: 'Specialization', prefixIcon: Icon(Icons.star_outline)),
                          items: specializations.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                          onChanged: (val) { if (val != null) setDialogState(() => selectedSpecializationId = val); },
                          validator: (val) => selectedRole == 'Doctor' && val == null ? 'Please select a specialization' : null,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (!editFormKey.currentState!.validate()) return;
                setDialogState(() => isSaving = true);
                try {
                  await _adminController.updateStaff(
                    id: user.id,
                    fullname: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    role: selectedRole,
                    medicalLicense: null,
                    specializationId: selectedRole == 'Doctor' ? selectedSpecializationId : null,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadStaff();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${nameCtrl.text.trim()} updated successfully!'), backgroundColor: Colors.green.shade600),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showDeleteConfirmation(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Delete Staff', style: TextStyle(fontWeight: FontWeight.bold)),
            content: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(text: user.fullname, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '? This action cannot be undone.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isDeleting ? null : () async {
                  setDialogState(() => isDeleting = true);
                  try {
                    await _adminController.deleteStaff(user.id);
                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadStaff();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${user.fullname} deleted.'), backgroundColor: Colors.green.shade600),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                      );
                    }
                  } finally {
                    if (mounted) setDialogState(() => isDeleting = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                child: isDeleting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sidebar (only on desktop)
            if (!isMobile) _buildSidebar(context),
            
            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  _buildHeader(context, isMobile),
                  Expanded(
                    child: ClipRRect(child: _buildBodyContent(isMobile)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    
    switch (_selectedIndex) {
      case 0:
        return _buildControlPanel(isMobile);
      case 1:
        if (user?.hasPermission('manage_users') ?? false) {
          return _buildStaffManagement(isMobile);
        }
        return const AccessDeniedWidget();
      case 2:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return RbacManagementWidget(isMobile: isMobile);
        }
        return const AccessDeniedWidget();
      default:
        return _buildControlPanel(isMobile);
    }
  }

  Widget _buildControlPanel(bool isMobile) {
    return SingleChildScrollView(
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
    );
  }

  Widget _buildStaffManagement(bool isMobile) {
    return FutureBuilder<List<UserModel>>(
      future: _staffFuture,
      builder: (context, snapshot) {
        List<UserModel> allStaff = snapshot.data ?? [];
        List<UserModel> filtered = _selectedRoleFilter == 'All'
            ? allStaff
            : allStaff.where((u) => u.role == _selectedRoleFilter).toList();

        return Column(
          children: [
            // ── Header: Title + Register Button ──
            Container(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 24, isMobile ? 16 : 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Staff Management', style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('View and manage healthcare staff members', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (Provider.of<AuthProvider>(context, listen: false).user?.hasPermission('manage_users') ?? false) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddUserDialog(context),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: Text(isMobile ? 'Add' : 'Register Staff', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Role Filter Tabs ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              alignment: Alignment.centerLeft,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _rbacFuture,
                builder: (context, rbacSnapshot) {
                  if (rbacSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
                  }
                  
                  List<String> filterRoles = ['All'];
                  if (rbacSnapshot.hasData) {
                    final rolesList = rbacSnapshot.data!['roles'] as List<dynamic>? ?? [];
                    final dbRoles = rolesList.map((r) => r['role_name'].toString()).toList();
                    filterRoles.addAll(dbRoles);
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filterRoles.map((role) {
                        final isActive = _selectedRoleFilter == role;
                        final count = role == 'All'
                            ? allStaff.length
                            : allStaff.where((u) => u.role == role).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() => _selectedRoleFilter = role),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive ? AppTheme.primaryColor : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isActive ? AppTheme.primaryColor : AppTheme.borderColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    role,
                                    style: TextStyle(
                                      color: isActive ? Colors.white : AppTheme.textSecondaryColor,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.white.withOpacity(0.2) : AppTheme.backgroundColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: isActive ? Colors.white : AppTheme.textSecondaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
              ),
            ),

            const SizedBox(height: 16),

            // ── Content Area ──
            Expanded(
              child: ClipRRect(
                child: _buildStaffContent(snapshot, filtered, isMobile),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaffContent(AsyncSnapshot<List<UserModel>> snapshot, List<UserModel> staff, bool isMobile) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            const Text('Failed to load staff data', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${snapshot.error}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadStaff,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (staff.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, color: AppTheme.textSecondaryColor.withOpacity(0.4), size: 64),
            const SizedBox(height: 12),
            const Text('No staff found', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              _selectedRoleFilter == 'All' ? 'Register your first staff member.' : 'No $_selectedRoleFilter found.',
              style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return _buildStaffCards(staff);
    }
    return _buildStaffTable(staff, isMobile);
  }

  Widget _buildStaffTable(List<UserModel> staff, bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              controller: _verticalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                horizontalMargin: 24,
                columnSpacing: 32,
                headingRowHeight: 56,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 68,
                headingRowColor: WidgetStateProperty.all(AppTheme.backgroundColor),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                columns: [
                  const DataColumn(label: Text('Staff ID')),
                  const DataColumn(label: Text('Name')),
                  const DataColumn(label: Text('Role')),
                  if (_selectedRoleFilter == 'Doctor')
                    const DataColumn(label: Text('Specialization')),
                  const DataColumn(label: Text('Status')),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: staff.map((user) {
                  Color roleColor;
                  switch (user.role) {
                    case 'Doctor': roleColor = const Color(0xFF6366F1); break;
                    case 'Nurse': roleColor = const Color(0xFF14B8A6); break;
                    case 'Admin': roleColor = const Color(0xFFF59E0B); break;
                    case 'Super Admin': roleColor = const Color(0xFFEC4899); break;
                    default: roleColor = Colors.grey; break;
                  }
                  return DataRow(
                    cells: [
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(user.staffUniqueId ?? '\u2014', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13, fontFamily: 'monospace')),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: roleColor.withOpacity(0.1),
                            child: Text(
                              user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : '?',
                              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.fullname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(user.email, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                            ],
                          ),
                        ],
                      )),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(user.role, style: TextStyle(color: roleColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      )),
                      if (_selectedRoleFilter == 'Doctor')
                        DataCell(Text(user.specialization ?? '\u2014', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('Active', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                            onPressed: () => _showEditDialog(context, user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: () => _showDeleteConfirmation(context, user),
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
     },
    ),
   ),
  );
}
  Widget _buildStaffCards(List<UserModel> staff) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: staff.length,
      itemBuilder: (context, index) {
        final user = staff[index];
        Color roleColor;
        switch (user.role) {
          case 'Doctor': roleColor = const Color(0xFF6366F1); break;
          case 'Nurse': roleColor = const Color(0xFF14B8A6); break;
          case 'Admin': roleColor = const Color(0xFFF59E0B); break;
          case 'Super Admin': roleColor = const Color(0xFFEC4899); break;
          default: roleColor = Colors.grey; break;
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleColor.withOpacity(0.1),
                child: Text(
                  user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : '?',
                  style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(user.fullname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        if (user.staffUniqueId != null)
                          Text(user.staffUniqueId!, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(user.email, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(user.role, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        if (_selectedRoleFilter == 'Doctor' && user.specialization != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(user.specialization!, style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              const Text('Active', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (user.medicalLicense != null) ...[
                          const SizedBox(width: 8),
                          Text(user.medicalLicense!, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _showEditDialog(context, user),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _showDeleteConfirmation(context, user),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
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
                  child: Image.asset('assets/image/sriPonniLogo.png', width: 32, height: 32),
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
          _buildSidebarItem(2, Icons.security_outlined, 'Access Control'),
          _buildSidebarItem(3, Icons.analytics_outlined, 'System Analytics'),
          _buildSidebarItem(4, Icons.settings_outlined, 'Settings'),
          
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
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Menu & Search
          if (isMobile) 
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.textSecondaryColor),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          
          Flexible(
            flex: 2,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search system...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Right Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notifications icon only on web
              if (!isMobile) ...[
                const Icon(Icons.notifications_none_outlined, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 20),
              ],
              
              // Restored LiveClock widget for real-time display with seconds and day
              if (!isMobile) 
                const LiveClock()
              else
                Text(
                  DateFormat('hh:mm a').format(DateTime.now()),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                ),
            ],
          ),
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
final AdminController _adminController = AdminController();

  String _selectedRole = 'Doctor';
  List<String> _roles = ['Doctor', 'Nurse'];
  int? _selectedSpecializationId;
  List<Map<String, dynamic>> _specializations = [];
  bool _isLoading = false;
  bool _isLoadingRoles = false;
  bool _isLoadingSpecializations = false;

  @override
  void initState() {
    super.initState();
    _loadSpecializations();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoadingRoles = true);
    try {
      final rbacData = await _adminController.fetchRbacData();
      final rolesList = rbacData['roles'] as List<dynamic>? ?? [];
      
      if (mounted) {
        final currentUserRole = Provider.of<AuthProvider>(context, listen: false).user?.role;
        setState(() {
          _roles = rolesList.map((r) => r['role_name'].toString()).where((r) {
             if (currentUserRole == 'Super Admin') return true;
             return r == 'Doctor' || r == 'Nurse';
          }).toList();
          
          if (!_roles.contains(_selectedRole) && _roles.isNotEmpty) {
             _selectedRole = _roles.first;
          }
          _isLoadingRoles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading roles: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadSpecializations() async {
    setState(() => _isLoadingSpecializations = true);
    try {
      final specs = await _adminController.fetchSpecializations();
      setState(() {
        _specializations = specs;
        _isLoadingSpecializations = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSpecializations = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading specializations: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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

  try {
    await _adminController.createStaff(
      fullname: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      role: _selectedRole,
      medicalLicense: _licenseController.text.trim(),
      specializationId: _selectedRole == 'Doctor' ? _selectedSpecializationId : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User created successfully'), backgroundColor: Colors.green),
    );
    Navigator.pop(context);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register New Staff', style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.9,
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
                _isLoadingRoles 
                  ? const Center(child: CircularProgressIndicator()) 
                  : DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                  items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRole = val;
                        if (_selectedRole != 'Doctor') {
                          _selectedSpecializationId = null;
                        }
                      });
                    }
                  },
                ),
                if (_selectedRole == 'Doctor') ...[
                  const SizedBox(height: 16),
                  _isLoadingSpecializations
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<int>(
                          value: _selectedSpecializationId,
                          decoration: const InputDecoration(
                            labelText: 'Specialization',
                            prefixIcon: Icon(Icons.star_outline),
                          ),
                          items: _specializations.map((spec) {
                            return DropdownMenuItem<int>(
                              value: spec['id'],
                              child: Text(spec['name']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedSpecializationId = val);
                          },
                          validator: (val) => _selectedRole == 'Doctor' && val == null ? 'Please select a specialization' : null,
                        ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(labelText: 'Medical License (Optional)', prefixIcon: Icon(Icons.medical_services_outlined)),
                  ),
                ],
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
              : const Text('Create Staff'),
        ),
      ],
    );
  }
}
