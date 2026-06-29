import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../widgets/custom_dropdown_search.dart';
import '../providers/auth_provider.dart';
import '../controllers/admin_controller.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../widgets/admin_widgets.dart';
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
import 'admin_staff_profile_view.dart';
import 'ipd_management.dart';
import 'ot_management.dart';
import '../utils/password_policy.dart';
import '../controllers/nurse_shift_controller.dart';
import 'icu_management_view.dart';



class AdminDashboardScreen extends StatefulWidget {
  final int initialIndex;
  const AdminDashboardScreen({Key? key, this.initialIndex = 0}) : super(key: key);

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
  final ScrollController _shiftAllocHorizontalScrollController = ScrollController();
  bool _showDeleted = false;
  final FocusNode _mainFocusNode = FocusNode();
  List<PatientModel> _dbPatients = [];
  final PatientController _patientController = PatientController();
  bool _isRegisteringPatient = false;
  PatientModel? _patientToComplete;
  UserModel? _viewingStaffProfile;

  final NurseShiftController _shiftCtrl = NurseShiftController();
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _allocations = [];
  List<UserModel> _nurses = [];
  bool _isLoadingShifts = false;

  UserModel? _selectedAllocNurse;
  Map<String, dynamic>? _selectedAllocShift;
  String? _selectedAllocWard;
  DateTime? _selectedAllocDate;
  DateTime? _filterAllocLogDate = DateTime.now();

  int _shiftManagementSubTab = 0; // 0 = Daily Allocations, 1 = Weekly Rosters
  List<Map<String, dynamic>> _rosters = [];
  DateTime _selectedRosterWeekStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(Duration(days: DateTime.now().weekday - 1));

