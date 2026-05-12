import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../controllers/admin_controller.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../widgets/admin_widgets.dart';
import 'login_page.dart';
import 'package:http/http.dart' as http;  
import 'dart:convert';                     
import '../widgets/rbac_management.dart';
import '../widgets/access_denied_widget.dart';
import '../models/patient_model.dart';
import '../controllers/patient_controller.dart';
import 'new_patient_registration.dart';
import 'patients_view.dart';
import '../utils/logout_helper.dart';
import 'admin_appointment_management.dart';
import 'opd_management.dart';

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
  bool _showDeleted = false;
  final FocusNode _mainFocusNode = FocusNode();
  List<PatientModel> _dbPatients = [];
  final PatientController _patientController = PatientController();
  bool _isRegisteringPatient = false;
  PatientModel? _patientToComplete;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _mainFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStaff();
    _loadRbacData();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final patients = await _patientController.fetchPatients();
      if (mounted) setState(() => _dbPatients = patients);
    } catch (e) {
      debugPrint('Error fetching patients for search: $e');
    }
  }

  void _showSearchOverlay() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return SearchOverlay(
          patients: _dbPatients.map((p) => p.toJson()).toList(),
          onNewPatient: () => setState(() => _selectedIndex = 2), // Navigate to Patient Management
          onBookAppointment: () => setState(() => _selectedIndex = 4), // Navigate to Appointments
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }

  void _loadStaff() {
    setState(() {
      _staffFuture = _adminController.fetchStaff(showDeleted: _showDeleted);
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
    final mobileCtrl = TextEditingController(text: user.mobile);
    final editFormKey = GlobalKey<FormState>();
    String selectedRole = user.role;
    String selectedStatus = user.status;
    int? selectedSpecializationId = user.specializationId;
    List<Map<String, dynamic>> specializations = [];
    bool isSaving = false;
    bool isLoadingSpecializations = false;

    List<String> availableRoles = [];
    bool isLoadingRoles = false;
    String? dialogError;
    
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
                final orderedRoles = ['Super Admin', 'Admin', 'Doctor', 'Nurse'];
                availableRoles = rolesList.map((r) => r['role_name'].toString()).where((r) {
                   if (currentUserRole == 'Super Admin') return true;
                   return r == 'Doctor' || r == 'Nurse' || r == selectedRole;
                }).toList();
                availableRoles.sort((a, b) {
                  int indexA = orderedRoles.indexOf(a);
                  int indexB = orderedRoles.indexOf(b);
                  if (indexA == -1 && indexB == -1) return a.compareTo(b);
                  if (indexA == -1) return 1;
                  if (indexB == -1) return -1;
                  return indexA.compareTo(indexB);
                });
                
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
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: const Text('Edit Staff', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: editFormKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dialogError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    TextFormField(
                      controller: mobileCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number', 
                        prefixIcon: Icon(Icons.phone_outlined),
                        counterText: "",
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter a mobile number';
                        if (val.trim().length != 10) return 'Mobile number must be 10 digits';
                        if (!RegExp(r'^[0-9]+$').hasMatch(val.trim())) return 'Please enter digits only';
                        return null;
                      },
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
                              dialogError = null; // Clear error on change
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
                          onChanged: (val) { if (val != null) setDialogState(() { selectedSpecializationId = val; dialogError = null; }); },
                          validator: (val) => selectedRole == 'Doctor' && val == null ? 'Please select a specialization' : null,
                        ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)),
                      items: ['active', 'inactive', 'suspended'].map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                      onChanged: (val) { if (val != null) setDialogState(() { selectedStatus = val; dialogError = null; }); },
                    ),
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
                    mobile: mobileCtrl.text.trim(),
                    role: selectedRole,
                    status: selectedStatus,
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
                    setDialogState(() => dialogError = e.toString().replaceFirst('Exception: ', ''));
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
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: const Text('Delete Staff', style: TextStyle(fontWeight: FontWeight.bold)),
            content: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(text: user.fullname, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: '? This will deactivate their account and hide them from active lists.'),
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

    return Focus(
      focusNode: _mainFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.slash) {
          _showSearchOverlay();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildBodyContent(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    if (_isRegisteringPatient) {
      return NewPatientRegistrationView(
        key: UniqueKey(),
        existingPatient: _patientToComplete,
        onBack: () {
          setState(() {
            _isRegisteringPatient = false;
            _patientToComplete = null;
          });
          _fetchPatients();
        },
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildControlPanel(isMobile);
      case 1:
        if (user?.hasPermission('manage_users') ?? false) {
          return _buildStaffManagement(isMobile);
        }
        return const AccessDeniedWidget();
      case 2:
        if (user?.hasPermission('view_patients') ?? false) {
          return AdminPatientManagementWrapper(
            onRegister: () => setState(() => _isRegisteringPatient = true),
            onCompleteProfile: (patient) => setState(() {
              _patientToComplete = patient;
              _isRegisteringPatient = true;
            }),
          );
        }
        return const AccessDeniedWidget();
      case 3:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return RbacManagementWidget(isMobile: isMobile);
        }
        return const AccessDeniedWidget();
      case 4:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return const AdminAppointmentManagement();
        }
        return const AccessDeniedWidget();
      case 5:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return OPDManagementScreen(isMobile: isMobile);
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
                        Text(
                          'Staff Management',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'View and manage healthcare staff members',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                    if (Provider.of<AuthProvider>(context, listen: false).user?.hasPermission('manage_users') ?? false) ...[
                      const SizedBox(width: 12),
                      // Show Deleted Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: _showDeleted ? Colors.red.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _showDeleted ? Colors.red.withOpacity(0.3) : AppTheme.borderColor),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() => _showDeleted = !_showDeleted);
                            _loadStaff();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _showDeleted ? Icons.delete_sweep : Icons.delete_outline,
                                  size: 18,
                                  color: _showDeleted ? Colors.red : AppTheme.textSecondaryColor,
                                ),
                                if (!isMobile) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'Show Deleted',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _showDeleted ? Colors.red : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddUserDialog(context),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: Text(isMobile ? 'Add' : 'Register Staff', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: AppTheme.primaryButton,
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
                  
                  final filterRoles = ['All'];
                  if (rbacSnapshot.hasData) {
                    final rolesList = rbacSnapshot.data!['roles'] as List<dynamic>? ?? [];
                    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
                    
                    List<String> dbRoles = rolesList.map((r) => r['role_name'].toString()).toList();
                    
                    // Filter roles based on requester's role
                    if (currentUser?.role == 'Admin') {
                      dbRoles = dbRoles.where((r) => r != 'Super Admin').toList();
                    }

                    final orderedRoles = ['Super Admin', 'Admin', 'Doctor', 'Nurse'];
                    dbRoles.sort((a, b) {
                      int indexA = orderedRoles.indexOf(a);
                      int indexB = orderedRoles.indexOf(b);
                      if (indexA == -1 && indexB == -1) return a.compareTo(b);
                      if (indexA == -1) return 1;
                      if (indexB == -1) return -1;
                      return indexA.compareTo(indexB);
                    });
                    filterRoles.addAll(dbRoles);
                  }

                  return SizedBox(
                    height: 44,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                                padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18, vertical: 10),
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
      decoration: AppTheme.cardDecoration,
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
                          color: user.status == 'active' ? Colors.green.withOpacity(0.1) : (user.status == 'suspended' ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: user.status == 'active' ? Colors.green : (user.status == 'suspended' ? Colors.red : Colors.grey), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(user.status[0].toUpperCase() + user.status.substring(1), style: TextStyle(color: user.status == 'active' ? Colors.green : (user.status == 'suspended' ? Colors.red : Colors.grey), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.role != 'Super Admin') ...[
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                              onPressed: () => _showEditDialog(context, user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () => _showDeleteConfirmation(context, user),
                            ),
                          ],
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

        final statusColor = user.status == 'active' ? Colors.green : (user.status == 'suspended' ? Colors.red : Colors.grey);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: user.isDeleted ? Colors.red.withOpacity(0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: user.isDeleted ? Colors.red.withOpacity(0.2) : AppTheme.borderColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: roleColor.withOpacity(0.1),
                    child: Text(
                      user.fullname.isNotEmpty ? user.fullname[0].toUpperCase() : '?',
                      style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(user.fullname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (user.isDeleted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                child: const Text('DELETED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        Text(user.email, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(user.role, style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Staff ID', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                      Text(user.staffUniqueId ?? '\u2014', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Status', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(user.status[0].toUpperCase() + user.status.substring(1), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (!user.isDeleted && user.role != 'Super Admin') ...[
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditDialog(context, user),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showDeleteConfirmation(context, user),
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
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
            padding: const EdgeInsets.only(left: 24, top: 0, bottom: 0, right: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
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

          // Navigation Items (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildSidebarItem(0, Icons.admin_panel_settings_outlined, 'Control Panel'),
                  _buildSidebarItem(1, Icons.people_outline, 'Staff Management'),
                  _buildSidebarItem(2, Icons.sick_outlined, 'Patient Management'),
                  _buildSidebarItem(3, Icons.security_outlined, 'Access Control'),
                  _buildSidebarItem(4, Icons.calendar_month_outlined, 'Appointments'),
                  _buildSidebarItem(5, Icons.monitor_heart_outlined, 'OPD Management'),
                ],
              ),
            ),
          ),

          // User Profile Footer
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final user = auth.user;
                    if (user == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.primaryColor,
                          radius: 18,
                          child: Icon(Icons.person, color: Colors.white, size: 20),
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
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index && !_isRegisteringPatient;
    return InkWell(
      onTap: () => setState(() {
        _selectedIndex = index;
        _isRegisteringPatient = false;
        _patientToComplete = null;
      }),
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
            Expanded(
              child: Text(
                label, 
                style: TextStyle(color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
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
      height: isMobile ? 80 : 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isMobile) ...[
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: AppTheme.textSecondaryColor,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextFormField(
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: isMobile ? 'Search...' : 'Quick search...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  suffixText: isMobile ? null : '/',
                  suffixStyle: const TextStyle(color: AppTheme.iconColor),
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding: const EdgeInsets.only(top: 2),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                readOnly: true,
                onTap: _showSearchOverlay,
              ),
            ),
          ),

          if (!isMobile) ...[
            const SizedBox(width: 24),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_outlined,
                  color: AppTheme.textSecondaryColor,
                  size: 22,
                ),
                const SizedBox(width: 20),
                const Icon(
                  Icons.help_outline,
                  color: AppTheme.textSecondaryColor,
                  size: 22,
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(80, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Share', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
          const SizedBox(width: 24),

          // Date & Time
          const AdminLiveClock(),
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
  final _mobileController = TextEditingController();
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
  String? _errorMessage;

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
          
          final orderedRoles = ['Super Admin', 'Admin', 'Doctor', 'Nurse'];
          _roles.sort((a, b) {
            int indexA = orderedRoles.indexOf(a);
            int indexB = orderedRoles.indexOf(b);
            if (indexA == -1 && indexB == -1) return a.compareTo(b);
            if (indexA == -1) return 1;
            if (indexB == -1) return -1;
            return indexA.compareTo(indexB);
          });
          
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
    _mobileController.dispose();
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
      mobile: _mobileController.text.trim(),
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
    if (mounted) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Register New Staff', style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  controller: _nameController,
                  onChanged: (_) { if (_errorMessage != null) setState(() => _errorMessage = null); },
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (val) => val == null || val.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  onChanged: (_) { if (_errorMessage != null) setState(() => _errorMessage = null); },
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || val.isEmpty || !val.contains('@') ? 'Please enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  onChanged: (_) { if (_errorMessage != null) setState(() => _errorMessage = null); },
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number', 
                    prefixIcon: Icon(Icons.phone_outlined),
                    counterText: "",
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Please enter a mobile number';
                    if (val.length != 10) return 'Mobile number must be 10 digits';
                    if (!RegExp(r'^[0-9]+$').hasMatch(val)) return 'Please enter digits only';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  onChanged: (_) { if (_errorMessage != null) setState(() => _errorMessage = null); },
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
                        _errorMessage = null;
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

class AdminPatientManagementWrapper extends StatefulWidget {
  final VoidCallback onRegister;
  final Function(PatientModel) onCompleteProfile;

  const AdminPatientManagementWrapper({
    Key? key,
    required this.onRegister,
    required this.onCompleteProfile,
  }) : super(key: key);

  @override
  State<AdminPatientManagementWrapper> createState() => _AdminPatientManagementWrapperState();
}

class _AdminPatientManagementWrapperState extends State<AdminPatientManagementWrapper> {
  List<PatientModel> _dbPatients = [];
  bool _isLoading = false;
  String? _error;
  final PatientController _patientController = PatientController();

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final patients = await _patientController.fetchPatients();
      if (mounted) setState(() => _dbPatients = patients);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PatientsView(
      patients: _dbPatients,
      isLoading: _isLoading,
      error: _error,
      onCompleteProfile: widget.onCompleteProfile,
      onRefresh: _fetchPatients,
      onRegisterPatient: widget.onRegister,
      onBookAppointment: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking appointments from Admin Dashboard is currently not supported.')),
        );
      },
    );
  }
}