  Future<void> _loadRosterData() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedRosterWeekStart);
    try {
      final rostersList = await _shiftCtrl.fetchRosters(dateStr);
      if (mounted) {
        setState(() {
          _rosters = rostersList;
        });
      }
    } catch (e) {
      debugPrint('Error loading rosters: $e');
    }
  }

  Map<String, dynamic> _getWeeklyRoster(String ward, int shiftId) {
    final allocations = _rosters.where(
      (r) => r['ward_type'] == ward && r['shift_id'] == shiftId
    ).toList();

    if (allocations.isEmpty) return <String, dynamic>{};

    final Map<int, List<Map<String, dynamic>>> nurseAllocations = {};
    for (final alloc in allocations) {
      final nurseId = alloc['nurse_id'];
      if (nurseId != null) {
        nurseAllocations.putIfAbsent(nurseId, () => []).add(alloc);
      }
    }

    for (final entry in nurseAllocations.entries) {
      if (entry.value.length == 7) {
        return entry.value.first;
      }
    }

    return <String, dynamic>{};
  }

  Future<void> _saveRosterEntry(int nurseId, int shiftId, String wardType) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedRosterWeekStart);
    if (mounted) setState(() => _isLoadingShifts = true);
    try {
      await _shiftCtrl.saveRosterEntry(nurseId, shiftId, wardType, dateStr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roster entry saved successfully!'), backgroundColor: Colors.green),
        );
      }
      await _loadShiftData(); // reload allocations and rosters
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving roster: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingShifts = false);
      }
    }
  }

  Future<void> _deleteRosterEntry(int id) async {
    if (mounted) setState(() => _isLoadingShifts = true);
    try {
      await _shiftCtrl.deleteRosterEntry(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roster entry deleted successfully!'), backgroundColor: Colors.green),
        );
      }
      await _loadShiftData(); // reload allocations and rosters
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting roster: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingShifts = false);
      }
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _shiftAllocHorizontalScrollController.dispose();
    _mainFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadStaff();
    _loadRbacData();
    _fetchPatients();
    if (_selectedIndex == 8) {
      _loadShiftData();
    }
  }

  @override
  void didUpdateWidget(covariant AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
      if (_selectedIndex == 8) {
        _loadShiftData();
      }
    }
  }

  Future<void> _loadShiftData() async {
    if (!mounted) return;
    setState(() => _isLoadingShifts = true);
    try {
      final results = await Future.wait([
        _shiftCtrl.fetchShifts(),
        _shiftCtrl.fetchAllocations(),
        _adminController.fetchStaff(role: 'Nurse'),
      ]);
      if (mounted) {
        setState(() {
          _shifts = List<Map<String, dynamic>>.from(results[0]);
          _allocations = List<Map<String, dynamic>>.from(results[1]);
          _nurses = List<UserModel>.from(results[2]);
        });
      }
      await _loadRosterData();
    } catch (e) {
      debugPrint('Error loading shift data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingShifts = false);
      }
    }
  }

  String _formatTo12Hour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      final formattedMinute = minute.toString().padLeft(2, '0');
      return '${formattedHour.toString().padLeft(2, '0')}:$formattedMinute $ampm';
    } catch (_) {
      return timeStr;
    }
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
          onNewPatient: () => context.go('${AppRoutes.adminDashboard}?tab=2'),
          onBookAppointment: () => context.go('${AppRoutes.adminDashboard}?tab=4'),
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
            _adminController
                .fetchSpecializations()
                .then((specs) {
                  setDialogState(() {
                    specializations = specs;
                    isLoadingSpecializations = false;
                  });
                })
                .catchError((e) {
                  setDialogState(() => isLoadingSpecializations = false);
                });
          }

          // Initialize roles dynamically
          if (availableRoles.length <= 1 && !isLoadingRoles) {
            setDialogState(() => isLoadingRoles = true);
            _adminController
                .fetchRbacData()
                .then((rbacData) {
                  setDialogState(() {
                    final rolesList = rbacData['roles'] as List<dynamic>? ?? [];
                    final currentUserRole = Provider.of<AuthProvider>(
                      ctx,
                      listen: false,
                    ).user?.role;

                    // Allow Super Admin to assign any role. Admin can only assign Doctor/Nurse/Front Desk/Anaesthetist
                    final orderedRoles = [
                      'Super Admin',
                      'Admin',
                      'Doctor',
                      'Nurse',
                      'Anaesthetist',
                      'Front Desk',
                    ];
                    availableRoles = rolesList
                        .map((r) => r['role_name'].toString())
                        .where((r) {
                          if (currentUserRole == 'Super Admin') return true;
                          return r == 'Doctor' ||
                              r == 'Nurse' ||
                              r == 'Front Desk' ||
                              r == 'Anaesthetist' ||
                              r == selectedRole;
                        })
                        .toList();
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
                })
                .catchError((e) {
                  setDialogState(() => isLoadingRoles = false);
                });
          }
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: const Text(
              'Edit Staff',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 500
                  ? 450
                  : MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Form(
                  key: editFormKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (user.staffUniqueId != null) ...[
                        const Text(
                          'Staff ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            initialValue: user.staffUniqueId,
                            readOnly: true,
                            decoration: const InputDecoration(
                              hintText: 'Staff ID',
                              prefixIcon: Icon(Icons.pin_outlined),
                              fillColor: Color(0xFFE5E7EB), // read-only color
                              filled: true,
                              helperText: 'Auto-generated ID',
                            ),
                          ),
                        ),
                      ],
                      const Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\s]'),
                          ),
                          LengthLimitingTextInputFormatter(30),
                        ],
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Please enter a name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter email address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter Email Address';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(val.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Mobile Number',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: mobileCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter mobile number',
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
                          if (val == null || val.trim().isEmpty)
                            return 'Please enter a mobile number';
                          if (val.trim().length != 10)
                            return 'Mobile number must be 10 digits';
                          if (!RegExp(r'^[0-9]+$').hasMatch(val.trim()))
                            return 'Please enter digits only';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (isLoadingRoles)
                        const Center(child: CircularProgressIndicator())
                      else
                        const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),

                      const SizedBox(height: 10),

                      CustomDropdownSearch(
                        label: '',
                        value: selectedRole,
                        dropdownItems: availableRoles,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                            });
                          }
                        },
                      ),
                      if (selectedRole == 'Doctor') ...[
                        const SizedBox(height: 16),
                        if (isLoadingSpecializations)
                          const Center(child: CircularProgressIndicator())
                        else
                          CustomDropdownSearch(
                            label: 'Specialization',
                            value: selectedSpecializationId?.toString(),
                            dropdownMap: {
                              for (var s in specializations)
                                s['id'].toString(): s['name'].toString(),
                            },
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedSpecializationId = int.tryParse(val);
                                  dialogError = null;
                                });
                              }
                            },
                            validator: (val) =>
                                selectedRole == 'Doctor' &&
                                    (val == null || val.isEmpty)
                                ? 'Please select a specialization'
                                : null,
                          ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 10),

                      CustomDropdownSearch(
                        label: '',
                        value: selectedStatus,
                        dropdownMap: const {
                          'active': 'Active',
                          'inactive': 'Inactive',
                          'suspended': 'Suspended',
                        },
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
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
                            specializationId: selectedRole == 'Doctor'
                                ? selectedSpecializationId
                                : null,
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadStaff();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${nameCtrl.text.trim()} updated successfully!',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setDialogState(
                              () => dialogError = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.logoRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: const Text(
              'Delete Staff',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: user.fullname,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        '? This will deactivate their account and hide them from active lists.',
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        try {
                          await _adminController.deleteStaff(user.id);
                          if (mounted) {
                            Navigator.pop(ctx);
                            _loadStaff();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${user.fullname} deleted.'),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isDeleting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
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

    if (_viewingStaffProfile != null) {
      return AdminStaffProfileView(
        user: _viewingStaffProfile!,
        onBack: () => setState(() => _viewingStaffProfile = null),
      );
    }

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
      case 6:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return IPDManagementScreen(isMobile: isMobile);
        }
        return const AccessDeniedWidget();
      case 7:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return OTManagementScreen(isMobile: isMobile);
        }
        return const AccessDeniedWidget();
      case 8:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return _buildShiftManagement(isMobile);
        }
        return const AccessDeniedWidget();
      case 9:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return ICUManagementView(isMobile: isMobile);
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
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                0,
              ),
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
                  if (Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).user?.hasPermission('manage_users') ??
                      false) ...[
                    const SizedBox(width: 12),
                    // Show Deleted Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: _showDeleted
                            ? Colors.red.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _showDeleted
                              ? Colors.red.withOpacity(0.3)
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() => _showDeleted = !_showDeleted);
                          _loadStaff();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _showDeleted
                                    ? Icons.delete_sweep
                                    : Icons.delete_outline,
                                size: 18,
                                color: _showDeleted
                                    ? Colors.red
                                    : AppTheme.textSecondaryColor,
                              ),
                              if (!isMobile) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Show Deleted',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _showDeleted
                                        ? Colors.red
                                        : AppTheme.textSecondaryColor,
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
                      label: Text(
                        isMobile ? 'Add' : 'Register Staff',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dangerColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(120, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                    return const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final filterRoles = ['All'];
                  if (rbacSnapshot.hasData) {
                    final rolesList =
                        rbacSnapshot.data!['roles'] as List<dynamic>? ?? [];
                    final currentUser = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).user;

                    List<String> dbRoles = rolesList
                        .map((r) => r['role_name'].toString())
                        .toList();

                    // Filter roles based on requester's role
                    if (currentUser?.role == 'Admin') {
                      dbRoles = dbRoles
                          .where((r) => r != 'Super Admin')
                          .toList();
                    }

                    final orderedRoles = [
                      'Super Admin',
                      'Admin',
                      'Doctor',
                      'Nurse',
                      'Anaesthetist',
                      'Front Desk',
                    ];
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
                              onTap: () =>
                                  setState(() => _selectedRoleFilter = role),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 14 : 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isActive
                                        ? AppTheme.primaryColor
                                        : AppTheme.borderColor,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      role,
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : AppTheme.textSecondaryColor,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.white.withOpacity(0.2)
                                            : AppTheme.backgroundColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.white
                                              : AppTheme.textSecondaryColor,
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
                },
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

  Widget _buildStaffContent(
    AsyncSnapshot<List<UserModel>> snapshot,
    List<UserModel> staff,
    bool isMobile,
  ) {
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
            const Text(
              'Failed to load staff data',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${snapshot.error}',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
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
            Icon(
              Icons.people_outline,
              color: AppTheme.textSecondaryColor.withOpacity(0.4),
              size: 64,
            ),
            const SizedBox(height: 12),
            const Text(
              'No staff found',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedRoleFilter == 'All'
                  ? 'Register your first staff member.'
                  : 'No $_selectedRoleFilter found.',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 13,
              ),
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
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFEDF2F7),
                      ),
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
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
                          case 'Doctor':
                            roleColor = const Color(0xFF6366F1);
                            break;
                          case 'Nurse':
                            roleColor = const Color(0xFF14B8A6);
                            break;
                          case 'Admin':
                            roleColor = const Color(0xFFF59E0B);
                            break;
                          case 'Super Admin':
                            roleColor = const Color(0xFFEC4899);
                            break;
                          case 'Front Desk':
                            roleColor = const Color(0xFF8B5CF6);
                            break;
                          case 'Anaesthetist':
                            roleColor = const Color(0xFF3B82F6);
                            break;
                          default:
                            roleColor = Colors.grey;
                            break;
                        }
                        return DataRow(
                          cells: [
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(
                                    0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user.staffUniqueId ?? '\u2014',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: roleColor.withOpacity(0.1),
                                    child: Text(
                                      user.fullname.isNotEmpty
                                          ? user.fullname[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: roleColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullname,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        user.email,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  user.role,
                                  style: TextStyle(
                                    color: roleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (_selectedRoleFilter == 'Doctor')
                              DataCell(
                                Text(
                                  user.specialization ?? '\u2014',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: user.status == 'active'
                                      ? Colors.green.withOpacity(0.1)
                                      : (user.status == 'suspended'
                                            ? Colors.red.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: user.status == 'active'
                                            ? Colors.green
                                            : (user.status == 'suspended'
                                                  ? Colors.red
                                                  : Colors.grey),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.status[0].toUpperCase() +
                                          user.status.substring(1),
                                      style: TextStyle(
                                        color: user.status == 'active'
                                            ? Colors.green
                                            : (user.status == 'suspended'
                                                  ? Colors.red
                                                  : Colors.grey),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: AppTheme.primaryColor,
                                    ),
                                    onPressed: () => setState(
                                      () => _viewingStaffProfile = user,
                                    ),
                                  ),
                                  if (user.role != 'Super Admin') ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      onPressed: () =>
                                          _showEditDialog(context, user),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _showDeleteConfirmation(
                                        context,
                                        user,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
          case 'Doctor':
            roleColor = const Color(0xFF6366F1);
            break;
          case 'Nurse':
            roleColor = const Color(0xFF14B8A6);
            break;
          case 'Admin':
            roleColor = const Color(0xFFF59E0B);
            break;
          case 'Super Admin':
            roleColor = const Color(0xFFEC4899);
            break;
          case 'Front Desk':
            roleColor = const Color(0xFF8B5CF6);
            break;
          case 'Anaesthetist':
            roleColor = const Color(0xFF3B82F6);
            break;
          default:
            roleColor = Colors.grey;
            break;
        }

        final statusColor = user.status == 'active'
            ? Colors.green
            : (user.status == 'suspended' ? Colors.red : Colors.grey);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: user.isDeleted ? Colors.red.withOpacity(0.02) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: user.isDeleted
                  ? Colors.red.withOpacity(0.2)
                  : AppTheme.borderColor.withOpacity(0.4),
            ),
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
                      user.fullname.isNotEmpty
                          ? user.fullname[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user.fullname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (user.isDeleted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DELETED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role,
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                      const Text(
                        'Staff ID',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        user.staffUniqueId ?? '\u2014',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 11,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.status[0].toUpperCase() +
                                user.status.substring(1),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _viewingStaffProfile = user),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                  ),
                  if (!user.isDeleted && user.role != 'Super Admin') ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showEditDialog(context, user),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showDeleteConfirmation(context, user),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
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
        border: Border(
          right: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.only(
              left: 24,
              top: 0,
              bottom: 0,
              right: 24,
            ),
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

          // Navigation Items (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildSidebarItem(
                    0,
                    Icons.admin_panel_settings_outlined,
                    'Control Panel',
                  ),
                  _buildSidebarItem(
                    1,
                    Icons.people_outline,
                    'Staff Management',
                  ),
                  _buildSidebarItem(
                    2,
                    Icons.sick_outlined,
                    'Patient Management',
                  ),
                  _buildSidebarItem(
                    3,
                    Icons.security_outlined,
                    'Access Control',
                  ),
                  _buildSidebarItem(
                    4,
                    Icons.calendar_month_outlined,
                    'Appointments',
                  ),
                  _buildSidebarItem(
                    5,
                    Icons.monitor_heart_outlined,
                    'OPD Management',
                  ),
                  _buildSidebarItem(6, Icons.hotel_outlined, 'IPD Management'),
                  _buildSidebarItem(7, Icons.healing_outlined, 'OT Management'),
                  _buildSidebarItem(8, Icons.schedule_outlined, 'Shift Allocation'),
                  _buildSidebarItem(
                    9,
                    Icons.emergency_outlined,
                    'ICU & Emergency',
                  ),


                ],
              ),
            ),
          ),

          // User Profile Footer
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(
                color: AppTheme.borderColor,
                height: 1,
                thickness: 1,
              ),
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
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: AppTheme.textSecondaryColor,
                          ),
                          onPressed: () => LogoutHelper.showLogoutConfirmation(
                            context,
                            auth,
                          ),
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
      onTap: () {
        switch (index) {
          case 0:
            context.go(AppRoutes.adminDashboard);
            break;
          case 1:
            context.go(AppRoutes.adminUsers);
            break;
          case 2:
            context.go(AppRoutes.adminPatients);
            break;
          case 3:
            context.go(AppRoutes.adminSettings);
            break;
          case 4:
            context.go(AppRoutes.adminAppointments);
            break;
          case 5:
            context.go(AppRoutes.adminOpd);
            break;
          case 6:
            context.go(AppRoutes.adminIpd);
            break;
          case 7:
            context.go(AppRoutes.adminOt);
            break;
          case 8:
            context.go(AppRoutes.adminShifts);
            break;
          case 9:
            context.go(AppRoutes.adminIcu);
            break;

          default:
            context.go(AppRoutes.adminDashboard);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  ),
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
                  child: const Text(
                    'Share',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
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
        Text(
          user != null ? 'Hello, ${user.fullname}' : 'Admin Dashboard',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage system operations and staff provisioning',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard(
            'Total Staff',
            '24',
            '+2',
            Icons.badge_outlined,
            Colors.blueGrey,
            isMobile,
          ),
          _buildStatCard(
            'Active Sessions',
            '5',
            'Live',
            Icons.online_prediction,
            Colors.green,
            isMobile,
          ),
          _buildStatCard(
            'System Health',
            '98%',
            'Optimal',
            Icons.speed,
            Colors.indigo,
            isMobile,
          ),
          _buildStatCard(
            'Security Alerts',
            '0',
            'Safe',
            Icons.security,
            Colors.teal,
            isMobile,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Staff',
            '24',
            '+2',
            Icons.badge_outlined,
            Colors.blueGrey,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Sessions',
            '5',
            'Live',
            Icons.online_prediction,
            Colors.green,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'System Health',
            '98%',
            'Optimal',
            Icons.speed,
            Colors.indigo,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Security Alerts',
            '0',
            'Safe',
            Icons.security,
            Colors.teal,
            isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String sub,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'System Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(
            Colors.orange.shade50,
            Colors.orange.shade900,
            'Database backup planned for tonight at 02:00 AM',
            'System',
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Color bg, Color textColor, String text, String type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            type,
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
          ),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, Color(0xFF0D4D7A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Administrative Actions',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            Icons.person_add_outlined,
            'Register New Staff',
            () => _showAddUserDialog(context),
          ),
          _buildActionButton(
            Icons.settings_suggest_outlined,
            'System Configuration',
            () {},
          ),
          _buildActionButton(
            Icons.backup_outlined,
            'Manual Database Backup',
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return QuickActionButton(icon: icon, label: label, onTap: onTap);
  }

  Widget _buildUserManagementInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staff Performance Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 16),
          Text(
            'User statistics, audit logs, and system access history will be integrated here.',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          SizedBox(height: 120), // Placeholder space
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.labelColor),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shift Allocation and Management UI ──────────────────────────────────────

  Widget _buildSubTabButton(int index, String label, IconData icon) {
    final bool isSelected = _shiftManagementSubTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _shiftManagementSubTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftManagement(bool isMobile) {
    if (_isLoadingShifts) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shift Allocation & Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Define shift schedules and allocate nurses to active shifts',
                      style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showAllocateNurseDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Allocate Nurse (Daily)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                          onPressed: _loadShiftData,
                          tooltip: 'Refresh Shift Data',
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Shift Allocation & Management',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Define shift schedules and allocate nurses to active shifts',
                            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showAllocateNurseDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Allocate Nurse (Daily)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                          onPressed: _loadShiftData,
                          tooltip: 'Refresh Shift Data',
                        ),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          if (isMobile) ...[
            _buildShiftDefinitionsCard(),
            const SizedBox(height: 24),
            _buildWeeklyRostersCard(isMobile),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildShiftDefinitionsCard()),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _buildWeeklyRostersCard(isMobile)),
              ],
            ),
          const SizedBox(height: 24),
          // History/Allocation Logs
          _buildAllocationLogsCard(),
        ],
      ),
    );
  }

  Map<String, dynamic> _getShiftTheme(Map<String, dynamic> shift) {
    final name = (shift['name'] ?? '').toString().toLowerCase();
    final startTime = (shift['start_time'] ?? '').toString();

    if (name.contains('morning') ||
        name.contains('morn') ||
        startTime.startsWith('06') ||
        startTime.startsWith('07') ||
        startTime.startsWith('08')) {
      return {
        'bg': const Color(0xFFFFFBEB), // Soft amber
        'text': const Color(0xFFB45309),
        'icon': Icons.wb_sunny_rounded,
        'border': const Color(0xFFFDE68A),
      };
    } else if (name.contains('evening') ||
        name.contains('afternoon') ||
        name.contains('eve') ||
        startTime.startsWith('14') ||
        startTime.startsWith('15') ||
        startTime.startsWith('16')) {
      return {
        'bg': const Color(0xFFFDF2F8), // Soft pink/rose
        'text': const Color(0xFFBE185D),
        'icon': Icons.wb_twilight_rounded,
        'border': const Color(0xFFFBCFE8),
      };
    } else if (name.contains('night') ||
        startTime.startsWith('22') ||
        startTime.startsWith('23') ||
        startTime.startsWith('20')) {
      return {
        'bg': const Color(0xFFEEF2FF), // Soft indigo
        'text': const Color(0xFF4338CA),
        'icon': Icons.dark_mode_rounded,
        'border': const Color(0xFFC7D2FE),
      };
    } else {
      return {
        'bg': const Color(0xFFECFDF5), // Soft emerald
        'text': const Color(0xFF047857),
        'icon': Icons.schedule_rounded,
        'border': const Color(0xFFA7F3D0),
      };
    }
  }

  Map<String, dynamic> _getWardInfo(String wardName) {
    final name = wardName.toLowerCase();
    if (name.contains('general')) {
      return {
        'icon': Icons.hotel_rounded,
        'color': const Color(0xFF0284C7), // Sky Blue
        'bg': const Color(0xFFF0F9FF),
      };
    } else if (name.contains('icu')) {
      return {
        'icon': Icons.local_hospital_rounded,
        'color': const Color(0xFFE11D48), // Rose
        'bg': const Color(0xFFFFF1F2),
      };
    } else if (name.contains('private') && !name.contains('semi')) {
      return {
        'icon': Icons.meeting_room_rounded,
        'color': const Color(0xFF7C3AED), // Violet
        'bg': const Color(0xFFF5F3FF),
      };
    } else if (name.contains('semi')) {
      return {
        'icon': Icons.people_rounded,
        'color': const Color(0xFF059669), // Emerald
        'bg': const Color(0xFFECFDF5),
      };
    } else {
      return {
        'icon': Icons.business_rounded,
        'color': const Color(0xFF4B5563), // Slate
        'bg': const Color(0xFFF3F4F6),
      };
    }
  }

  Widget _buildAssignedNurseChip(String nurseName, int rosterId) {
    final avatarColors = AppTheme.getAvatarColors(nurseName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: avatarColors['bg'],
            child: Text(
              nurseName.isNotEmpty
                  ? nurseName.substring(0, 1).toUpperCase()
                  : 'N',
              style: TextStyle(
                color: avatarColors['text'],
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              nurseName,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _deleteRosterEntry(rosterId),
            child: Icon(
              Icons.cancel,
              size: 14,
              color: Colors.redAccent.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignNurseButton(String ward, int shiftId) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showNurseSelectionDialog(ward, shiftId),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: AppTheme.primaryColor.withOpacity(0.4),
            strokeWidth: 1.2,
            borderRadius: 20,
            dash: 4.0,
            gap: 3.0,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 14,
                  color: AppTheme.primaryColor.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Assign Nurse',
                  style: TextStyle(
                    color: AppTheme.primaryColor.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNurseSelectionDialog(String ward, int shiftId) {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final filteredNurses = _nurses.where((n) {
              return n.fullname
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.assignment_ind_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Assign Nurse to $ward Ward',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search by nurse name...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (filteredNurses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No nurses found',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredNurses.length,
                          itemBuilder: (listCtx, index) {
                            final nurse = filteredNurses[index];
                            final avatarColors =
                                AppTheme.getAvatarColors(nurse.fullname);

                            return Card(
                              elevation: 0,
                              color: Colors.transparent,
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _saveRosterEntry(nurse.id, shiftId, ward);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: avatarColors['bg'],
                                        child: Text(
                                          nurse.fullname.isNotEmpty
                                              ? nurse.fullname
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : 'N',
                                          style: TextStyle(
                                            color: avatarColors['text'],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          nurse.fullname,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _autoShuffleNextWeek() async {
    final WARD_TYPES = ['General', 'ICU', 'Private', 'Semi-Private'];
    
    // 1. Collect active assignments of the current week
    List<Map<String, dynamic>> activeSlots = [];
    for (final ward in WARD_TYPES) {
      for (final shift in _shifts) {
        final roster = _getWeeklyRoster(ward, shift['id']);
        if (roster.isNotEmpty) {
          activeSlots.add({
            'ward': ward,
            'shift_id': shift['id'],
            'nurse_id': roster['nurse_id'],
            'nurse_name': roster['nurse_name'],
          });
        }
      }
    }

    if (activeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign at least one nurse to the current week first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Confirm dialog with the user showing next week's dates
    final nextWeekStart = _selectedRosterWeekStart.add(const Duration(days: 7));
    final nextWeekStartStr = DateFormat('dd MMM').format(nextWeekStart);
    final nextWeekEndStr = DateFormat('dd MMM yyyy').format(nextWeekStart.add(const Duration(days: 6)));
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shuffle_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            const Text('Auto-Shuffle Next Week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will automatically assign shifts for the next week ($nextWeekStartStr - $nextWeekEndStr) '
          'by shuffling the ${activeSlots.length} nurse assignments from the current week.\n\n'
          'Existing assignments in the target week will be overwritten.\n\n'
          'Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Shuffle & Assign'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 3. Create a pool of unique nurse IDs to assign to the active slots
    // We prioritize the nurse IDs that are already active this week
    final List<int> activeNurseIds = activeSlots.map((s) => s['nurse_id'] as int).toSet().toList();
    final List<int> targetNurseIds = [...activeNurseIds];

    // If we have fewer unique active nurses than active slots, backfill from the general nurses pool
    if (targetNurseIds.length < activeSlots.length) {
      for (final nurse in _nurses) {
        if (!targetNurseIds.contains(nurse.id)) {
          targetNurseIds.add(nurse.id);
        }
        if (targetNurseIds.length >= activeSlots.length) {
          break;
        }
      }
    }

    // If we STILL don't have enough unique nurses (extreme nurse shortage), repeat the pool
    while (targetNurseIds.length < activeSlots.length) {
      targetNurseIds.addAll(activeNurseIds);
    }
    
    final List<int> finalNurseIds = targetNurseIds.sublist(0, activeSlots.length);

    // Helper to verify if a nurse is assigned to continuous shifts or duplicates on the same shift
    bool areShiftsContinuous(Map<String, dynamic> s1, Map<String, dynamic> s2) {
      final end1 = s1['end_time']?.toString().trim();
      final start1 = s1['start_time']?.toString().trim();
      final end2 = s2['end_time']?.toString().trim();
      final start2 = s2['start_time']?.toString().trim();

      if (end1 == null || start1 == null || end2 == null || start2 == null) return false;

      // Check if s1 ends when s2 starts, or s2 ends when s1 starts
      return end1 == start2 || end2 == start1;
    }

    bool isValidRoster(List<int> list) {
      final Map<int, List<Map<String, dynamic>>> nurseShifts = {};
      for (int i = 0; i < list.length; i++) {
        final nurseId = list[i];
        final slot = activeSlots[i];
        final shiftId = slot['shift_id'] as int;

        final shiftDetail = _shifts.firstWhere((s) => s['id'] == shiftId, orElse: () => <String, dynamic>{});
        if (shiftDetail.isEmpty) continue;

        if (!nurseShifts.containsKey(nurseId)) {
          nurseShifts[nurseId] = [];
        }

        for (final assignedShift in nurseShifts[nurseId]!) {
          if (assignedShift['id'] == shiftId) return false;
          if (areShiftsContinuous(assignedShift, shiftDetail)) return false;
        }

        nurseShifts[nurseId]!.add(shiftDetail);
      }
      return true;
    }

    bool foundValid = false;
    for (int iter = 0; iter < 1000; iter++) {
      finalNurseIds.shuffle();
      if (isValidRoster(finalNurseIds)) {
        foundValid = true;
        break;
      }
    }

    // 4. Save slots for next week using the shuffled list
    final targetWeekStartStr = DateFormat('yyyy-MM-dd').format(nextWeekStart);
    
    setState(() => _isLoadingShifts = true);
    
    try {
      int successCount = 0;
      for (int i = 0; i < activeSlots.length; i++) {
        final slot = activeSlots[i];
        final nurseId = finalNurseIds[i];
        await _shiftCtrl.saveRosterEntry(nurseId, slot['shift_id'], slot['ward'], targetWeekStartStr);
        successCount++;
      }
      
      // Navigate to next week to show results immediately
      setState(() {
        _selectedRosterWeekStart = nextWeekStart;
      });
      await _loadRosterData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully shuffled and assigned $successCount shifts for the next week!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error shuffling roster: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingShifts = false);
      }
    }
  }

  Widget _buildWeeklyRostersCard(bool isMobile) {
    final WARD_TYPES = ['General', 'ICU', 'Private', 'Semi-Private'];
    final weekStartStr = DateFormat('dd MMM').format(_selectedRosterWeekStart);
    final weekEndStr = DateFormat('dd MMM yyyy').format(_selectedRosterWeekStart.add(const Duration(days: 6)));

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Week Selector
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.date_range_rounded, color: AppTheme.primaryColor),
                          SizedBox(width: 10),
                          Text(
                            'Weekly Roster Templates',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _autoShuffleNextWeek,
                            icon: const Icon(Icons.shuffle_rounded, size: 14),
                            label: const Text('Shuffle Next Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, size: 20, color: AppTheme.primaryColor),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart = _selectedRosterWeekStart.subtract(const Duration(days: 7));
                                    });
                                    _loadRosterData();
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$weekStartStr - $weekEndStr',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.primaryColor),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart = _selectedRosterWeekStart.add(const Duration(days: 7));
                                    });
                                    _loadRosterData();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.date_range_rounded, color: AppTheme.primaryColor),
                          SizedBox(width: 10),
                          Text(
                            'Weekly Roster Templates',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _autoShuffleNextWeek,
                            icon: const Icon(Icons.shuffle_rounded, size: 14),
                            label: const Text('Auto-Shuffle Next Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),

                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, size: 20, color: AppTheme.primaryColor),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart = _selectedRosterWeekStart.subtract(const Duration(days: 7));
                                    });
                                    _loadRosterData();
                                  },
                                  tooltip: 'Previous Week',
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$weekStartStr - $weekEndStr',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.primaryColor),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart = _selectedRosterWeekStart.add(const Duration(days: 7));
                                    });
                                    _loadRosterData();
                                  },
                                  tooltip: 'Next Week',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            const Divider(height: 24),
            const Text(
              'Assign nurses to weekly slots. The backend will automatically generate the 7 daily shift allocations for this entire week.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            if (_shifts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Please define shift schedules first.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else ...[
              if (_rosters.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'No shifts allocated for this week.',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please allocate shifts manually or navigate to the previous week to auto-shuffle slots into this week.',
                              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No shifts allocated for this week.',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Please allocate shifts manually or navigate to the previous week to auto-shuffle slots into this week.',
                                    style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              if (isMobile)
                _buildMobileRosterList(WARD_TYPES)
              else
                _buildDesktopRosterGrid(WARD_TYPES),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopRosterGrid(List<String> wards) {
    return Column(
      children: [
        // Header Row
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Expanded(
                flex: 12,
                child: Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text(
                    'Ward / Dept',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ),
              ..._shifts.map((shift) {
                final shiftTheme = _getShiftTheme(shift);
                return Expanded(
                  flex: 15,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: shiftTheme['bg'] as Color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: shiftTheme['border'] as Color,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              shiftTheme['icon'] as IconData,
                              size: 14,
                              color: shiftTheme['text'] as Color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              shift['name'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: shiftTheme['text'] as Color,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(${_formatTo12Hour(shift['start_time'])} - ${_formatTo12Hour(shift['end_time'])})',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                (shiftTheme['text'] as Color).withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Data Rows
        ...wards.map((ward) {
          final wardInfo = _getWardInfo(ward);
          return Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Ward Header Cell
                Expanded(
                  flex: 12,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: wardInfo['bg'] as Color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            wardInfo['icon'] as IconData,
                            size: 18,
                            color: wardInfo['color'] as Color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$ward Ward',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Shift Allocation Cells
                ..._shifts.map((shift) {
                  final roster = _getWeeklyRoster(ward, shift['id']);
                  final bool hasAssignment = roster.isNotEmpty;
                  final nurseName = roster['nurse_name'] ?? 'Unassigned';

                  return Expanded(
                    flex: 15,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: hasAssignment
                          ? _buildAssignedNurseChip(nurseName, roster['id'])
                          : _buildAssignNurseButton(ward, shift['id']),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMobileRosterList(List<String> wards) {
    return Column(
      children: wards.map((ward) {
        final wardInfo = _getWardInfo(ward);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: ExpansionTile(
            leading: Icon(
              wardInfo['icon'] as IconData,
              color: wardInfo['color'] as Color,
            ),
            title: Text(
              '$ward Ward',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            children: _shifts.map((shift) {
              final roster = _getWeeklyRoster(ward, shift['id']);
              final bool hasAssignment = roster.isNotEmpty;
              final nurseName = roster['nurse_name'] ?? 'Unassigned';

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      shift['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    hasAssignment
                        ? _buildAssignedNurseChip(nurseName, roster['id'])
                        : SizedBox(
                            width: 140,
                            child: _buildAssignNurseButton(ward, shift['id']),
                          ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShiftDefinitionsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.schedule, color: AppTheme.primaryColor),
                    SizedBox(width: 10),
                    Text(
                      'Shift Schedules',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showShiftDialog(null),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Define Shift', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_shifts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No shift schedules defined.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _shifts.length,
                itemBuilder: (context, index) {
                  final shift = _shifts[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Timings: ${_formatTo12Hour(shift['start_time'])} - ${_formatTo12Hour(shift['end_time'])}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                              onPressed: () => _showShiftDialog(shift),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () => _deleteShift(shift['id']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAllocateNurseDialog() {
    setState(() {
      _selectedAllocNurse = null;
      _selectedAllocShift = null;
      _selectedAllocWard = null;
      _selectedAllocDate = DateTime.now(); // default to today's date
    });

    showDialog(
      context: context,
      builder: (ctx) {
        final WARD_TYPES = ['General', 'ICU', 'Private', 'Semi-Private'];
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.assignment_ind_outlined, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  const Text(
                    'Allocate Nurse (Daily)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 16),
                      const SizedBox(height: 16),

                      // Dropdown Nurse
                      const Text('Nurse', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<UserModel>(
                        value: _selectedAllocNurse == null || !_nurses.any((n) => n.id == _selectedAllocNurse!.id)
                            ? null
                            : _nurses.firstWhere((n) => n.id == _selectedAllocNurse!.id),
                        hint: const Text('Select Nurse'),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _nurses.map((n) {
                          return DropdownMenuItem<UserModel>(
                            value: n,
                            child: Text(n.fullname),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => _selectedAllocNurse = val);
                          setState(() => _selectedAllocNurse = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Shift
                      const Text('Shift Schedule', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedAllocShift == null || !_shifts.any((s) => s['id'] == _selectedAllocShift!['id'])
                            ? null
                            : _shifts.firstWhere((s) => s['id'] == _selectedAllocShift!['id']),
                        hint: const Text('Select Shift'),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.schedule, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _shifts.map((s) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: s,
                            child: Text('${s['name']} (${_formatTo12Hour(s['start_time'])} - ${_formatTo12Hour(s['end_time'])})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => _selectedAllocShift = val);
                          setState(() => _selectedAllocShift = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Ward
                      const Text('Ward / Department', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedAllocWard,
                        hint: const Text('Select Ward'),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.bed_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: WARD_TYPES.map((w) {
                          return DropdownMenuItem<String>(
                            value: w,
                            child: Text('$w Ward'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => _selectedAllocWard = val);
                          setState(() => _selectedAllocWard = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date Picker
                      const Text('Allocation Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate: _selectedAllocDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setDialogState(() => _selectedAllocDate = picked);
                            setState(() => _selectedAllocDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedAllocDate != null
                                    ? DateFormat('yyyy-MM-dd').format(_selectedAllocDate!)
                                    : 'Choose Date',
                              ),
                              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (_selectedAllocNurse == null ||
                        _selectedAllocShift == null ||
                        _selectedAllocWard == null ||
                        _selectedAllocDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select Nurse, Shift, Ward, and Date.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    _submitAllocation();
                  },
                  child: const Text('Save Allocation', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAllocationLogsCard() {
    final filteredAllocations = _allocations.where((alloc) {
      if (_filterAllocLogDate == null) return true;
      if (alloc['allocation_date'] == null) return false;
      try {
        final allocDateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(alloc['allocation_date']));
        final filterDateStr = DateFormat('yyyy-MM-dd').format(_filterAllocLogDate!);
        return allocDateStr == filterDateStr;
      } catch (_) {
        return false;
      }
    }).toList();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            (() {
              final bool isMobile = MediaQuery.of(context).size.width < 900;
              return isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Allocation Logs & Schedule History',
                                style: TextStyle(
                                  fontSize: isMobile ? 15 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _filterAllocLogDate ?? DateTime.now(),
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() => _filterAllocLogDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        _filterAllocLogDate != null
                                            ? DateFormat('yyyy-MM-dd').format(_filterAllocLogDate!)
                                            : 'Filter by Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_filterAllocLogDate != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() => _filterAllocLogDate = null);
                                },
                                tooltip: 'Clear Filter',
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history, color: AppTheme.primaryColor),
                            SizedBox(width: 10),
                            Text(
                              'Allocation Logs & Schedule History',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _filterAllocLogDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                if (picked != null) {
                                  setState(() => _filterAllocLogDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Text(
                                      _filterAllocLogDate != null
                                          ? DateFormat('yyyy-MM-dd').format(_filterAllocLogDate!)
                                          : 'Filter by Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_filterAllocLogDate != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() => _filterAllocLogDate = null);
                                },
                                tooltip: 'Clear Filter',
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
            })(),
            const Divider(height: 24),
            if (_allocations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No shift allocations logged.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else if (filteredAllocations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No allocations found for ${DateFormat('yyyy-MM-dd').format(_filterAllocLogDate!)}.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: () => setState(() => _filterAllocLogDate = null),
                        label: const Text('Clear Date Filter'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
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
                        controller: _shiftAllocHorizontalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _shiftAllocHorizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              horizontalMargin: 20,
                              columnSpacing: 24,
                              headingRowHeight: 52,
                              dataRowMinHeight: 58,
                              dataRowMaxHeight: 72,
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFEDF2F7),
                              ),
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Nurse')),
                                DataColumn(label: Text('Ward')),
                                DataColumn(label: Text('Shift')),
                                DataColumn(label: Text('Timings')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filteredAllocations.map((alloc) {
                                final dateStr = alloc['allocation_date'] != null
                                    ? DateFormat('yyyy-MM-dd').format(DateTime.parse(alloc['allocation_date']))
                                    : '--';
                                final timings = '${_formatTo12Hour(alloc['start_time'])} - ${_formatTo12Hour(alloc['end_time'])}';
                                final status = alloc['status'] ?? 'Active';
                                final statusColor = status == 'Active' ? Colors.green : Colors.grey;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(dateStr)),
                                    DataCell(Text(alloc['nurse_name'] ?? 'Unknown')),
                                    DataCell(Text('${alloc['ward_type'] ?? ''} Ward')),
                                    DataCell(Text(alloc['shift_name'] ?? '')),
                                    DataCell(Text(timings)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        onPressed: () => _deleteAllocation(alloc['id']),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Helpers & Dialogs ---

  void _showShiftDialog(Map<String, dynamic>? shift) {
    final nameCtrl = TextEditingController(text: shift?['name'] ?? '');
    TimeOfDay? startTime = shift != null
        ? TimeOfDay(
            hour: int.parse(shift['start_time'].split(':')[0]),
            minute: int.parse(shift['start_time'].split(':')[1]),
          )
        : null;
    TimeOfDay? endTime = shift != null
        ? TimeOfDay(
            hour: int.parse(shift['end_time'].split(':')[0]),
            minute: int.parse(shift['end_time'].split(':')[1]),
          )
        : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(shift == null ? 'Define Shift Schedule' : 'Edit Shift Schedule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shift Name',
                      hintText: 'e.g., Morning, Evening, Night',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        startTime != null
                            ? 'Start Time: ${startTime!.format(dialogCtx)}'
                            : 'Choose Start Time',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: dialogCtx,
                            initialTime: startTime ?? const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() => startTime = picked);
                          }
                        },
                        child: const Text('Pick'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        endTime != null
                            ? 'End Time: ${endTime!.format(dialogCtx)}'
                            : 'Choose End Time',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: dialogCtx,
                            initialTime: endTime ?? const TimeOfDay(hour: 16, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() => endTime = picked);
                          }
                        },
                        child: const Text('Pick'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || startTime == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please complete all shift details.')),
                      );
                      return;
                    }

                    final startStr = '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00';
                    final endStr = '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00';

                    try {
                      if (shift == null) {
                        await _shiftCtrl.createShift(nameCtrl.text, startStr, endStr);
                      } else {
                        await _shiftCtrl.updateShift(shift['id'], nameCtrl.text, startStr, endStr);
                      }
                      Navigator.pop(dialogCtx);
                      _loadShiftData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Shift schedule saved successfully!')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteShift(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shift'),
        content: const Text('Are you sure you want to delete this shift schedule? All associated allocations will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _shiftCtrl.deleteShift(id);
        _loadShiftData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift schedule deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  void _submitAllocation() async {
    if (_selectedAllocNurse == null ||
        _selectedAllocShift == null ||
        _selectedAllocWard == null ||
        _selectedAllocDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Nurse, Shift, Ward, and Date.')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedAllocDate!);

    try {
      await _shiftCtrl.createAllocation(
        _selectedAllocNurse!.id,
        _selectedAllocShift!['id'],
        _selectedAllocWard!,
        dateStr,
      );
      setState(() {
        _selectedAllocNurse = null;
        _selectedAllocShift = null;
        _selectedAllocWard = null;
        _selectedAllocDate = null;
      });
      _loadShiftData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nurse allocated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteAllocation(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Allocation'),
        content: const Text('Are you sure you want to delete this nurse shift allocation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _shiftCtrl.deleteAllocation(id);
        _loadShiftData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allocation deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  String? _selectedRole;
  List<String> _roles = ['Doctor', 'Nurse', 'Anaesthetist', 'Front Desk'];
  int? _selectedSpecializationId;
  List<Map<String, dynamic>> _specializations = [];
  bool _isLoading = false;
  bool _isLoadingRoles = false;
  bool _isLoadingSpecializations = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.text = PasswordPolicy.generateSecurePassword();
    _loadSpecializations();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoadingRoles = true);
    try {
      final rbacData = await _adminController.fetchRbacData();
      final rolesList = rbacData['roles'] as List<dynamic>? ?? [];

      if (mounted) {
        final currentUserRole = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).user?.role;
        setState(() {
          _roles = rolesList.map((r) => r['role_name'].toString()).where((r) {
            if (currentUserRole == 'Super Admin') return true;
            return r == 'Doctor' || r == 'Nurse' || r == 'Front Desk' || r == 'Anaesthetist';
          }).toList();

          final orderedRoles = ['Super Admin', 'Admin', 'Doctor', 'Nurse', 'Anaesthetist', 'Front Desk'];
          _roles.sort((a, b) {
            int indexA = orderedRoles.indexOf(a);
            int indexB = orderedRoles.indexOf(b);
            if (indexA == -1 && indexB == -1) return a.compareTo(b);
            if (indexA == -1) return 1;
            if (indexB == -1) return -1;
            return indexA.compareTo(indexB);
          });

          if (_selectedRole != null && !_roles.contains(_selectedRole)) {
            _selectedRole = null;
          }
          _isLoadingRoles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoles = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading roles: $e'),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text('Error loading specializations: $e'),
            backgroundColor: Colors.red,
          ),
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
        role: _selectedRole ?? '',
        medicalLicense: _licenseController.text.trim(),
        specializationId: _selectedRole == 'Doctor'
            ? _selectedSpecializationId
            : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
        );
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
      title: const Text(
        'Register New Staff',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 640
            ? 600
            : MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // ── Patient-form style helper ──
                // Labels: black, 12px, w600 | Fields: light fill, E2E8F0 border, primaryColor focused, CBD5E0 hint

                // ── Row 1: Full Name | Email ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Full Name',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _nameController,
                            onChanged: (_) {
                              if (_errorMessage != null)
                                setState(() => _errorMessage = null);
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z\s]'),
                              ),
                              LengthLimitingTextInputFormatter(30),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter full name',
                              hintStyle: const TextStyle(
                                color: Color(0xFFCBD5E0),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: AppTheme.backgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Please enter full name'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emailController,
                            onChanged: (_) {
                              if (_errorMessage != null)
                                setState(() => _errorMessage = null);
                            },
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Enter email address',
                              hintStyle: const TextStyle(
                                color: Color(0xFFCBD5E0),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: AppTheme.backgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter Email Address';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(val.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Row 2: Mobile | Password ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mobile Number',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _mobileController,
                            onChanged: (_) {
                              if (_errorMessage != null)
                                setState(() => _errorMessage = null);
                            },
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter 10-digit number',
                              hintStyle: const TextStyle(
                                color: Color(0xFFCBD5E0),
                                fontSize: 11,
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: AppTheme.backgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return 'Please enter mobile number';
                              if (val.length != 10)
                                return 'Please enter 10 digit mobile number';
                              if (!RegExp(r'^[0-9]+$').hasMatch(val))
                                return 'Please enter digits only';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            onChanged: (_) {
                              if (_errorMessage != null)
                                setState(() => _errorMessage = null);
                            },
                            obscureText: _obscurePassword,
                            maxLength: 16,
                            inputFormatters: [LengthLimitingTextInputFormatter(16)],
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Enter password',
                              hintStyle: const TextStyle(color: Color(0xFFCBD5E0), fontSize: 11),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 20),
                                    tooltip: 'Regenerate Password',
                                    onPressed: () {
                                      setState(() {
                                        _passwordController.text = PasswordPolicy.generateSecurePassword();
                                        _obscurePassword = false;
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: AppTheme.textSecondaryColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              filled: true,
                              fillColor: AppTheme.backgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: PasswordPolicy.validatePassword,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Row 3: Role (full width) ──
                const Text(
                  'Role',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                _isLoadingRoles
                    ? const Center(child: CircularProgressIndicator())
                    : CustomDropdownSearch(
                        label: '', // label shown externally above
                        hint: 'Select Role',
                        dropdownItems: _roles,
                        value: _selectedRole,
                        fillColor: AppTheme.backgroundColor,
                        popupBgColor: Colors.white,
                        borderColor: const Color(0xFFE2E8F0),
                        focusedBorderColor: AppTheme.primaryColor,
                        height: 52,
                        hintFontSize: 11,
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
                        validator: (val) => val == null || val.isEmpty
                            ? 'Please select a role'
                            : null,
                      ),

                // ── Row 4: Specialization | Medical License (Doctor only) ──
                if (_selectedRole == 'Doctor') ...[
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Specialization',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _isLoadingSpecializations
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : CustomDropdownSearch(
                                    label: '',
                                    hint: 'Select specialization',
                                    dropdownMap: {
                                      for (var spec in _specializations)
                                        spec['id'].toString(): spec['name']
                                            .toString(),
                                    },
                                    value: _selectedSpecializationId
                                        ?.toString(),
                                    fillColor: AppTheme.backgroundColor,
                                    popupBgColor: Colors.white,
                                    borderColor: const Color(0xFFE2E8F0),
                                    focusedBorderColor: AppTheme.primaryColor,
                                    height: 52,
                                    hintFontSize: 11,
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedSpecializationId = val != null
                                            ? int.tryParse(val)
                                            : null;
                                      });
                                    },
                                    validator: (val) =>
                                        _selectedRole == 'Doctor' && val == null
                                        ? 'Please select specialization'
                                        : null,
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medical License',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _licenseController,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(30),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Optional',
                                hintStyle: const TextStyle(
                                  color: Color(0xFFCBD5E0),
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: AppTheme.cancelButton,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.logoRed,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 48),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
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
  State<AdminPatientManagementWrapper> createState() =>
      _AdminPatientManagementWrapperState();
}

class _AdminPatientManagementWrapperState
    extends State<AdminPatientManagementWrapper> {
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
          const SnackBar(
            content: Text(
              'Booking appointments from Admin Dashboard is currently not supported.',
            ),
          ),
        );
      },
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  DashedBorderPainter({
    this.color = Colors.grey,
    this.strokeWidth = 1.0,
    this.gap = 3.0,
    this.dash = 5.0,
    this.borderRadius = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
