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
import 'dart:async';
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
import '../widgets/user_profile_dialog.dart';
import 'ipd_management.dart';
import 'ot_management.dart';
import '../utils/password_policy.dart';
import '../controllers/nurse_shift_controller.dart';
import 'icu_management_view.dart';
import 'inventory_management_view.dart';
import 'billing_management_view.dart';
import '../controllers/home_visit_controller.dart';
import '../services/home_visit_service.dart';
import '../models/home_visit_model.dart';
import 'home_visit_list_view.dart';
import 'home_visit_execution_screen.dart';
import '../services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int initialIndex;
  final bool isRegisteringPatient;
  final PatientModel? existingPatient;
  final PatientModel? viewPatient;
  final UserModel? viewingStaffProfile;
  final int? selectedHomeVisitId;

  const AdminDashboardScreen({
    Key? key,
    this.initialIndex = 0,
    this.isRegisteringPatient = false,
    this.existingPatient,
    this.viewPatient,
    this.viewingStaffProfile,
    this.selectedHomeVisitId,
  }) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isCatalogMenuExpanded = true;
  String _selectedRoleFilter = 'All';
  String _selectedStatusFilter = 'All';
  final AdminController _adminController = AdminController();

  String _totalStaffCount = '--';
  String _activeSessionsCount = '--';
  String _systemHealthPercent = '--';
  String _securityAlertsCount = '--';
  bool _isLoadingDashboardStats = false;

  Future<List<UserModel>>? _staffFuture;
  Future<Map<String, dynamic>>? _rbacFuture;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _shiftAllocHorizontalScrollController =
      ScrollController();
  bool _showDeleted = false;
  final FocusNode _mainFocusNode = FocusNode();
  List<PatientModel> _dbPatients = [];
  final PatientController _patientController = PatientController();
  bool _isRegisteringPatient = false;
  PatientModel? _patientToComplete;
  PatientModel? _viewPatient;
  UserModel? _viewingStaffProfile;
  int? _selectedHomeVisitId;
  String _staffSearchQuery = '';
  int _staffCurrentPage = 0;
  final int _itemsPerPage = 10;
  final TextEditingController _staffSearchController = TextEditingController();

  final NurseShiftController _shiftCtrl = NurseShiftController();
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _allocations = [];
  List<UserModel> _nurses = [];
  bool _isLoadingShifts = false;

  UserModel? _selectedAllocNurse;
  Map<String, dynamic>? _selectedAllocShift;
  String? _selectedAllocWard;
  DateTime? _selectedAllocDate;

  int _shiftManagementSubTab = 0; // 0 = Daily Allocations, 1 = Weekly Rosters
  List<Map<String, dynamic>> _rosters = [];
  DateTime _selectedRosterWeekStart = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ).subtract(Duration(days: DateTime.now().weekday - 1));

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
    final allocations = _rosters
        .where((r) => r['ward_type'] == ward && r['shift_id'] == shiftId)
        .toList();

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

  Future<void> _saveRosterEntry(
    int nurseId,
    int shiftId,
    String wardType,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedRosterWeekStart);
    if (mounted) setState(() => _isLoadingShifts = true);
    try {
      await _shiftCtrl.saveRosterEntry(nurseId, shiftId, wardType, dateStr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roster entry saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadShiftData(); // reload allocations and rosters
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving roster: $e'),
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

  Future<void> _deleteRosterEntry(int id) async {
    if (mounted) setState(() => _isLoadingShifts = true);
    try {
      await _shiftCtrl.deleteRosterEntry(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roster entry deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadShiftData(); // reload allocations and rosters
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting roster: $e'),
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

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _shiftAllocHorizontalScrollController.dispose();
    _mainFocusNode.dispose();
    _staffSearchController.dispose();
    _medSearchController.dispose();
    _hvSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _isRegisteringPatient = widget.isRegisteringPatient;
    _patientToComplete = widget.existingPatient;
    _viewPatient = widget.viewPatient;
    _viewingStaffProfile = widget.viewingStaffProfile;
    _selectedHomeVisitId = widget.selectedHomeVisitId;
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
    if (widget.initialIndex != oldWidget.initialIndex ||
        widget.isRegisteringPatient != oldWidget.isRegisteringPatient ||
        widget.existingPatient != oldWidget.existingPatient ||
        widget.viewPatient != oldWidget.viewPatient ||
        widget.viewingStaffProfile != oldWidget.viewingStaffProfile ||
        widget.selectedHomeVisitId != oldWidget.selectedHomeVisitId) {
      _selectedIndex = widget.initialIndex;
      _isRegisteringPatient = widget.isRegisteringPatient;
      _patientToComplete = widget.existingPatient;
      _viewPatient = widget.viewPatient;
      _viewingStaffProfile = widget.viewingStaffProfile;
      _selectedHomeVisitId = widget.selectedHomeVisitId;

      if (_selectedIndex == 1) {
        _staffFuture = _adminController.fetchStaff(showDeleted: _showDeleted);
      }
      if (_selectedIndex == 8) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadShiftData();
        });
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

  Future<void> _loadDashboardStats() async {
    if (!mounted) return;
    setState(() => _isLoadingDashboardStats = true);
    try {
      final stats = await _adminController.fetchDashboardStats();
      if (mounted) {
        setState(() {
          _totalStaffCount = stats['totalStaff']?.toString() ?? '--';
          _activeSessionsCount = stats['activeSessions']?.toString() ?? '--';
          _systemHealthPercent = stats['systemHealth']?.toString() ?? '--';
          _securityAlertsCount = stats['securityAlerts']?.toString() ?? '--';
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingDashboardStats = false);
      }
    }
  }

  void _loadStaff() {
    setState(() {
      _staffFuture = _adminController.fetchStaff(showDeleted: _showDeleted);
    });
    _loadDashboardStats();
  }

  void _loadRbacData() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.role == 'Super Admin') {
      setState(() {
        _rbacFuture = _adminController.fetchRbacData();
      });
    }
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddUserDialog(),
    ).then((_) => _loadStaff()); // Refresh list after dialog closes
  }

  void _showEditDialog(BuildContext context, UserModel user) {
    final String initialName = (user.rawFullname ?? '').trim();
    final String initialEmail = user.email.trim();
    final String initialMobile = (user.mobile ?? '').trim();
    final String initialRole = user.role;
    final String initialStatus = user.status;
    final int? initialSpecializationId = user.specializationId;

    final nameCtrl = TextEditingController(text: user.rawFullname);
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

    bool hasChanges() {
      final currentName = nameCtrl.text.trim();
      final currentEmail = emailCtrl.text.trim();
      final currentMobile = mobileCtrl.text.trim();
      final currentRole = selectedRole;
      final currentStatus = selectedStatus;
      final currentSpecId =
          selectedRole == 'Doctor' ? selectedSpecializationId : null;
      final origSpecId =
          initialRole == 'Doctor' ? initialSpecializationId : null;

      return currentName != initialName ||
          currentEmail != initialEmail ||
          currentMobile != initialMobile ||
          currentRole != initialRole ||
          currentStatus != initialStatus ||
          currentSpecId != origSpecId;
    }

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
                        onChanged: (_) => setDialogState(() {}),
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
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Enter email address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
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
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Enter mobile number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          counterText: "",
                          errorMaxLines: 2,
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a mobile number';
                          }
                          final clean = val.trim();
                          if (!RegExp(r'^[6-9]').hasMatch(clean)) {
                            return 'Mobile number must start with 6, 7, 8, or 9';
                          }
                          if (clean.length != 10) {
                            return 'Mobile number must be exactly 10 digits';
                          }
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
                          CustomDropdownSearch(
                            label: 'Specialization',
                            value: selectedSpecializationId?.toString(),
                            dropdownMap: {
                              for (var s in specializations)
                                s['id'].toString(): s['name'].toString(),
                            },
                            onChanged: (val) {
                              setDialogState(() {
                                selectedSpecializationId =
                                    val != null ? int.tryParse(val) : null;
                                dialogError = null;
                              });
                            },
                            validator: (val) {
                              if (selectedRole != 'Doctor') return null;
                              if (val == null || val.isEmpty) {
                                return 'Please select a specialization';
                              }
                              final validSpecIds = specializations
                                  .map((s) => s['id'].toString())
                                  .toSet();
                              if (!validSpecIds.contains(val)) {
                                return 'Please select a valid specialization from the list';
                              }
                              return null;
                            },
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
                onPressed: (isSaving || !hasChanges())
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
                  if (_selectedIndex != 0) _buildHeader(context, isMobile),
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

    if (_viewingStaffProfile != null) {
      return AdminStaffProfileView(
        user: _viewingStaffProfile!,
        onBack: () {
          setState(() => _viewingStaffProfile = null);
          context.go(AppRoutes.adminUsers);
        },
      );
    }

    if (_isRegisteringPatient) {
      return NewPatientRegistrationView(
        key: ValueKey('admin_reg_${_patientToComplete?.id ?? 'new'}'),
        existingPatient: _patientToComplete,
        onBack: () {
          final patientToReturn = _patientToComplete;
          setState(() {
            _isRegisteringPatient = false;
            _patientToComplete = null;
            if (patientToReturn != null && patientToReturn.id != null) {
              _viewPatient = patientToReturn;
            }
          });
          if (patientToReturn != null && patientToReturn.id != null) {
            context.go(AppRoutes.adminViewPatient, extra: patientToReturn);
          } else {
            context.go(AppRoutes.adminPatients);
          }
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
            onRegister: ([prefilledPatient]) =>
                context.go(AppRoutes.adminNewPatient, extra: prefilledPatient),
            onCompleteProfile: (patient) =>
                context.go(AppRoutes.adminEditPatient, extra: patient),
            viewPatient: _viewPatient,
          );
        }
        return const AccessDeniedWidget();
      case 3:
        if (user?.role == 'Super Admin') {
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
      case 10:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return const BillingManagementView();
        }
        return const AccessDeniedWidget();
      case 11:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return InventoryManagementView(isMobile: isMobile);
        }
        return const AccessDeniedWidget();
      case 12:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return _buildAdminHomeVisitCare(isMobile);
        }
        return const AccessDeniedWidget();
      case 13:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return _buildMedicationCatalog(isMobile);
        }
        return const AccessDeniedWidget();
      case 14:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return _buildHomeVisitConsumablesCatalog(isMobile);
        }
        return const AccessDeniedWidget();
      case 15:
        if (user?.role == 'Admin' || user?.role == 'Super Admin') {
          return _buildCarriedKitItemsCatalog(isMobile);
        }
        return const AccessDeniedWidget();

      default:
        return _buildControlPanel(isMobile);
    }
  }

  Widget _buildControlPanel(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed Top Bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          color: Colors.transparent,
          child: _buildBannerTopBar(context, isMobile),
        ),
        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
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
                  _buildQuickActions(isMobile),
                  const SizedBox(height: 24),
                  _buildStaffOverviewChart(),
                  const SizedBox(height: 24),
                  _buildSystemStatus(),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildAlertsSection(),
                            const SizedBox(height: 24),
                            _buildStaffOverviewChart(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildQuickActions(false),
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
    );
  }

  Widget _buildStaffManagement(bool isMobile) {
    return FutureBuilder<List<UserModel>>(
      future: _staffFuture,
      builder: (context, snapshot) {
        List<UserModel> allStaff = snapshot.data ?? [];

        List<UserModel> searchedStaff = allStaff;
        if (_staffSearchQuery.trim().isNotEmpty) {
          final query = _staffSearchQuery.toLowerCase();
          searchedStaff = allStaff.where((u) {
            return u.fullname.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query) ||
                u.role.toLowerCase().contains(query) ||
                (u.specialization?.toLowerCase().contains(query) ?? false) ||
                (u.staffUniqueId?.toLowerCase().contains(query) ?? false);
          }).toList();
        }

        List<UserModel> filtered = searchedStaff.where((u) {
          final matchesRole =
              _selectedRoleFilter == 'All' || u.role == _selectedRoleFilter;
          final matchesStatus = _selectedStatusFilter == 'All' ||
              u.status.toLowerCase() == _selectedStatusFilter.toLowerCase();
          return matchesRole && matchesStatus;
        }).toList();

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
              child: isMobile
                  ? Column(
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
                        if (Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            ).user?.hasPermission('manage_users') ??
                            false) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Show Deleted Toggle
                              Expanded(
                                child: Container(
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
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddUserDialog(context),
                                  icon: const Icon(
                                    Icons.person_add_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Register Staff',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.dangerColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    )
                  : Row(
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
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showAddUserDialog(context),
                            icon: const Icon(
                              Icons.person_add_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Register Staff',
                              style: TextStyle(
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

            // ── Search Bar ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              margin: const EdgeInsets.only(bottom: 12),
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _staffSearchController,
                        onChanged: (v) => setState(() {
                          _staffSearchQuery = v;
                          _staffCurrentPage = 0;
                        }),
                        decoration: const InputDecoration(
                          hintText:
                              'Search staff by name, email, specialization or role...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_staffSearchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 20,
                          color: AppTheme.textSecondaryColor,
                        ),
                        onPressed: () {
                          _staffSearchController.clear();
                          setState(() {
                            _staffSearchQuery = '';
                            _staffCurrentPage = 0;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            // ── Role & Status Filters Row ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              alignment: Alignment.centerLeft,
              child: FutureBuilder<Map<String, dynamic>>(
                future: _rbacFuture,
                builder: (context, rbacSnapshot) {
                  final currentUser =
                      Provider.of<AuthProvider>(context, listen: false).user;

                  final Set<String> rolesSet = {
                    'All',
                    if (currentUser?.role != 'Admin') 'Super Admin',
                    'Admin',
                    'Doctor',
                    'Nurse',
                    'Anaesthetist',
                    'Front Desk',
                  };

                  for (final staff in allStaff) {
                    if (staff.role.isNotEmpty) {
                      if (currentUser?.role == 'Admin' &&
                          staff.role == 'Super Admin') {
                        continue;
                      }
                      rolesSet.add(staff.role);
                    }
                  }

                  if (rbacSnapshot.hasData) {
                    final rolesList =
                        rbacSnapshot.data!['roles'] as List<dynamic>? ?? [];
                    for (final r in rolesList) {
                      final rName = r['role_name'].toString();
                      if (currentUser?.role == 'Admin' &&
                          rName == 'Super Admin') {
                        continue;
                      }
                      rolesSet.add(rName);
                    }
                  }

                  final orderedRoles = [
                    'All',
                    'Super Admin',
                    'Admin',
                    'Doctor',
                    'Nurse',
                    'Anaesthetist',
                    'Front Desk',
                  ];

                  final filterRoles = rolesSet.toList();
                  filterRoles.sort((a, b) {
                    int indexA = orderedRoles.indexOf(a);
                    int indexB = orderedRoles.indexOf(b);
                    if (indexA != -1 && indexB != -1) {
                      return indexA.compareTo(indexB);
                    }
                    if (indexA != -1) return -1;
                    if (indexB != -1) return 1;
                    return a.compareTo(b);
                  });

                  return Row(
                    children: [
                      // Role Filter Pills
                      Expanded(
                        child: SizedBox(
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
                                    onTap: () => setState(() {
                                      _selectedRoleFilter = role;
                                      _staffCurrentPage = 0;
                                    }),
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
                                                  ? Colors.white.withValues(alpha: 0.2)
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
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Status / Availability Dropdown Filter on the Same Row
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _selectedStatusFilter != 'All'
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedStatusFilter != 'All'
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatusFilter,
                            icon: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Colors.white,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                            onChanged: (newStatus) {
                              if (newStatus != null) {
                                setState(() {
                                  _selectedStatusFilter = newStatus;
                                  _staffCurrentPage = 0;
                                });
                              }
                            },
                            items: [
                              'All',
                              'Active',
                              'Inactive',
                              'Suspended',
                            ].map((status) {
                              Color dotColor = AppTheme.textSecondaryColor;
                              if (status == 'Active') dotColor = Colors.green;
                              if (status == 'Inactive') dotColor = Colors.grey;
                              if (status == 'Suspended') dotColor = Colors.red;

                              return DropdownMenuItem<String>(
                                value: status,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (status != 'All') ...[
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      status == 'All' ? 'Status: All' : status,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: status == _selectedStatusFilter
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
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

    final totalStaff = staff.length;
    final totalPages = (totalStaff / _itemsPerPage).ceil();

    if (_staffCurrentPage >= totalPages && totalPages > 0) {
      _staffCurrentPage = totalPages - 1;
    }
    if (_staffCurrentPage < 0) _staffCurrentPage = 0;

    final paginatedStaff = staff
        .skip(_staffCurrentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    if (isMobile) {
      return Column(
        children: [
          Expanded(
            child: _buildStaffCards(paginatedStaff),
          ),
          if (totalPages > 1) ...[
            const Divider(height: 1),
            _buildStaffPaginationControls(totalPages, true),
          ],
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: _buildStaffTable(paginatedStaff, isMobile)),
        if (totalPages > 1) ...[
          const Divider(height: 1),
          _buildStaffPaginationControls(totalPages, false),
        ],
      ],
    );
  }

  Widget _buildStaffContentOriginal(
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
                        const DataColumn(label: Text('S.No')),
                        const DataColumn(label: Text('Staff ID')),
                        const DataColumn(label: Text('Name')),
                        const DataColumn(label: Text('Role')),
                        if (_selectedRoleFilter == 'Doctor')
                          const DataColumn(label: Text('Specialization')),
                        const DataColumn(label: Text('Status')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: staff.asMap().entries.map((entry) {
                        final index = entry.key;
                        final user = entry.value;
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
                              Text(
                                '${(index + 1) + (_staffCurrentPage * _itemsPerPage)}',
                              ),
                            ),
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
                                    onPressed: () => context.go(
                                      AppRoutes.adminViewStaff,
                                      extra: user,
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

  Widget _buildStaffPaginationControls(int totalPages, bool isMobile) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 10 : 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Page ${_staffCurrentPage + 1} of $totalPages',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: _staffCurrentPage > 0
                    ? () => setState(() => _staffCurrentPage--)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: _staffCurrentPage > 0
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.chevron_left, size: 16),
                    Text('Prev', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _staffCurrentPage < totalPages - 1
                    ? () => setState(() => _staffCurrentPage++)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: _staffCurrentPage < totalPages - 1
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Next', style: TextStyle(fontSize: 12)),
                    Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCards(List<UserModel> staff) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  ? Colors.red.withOpacity(0.3)
                  : AppTheme.borderColor.withOpacity(0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
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
                            Expanded(
                              child: Text(
                                user.fullname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
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
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          context.go(AppRoutes.adminViewStaff, extra: user),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                    ),
                    if (!user.isDeleted && user.role != 'Super Admin') ...[
                      TextButton.icon(
                        onPressed: () => _showEditDialog(context, user),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;

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

          // Navigation Items (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  _buildSidebarItem(
                    0,
                    Icons.admin_panel_settings_outlined,
                    'Dashboard',
                  ),
                  _buildSidebarItem(
                    1,
                    Icons.people_outline,
                    'Staff Management',
                  ),
                  _buildSidebarItem(2, Icons.sick_outlined, 'Patients'),
                  if (user?.role == 'Super Admin')
                    _buildSidebarItem(
                      3,
                      Icons.security_outlined,
                      'Access Control (RBAC)',
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
                  _buildSidebarItem(
                    8,
                    Icons.schedule_outlined,
                    'Shift Allocation',
                  ),
                  _buildSidebarItem(
                    9,
                    Icons.emergency_outlined,
                    'ICU & Emergency',
                  ),
                  _buildSidebarItem(
                    10,
                    Icons.receipt_long_outlined,
                    'Billing & Invoices',
                  ),
                  _buildSidebarItem(
                    11,
                    Icons.inventory_2_outlined,
                    'Inventory Management',
                  ),
                  _buildSidebarItem(
                    12,
                    Icons.home_work_outlined,
                    'Home Visit Care',
                  ),
                  _buildCatalogParentMenu(),
                ],
              ),
            ),
          ),

          // User Profile Footer
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: user == null
                ? const SizedBox.shrink()
                : Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      final user = auth.user;
                      if (user == null) return const SizedBox.shrink();
                      return Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  UserProfileDialog.show(context, user),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    radius: 18,
                                    child: Text(
                                      (user.rawFullname ?? user.fullname)
                                              .isNotEmpty
                                          ? (user.rawFullname ??
                                                    user.fullname)[0]
                                                .toUpperCase()
                                          : '?',
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.rawFullname ?? user.fullname,
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogParentMenu() {
    bool isChildSelected =
        _selectedIndex == 13 || _selectedIndex == 14 || _selectedIndex == 15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isCatalogMenuExpanded = !_isCatalogMenuExpanded;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isChildSelected
                  ? AppTheme.primaryColor.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: isChildSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFF4A5568),
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Master Catalog',
                    style: TextStyle(
                      color: isChildSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFF4A5568),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _isCatalogMenuExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isChildSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFF718096),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_isCatalogMenuExpanded)
          Column(
            children: [
              _buildSidebarItem(
                13,
                Icons.medication_outlined,
                'Medicine Catalog',
                isSubItem: true,
              ),
              _buildSidebarItem(
                14,
                Icons.home_repair_service_outlined,
                'Home Visit Consumables',
                isSubItem: true,
              ),
              _buildSidebarItem(
                15,
                Icons.inventory_outlined,
                'Carried Kit Items',
                isSubItem: true,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String label, {
    bool isSubItem = false,
  }) {
    bool isSelected =
        (_selectedIndex == index && !_isRegisteringPatient) ||
        (_isRegisteringPatient && index == 2);
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
          case 10:
            context.go(AppRoutes.adminBilling);
            break;
          case 11:
            context.go(AppRoutes.adminInventory);
            break;
          case 12:
            context.go(AppRoutes.adminHomeVisits);
            break;
          case 13:
            context.go(AppRoutes.adminMedicationCatalog);
            break;
          case 14:
            context.go(AppRoutes.adminHomeVisitConsumables);
            break;
          case 15:
            context.go(AppRoutes.adminCarriedKitItems);
            break;

          default:
            context.go(AppRoutes.adminDashboard);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(
          left: isSubItem ? 28 : 12,
          right: 12,
          top: 2,
          bottom: 2,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isSubItem ? 12 : 14,
          vertical: isSubItem ? 9 : 11,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF4A5568),
              size: isSubItem ? 18 : 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF4A5568),
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : (isSubItem ? FontWeight.w600 : FontWeight.bold),
                  fontSize: isSubItem ? 13 : 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerTopBar(BuildContext context, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          child: InkWell(
            onTap: _showSearchOverlay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMobile ? 'Search...' : 'Quick search...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
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
          const SizedBox(width: 24),
          // Date & Time
          const AdminLiveClock(),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      padding: EdgeInsets.only(
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        top: 20,
        bottom: 0,
      ),
      child: _buildBannerTopBar(context, isMobile),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Welcome back,',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: const [
            Text(
              'System Admin',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(width: 8),
            Text('👋', style: TextStyle(fontSize: 24)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Here\'s what\'s happening in your hospital today.',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    final securityColor =
        (_securityAlertsCount != '0' && _securityAlertsCount != '--')
        ? AppTheme.logoRed
        : AppTheme.secondaryColor;
    final securitySub = (_securityAlertsCount == '0')
        ? 'Safe'
        : (_securityAlertsCount == '--' ? '' : 'Requires attention');

    final card1 = _buildStatCard(
      'Total Staff',
      _totalStaffCount,
      _totalStaffCount == '--' ? '' : 'Registered',
      Icons.people_alt_outlined,
      AppTheme.primaryColor,
      isMobile,
      () => context.go(AppRoutes.adminUsers),
    );

    final card2 = _buildStatCard(
      'Active Sessions',
      _activeSessionsCount,
      _activeSessionsCount == '--' ? '' : 'Live',
      Icons.monitor_heart_outlined,
      AppTheme.secondaryColor,
      isMobile,
      () => context.go(AppRoutes.adminUsers),
    );

    final card3 = _buildStatCard(
      'System Health',
      _systemHealthPercent,
      _systemHealthPercent == '--' ? '' : 'Optimal',
      Icons.health_and_safety_outlined,
      Colors.indigo,
      isMobile,
      () => {},
    );

    final card4 = _buildStatCard(
      'Security Alerts',
      _securityAlertsCount,
      securitySub,
      Icons.security_outlined,
      securityColor,
      isMobile,
      () {
        final currentUser = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).user;
        if (currentUser?.role == 'Super Admin') {
          context.go(AppRoutes.adminSettings);
        }
      },
    );

    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: cardWidth, child: card1),
              SizedBox(width: cardWidth, child: card2),
              SizedBox(width: cardWidth, child: card3),
              SizedBox(width: cardWidth, child: card4),
            ],
          );
        },
      );
    }

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 16),
        Expanded(child: card2),
        const SizedBox(width: 16),
        Expanded(child: card3),
        const SizedBox(width: 16),
        Expanded(child: card4),
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
    VoidCallback onViewDetails,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 7 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: isMobile ? 18 : 22),
              ),
              SizedBox(width: isMobile ? 8 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: isMobile ? 10.5 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 16),
          InkWell(
            onTap: onViewDetails,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'View details',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  color: AppTheme.primaryColor,
                  size: isMobile ? 12 : 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.logoRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.report_problem_outlined,
                        color: AppTheme.logoRed,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'System Alerts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {},
                child: const Text(
                  'View all alerts',
                  style: TextStyle(
                    color: AppTheme.logoRed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withOpacity(0.1), width: 1),
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
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                type,
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.more_vert,
                color: textColor.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions([bool isMobile = false]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Administrative Actions',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isMobile)
            Column(
              children: [
                Row(
                  children: [
                    _buildActionGridItem(
                      Icons.person_add_outlined,
                      'Register\nNew Staff',
                      () => _showAddUserDialog(context),
                    ),
                    const SizedBox(width: 12),
                    _buildActionGridItem(
                      Icons.settings_suggest_outlined,
                      'System\nConfiguration',
                      () {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildActionGridItem(
                      Icons.storage_outlined,
                      'Manual\nDatabase Backup',
                      () {},
                    ),
                    const SizedBox(width: 12),
                    _buildActionGridItem(
                      Icons.receipt_long_outlined,
                      'Audit\nLogs',
                      () {},
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                _buildActionGridItem(
                  Icons.person_add_outlined,
                  'Register\nNew Staff',
                  () => _showAddUserDialog(context),
                ),
                const SizedBox(width: 12),
                _buildActionGridItem(
                  Icons.settings_suggest_outlined,
                  'System\nConfiguration',
                  () {},
                ),
                const SizedBox(width: 12),
                _buildActionGridItem(
                  Icons.storage_outlined,
                  'Manual\nDatabase Backup',
                  () {},
                ),
                const SizedBox(width: 12),
                _buildActionGridItem(
                  Icons.receipt_long_outlined,
                  'Audit\nLogs',
                  () {},
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionGridItem(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatus([bool isMobile = false]) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'System Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSystemStatusItem(
                      'Backend API',
                      'All systems operational',
                      'Online',
                      AppTheme.secondaryColor,
                    ),
                    const SizedBox(height: 16),
                    _buildSystemStatusItem(
                      'PostgreSQL DB',
                      'Database connected',
                      'Connected',
                      AppTheme.secondaryColor,
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.show_chart,
                        color: AppTheme.primaryColor,
                        size: 40,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: AppTheme.secondaryColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusItem(
    String title,
    String subtitle,
    String status,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textPrimaryColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStaffOverviewChart([bool isMobile = false]) {
    final List<double> weeklyData = [16, 24, 21, 32, 23, 12, 25];
    final List<String> weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Staff Overview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: const [
                    Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                // Y-Axis labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      '40',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '30',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '20',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '10',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Line Graph
                Expanded(
                  child: CustomPaint(
                    painter: LineChartPainter(weeklyData),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 155.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(weekdays.length, (index) {
                              return Text(
                                weekdays[index],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }),
                          ),
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
                  ),
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
                      'Shift Allocation',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Define shift schedules and allocate nurses to active shifts',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showAllocateNurseDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Allocate Nurse (Daily)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: AppTheme.primaryColor,
                          ),
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
                            'Shift Allocation',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Define shift schedules and allocate nurses to active shifts',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 13,
                            ),
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
                          label: const Text(
                            'Allocate Nurse (Daily)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: AppTheme.primaryColor,
                          ),
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
              return n.fullname.toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
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
                            final avatarColors = AppTheme.getAvatarColors(
                              nurse.fullname,
                            );

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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              nurse.fullname,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color:
                                                    AppTheme.textPrimaryColor,
                                              ),
                                            ),
                                            if (nurse.staffUniqueId != null &&
                                                nurse
                                                    .staffUniqueId!
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                nurse.staffUniqueId!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme
                                                      .textSecondaryColor,
                                                ),
                                              ),
                                            ],
                                          ],
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

  Future<void> _autoAllocateThisWeek() async {
    final WARD_TYPES = ['General', 'ICU', 'Private', 'Semi-Private'];

    if (_nurses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No nurses available in the system.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No shifts defined in the system. Please define shifts first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm dialog
    final weekStartStr = DateFormat('dd MMM').format(_selectedRosterWeekStart);
    final weekEndStr = DateFormat(
      'dd MMM yyyy',
    ).format(_selectedRosterWeekStart.add(const Duration(days: 6)));

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            const Text(
              'Auto-Allocate This Week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This will automatically assign shifts for the selected week ($weekStartStr - $weekEndStr) '
          'using the available nurses in the system.\n\n'
          'Existing assignments in this week will be overwritten.\n\n'
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
            child: const Text('Allocate Automatically'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Define all target slots: each ward combined with each shift
    List<Map<String, dynamic>> slotsToAssign = [];
    for (final ward in WARD_TYPES) {
      for (final shift in _shifts) {
        slotsToAssign.add({'ward': ward, 'shift_id': shift['id']});
      }
    }

    // Build the pool of nurse IDs
    final List<int> nurseIdsPool = _nurses.map((n) => n.id).toList();
    final List<int> targetNurseIds = [...nurseIdsPool];

    // If we have fewer unique nurses than slots, backfill/repeat the pool
    while (targetNurseIds.length < slotsToAssign.length) {
      targetNurseIds.addAll(nurseIdsPool.isNotEmpty ? nurseIdsPool : [1]);
    }

    final List<int> finalNurseIds = targetNurseIds.sublist(
      0,
      slotsToAssign.length,
    );

    // Helper to check for continuous shifts
    bool areShiftsContinuous(Map<String, dynamic> s1, Map<String, dynamic> s2) {
      final end1 = s1['end_time']?.toString().trim();
      final start1 = s1['start_time']?.toString().trim();
      final end2 = s2['end_time']?.toString().trim();
      final start2 = s2['start_time']?.toString().trim();

      if (end1 == null || start1 == null || end2 == null || start2 == null)
        return false;
      return end1 == start2 || end2 == start1;
    }

    bool isValidRoster(List<int> list) {
      final Map<int, List<Map<String, dynamic>>> nurseShifts = {};
      for (int i = 0; i < list.length; i++) {
        final nurseId = list[i];
        final slot = slotsToAssign[i];
        final shiftId = slot['shift_id'] as int;

        final shiftDetail = _shifts.firstWhere(
          (s) => s['id'] == shiftId,
          orElse: () => <String, dynamic>{},
        );
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

    final targetWeekStartStr = DateFormat(
      'yyyy-MM-dd',
    ).format(_selectedRosterWeekStart);
    setState(() => _isLoadingShifts = true);

    try {
      int successCount = 0;
      for (int i = 0; i < slotsToAssign.length; i++) {
        final slot = slotsToAssign[i];
        final nurseId = finalNurseIds[i];
        await _shiftCtrl.saveRosterEntry(
          nurseId,
          slot['shift_id'],
          slot['ward'],
          targetWeekStartStr,
        );
        successCount++;
      }

      await _loadRosterData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully allocated $successCount shifts for this week!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to auto-allocate: $e'),
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

    bool isEmptyRoster = false;
    if (activeSlots.isEmpty) {
      isEmptyRoster = true;
      if (_nurses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No nurses available in the system.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Auto-populate all slots to allocate automatically
      for (final ward in WARD_TYPES) {
        for (final shift in _shifts) {
          activeSlots.add({
            'ward': ward,
            'shift_id': shift['id'],
            'nurse_id': 0,
            'nurse_name': 'Unassigned',
          });
        }
      }
    }

    // 2. Confirm dialog with the user showing next week's dates
    final nextWeekStart = _selectedRosterWeekStart.add(const Duration(days: 7));
    final nextWeekStartStr = DateFormat('dd MMM').format(nextWeekStart);
    final nextWeekEndStr = DateFormat(
      'dd MMM yyyy',
    ).format(nextWeekStart.add(const Duration(days: 6)));

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
            Text(
              isEmptyRoster
                  ? 'Auto-Allocate Next Week'
                  : 'Auto-Shuffle Next Week',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isEmptyRoster
              ? 'This will automatically allocate shifts for the next week ($nextWeekStartStr - $nextWeekEndStr) '
                    'using the available nurses in the system.\n\n'
                    'Existing assignments in the target week will be overwritten.\n\n'
                    'Do you want to proceed?'
              : 'This will automatically assign shifts for the next week ($nextWeekStartStr - $nextWeekEndStr) '
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
            child: Text(
              isEmptyRoster ? 'Allocate Automatically' : 'Shuffle & Assign',
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 3. Create a pool of unique nurse IDs to assign to the active slots
    // We prioritize the nurse IDs that are already active this week
    final List<int> activeNurseIds = activeSlots
        .map((s) => s['nurse_id'] as int)
        .toSet()
        .toList();
    activeNurseIds.remove(0); // Remove placeholder id
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

    // If we STILL don't have enough unique nurses, repeat the pool
    final List<int> fallbackNursePool = _nurses.map((n) => n.id).toList();
    while (targetNurseIds.length < activeSlots.length) {
      targetNurseIds.addAll(
        fallbackNursePool.isNotEmpty ? fallbackNursePool : [1],
      );
    }

    final List<int> finalNurseIds = targetNurseIds.sublist(
      0,
      activeSlots.length,
    );

    // Helper to verify if a nurse is assigned to continuous shifts or duplicates on the same shift
    bool areShiftsContinuous(Map<String, dynamic> s1, Map<String, dynamic> s2) {
      final end1 = s1['end_time']?.toString().trim();
      final start1 = s1['start_time']?.toString().trim();
      final end2 = s2['end_time']?.toString().trim();
      final start2 = s2['start_time']?.toString().trim();

      if (end1 == null || start1 == null || end2 == null || start2 == null)
        return false;

      // Check if s1 ends when s2 starts, or s2 ends when s1 starts
      return end1 == start2 || end2 == start1;
    }

    bool isValidRoster(List<int> list) {
      final Map<int, List<Map<String, dynamic>>> nurseShifts = {};
      for (int i = 0; i < list.length; i++) {
        final nurseId = list[i];
        final slot = activeSlots[i];
        final shiftId = slot['shift_id'] as int;

        final shiftDetail = _shifts.firstWhere(
          (s) => s['id'] == shiftId,
          orElse: () => <String, dynamic>{},
        );
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
        await _shiftCtrl.saveRosterEntry(
          nurseId,
          slot['shift_id'],
          slot['ward'],
          targetWeekStartStr,
        );
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
            content: Text(
              isEmptyRoster
                  ? 'Successfully allocated $successCount shifts for the next week!'
                  : 'Successfully shuffled and assigned $successCount shifts for the next week!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEmptyRoster
                  ? 'Failed to auto-allocate: $e'
                  : 'Error shuffling roster: $e',
            ),
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
    final weekEndStr = DateFormat(
      'dd MMM yyyy',
    ).format(_selectedRosterWeekStart.add(const Duration(days: 6)));

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
                          Icon(
                            Icons.date_range_rounded,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Weekly Roster Templates',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                            onPressed: _autoAllocateThisWeek,
                            icon: const Icon(Icons.auto_awesome, size: 14),
                            label: const Text(
                              'Auto-Allocate This Week',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _autoShuffleNextWeek,
                            icon: const Icon(Icons.shuffle_rounded, size: 14),
                            label: const Text(
                              'Shuffle Next Week',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart =
                                          _selectedRosterWeekStart.subtract(
                                            const Duration(days: 7),
                                          );
                                    });
                                    _loadRosterData();
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
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
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart =
                                          _selectedRosterWeekStart.add(
                                            const Duration(days: 7),
                                          );
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
                          Icon(
                            Icons.date_range_rounded,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Weekly Roster Templates',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _autoAllocateThisWeek,
                            icon: const Icon(Icons.auto_awesome, size: 14),
                            label: const Text(
                              'Auto-Allocate This Week',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _autoShuffleNextWeek,
                            icon: const Icon(Icons.shuffle_rounded, size: 14),
                            label: const Text(
                              'Auto-Shuffle Next Week',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart =
                                          _selectedRosterWeekStart.subtract(
                                            const Duration(days: 7),
                                          );
                                    });
                                    _loadRosterData();
                                  },
                                  tooltip: 'Previous Week',
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
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
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedRosterWeekStart =
                                          _selectedRosterWeekStart.add(
                                            const Duration(days: 7),
                                          );
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
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'No shifts allocated for this week.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please allocate shifts manually or navigate to the previous week to auto-shuffle slots into this week.',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _autoAllocateThisWeek,
                              icon: const Icon(Icons.auto_awesome, size: 14),
                              label: const Text('Auto-Allocate This Week'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'No shifts allocated for this week.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Please allocate shifts manually or navigate to the previous week to auto-shuffle slots into this week.',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: _autoAllocateThisWeek,
                                    icon: const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Auto-Allocate This Week',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
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
                            color: (shiftTheme['text'] as Color).withOpacity(
                              0.8,
                            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showShiftDialog(null),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text(
                      'Define Shift',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Timings: ${_formatTo12Hour(shift['start_time'])} - ${_formatTo12Hour(shift['end_time'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () => _showShiftDialog(shift),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.redAccent,
                              ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppTheme.primaryColor,
                  ),
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
                      const Text(
                        'Nurse',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CustomDropdownSearch(
                        label: '',
                        hint: 'Select Nurse',
                        value:
                            _selectedAllocNurse == null ||
                                !_nurses.any(
                                  (n) => n.id == _selectedAllocNurse!.id,
                                )
                            ? null
                            : _selectedAllocNurse!.id.toString(),
                        dropdownMap: {
                          for (var n in _nurses)
                            n.id.toString():
                                n.staffUniqueId != null &&
                                    n.staffUniqueId!.isNotEmpty
                                ? '${n.fullname} (${n.staffUniqueId})'
                                : n.fullname,
                        },
                        onChanged: (val) {
                          final found = val == null
                              ? null
                              : _nurses.firstWhere(
                                  (n) => n.id.toString() == val,
                                );
                          setDialogState(() => _selectedAllocNurse = found);
                          setState(() => _selectedAllocNurse = found);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Shift
                      const Text(
                        'Shift Schedule',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CustomDropdownSearch(
                        label: '',
                        hint: 'Select Shift',
                        value:
                            _selectedAllocShift == null ||
                                !_shifts.any(
                                  (s) => s['id'] == _selectedAllocShift!['id'],
                                )
                            ? null
                            : _selectedAllocShift!['id'].toString(),
                        dropdownMap: {
                          for (var s in _shifts)
                            s['id'].toString():
                                '${s['name']} (${_formatTo12Hour(s['start_time'])} - ${_formatTo12Hour(s['end_time'])})',
                        },
                        onChanged: (val) {
                          final found = val == null
                              ? null
                              : _shifts.firstWhere(
                                  (s) => s['id'].toString() == val,
                                );
                          setDialogState(() => _selectedAllocShift = found);
                          setState(() => _selectedAllocShift = found);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Ward
                      const Text(
                        'Ward / Department',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CustomDropdownSearch(
                        label: '',
                        hint: 'Select Ward',
                        value: _selectedAllocWard,
                        dropdownMap: {for (var w in WARD_TYPES) w: '$w Ward'},
                        onChanged: (val) {
                          setDialogState(() => _selectedAllocWard = val);
                          setState(() => _selectedAllocWard = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date Picker
                      const Text(
                        'Allocation Date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate: _selectedAllocDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 90),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => _selectedAllocDate = picked);
                            setState(() => _selectedAllocDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedAllocDate != null
                                    ? DateFormat(
                                        'dd-MM-yyyy',
                                      ).format(_selectedAllocDate!)
                                    : 'Choose Date',
                              ),
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A5568),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(130, 48),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.logoRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(130, 48),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (_selectedAllocNurse == null ||
                        _selectedAllocShift == null ||
                        _selectedAllocWard == null ||
                        _selectedAllocDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select Nurse, Shift, Ward, and Date.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    _submitAllocation();
                  },
                  child: const Text(
                    'Save Allocation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAllocationLogsCard() {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

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
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: AppTheme.primaryColor,
                  size: isMobile ? 20 : 24,
                ),
                const SizedBox(width: 10),
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
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.borderColor.withOpacity(0.5),
                  ),
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
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
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
                              rows: _allocations.map((alloc) {
                                final dateStr = alloc['allocation_date'] != null
                                    ? DateFormat('dd-MM-yyyy').format(
                                        DateTime.parse(
                                          alloc['allocation_date'],
                                        ),
                                      )
                                    : '--';
                                final timings =
                                    '${_formatTo12Hour(alloc['start_time'])} - ${_formatTo12Hour(alloc['end_time'])}';
                                final status = alloc['status'] ?? 'Active';
                                final statusColor = status == 'Active'
                                    ? Colors.green
                                    : Colors.grey;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(dateStr)),
                                    DataCell(
                                      Text(alloc['nurse_name'] ?? 'Unknown'),
                                    ),
                                    DataCell(
                                      Text('${alloc['ward_type'] ?? ''} Ward'),
                                    ),
                                    DataCell(Text(alloc['shift_name'] ?? '')),
                                    DataCell(Text(timings)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            _deleteAllocation(alloc['id']),
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

  // --- Home Visit Care Section (Admin Only Schedule) ---

  Widget _buildAdminHomeVisitCare(bool isMobile) {
    if (_selectedHomeVisitId != null) {
      return HomeVisitExecutionScreen(
        visitId: _selectedHomeVisitId!,
        isReadOnlyView: true,
        onBack: () {
          setState(() {
            _selectedHomeVisitId = null;
          });
          context.go(AppRoutes.adminHomeVisits);
        },
      );
    }

    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            color: Colors.white,
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.home_work_outlined,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Home Visit Care & Scheduling',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                Text(
                                  'Schedule home care visits by assigning nurses & patients',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: AppTheme.dangerButton,
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Schedule Home Visit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () =>
                              _showAdminScheduleVisitDialog(context),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.home_work_outlined,
                                color: AppTheme.primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Home Visit Care & Scheduling',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimaryColor,
                                      fontFamily: 'Inter',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Schedule home care visits by assigning nurses & patients',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                      fontFamily: 'Inter',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          style: AppTheme.dangerButton,
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Schedule Home Visit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () =>
                              _showAdminScheduleVisitDialog(context),
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: HomeVisitListView(
              showHeader: false,
              showScheduleButton: false,
              showExecuteButton: false,
              onViewSummary: (visitId) {
                setState(() {
                  _selectedHomeVisitId = visitId;
                });
                context.go('/admin/home-visits/summary/$visitId');
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminScheduleVisitDialog(BuildContext context) async {
    List<UserModel> availableNurses = _nurses;
    if (availableNurses.isEmpty) {
      try {
        availableNurses = await _adminController.fetchStaff(role: 'Nurse');
      } catch (_) {}
    }

    List<PatientModel> availablePatients = _dbPatients;
    if (availablePatients.isEmpty) {
      try {
        availablePatients = await _patientController.fetchPatients();
      } catch (_) {}
    }

    UserModel? selectedNurse;
    PatientModel? selectedPatient;

    final now = DateTime.now();
    final dateCtrl = TextEditingController(
      text:
          "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}",
    );
    final addressCtrl = TextEditingController(text: '');
    final timeCtrl = TextEditingController(text: '9:00 AM');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final homeVisitCtrl = Provider.of<HomeVisitController>(
            context,
            listen: false,
          );

          String apiDateStr = dateCtrl.text;
          final dateParts = dateCtrl.text.split('-');
          if (dateParts.length == 3 && dateParts[2].length == 4) {
            apiDateStr = "${dateParts[2]}-${dateParts[1]}-${dateParts[0]}";
          }

          // Validation Check: "Once already chosen nurse patient on selected date cannot chosen again."
          final bool isDuplicateNursePatient =
              selectedNurse != null &&
              selectedPatient != null &&
              homeVisitCtrl.visits.any(
                (v) =>
                    v.nurseId == selectedNurse!.id &&
                    v.patientId == selectedPatient!.id &&
                    v.scheduledDate == apiDateStr &&
                    v.status != 'Cancelled',
              );

          final bool isDuplicatePatientDate =
              selectedPatient != null &&
              homeVisitCtrl.visits.any(
                (v) =>
                    v.patientId == selectedPatient!.id &&
                    v.scheduledDate == apiDateStr &&
                    v.status != 'Cancelled',
              );

          final bool hasValidationError =
              isDuplicateNursePatient || isDuplicatePatientDate;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.home_work_outlined,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Schedule Home Visit',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width > 520
                    ? 480
                    : MediaQuery.of(context).size.width * 0.88,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign a nurse and select a patient to schedule a home care visit.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // 1. Choose Nurse
                    const Text(
                      'Select Nurse:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomDropdownSearch(
                      label: '',
                      hint: 'Select Nurse',
                      dropdownItems: availableNurses.map((n) {
                        final uid = n.staffUniqueId ?? '';
                        final idStr = uid.isNotEmpty ? ' ($uid)' : '';
                        return '${n.fullname}$idStr';
                      }).toList(),
                      value: selectedNurse != null
                          ? '${selectedNurse!.fullname}${(selectedNurse!.staffUniqueId != null && selectedNurse!.staffUniqueId!.isNotEmpty) ? ' (${selectedNurse!.staffUniqueId})' : ''}'
                          : null,
                      onChanged: (val) {
                        if (val != null) {
                          final found = availableNurses.firstWhere((n) {
                            final uid = n.staffUniqueId ?? '';
                            final idStr = uid.isNotEmpty ? ' ($uid)' : '';
                            return '${n.fullname}$idStr' == val;
                          }, orElse: () => availableNurses.first);
                          setDialogState(() {
                            selectedNurse = found;
                          });
                        }
                      },
                      height: 48,
                      borderColor: const Color(0xFFE2E8F0),
                      focusedBorderColor: AppTheme.primaryColor,
                      fillColor: AppTheme.backgroundColor,
                      popupBgColor: Colors.white,
                    ),
                    const SizedBox(height: 16),

                    // 2. Choose Patient
                    const Text(
                      'Select Patient:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomDropdownSearch(
                      label: '',
                      hint: 'Search/Select Patient',
                      dropdownItems: availablePatients
                          .map((p) => "${p.name} (${p.patientId ?? 'N/A'})")
                          .toList(),
                      value: selectedPatient != null
                          ? "${selectedPatient!.name} (${selectedPatient!.patientId ?? 'N/A'})"
                          : null,
                      onChanged: (val) {
                        if (val != null) {
                          final found = availablePatients.firstWhere(
                            (p) => "${p.name} (${p.patientId ?? 'N/A'})" == val,
                            orElse: () => availablePatients.first,
                          );
                          setDialogState(() {
                            selectedPatient = found;
                            addressCtrl.text = found.fullAddress.isNotEmpty
                                ? found.fullAddress
                                : found.address;
                          });
                        }
                      },
                      height: 48,
                      borderColor: const Color(0xFFE2E8F0),
                      focusedBorderColor: AppTheme.primaryColor,
                      fillColor: AppTheme.backgroundColor,
                      popupBgColor: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    // Single small gray line for Visit Address directly below patient field
                    Padding(
                      padding: const EdgeInsets.only(left: 2.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              selectedPatient != null
                                  ? 'Visit Address: ${addressCtrl.text.isNotEmpty ? addressCtrl.text : "No address recorded"}'
                                  : 'Visit Address: Select a patient to view address',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Scheduled Date
                    const Text(
                      'Scheduled Date:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      decoration: AppTheme.standardInputDecoration(
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            dateCtrl.text =
                                "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                          });
                        }
                      },
                    ),

                    // Validation Warning Box
                    if (isDuplicateNursePatient) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '⚠️ Nurse "${selectedNurse?.fullname}" is already scheduled for "${selectedPatient?.name}" on ${dateCtrl.text}. Once chosen, this nurse & patient combination on this date cannot be scheduled again.',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isDuplicatePatientDate) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '⚠️ A home visit is already scheduled for "${selectedPatient?.name}" on ${dateCtrl.text}. Only 1 visit per patient per day is allowed.',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogCtx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: AppTheme.dangerButton,
                onPressed:
                    (isSubmitting ||
                        hasValidationError ||
                        selectedNurse == null ||
                        selectedPatient == null)
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        final homeVisitCtrl = Provider.of<HomeVisitController>(
                          context,
                          listen: false,
                        );

                        final newVisit = await homeVisitCtrl.createVisit({
                          'nurse_id': selectedNurse!.id,
                          'patient_id': selectedPatient!.id,
                          'scheduled_date': apiDateStr,
                          'scheduled_time': timeCtrl.text,
                          'visit_address': addressCtrl.text,
                          'carried_items': [],
                        });

                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                        if (newVisit != null) {
                          await homeVisitCtrl.fetchVisits();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Home visit ${newVisit.visitNumber} scheduled for ${selectedPatient!.name} with Nurse ${selectedNurse!.fullname}!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                homeVisitCtrl.errorMessage ??
                                    'Failed to schedule home visit.',
                              ),
                              backgroundColor: AppTheme.dangerColor,
                            ),
                          );
                        }
                      },
                child: Text(isSubmitting ? 'Scheduling...' : 'Schedule Visit'),
              ),
            ],
          );
        },
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
              title: Text(
                shift == null ? 'Define Shift Schedule' : 'Edit Shift Schedule',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Shift Name',
                      hintText: 'e.g., Morning, Evening, Night',
                      counterText: '',
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
                            initialTime:
                                startTime ??
                                const TimeOfDay(hour: 8, minute: 0),
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
                            initialTime:
                                endTime ?? const TimeOfDay(hour: 16, minute: 0),
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
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A5568),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(130, 48),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.logoRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(130, 48),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty ||
                        startTime == null ||
                        endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please complete all shift details.'),
                        ),
                      );
                      return;
                    }

                    final startStr =
                        '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00';
                    final endStr =
                        '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00';

                    try {
                      if (shift == null) {
                        await _shiftCtrl.createShift(
                          nameCtrl.text,
                          startStr,
                          endStr,
                        );
                      } else {
                        await _shiftCtrl.updateShift(
                          shift['id'],
                          nameCtrl.text,
                          startStr,
                          endStr,
                        );
                      }
                      Navigator.pop(dialogCtx);
                      _loadShiftData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Shift schedule saved successfully!'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
        content: const Text(
          'Are you sure you want to delete this shift schedule? All associated allocations will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
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
        const SnackBar(
          content: Text('Please select Nurse, Shift, Ward, and Date.'),
        ),
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
        content: const Text(
          'Are you sure you want to delete this nurse shift allocation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // MEDICATION CATALOG MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  final List<Map<String, dynamic>> _medicationCatalog = [];
  bool _isMedCatalogLoading = false;
  String? _medCatalogError;
  String _medCatalogSearch = '';
  String _selectedMedCategoryFilter = 'Total';
  final TextEditingController _medSearchController = TextEditingController();

  String get _medBaseUrl => ApiEndpoints.baseUrl;

  Future<void> _loadMedicationCatalog() async {
    if (!mounted) return;
    setState(() {
      _isMedCatalogLoading = true;
      _medCatalogError = null;
    });
    try {
      final search = _medCatalogSearch.trim();
      final url = search.isEmpty
          ? '$_medBaseUrl/inventory/medicine-catalog'
          : '$_medBaseUrl/inventory/medicine-catalog?search=${Uri.encodeComponent(search)}';
      final resp = await ApiService.get(url);
      final body = ApiService.decodeJsonResponse(resp);
      if (mounted) {
        setState(() {
          _medicationCatalog.clear();
          _medicationCatalog.addAll(
            List<Map<String, dynamic>>.from(body['data'] ?? []),
          );
          _isMedCatalogLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _medCatalogError = e.toString().replaceFirst('Exception: ', '');
          _isMedCatalogLoading = false;
        });
      }
    }
  }

  Future<void> _showAddMedicationDialog(bool isMobile) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'tabs');
    String selectedCategory = 'Medicine';
    bool isControlled = false;
    bool isSaving = false;

    final categories = ['Medicine', 'ICU Consumable', 'Surgical Item'];
    final defaultUnits = [
      'tabs',
      'caps',
      'vials',
      'bags',
      'pcs',
      'pairs',
      'ml',
      'mg',
      'strips',
    ];

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Add New Medication',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medication Name
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Medication Name ',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(80),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.medication,
                          hintText: 'e.g. Aspirin 75mg',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Medication name is required';
                          }
                          final clean = v.trim();
                          if (clean.length < 3) {
                            return 'Must be at least 3 characters';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                            return 'Medication name must contain alphabetical characters';
                          }
                          final words = clean
                              .split(RegExp(r'\s+'))
                              .where((w) => w.isNotEmpty)
                              .toList();
                          if (words.length > 80) {
                            return 'Medication name cannot exceed 80 words';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Category
                      CustomDropdownSearch(
                        label: 'Category',
                        requiredMark: true,
                        hint: 'Select category',
                        value: selectedCategory,
                        dropdownItems: categories,
                        onChanged: (val) {
                          if (val != null) setD(() => selectedCategory = val);
                        },
                        validator: (v) =>
                            v == null || v.isEmpty || !categories.contains(v)
                            ? 'Please select a category'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Default Unit
                      CustomDropdownSearch(
                        label: 'Default Unit',
                        requiredMark: true,
                        hint: 'Select unit',
                        value: unitCtrl.text,
                        dropdownItems: defaultUnits,
                        onChanged: (val) {
                          if (val != null) setD(() => unitCtrl.text = val);
                        },
                        validator: (v) =>
                            v == null || v.isEmpty || !defaultUnits.contains(v)
                            ? 'Please select a unit'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Controlled Substance Switch
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: isControlled
                                  ? AppTheme.logoRed
                                  : AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Controlled Substance',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Requires special prescription & dispensing log',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isControlled,
                              onChanged: (v) => setD(() => isControlled = v),
                              activeColor: AppTheme.logoRed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          final resp = await ApiService.post(
                            '$_medBaseUrl/inventory/medicine-catalog',
                            {
                              'name': nameCtrl.text.trim(),
                              'category': selectedCategory,
                              'default_unit': unitCtrl.text,
                              'is_controlled': isControlled,
                            },
                          );
                          final respBody = ApiService.decodeJsonResponse(resp);
                          if (resp.statusCode == 201 &&
                              respBody['success'] == true) {
                            if (mounted) Navigator.pop(ctx, true);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    respBody['message'] ??
                                        'Medication added successfully',
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                ),
                              );
                            }
                          } else {
                            throw Exception(
                              respBody['message'] ?? 'Failed to add medication',
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },

                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Medication'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadMedicationCatalog();
  }

  void _showEditMedicationDialog(
    Map<String, dynamic> med, [
    bool isMobile = false,
  ]) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: med['name']?.toString() ?? '');
    final unitCtrl = TextEditingController(
      text: med['default_unit']?.toString() ?? 'tabs',
    );
    String selectedCategory = med['category']?.toString() ?? 'Medicine';
    bool isControlled = med['is_controlled'] == true;
    bool isSaving = false;

    final categories = ['Medicine', 'ICU Consumable', 'Surgical Item'];
    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }

    final defaultUnits = [
      'tabs',
      'caps',
      'vials',
      'bags',
      'pcs',
      'pairs',
      'ml',
      'mg',
      'strips',
    ];
    if (!defaultUnits.contains(unitCtrl.text)) {
      defaultUnits.add(unitCtrl.text);
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Edit Medication',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medication Name
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Medication Name ',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        keyboardType: TextInputType.text,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(80),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.medication,
                          hintText: 'e.g. Aspirin 75mg',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Medication name is required';
                          }
                          final clean = v.trim();
                          if (clean.length < 3) {
                            return 'Must be at least 3 characters';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                            return 'Medication name must contain alphabetical characters';
                          }
                          final words = clean
                              .split(RegExp(r'\s+'))
                              .where((w) => w.isNotEmpty)
                              .toList();
                          if (words.length > 80) {
                            return 'Medication name cannot exceed 80 words';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Category
                      CustomDropdownSearch(
                        label: 'Category',
                        requiredMark: true,
                        hint: 'Select category',
                        value: selectedCategory,
                        dropdownItems: categories,
                        onChanged: (val) {
                          if (val != null) setD(() => selectedCategory = val);
                        },
                        validator: (v) =>
                            v == null || v.isEmpty || !categories.contains(v)
                            ? 'Please select a category'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Default Unit
                      CustomDropdownSearch(
                        label: 'Default Unit',
                        requiredMark: true,
                        hint: 'Select unit',
                        value: unitCtrl.text,
                        dropdownItems: defaultUnits,
                        onChanged: (val) {
                          if (val != null) setD(() => unitCtrl.text = val);
                        },
                        validator: (v) =>
                            v == null || v.isEmpty || !defaultUnits.contains(v)
                            ? 'Please select a unit'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Controlled Substance Switch
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: isControlled
                                  ? AppTheme.logoRed
                                  : AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Controlled Substance',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Requires special prescription & dispensing log',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isControlled,
                              onChanged: (v) => setD(() => isControlled = v),
                              activeColor: AppTheme.logoRed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          final resp = await ApiService.put(
                            '$_medBaseUrl/inventory/medicine-catalog/${med['id']}',
                            {
                              'name': nameCtrl.text.trim(),
                              'category': selectedCategory,
                              'default_unit': unitCtrl.text,
                              'is_controlled': isControlled,
                            },
                          );
                          final respBody = ApiService.decodeJsonResponse(resp);
                          if (resp.statusCode == 200 &&
                              respBody['success'] == true) {
                            if (mounted) Navigator.pop(ctx, true);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    respBody['message'] ??
                                        'Medication updated successfully',
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                ),
                              );
                            }
                          } else {
                            throw Exception(
                              respBody['message'] ?? 'Failed to update medication',
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },
                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadMedicationCatalog();
  }

  Future<void> _deleteMedication(Map<String, dynamic> med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Remove Medication',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to remove '),
              TextSpan(
                text: '"${med['name']}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' from the medication catalog? This cannot be undone.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.dangerButton,
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.delete(
        '$_medBaseUrl/inventory/medicine-catalog/${med['id']}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${med['name']}" removed from catalog.'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _loadMedicationCatalog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Widget _buildMedicationCatalog(bool isMobile) {
    // Load on first access
    if (_medicationCatalog.isEmpty &&
        !_isMedCatalogLoading &&
        _medCatalogError == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadMedicationCatalog(),
      );
    }

    final filtered = _medicationCatalog.where((m) {
      final matchesSearch = _medCatalogSearch.trim().isEmpty ||
          (m['name'] as String).toLowerCase().contains(
                _medCatalogSearch.toLowerCase(),
              ) ||
          (m['category'] as String).toLowerCase().contains(
                _medCatalogSearch.toLowerCase(),
              );

      final matchesCategory = () {
        if (_selectedMedCategoryFilter == 'Total') return true;
        if (_selectedMedCategoryFilter == 'Controlled') {
          return m['is_controlled'] == true;
        }
        return m['category'] == _selectedMedCategoryFilter;
      }();

      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Bar ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMedCatalogHeaderTitle(),
                    const SizedBox(height: 12),
                    _buildMedCatalogSearchBar(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddMedicationDialog(isMobile),
                        style: AppTheme.primaryButton,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Medication'),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _buildMedCatalogHeaderTitle(),
                    const Spacer(),
                    SizedBox(width: 280, child: _buildMedCatalogSearchBar()),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddMedicationDialog(isMobile),
                      style: AppTheme.primaryButton,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Medication'),
                    ),
                  ],
                ),
        ),

        // ── Stats Row ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMedStatChip(
                Icons.medication_outlined,
                AppTheme.primaryColor,
                'Total',
                '${_medicationCatalog.length}',
              ),
              _buildMedStatChip(
                Icons.science_outlined,
                AppTheme.secondaryColor,
                'Medicine',
                '${_medicationCatalog.where((m) => m['category'] == 'Medicine').length}',
              ),
              _buildMedStatChip(
                Icons.local_hospital_outlined,
                const Color(0xFF7C3AED),
                'ICU Consumable',
                '${_medicationCatalog.where((m) => m['category'] == 'ICU Consumable').length}',
              ),
              _buildMedStatChip(
                Icons.content_cut_outlined,
                const Color(0xFFF59E0B),
                'Surgical Item',
                '${_medicationCatalog.where((m) => m['category'] == 'Surgical Item').length}',
              ),
              _buildMedStatChip(
                Icons.lock_outline,
                AppTheme.dangerColor,
                'Controlled',
                '${_medicationCatalog.where((m) => m['is_controlled'] == true).length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Content ──────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isMedCatalogLoading
                ? const Center(child: CircularProgressIndicator())
                : _medCatalogError != null
                ? _buildMedCatalogError()
                : filtered.isEmpty
                ? _buildMedCatalogEmpty()
                : isMobile
                ? _buildMedCatalogMobileList(filtered)
                : _buildMedCatalogDesktopTable(filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildMedCatalogHeaderTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.medication_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Medication Catalog',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage the master list of medications used across the system',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
        ),
      ],
    );
  }

  Widget _buildMedCatalogSearchBar() {
    return TextField(
      controller: _medSearchController,
      decoration:
          AppTheme.standardInputDecoration(
            label: null,
            prefixIcon: Icons.search,
            hintText: 'Search medications...',
          ).copyWith(
            suffixIcon: _medCatalogSearch.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _medSearchController.clear();
                      setState(() => _medCatalogSearch = '');
                      _loadMedicationCatalog();
                    },
                  )
                : null,
          ),
      onChanged: (v) {
        setState(() => _medCatalogSearch = v);
      },
      onSubmitted: (_) => _loadMedicationCatalog(),
    );
  }

  Widget _buildMedStatChip(
    IconData icon,
    Color color,
    String label,
    String count,
  ) {
    final isSelected = _selectedMedCategoryFilter == label;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _selectedMedCategoryFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedCatalogError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppTheme.dangerColor.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            _medCatalogError ?? 'An error occurred',
            style: const TextStyle(color: AppTheme.textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadMedicationCatalog,
            style: AppTheme.primaryButton,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMedCatalogEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _medCatalogSearch.isNotEmpty
                ? 'No medications match "$_medCatalogSearch"'
                : 'No medications in catalog yet',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Medication" to add a new entry',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildMedCatalogDesktopTable(List<Map<String, dynamic>> items) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '#  Medication Name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Unit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Table Rows
            Expanded(
              child: ListView.separated(
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppTheme.borderColor),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final med = items[i];
                  final isControlled = med['is_controlled'] == true;
                  final category = med['category'] as String? ?? 'Medicine';
                  final catColor = category == 'Medicine'
                      ? AppTheme.primaryColor
                      : category == 'ICU Consumable'
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFF59E0B);
                  return Container(
                    color: i.isEven ? Colors.white : const Color(0xFFFAFBFC),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Text(
                                '${i + 1}. ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  med['name'] as String? ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 13,
                              color: catColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            med['default_unit'] as String? ?? '-',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: isControlled
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 12,
                                        color: AppTheme.dangerColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Controlled',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.dangerColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Standard',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.secondaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                        SizedBox(
                          width: 88,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                                tooltip: 'Edit Medication',
                                onPressed: () =>
                                    _showEditMedicationDialog(med, false),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppTheme.dangerColor,
                                ),
                                tooltip: 'Remove from catalog',
                                onPressed: () => _deleteMedication(med),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedCatalogMobileList(List<Map<String, dynamic>> items) {
    return ListView.separated(
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final med = items[i];
        final isControlled = med['is_controlled'] == true;
        final category = med['category'] as String? ?? 'Medicine';
        final catColor = category == 'Medicine'
            ? AppTheme.primaryColor
            : category == 'ICU Consumable'
            ? const Color(0xFF7C3AED)
            : const Color(0xFFF59E0B);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med['name'] as String? ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: catColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            med['default_unit'] as String? ?? '-',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isControlled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 11,
                                  color: AppTheme.dangerColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Controlled',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.dangerColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    tooltip: 'Edit Medication',
                    onPressed: () => _showEditMedicationDialog(med, true),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.dangerColor,
                    ),
                    tooltip: 'Remove',
                    onPressed: () => _deleteMedication(med),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOME VISIT PROCEDURES & CONSUMABLES MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  List<ProcedureMasterModel> _hvProceduresMaster = [];
  List<Map<String, dynamic>> _hvConsumablesMasterList = [];
  final Set<int> _expandedProcedureIds = <int>{};
  bool _isHVConsumableLoading = false;
  String? _hvConsumableError;
  String _hvConsumableSearch = '';
  int _hvCatalogSelectedTab = 0;
  final TextEditingController _hvSearchController = TextEditingController();

  List<Map<String, dynamic>> _hvKitItemsMasterList = [];
  bool _isHVKitItemsLoading = false;
  String? _hvKitItemsError;
  String _hvKitItemsSearch = '';
  String _selectedHVCatalogCategoryFilter = 'Total Master Items';
  final TextEditingController _hvKitItemsSearchController =
      TextEditingController();

  Future<void> _loadHomeVisitKitItemsCatalog() async {
    if (!mounted) return;
    setState(() {
      _isHVKitItemsLoading = true;
      _hvKitItemsError = null;
    });
    try {
      final service = HomeVisitService();
      final items = await service.fetchKitItemsMaster();
      items.sort(
        (a, b) => (int.tryParse(b['id']?.toString() ?? '0') ?? 0).compareTo(
          int.tryParse(a['id']?.toString() ?? '0') ?? 0,
        ),
      );

      if (mounted) {
        setState(() {
          _hvKitItemsMasterList = items;
          _isHVKitItemsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hvKitItemsError = e.toString().replaceFirst('Exception: ', '');
          _isHVKitItemsLoading = false;
        });
      }
    }
  }

  Future<void> _loadHomeVisitConsumablesCatalog() async {
    if (!mounted) return;
    setState(() {
      _isHVConsumableLoading = true;
      _hvConsumableError = null;
    });
    try {
      final service = HomeVisitService();
      final procedures = await service.fetchProceduresMaster();
      final consumables = await service.fetchConsumablesMaster();

      procedures.sort((a, b) => b.id.compareTo(a.id));

      if (mounted) {
        setState(() {
          _hvProceduresMaster = procedures;
          _hvConsumablesMasterList = consumables;
          _isHVConsumableLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hvConsumableError = e.toString().replaceFirst('Exception: ', '');
          _isHVConsumableLoading = false;
        });
      }
    }
  }

  // Modal Dialog: Add New Procedure with Mapped Consumable Items
  Future<void> _showAddProcedureDialog(bool isMobile) async {
    if (_hvConsumablesMasterList.isEmpty) {
      try {
        final list = await HomeVisitService().fetchConsumablesMaster();
        if (mounted) setState(() => _hvConsumablesMasterList = list);
      } catch (_) {}
    }

    final formKey = GlobalKey<FormState>();
    final procNameCtrl = TextEditingController();
    final procChargeCtrl = TextEditingController(text: '0.00');

    // Dynamic list of consumables to attach
    final List<Map<String, dynamic>> itemsList = [];
    bool isSaving = false;

    void addConsumableRow(StateSetter setD) {
      setD(() {
        itemsList.add({
          'id': 'proc_row_${DateTime.now().microsecondsSinceEpoch}',
          'name_ctrl': TextEditingController(),
          'unit': 'Pc',
          'price_ctrl': TextEditingController(text: '0.00'),
          'qty_ctrl': TextEditingController(text: '1'),
        });
      });
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          final mediaQuery = MediaQuery.of(dialogCtx);
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 600,
                maxHeight: mediaQuery.size.height * (isMobile ? 0.9 : 0.85),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Dialog Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.medical_services_outlined,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add Procedure & Mapped Consumables',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // ── Dialog Body ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: Procedure Details
                            const Text(
                              'PROCEDURE DETAILS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Procedure Name ',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '*',
                                    style: TextStyle(
                                      color: AppTheme.logoRed,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: procNameCtrl,
                              maxLength: 150,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9\s\-\(\)]'),
                                ),
                              ],
                              decoration: AppTheme.standardInputDecoration(
                                label: null,
                                prefixIcon: Icons.healing_outlined,
                                hintText: 'e.g. Tracheostomy Care, Wound Dressing',
                              ).copyWith(counterText: ''),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Procedure name is required';
                                if (v.trim().length < 3)
                                  return 'Min 3 characters required';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Procedure Service Charge (₹) ',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '*',
                                    style: TextStyle(
                                      color: AppTheme.logoRed,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: procChargeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: AppTheme.standardInputDecoration(
                                label: null,
                                prefixIcon: Icons.currency_rupee,
                                hintText: '0.00',
                              ).copyWith(counterText: ''),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Procedure service charge is required';
                                }
                                final clean = v.trim();
                                if (clean.length > 10) {
                                  return 'Charge cannot exceed 10 characters';
                                }
                                final val = double.tryParse(clean);
                                if (val == null || val < 0) {
                                  return 'Enter a valid non-negative amount';
                                }
                                if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
                                  return 'Decimal value cannot exceed 2 decimal places';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Section 2: Consumables Mapped to Procedure
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'MAPPED CONSUMABLE ITEMS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => addConsumableRow(setD),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 16,
                                    color: AppTheme.secondaryColor,
                                  ),
                                  label: const Text(
                                    'Add Consumable',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Define items automatically required & deducted per procedure execution:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (itemsList.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'No consumables mapped yet. Click "Add Consumable" above to attach items.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: itemsList.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final row = entry.value;
                                  final rowId = row['id']?.toString() ?? 'row_$idx';
                                  final nameCtrl =
                                      row['name_ctrl'] as TextEditingController;
                                  final priceCtrl =
                                      row['price_ctrl'] as TextEditingController;
                                  final qtyCtrl =
                                      row['qty_ctrl'] as TextEditingController;

                                  return Container(
                                    key: ValueKey(rowId),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Item #${idx + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppTheme.textPrimaryColor,
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: AppTheme.logoRed,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                setD(() => itemsList.removeAt(idx));
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Consumable Item Name Dropdown / Searchable Input
                                        CustomDropdownSearch(
                                          key: ValueKey('name_$rowId'),
                                          label: 'Consumable Item',
                                          requiredMark: true,
                                          hint: 'Select or type consumable item name',
                                          value: nameCtrl.text.isEmpty
                                              ? null
                                              : nameCtrl.text,
                                          dropdownItems: _hvConsumablesMasterList
                                              .map((c) => c['name']?.toString() ?? '')
                                              .where((n) => n.isNotEmpty)
                                              .toSet()
                                              .toList(),
                                          allowFreeText: true,
                                          onChanged: (val) {
                                            if (val != null) {
                                              setD(() {
                                                nameCtrl.text = val;
                                                // Auto-fill unit & unit_price if item matches master list
                                                final matched =
                                                    _hvConsumablesMasterList
                                                        .firstWhere(
                                                          (c) =>
                                                              (c['name']
                                                                      ?.toString()
                                                                      .toLowerCase() ??
                                                                  '') ==
                                                              val.toLowerCase(),
                                                          orElse: () => {},
                                                        );
                                                if (matched.isNotEmpty) {
                                                  row['is_master'] = true;
                                                  row['unit'] =
                                                      matched['unit']?.toString() ??
                                                      'Pc';
                                                  priceCtrl.text =
                                                      (double.tryParse(
                                                                matched['unit_price']
                                                                        ?.toString() ??
                                                                    '0',
                                                              ) ??
                                                              0.0)
                                                          .toStringAsFixed(2);
                                                } else {
                                                  row['is_master'] = false;
                                                }
                                              });
                                            }
                                          },
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Consumable item name is required';
                                            }
                                            final clean = v.trim().toLowerCase();
                                            final duplicateCount = itemsList.where((r) {
                                              final ctrl = r['name_ctrl'] as TextEditingController;
                                              return ctrl.text.trim().toLowerCase() == clean;
                                            }).length;
                                            if (duplicateCount > 1) {
                                              return 'Duplicate consumable item in procedure';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            // Unit Dropdown
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Unit',
                                                    style: TextStyle(
                                                      fontFamily: 'Manrope',
                                                      color: Colors.grey.shade700,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  DropdownButtonFormField<String>(
                                                    value: (row['unit'] as String?) ?? 'Pc',
                                                    isExpanded: true,
                                                    decoration: AppTheme.standardInputDecoration(
                                                      label: null,
                                                    ).copyWith(
                                                      contentPadding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                      fillColor: row['is_master'] == true
                                                          ? const Color(0xFFF1F5F9)
                                                          : Colors.white,
                                                    ),
                                                    items: const [
                                                      'Pc',
                                                      'Pair',
                                                      'Pack',
                                                      'Roll',
                                                      'Vial',
                                                      'Box',
                                                      'Strip',
                                                      'ml',
                                                    ].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                                                    onChanged: row['is_master'] == true
                                                        ? null
                                                        : (newU) {
                                                            if (newU != null) {
                                                              setD(() => row['unit'] = newU);
                                                            }
                                                          },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Price
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Price (₹)',
                                                    style: TextStyle(
                                                      fontFamily: 'Manrope',
                                                      color: Colors.grey.shade700,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  MouseRegion(
                                                    cursor: row['is_master'] == true
                                                        ? SystemMouseCursors.forbidden
                                                        : SystemMouseCursors.text,
                                                    child: TextFormField(
                                                      controller: priceCtrl,
                                                      readOnly: row['is_master'] == true,
                                                      showCursor: row['is_master'] != true,
                                                      canRequestFocus: row['is_master'] != true,
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter.allow(
                                                          RegExp(r'^\d*\.?\d{0,2}'),
                                                        ),
                                                        LengthLimitingTextInputFormatter(10),
                                                      ],
                                                      decoration:
                                                          AppTheme.standardInputDecoration(
                                                            label: null,
                                                            prefixIcon:
                                                                Icons.currency_rupee,
                                                            suffixIcon: row['is_master'] == true
                                                                ? Tooltip(
                                                                    message:
                                                                        'Price locked to Master Catalog',
                                                                    child: Icon(
                                                                      Icons.lock_outline,
                                                                      size: 16,
                                                                      color: Colors.grey.shade600,
                                                                    ),
                                                                  )
                                                                : null,
                                                            hintText: row['is_master'] == true
                                                                ? 'Locked'
                                                                : 'Unit Price',
                                                          ).copyWith(
                                                            fillColor: row['is_master'] == true
                                                                ? const Color(0xFFF1F5F9)
                                                                : Colors.white,
                                                            counterText: '',
                                                          ),
                                                      validator: (v) {
                                                        if (v == null || v.trim().isEmpty) {
                                                          return 'Required';
                                                        }
                                                        final clean = v.trim();
                                                        if (clean.length > 10) {
                                                          return 'Max 10 chars';
                                                        }
                                                        final val = double.tryParse(clean);
                                                        if (val == null || val < 0) {
                                                          return 'Invalid';
                                                        }
                                                        if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
                                                          return 'Max 2 decimals';
                                                        }
                                                        return null;
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Qty per procedure
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Qty/Proc',
                                                    style: TextStyle(
                                                      fontFamily: 'Manrope',
                                                      color: Colors.grey.shade700,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  TextFormField(
                                                    controller: qtyCtrl,
                                                    keyboardType: TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.digitsOnly,
                                                      LengthLimitingTextInputFormatter(5),
                                                    ],
                                                    decoration:
                                                        AppTheme.standardInputDecoration(
                                                          label: null,
                                                          prefixIcon: Icons.numbers,
                                                          hintText: 'Qty',
                                                        ),
                                                    validator: (v) {
                                                      if (v == null || v.trim().isEmpty) {
                                                        return 'Required';
                                                      }
                                                      final val = int.tryParse(v.trim());
                                                      if (val == null || val <= 0) {
                                                        return '> 0';
                                                      }
                                                      if (v.trim().length > 5) {
                                                        return 'Max 5 digits';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Dialog Actions ──
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  final seenNames = <String>{};
                                  for (final row in itemsList) {
                                    final cName = (row['name_ctrl'] as TextEditingController)
                                        .text
                                        .trim()
                                        .toLowerCase();
                                    if (cName.isNotEmpty) {
                                      if (seenNames.contains(cName)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Duplicate consumable item "${(row['name_ctrl'] as TextEditingController).text.trim()}" in procedure mapping. Redundant items are not allowed.',
                                            ),
                                            backgroundColor: AppTheme.dangerColor,
                                          ),
                                        );
                                        return;
                                      }
                                      seenNames.add(cName);
                                    }
                                  }
                                  setD(() => isSaving = true);
                                  try {
                                    final mappedItems = itemsList.map((row) {
                                      return {
                                        'consumable_name':
                                            (row['name_ctrl'] as TextEditingController)
                                                .text
                                                .trim(),
                                        'unit': row['unit'],
                                        'unit_price':
                                            double.tryParse(
                                              (row['price_ctrl'] as TextEditingController)
                                                  .text
                                                  .trim(),
                                            ) ??
                                            0.0,
                                        'qty_per_procedure':
                                            int.tryParse(
                                              (row['qty_ctrl'] as TextEditingController)
                                                  .text
                                                  .trim(),
                                            ) ??
                                            1,
                                      };
                                    }).toList();

                                    await HomeVisitService().createProcedureMaster({
                                      'name': procNameCtrl.text.trim(),
                                      'procedure_charge':
                                          double.tryParse(procChargeCtrl.text.trim()) ??
                                          0.0,
                                      'items': mappedItems,
                                    });

                                    if (mounted) Navigator.pop(ctx, true);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Procedure and mapped consumables saved successfully',
                                          ),
                                          backgroundColor: Colors.green.shade600,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setD(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            e.toString().replaceFirst('Exception: ', ''),
                                          ),
                                          backgroundColor: AppTheme.dangerColor,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: AppTheme.primaryButton,
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Procedure'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == true) _loadHomeVisitConsumablesCatalog();
  }

  // Modal Dialog: Edit Procedure Master
  Future<void> _showEditProcedureDialog(
    ProcedureMasterModel proc,
    bool isMobile,
  ) async {
    final formKey = GlobalKey<FormState>();
    final procNameCtrl = TextEditingController(text: proc.name);
    procNameCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: procNameCtrl.text.length),
    );
    final procChargeCtrl = TextEditingController(
      text: proc.procedureCharge.toStringAsFixed(2),
    );
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Edit Procedure',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Procedure Name ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: AppTheme.logoRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: procNameCtrl,
                        keyboardType: TextInputType.text,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(80),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.medical_services_outlined,
                          hintText:
                              'e.g. Catheterization, Wound Dressing, IV Infusion',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Procedure name is required';
                          }
                          final clean = v.trim();
                          if (clean.length < 2) {
                            return 'Min 2 characters required';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                            return 'Must contain alphabetical characters';
                          }
                          final isDuplicate = _hvProceduresMaster.any(
                            (p) =>
                                p.id != proc.id &&
                                p.name.trim().toLowerCase() ==
                                    clean.toLowerCase(),
                          );
                          if (isDuplicate) {
                            return 'A procedure with this name already exists';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Procedure Service Charge (₹) ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: AppTheme.logoRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: procChargeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.currency_rupee,
                          hintText: '0.00',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Procedure service charge is required';
                          }
                          final clean = v.trim();
                          if (clean.length > 10) {
                            return 'Charge cannot exceed 10 characters';
                          }
                          final val = double.tryParse(clean);
                          if (val == null || val < 0) {
                            return 'Enter a valid non-negative amount';
                          }
                          if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
                            return 'Decimal value cannot exceed 2 decimal places';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          await HomeVisitService().updateProcedureMaster(
                            proc.id,
                            {
                              'name': procNameCtrl.text.trim(),
                              'procedure_charge':
                                  double.tryParse(
                                        procChargeCtrl.text.trim(),
                                      ) ??
                                      0.0,
                            },
                          );

                          if (mounted) Navigator.pop(ctx, true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Procedure "${procNameCtrl.text.trim()}" updated successfully',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },
                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update Procedure'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadHomeVisitConsumablesCatalog();
  }

  // Modal Dialog: Add Consumable Item to Existing Procedure
  Future<void> _showAddConsumableToProcedureDialog(
    ProcedureMasterModel proc,
    bool isMobile,
  ) async {
    if (_hvConsumablesMasterList.isEmpty) {
      try {
        final list = await HomeVisitService().fetchConsumablesMaster();
        if (mounted) setState(() => _hvConsumablesMasterList = list);
      } catch (_) {}
    }

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0.00');
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUnit = 'Pc';
    bool isMasterItem = false;
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart,
                    color: AppTheme.secondaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add Consumable to "${proc.name}"',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomDropdownSearch(
                        label: 'Consumable Item Name',
                        requiredMark: true,
                        hint: 'Select or type consumable item name',
                        value: nameCtrl.text.isEmpty ? null : nameCtrl.text,
                        dropdownItems: _hvConsumablesMasterList
                            .map((c) => c['name']?.toString() ?? '')
                            .where((n) => n.isNotEmpty)
                            .toSet()
                            .toList(),
                        allowFreeText: true,
                        onChanged: (val) {
                          if (val != null) {
                            setD(() {
                              nameCtrl.text = val;
                              final matched = _hvConsumablesMasterList
                                  .firstWhere(
                                    (c) =>
                                        (c['name']?.toString().toLowerCase() ??
                                            '') ==
                                        val.toLowerCase(),
                                    orElse: () => {},
                                  );
                              if (matched.isNotEmpty) {
                                isMasterItem = true;
                                selectedUnit =
                                    matched['unit']?.toString() ?? 'Pc';
                                priceCtrl.text =
                                    (double.tryParse(
                                              matched['unit_price']
                                                      ?.toString() ??
                                                  '0',
                                            ) ??
                                            0.0)
                                        .toStringAsFixed(2);
                              } else {
                                isMasterItem = false;
                              }
                            });
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Consumable item name is required';
                          }
                          final clean = v.trim().toLowerCase();
                          final alreadyMapped = proc.mappedConsumables.any(
                            (c) => c.consumableName.trim().toLowerCase() == clean,
                          );
                          if (alreadyMapped) {
                            return 'Item is already mapped to this procedure';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: CustomDropdownSearch(
                              label: 'Unit',
                              requiredMark: true,
                              hint: 'Select Unit',
                              value: selectedUnit,
                              isEnabled: !isMasterItem,
                              dropdownItems: const [
                                'Pc',
                                'Pair',
                                'Pack',
                                'Roll',
                                'Vial',
                                'Box',
                                'Strip',
                                'ml',
                              ],
                              onChanged: (v) {
                                if (v != null) setD(() => selectedUnit = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Unit Price (₹) ',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '*',
                                        style: TextStyle(
                                          color: AppTheme.logoRed,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                MouseRegion(
                                  cursor: isMasterItem
                                      ? SystemMouseCursors.forbidden
                                      : SystemMouseCursors.text,
                                  child: TextFormField(
                                    controller: priceCtrl,
                                    readOnly: isMasterItem,
                                    showCursor: !isMasterItem,
                                    canRequestFocus: !isMasterItem,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}'),
                                      ),
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: AppTheme.standardInputDecoration(
                                      label: null,
                                      prefixIcon: Icons.currency_rupee,
                                      suffixIcon: isMasterItem
                                          ? Tooltip(
                                              message:
                                                  'Price locked to Master Catalog',
                                              child: Icon(
                                                Icons.lock_outline,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            )
                                          : null,
                                      hintText: isMasterItem ? 'Locked' : '0.00',
                                    ).copyWith(
                                      fillColor: isMasterItem
                                          ? const Color(0xFFF1F5F9)
                                          : Colors.white,
                                      counterText: '',
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Unit price is required';
                                      }
                                      final clean = v.trim();
                                      if (clean.length > 10) {
                                        return 'Price cannot exceed 10 characters';
                                      }
                                      final val = double.tryParse(clean);
                                      if (val == null || val < 0) {
                                        return 'Enter a valid non-negative amount';
                                      }
                                      if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
                                        return 'Decimal value cannot exceed 2 decimal places';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Quantity per Procedure Execution ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: AppTheme.logoRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.numbers,
                          hintText: 'e.g. 1',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Quantity is required';
                          }
                          final val = int.tryParse(v.trim());
                          if (val == null || val <= 0) {
                            return 'Quantity must be greater than 0';
                          }
                          if (v.trim().length > 5) {
                            return 'Max 5 digits';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          await HomeVisitService().addConsumableToProcedure(
                            proc.id,
                            {
                              'consumable_name': nameCtrl.text.trim(),
                              'unit': selectedUnit,
                              'unit_price':
                                  double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                              'qty_per_procedure':
                                  int.tryParse(qtyCtrl.text.trim()) ?? 1,
                            },
                          );

                          if (mounted) Navigator.pop(ctx, true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Consumable mapped to "${proc.name}" successfully',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },
                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Map Consumable'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadHomeVisitConsumablesCatalog();
  }

  // Deactivate Procedure Master
  Future<void> _deleteProcedureMaster(ProcedureMasterModel proc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Deactivate Procedure',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to deactivate '),
              TextSpan(
                text: '"${proc.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '? It will no longer be selectable during home visits.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.dangerButton,
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await HomeVisitService().deleteProcedureMaster(proc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Procedure "${proc.name}" deactivated'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _loadHomeVisitConsumablesCatalog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  // Remove Consumable Mapping from Procedure
  Future<void> _removeConsumableMapping(
    ProcedureMasterModel proc,
    ProcedureConsumableMappingModel item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Remove Consumable Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Remove '),
              TextSpan(
                text: '"${item.consumableName}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ' from procedure "${proc.name}"?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.dangerButton,
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await HomeVisitService().removeConsumableMapping(
        proc.id,
        item.consumableId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${item.consumableName}" removed from "${proc.name}"',
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _loadHomeVisitConsumablesCatalog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  // Modal Dialog: Add Standalone Consumable Item Master Directly
  Future<void> _showAddStandaloneConsumableDialog(bool isMobile) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0.00');
    String selectedUnit = 'Pc';
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.secondaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Standalone Consumable Item',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Consumable Item Name ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: AppTheme.logoRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        maxLength: 150,
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.home_repair_service_outlined,
                          hintText:
                              'e.g. Disposable Diaper L, Sterile Gauze Pack',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Consumable item name is required';
                          }
                          if (v.trim().length < 2) {
                            return 'Min 2 characters required';
                          }
                          final clean = v.trim().toLowerCase();
                          final alreadyExists = _hvConsumablesMasterList.any(
                            (c) =>
                                (c['name']?.toString().trim().toLowerCase() ??
                                    '') ==
                                clean,
                          );
                          if (alreadyExists) {
                            return 'Consumable item already exists in catalog';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: CustomDropdownSearch(
                              label: 'Unit',
                              requiredMark: true,
                              hint: 'Select Unit',
                              value: selectedUnit,
                              dropdownItems: const [
                                'Pc',
                                'Pair',
                                'Pack',
                                'Roll',
                                'Vial',
                                'Box',
                                'Strip',
                                'ml',
                              ],
                              onChanged: (v) {
                                if (v != null) setD(() => selectedUnit = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Unit Price (₹) ',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '*',
                                        style: TextStyle(
                                          color: AppTheme.logoRed,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                 TextFormField(
                                   controller: priceCtrl,
                                   keyboardType:
                                       const TextInputType.numberWithOptions(
                                         decimal: true,
                                       ),
                                   inputFormatters: [
                                     FilteringTextInputFormatter.allow(
                                       RegExp(r'^\d*\.?\d{0,2}'),
                                     ),
                                     LengthLimitingTextInputFormatter(10),
                                   ],
                                   decoration: AppTheme.standardInputDecoration(
                                     label: null,
                                     prefixIcon: Icons.currency_rupee,
                                     hintText: '0.00',
                                   ).copyWith(counterText: ''),
                                   validator: (v) {
                                     if (v == null || v.trim().isEmpty) {
                                       return 'Unit price is required';
                                     }
                                     final clean = v.trim();
                                     if (clean.length > 10) {
                                       return 'Price cannot exceed 10 characters';
                                     }
                                     final val = double.tryParse(clean);
                                     if (val == null || val < 0) {
                                       return 'Enter a valid non-negative amount';
                                     }
                                     if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
                                       return 'Decimal value cannot exceed 2 decimal places';
                                     }
                                     return null;
                                   },
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                      ],
                    ),
                  ),
                ),
              ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          await HomeVisitService().createConsumableMaster({
                            'name': nameCtrl.text.trim(),
                            'unit': selectedUnit,
                            'unit_price':
                                double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                          });

                          if (mounted) Navigator.pop(ctx, true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Consumable "${nameCtrl.text.trim()}" saved successfully',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },
                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Consumable'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadHomeVisitConsumablesCatalog();
  }


  // Modal Dialog: Edit Standalone Consumable Item
  Future<void> _showEditStandaloneConsumableDialog(
    Map<String, dynamic> item,
    bool isMobile,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: item['name']?.toString() ?? '');
    nameCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: nameCtrl.text.length),
    );
    final priceCtrl = TextEditingController(
      text: (double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0)
          .toStringAsFixed(2),
    );
    String selectedUnit = item['unit']?.toString() ?? 'Pc';
    final itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Edit Consumable Item',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Consumable Item Name ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: AppTheme.logoRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        keyboardType: TextInputType.text,
                        autofocus: true,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(150),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.home_repair_service_outlined,
                          hintText:
                              'e.g. Disposable Diaper L, Sterile Gauze Pack',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Consumable item name is required';
                          }
                          if (v.trim().length < 2) {
                            return 'Min 2 characters required';
                          }
                          final clean = v.trim().toLowerCase();
                          final alreadyExists = _hvConsumablesMasterList.any(
                            (c) =>
                                (int.tryParse(c['id']?.toString() ?? '0') ??
                                        0) !=
                                    itemId &&
                                (c['name']?.toString().trim().toLowerCase() ??
                                        '') ==
                                    clean,
                          );
                          if (alreadyExists) {
                            return 'Consumable item already exists in catalog';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: CustomDropdownSearch(
                              label: 'Unit',
                              requiredMark: true,
                              hint: 'Select Unit',
                              value: selectedUnit,
                              dropdownItems: const [
                                'Pc',
                                'Pair',
                                'Pack',
                                'Roll',
                                'Vial',
                                'Box',
                                'Strip',
                                'ml',
                              ],
                              onChanged: (v) {
                                if (v != null) setD(() => selectedUnit = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Unit Price (₹) ',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '*',
                                        style: TextStyle(
                                          color: AppTheme.logoRed,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    label: null,
                                    prefixIcon: Icons.currency_rupee,
                                    hintText: '0.00',
                                  ).copyWith(counterText: ''),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Unit price is required';
                                    }
                                    final clean = v.trim();
                                    if (clean.length > 10) {
                                      return 'Price cannot exceed 10 characters';
                                    }
                                    final val = double.tryParse(clean);
                                    if (val == null || val < 0) {
                                      return 'Enter a valid non-negative amount';
                                    }
                                    if (!RegExp(r'^\d+(\.\d{1,2})?$')
                                        .hasMatch(clean)) {
                                      return 'Decimal value cannot exceed 2 decimal places';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          await HomeVisitService().updateConsumableMaster(
                            itemId,
                            {
                              'name': nameCtrl.text.trim(),
                              'unit': selectedUnit,
                              'unit_price':
                                  double.tryParse(priceCtrl.text.trim()) ??
                                      0.0,
                            },
                          );

                          if (mounted) Navigator.pop(ctx, true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Consumable "${nameCtrl.text.trim()}" updated successfully',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },
                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update Consumable'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadHomeVisitConsumablesCatalog();
  }

  // Deactivate Standalone Consumable Item
  Future<void> _deleteConsumableMaster(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'this consumable';
    final itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Deactivate Consumable Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to deactivate '),
              TextSpan(
                text: '"$name"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    '? It will no longer appear in the active master catalog or be selectable for procedures.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: AppTheme.cancelButton,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.dangerButton,
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await HomeVisitService().deleteConsumableMaster(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Consumable "$name" deactivated'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _loadHomeVisitConsumablesCatalog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Widget _buildHomeVisitConsumablesCatalog(bool isMobile) {
    if (_hvProceduresMaster.isEmpty &&
        !_isHVConsumableLoading &&
        _hvConsumableError == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadHomeVisitConsumablesCatalog(),
      );
    }

    final query = _hvConsumableSearch.trim().toLowerCase();
    final filteredProcedures = query.isEmpty
        ? _hvProceduresMaster
        : _hvProceduresMaster.where((p) {
            final procMatch = p.name.toLowerCase().contains(query);
            final itemMatch = p.mappedConsumables.any(
              (c) => c.consumableName.toLowerCase().contains(query),
            );
            return procMatch || itemMatch;
          }).toList();

    final filteredConsumables = query.isEmpty
        ? _hvConsumablesMasterList
        : _hvConsumablesMasterList.where((item) {
            final nameMatch = (item['name']?.toString() ?? '')
                .toLowerCase()
                .contains(query);
            final unitMatch = (item['unit']?.toString() ?? '')
                .toLowerCase()
                .contains(query);
            return nameMatch || unitMatch;
          }).toList();

    int totalMappingsCount = 0;
    for (var p in _hvProceduresMaster) {
      totalMappingsCount += p.mappedConsumables.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar
        Container(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 16 : 20,
            isMobile ? 16 : 24,
            16,
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHVConsumablesHeaderTitle(),
                    const SizedBox(height: 12),
                    _buildHVConsumablesSearchBar(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showAddProcedureDialog(isMobile),
                              style: AppTheme.primaryButton.copyWith(
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Add Procedure',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showAddStandaloneConsumableDialog(isMobile),
                              style: AppTheme.outlinedButton.copyWith(
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                size: 16,
                                color: AppTheme.secondaryColor,
                              ),
                              label: const Text(
                                'Add Consumable',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _buildHVConsumablesHeaderTitle(),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          child: _buildHVConsumablesSearchBar(),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProcedureDialog(isMobile),
                          style: AppTheme.primaryButton,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Procedure'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showAddStandaloneConsumableDialog(isMobile),
                          style: AppTheme.outlinedButton,
                          icon: const Icon(
                            Icons.add_shopping_cart,
                            size: 18,
                            color: AppTheme.secondaryColor,
                          ),
                          label: const Text(
                            'Add Consumable',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        // Stats Row (Horizontal scrollable on mobile)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMedStatChip(
                  Icons.medical_services_outlined,
                  AppTheme.primaryColor,
                  'Total Procedures',
                  '${_hvProceduresMaster.length}',
                ),
                const SizedBox(width: 10),
                _buildMedStatChip(
                  Icons.home_repair_service_outlined,
                  AppTheme.secondaryColor,
                  'Master Consumable Items',
                  '${_hvConsumablesMasterList.length}',
                ),
                const SizedBox(width: 10),
                _buildMedStatChip(
                  Icons.alt_route_outlined,
                  const Color(0xFF8B5CF6),
                  'Active Item Mappings',
                  '$totalMappingsCount',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Sub-Tab Switcher Row (Segmented on mobile, Chips on desktop)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          child: isMobile
              ? Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(() => _hvCatalogSelectedTab = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _hvCatalogSelectedTab == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _hvCatalogSelectedTab == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    size: 15,
                                    color: _hvCatalogSelectedTab == 0
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Procedures (${_hvProceduresMaster.length})',
                                    style: TextStyle(
                                      color: _hvCatalogSelectedTab == 0
                                          ? AppTheme.primaryColor
                                          : AppTheme.textSecondaryColor,
                                      fontWeight: _hvCatalogSelectedTab == 0
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(() => _hvCatalogSelectedTab = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _hvCatalogSelectedTab == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: _hvCatalogSelectedTab == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 15,
                                    color: _hvCatalogSelectedTab == 1
                                        ? AppTheme.secondaryColor
                                        : AppTheme.textSecondaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Consumables (${_hvConsumablesMasterList.length})',
                                    style: TextStyle(
                                      color: _hvCatalogSelectedTab == 1
                                          ? AppTheme.secondaryColor
                                          : AppTheme.textSecondaryColor,
                                      fontWeight: _hvCatalogSelectedTab == 1
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        'Procedures Catalog (${_hvProceduresMaster.length})',
                      ),
                      selected: _hvCatalogSelectedTab == 0,
                      onSelected: (val) {
                        if (val) setState(() => _hvCatalogSelectedTab = 0);
                      },
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _hvCatalogSelectedTab == 0
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondaryColor,
                        fontWeight: _hvCatalogSelectedTab == 0
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        'Master Consumable Items (${_hvConsumablesMasterList.length})',
                      ),
                      selected: _hvCatalogSelectedTab == 1,
                      onSelected: (val) {
                        if (val) setState(() => _hvCatalogSelectedTab = 1);
                      },
                      selectedColor:
                          AppTheme.secondaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _hvCatalogSelectedTab == 1
                            ? AppTheme.secondaryColor
                            : AppTheme.textSecondaryColor,
                        fontWeight: _hvCatalogSelectedTab == 1
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),

        // Catalog Content View
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: _isHVConsumableLoading
                ? const Center(child: CircularProgressIndicator())
                : _hvConsumableError != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppTheme.dangerColor.withOpacity(0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _hvConsumableError!,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadHomeVisitConsumablesCatalog,
                          style: AppTheme.primaryButton,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _hvCatalogSelectedTab == 0
                ? (filteredProcedures.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medical_services_outlined,
                                size: 56,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _hvConsumableSearch.isNotEmpty
                                    ? 'No procedures match "$_hvConsumableSearch"'
                                    : 'No Home Visit procedures registered yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Click "Add Procedure & Consumables" to create your first procedure master',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildProceduresCatalogList(
                          filteredProcedures,
                          isMobile,
                        ))
                : _buildMasterConsumablesList(filteredConsumables, isMobile),
          ),
        ),
      ],
    );
  }

  Widget _buildMasterConsumablesList(
    List<Map<String, dynamic>> items,
    bool isMobile,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _hvConsumableSearch.isNotEmpty
                  ? 'No consumable items match "$_hvConsumableSearch"'
                  : 'No master consumable items registered yet',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click "Add Consumable Item" to register new items',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          final price =
              double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Unit: ${item['unit']?.toString() ?? 'Pc'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '₹${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['status']?.toString() ?? 'Active',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      tooltip: 'Edit Consumable',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => _showEditStandaloneConsumableDialog(
                        item,
                        isMobile,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppTheme.dangerColor,
                      ),
                      tooltip: 'Deactivate Consumable',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => _deleteConsumableMaster(item),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableMinWidth = constraints.maxWidth > 650 ? constraints.maxWidth : 650.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: tableMinWidth,
              maxWidth: tableMinWidth,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              '#',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Consumable Item Name',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Unit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Unit Price (₹)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Actions',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppTheme.borderColor),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          final price =
                              double.tryParse(item['unit_price']?.toString() ?? '0') ??
                              0.0;
                          return Container(
                            color: i.isEven ? Colors.white : const Color(0xFFFAFBFC),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item['name']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item['unit']?.toString() ?? 'Pc',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '₹${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item['status']?.toString() ?? 'Active',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.secondaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: AppTheme.primaryColor,
                                        ),
                                        tooltip: 'Edit Consumable',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _showEditStandaloneConsumableDialog(
                                              item,
                                              isMobile,
                                            ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: AppTheme.dangerColor,
                                        ),
                                        tooltip: 'Deactivate Consumable',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _deleteConsumableMaster(item),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Modal Dialog: Add Carried Kit Item / Equipment Master
  Future<void> _showAddCarriedKitItemDialog(bool isMobile) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'Device';
    bool isSaving = false;

    final availableItemTypes = const [
      'Device',
      'Equipment',
      'Kit',
      'Monitoring Tool',
      'Accessories',
    ];

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Carried Kit Item / Equipment',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 460,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Kit Item Name ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: AppTheme.logoRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(80),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.medical_information_outlined,
                          hintText:
                              'e.g. BP Apparatus Digital, Portable Oxygen Cylinder',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Kit item name is required';
                          }
                          final clean = v.trim();
                          if (clean.length < 2) {
                            return 'Min 2 characters required';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                            return 'Must contain alphabetical characters';
                          }
                          final isDuplicate = _hvKitItemsMasterList.any(
                            (item) =>
                                (item['name']?.toString().trim().toLowerCase() ?? '') ==
                                clean.toLowerCase(),
                          );
                          if (isDuplicate) {
                            return 'A kit item with this name already exists in the catalog';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      CustomDropdownSearch(
                        label: 'Item Type',
                        requiredMark: true,
                        hint: 'Select Item Type',
                        value: selectedType,
                        dropdownItems: availableItemTypes,
                        onChanged: (v) {
                          if (v != null) setD(() => selectedType = v);
                        },
                        validator: (v) =>
                            v == null ||
                            v.isEmpty ||
                            !availableItemTypes.contains(v)
                            ? 'Please select a valid item type'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Description / Specifications',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(100),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.notes_outlined,
                          hintText:
                              'e.g. Digital blood pressure monitor with cuff for adult home visits...',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final clean = v.trim();
                            if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                              return 'Description must contain alphabetical characters';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          await HomeVisitService().createKitItemMaster({
                            'name': nameCtrl.text.trim(),
                            'item_type': selectedType,
                            'description': descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                          });

                          if (mounted) Navigator.pop(ctx, true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Carried Kit Item "${nameCtrl.text.trim()}" saved successfully',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },
                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Kit Item'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadHomeVisitKitItemsCatalog();
  }

  // Modal Dialog: Edit Carried Kit Item & Equipment
  Future<void> _showEditStandaloneKitItemDialog(
    Map<String, dynamic> item,
    bool isMobile,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: item['name']?.toString() ?? '');
    final descCtrl = TextEditingController(
      text: item['description']?.toString() ?? '',
    );
    String selectedType = item['item_type']?.toString() ?? 'Device';
    bool isSaving = false;

    final availableItemTypes = [
      'Device',
      'Equipment',
      'Diagnostic',
      'Emergency Tool',
      'Accessory',
      'Other',
    ];
    if (!availableItemTypes.contains(selectedType)) {
      availableItemTypes.add(selectedType);
    }

    final itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Edit Carried Kit Item',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.infinity : 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Kit Item Name ',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: '*',
                              style: TextStyle(
                                color: AppTheme.logoRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(80),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.medical_information_outlined,
                          hintText:
                              'e.g. BP Apparatus Digital, Portable Oxygen Cylinder',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Kit item name is required';
                          }
                          final clean = v.trim();
                          if (clean.length < 2) {
                            return 'Min 2 characters required';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                            return 'Must contain alphabetical characters';
                          }
                          final isDuplicate = _hvKitItemsMasterList.any(
                            (it) =>
                                (it['id']?.toString() != item['id']?.toString()) &&
                                ((it['name']?.toString().trim().toLowerCase() ??
                                        '') ==
                                    clean.toLowerCase()),
                          );
                          if (isDuplicate) {
                            return 'A kit item with this name already exists in the catalog';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      CustomDropdownSearch(
                        label: 'Item Type',
                        requiredMark: true,
                        hint: 'Select Item Type',
                        value: selectedType,
                        dropdownItems: availableItemTypes,
                        onChanged: (v) {
                          if (v != null) setD(() => selectedType = v);
                        },
                        validator: (v) =>
                            v == null ||
                            v.isEmpty ||
                            !availableItemTypes.contains(v)
                            ? 'Please select a valid item type'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Description / Specifications',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(100),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          label: null,
                          prefixIcon: Icons.notes_outlined,
                          hintText:
                              'e.g. Digital blood pressure monitor with cuff for adult home visits...',
                        ).copyWith(counterText: ''),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final clean = v.trim();
                            if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                              return 'Description must contain alphabetical characters';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setD(() => isSaving = true);
                        try {
                          await HomeVisitService().updateKitItemMaster(itemId, {
                            'name': nameCtrl.text.trim(),
                            'item_type': selectedType,
                            'description': descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                          });

                          if (mounted) Navigator.pop(ctx, true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Carried Kit Item "${nameCtrl.text.trim()}" updated successfully',
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } catch (e) {
                          setD(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppTheme.dangerColor,
                              ),
                            );
                          }
                        }
                      },
                style: AppTheme.primaryButton,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) _loadHomeVisitKitItemsCatalog();
  }

  Widget _buildCarriedKitItemsCatalog(bool isMobile) {
    if (_hvKitItemsMasterList.isEmpty &&
        !_isHVKitItemsLoading &&
        _hvKitItemsError == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadHomeVisitKitItemsCatalog(),
      );
    }

    final query = _hvKitItemsSearch.trim().toLowerCase();
    final filteredItems = _hvKitItemsMasterList.where((item) {
      final nameMatch = (item['name']?.toString() ?? '')
          .toLowerCase()
          .contains(query);
      final typeMatch = (item['item_type']?.toString() ?? '')
          .toLowerCase()
          .contains(query);
      final descMatch = (item['description']?.toString() ?? '')
          .toLowerCase()
          .contains(query);
      final matchesSearch = query.isEmpty || nameMatch || typeMatch || descMatch;

      final type = item['item_type']?.toString() ?? '';
      final matchesCategory = () {
        if (_selectedHVCatalogCategoryFilter == 'Total Master Items') return true;
        if (_selectedHVCatalogCategoryFilter == 'Medical Devices') {
          return type == 'Device' || type == 'Medical Devices';
        }
        if (_selectedHVCatalogCategoryFilter == 'Equipment') {
          return type == 'Equipment';
        }
        if (_selectedHVCatalogCategoryFilter == 'Kits & Accessories') {
          return type != 'Device' && type != 'Equipment' && type != 'Medical Devices';
        }
        return true;
      }();

      return matchesSearch && matchesCategory;
    }).toList();

    int deviceCount = 0;
    int equipmentCount = 0;
    int kitCount = 0;
    for (var item in _hvKitItemsMasterList) {
      final type = item['item_type']?.toString() ?? '';
      if (type == 'Device' || type == 'Medical Devices') {
        deviceCount++;
      } else if (type == 'Equipment') {
        equipmentCount++;
      } else {
        kitCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar
        Container(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 16 : 20,
            isMobile ? 16 : 24,
            16,
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.inventory_outlined,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Carried Kit Items & Equipment Catalog',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage standard devices, medical equipment, and kits carried by nurses during home visits',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hvKitItemsSearchController,
                      decoration:
                          AppTheme.standardInputDecoration(
                            label: null,
                            prefixIcon: Icons.search,
                            hintText: 'Search kit items or equipment...',
                          ).copyWith(
                            suffixIcon: _hvKitItemsSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _hvKitItemsSearchController.clear();
                                      setState(() => _hvKitItemsSearch = '');
                                      _loadHomeVisitKitItemsCatalog();
                                    },
                                  )
                                : null,
                          ),
                      onChanged: (v) => setState(() => _hvKitItemsSearch = v),
                      onSubmitted: (_) => _loadHomeVisitKitItemsCatalog(),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddCarriedKitItemDialog(isMobile),
                        style: AppTheme.primaryButton,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Carried Kit Item'),
                      ),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.inventory_outlined,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Carried Kit Items & Equipment Catalog',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Manage standard devices, medical equipment, and kits carried by nurses during home visits',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: _hvKitItemsSearchController,
                            decoration:
                                AppTheme.standardInputDecoration(
                                  label: null,
                                  prefixIcon: Icons.search,
                                  hintText: 'Search kit items or equipment...',
                                ).copyWith(
                                  suffixIcon: _hvKitItemsSearch.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _hvKitItemsSearchController.clear();
                                            setState(() => _hvKitItemsSearch = '');
                                            _loadHomeVisitKitItemsCatalog();
                                          },
                                        )
                                      : null,
                                ),
                            onChanged: (v) => setState(() => _hvKitItemsSearch = v),
                            onSubmitted: (_) => _loadHomeVisitKitItemsCatalog(),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showAddCarriedKitItemDialog(isMobile),
                          style: AppTheme.primaryButton,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Carried Kit Item'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        // Summary Stats Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHVCatalogStatChip(
                Icons.inventory_outlined,
                AppTheme.primaryColor,
                'Total Master Items',
                '${_hvKitItemsMasterList.length}',
              ),
              _buildHVCatalogStatChip(
                Icons.medical_information_outlined,
                AppTheme.secondaryColor,
                'Medical Devices',
                '$deviceCount',
              ),
              _buildHVCatalogStatChip(
                Icons.precision_manufacturing_outlined,
                const Color(0xFF8B5CF6),
                'Equipment',
                '$equipmentCount',
              ),
              _buildHVCatalogStatChip(
                Icons.home_repair_service_outlined,
                const Color(0xFFE53E3E),
                'Kits & Accessories',
                '$kitCount',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Catalog List View
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: _isHVKitItemsLoading
                ? const Center(child: CircularProgressIndicator())
                : _hvKitItemsError != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppTheme.dangerColor.withOpacity(0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _hvKitItemsError!,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadHomeVisitKitItemsCatalog,
                          style: AppTheme.primaryButton,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_outlined,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _hvKitItemsSearch.isNotEmpty
                              ? 'No kit items match "$_hvKitItemsSearch"'
                              : 'No master carried kit items registered yet',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Click "Add Carried Kit Item" to add devices or equipment to the catalog',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : isMobile
                    ? ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemCount: filteredItems.length,
                        itemBuilder: (ctx, i) {
                          final item = filteredItems[i];
                          final itemId =
                              int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                          final typeStr =
                              item['item_type']?.toString() ?? 'Device';
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              typeStr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if ((item['description']
                                                      ?.toString() ??
                                                  '')
                                              .isNotEmpty)
                                            Text(
                                              item['description']?.toString() ??
                                                  '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppTheme.textSecondaryColor,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.logoRed,
                                  ),
                                  tooltip: 'Remove',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text(
                                          'Deactivate Kit Item',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 400,
                                          ),
                                          child: Text(
                                            'Are you sure you want to deactivate "${item['name']}"?',
                                            softWrap: true,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            style: AppTheme.dangerButton,
                                            child: const Text('Deactivate'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && itemId > 0) {
                                      try {
                                        await HomeVisitService()
                                            .deleteKitItemMaster(itemId);
                                        _loadHomeVisitKitItemsCatalog();
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                              backgroundColor:
                                                  AppTheme.dangerColor,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppTheme.borderColor),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  border: Border(
                                    bottom: BorderSide(color: AppTheme.borderColor),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '#',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Kit Item Name',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Type',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Description / Specs',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Actions',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    color: AppTheme.borderColor,
                                  ),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (ctx, i) {
                                    final item = filteredItems[i];
                                    final itemId =
                                        int.tryParse(
                                          item['id']?.toString() ?? '0',
                                        ) ??
                                        0;
                                    final typeStr =
                                        item['item_type']?.toString() ?? 'Device';
                                    return Container(
                                      color: i.isEven
                                          ? Colors.white
                                          : const Color(0xFFFAFBFC),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              item['name']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: AppTheme.textPrimaryColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              typeStr,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              item['description']?.toString() ??
                                                  '--',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondaryColor,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton.icon(
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (c) => AlertDialog(
                                                          title: const Text(
                                                            'Deactivate Kit Item',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          content: ConstrainedBox(
                                                            constraints: const BoxConstraints(
                                                              maxWidth: 400,
                                                            ),
                                                            child: Text(
                                                              'Are you sure you want to deactivate "${item['name']}"?',
                                                              softWrap: true,
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    c,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    c,
                                                                    true,
                                                                  ),
                                                              style: AppTheme
                                                                  .dangerButton,
                                                              child: const Text(
                                                                'Deactivate',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                  if (confirm == true &&
                                                      itemId > 0) {
                                                    try {
                                                      await HomeVisitService()
                                                          .deleteKitItemMaster(
                                                            itemId,
                                                          );
                                                      _loadHomeVisitKitItemsCatalog();
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              e.toString(),
                                                            ),
                                                            backgroundColor:
                                                                AppTheme
                                                                    .dangerColor,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 16,
                                                  color: AppTheme.logoRed,
                                                ),
                                                label: const Text(
                                                  'Remove',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.logoRed,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildHVCatalogStatChip(
    IconData icon,
    Color color,
    String label,
    String count,
  ) {
    final isSelected = _selectedHVCatalogCategoryFilter == label;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _selectedHVCatalogCategoryFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHVConsumablesHeaderTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Home Visit Procedures & Consumables Catalog',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage procedures, service charges, and consumable items mapped under each procedure',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
        ),
      ],
    );
  }

  Widget _buildHVConsumablesSearchBar() {
    return TextField(
      controller: _hvSearchController,
      decoration:
          AppTheme.standardInputDecoration(
            label: null,
            prefixIcon: Icons.search,
            hintText: 'Search procedure or consumable item...',
          ).copyWith(
            suffixIcon: _hvConsumableSearch.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _hvSearchController.clear();
                      setState(() => _hvConsumableSearch = '');
                      _loadHomeVisitConsumablesCatalog();
                    },
                  )
                : null,
          ),
      onChanged: (v) {
        setState(() => _hvConsumableSearch = v);
      },
      onSubmitted: (_) => _loadHomeVisitConsumablesCatalog(),
    );
  }

  Widget _buildProceduresCatalogList(
    List<ProcedureMasterModel> procedures,
    bool isMobile,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemCount: procedures.length,
      itemBuilder: (ctx, i) {
        final proc = procedures[i];
        final isExpanded = _expandedProcedureIds.contains(proc.id);
        double totalConsumablesCost = 0.0;
        for (var item in proc.mappedConsumables) {
          totalConsumablesCost += (item.unitPrice * item.qtyPerProcedure);
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Procedure Card Header
              InkWell(
                borderRadius: !isExpanded
                    ? BorderRadius.circular(14)
                    : const BorderRadius.vertical(top: Radius.circular(14)),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedProcedureIds.remove(proc.id);
                    } else {
                      _expandedProcedureIds.add(proc.id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: !isExpanded
                        ? BorderRadius.circular(14)
                        : const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                    border: !isExpanded
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppTheme.borderColor),
                          ),
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.healing_outlined,
                                    color: AppTheme.primaryColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    proc.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    size: 24,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  tooltip: isExpanded
                                      ? 'Minimize / Collapse'
                                      : 'Expand Mapped Consumables',
                                  onPressed: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedProcedureIds.remove(proc.id);
                                      } else {
                                        _expandedProcedureIds.add(proc.id);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${proc.status}  •  ${proc.mappedConsumables.length} mapped consumable items',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Charge: ₹${proc.procedureCharge.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                ),
                                if (proc.mappedConsumables.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Total Est: ₹${(proc.procedureCharge + totalConsumablesCost).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      tooltip: 'Edit Procedure',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () => _showEditProcedureDialog(
                                        proc,
                                        isMobile,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_shopping_cart,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      tooltip: 'Map Consumable Item',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () =>
                                          _showAddConsumableToProcedureDialog(
                                            proc,
                                            isMobile,
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppTheme.dangerColor,
                                      ),
                                      tooltip: 'Deactivate Procedure',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: () =>
                                          _deleteProcedureMaster(proc),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.healing_outlined,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          proc.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppTheme.textPrimaryColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Status: ${proc.status}  •  ${proc.mappedConsumables.length} mapped consumable items',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Charge Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.secondaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Charge: ₹${proc.procedureCharge.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                            ),
                            if (proc.mappedConsumables.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Total Est: ₹${(proc.procedureCharge + totalConsumablesCost).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            // Action Buttons
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                              tooltip: 'Edit Procedure',
                              onPressed: () =>
                                  _showEditProcedureDialog(proc, isMobile),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                              tooltip: 'Map Consumable Item',
                              onPressed: () =>
                                  _showAddConsumableToProcedureDialog(
                                    proc,
                                    isMobile,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppTheme.dangerColor,
                              ),
                              tooltip: 'Deactivate Procedure',
                              onPressed: () => _deleteProcedureMaster(proc),
                            ),
                            // Minimize / Expand Toggle Icon
                            IconButton(
                              icon: Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 24,
                                color: AppTheme.textSecondaryColor,
                              ),
                              tooltip: isExpanded
                                  ? 'Minimize / Collapse'
                                  : 'Expand Mapped Consumables',
                              onPressed: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedProcedureIds.remove(proc.id);
                                  } else {
                                    _expandedProcedureIds.add(proc.id);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                ),
              ),

              // Procedure Mapped Consumables List (Shown only when isExpanded)
              if (isExpanded) ...[
                if (proc.mappedConsumables.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No consumable items mapped under this procedure.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showAddConsumableToProcedureDialog(proc, isMobile),
                          icon: const Icon(
                            Icons.add,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          label: const Text(
                            'Add Consumable',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'MAPPED CONSUMABLES (AUTO-DEDUCTED):',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 550),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(9),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Item Name',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Unit Price',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Qty / Procedure',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Total Item Cost',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 36),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      for (int cIdx = 0;
                                          cIdx < proc.mappedConsumables.length;
                                          cIdx++) ...[
                                        if (cIdx > 0)
                                          const Divider(
                                            height: 1,
                                            color: AppTheme.borderColor,
                                          ),
                                        Builder(
                                          builder: (ctx) {
                                            final item =
                                                proc.mappedConsumables[cIdx];
                                            final itemTotalCost =
                                                item.unitPrice *
                                                item.qtyPerProcedure;

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      '${cIdx + 1}.  ${item.consumableName}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13,
                                                        color: AppTheme
                                                            .textPrimaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '₹${item.unitPrice.toStringAsFixed(2)} / ${item.unit}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppTheme
                                                            .textSecondaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '${item.qtyPerProcedure} ${item.unit}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme
                                                            .textPrimaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      '₹${itemTotalCost.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 36,
                                                    child: IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        size: 16,
                                                        color: AppTheme.dangerColor,
                                                      ),
                                                      tooltip:
                                                          'Remove consumable mapping',
                                                      onPressed: () =>
                                                          _removeConsumableMapping(
                                                            proc,
                                                            item,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Estimated Consumables Total: ₹${totalConsumablesCost.toStringAsFixed(2)}  |  Total Procedure Billing: ₹${(proc.procedureCharge + totalConsumablesCost).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
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
            return r == 'Doctor' ||
                r == 'Nurse' ||
                r == 'Front Desk' ||
                r == 'Anaesthetist';
          }).toList();

          final orderedRoles = [
            'Super Admin',
            'Admin',
            'Doctor',
            'Nurse',
            'Anaesthetist',
            'Front Desk',
          ];
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
    if (_selectedRole == null || !_roles.contains(_selectedRole)) {
      setState(() => _errorMessage = 'Please select a valid role from the list');
      return;
    }
    if (_selectedRole == 'Doctor') {
      final validSpecIds =
          _specializations.map((s) => s['id'].toString()).toSet();
      if (_selectedSpecializationId == null ||
          !validSpecIds.contains(_selectedSpecializationId.toString())) {
        setState(
          () => _errorMessage =
              'Please select a valid specialization from the list',
        );
        return;
      }
    }
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

  Widget _buildFullNameField() {
    return Column(
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
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
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
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
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
          validator: (val) =>
              val == null || val.isEmpty ? 'Please enter full name' : null,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
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
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          keyboardType: TextInputType.emailAddress,
          maxLength: 254,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
            LengthLimitingTextInputFormatter(254),
          ],
          decoration: InputDecoration(
            hintText: 'Enter email address',
            hintStyle: const TextStyle(
              color: Color(0xFFCBD5E0),
              fontSize: 11,
            ),
            counterText: '',
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
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
    );
  }

  Widget _buildMobileField() {
    return Column(
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
            if (_errorMessage != null) setState(() => _errorMessage = null);
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
            errorMaxLines: 2,
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            errorStyle: const TextStyle(fontSize: 11, color: Colors.red),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter mobile number';
            }
            final clean = val.trim();
            if (!RegExp(r'^[6-9]').hasMatch(clean)) {
              return 'Mobile number must start with 6, 7, 8, or 9';
            }
            if (clean.length != 10) {
              return 'Mobile number must be exactly 10 digits';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
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
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          obscureText: _obscurePassword,
          maxLength: 16,
          inputFormatters: [
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter password',
            hintStyle: const TextStyle(
              color: Color(0xFFCBD5E0),
              fontSize: 11,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  tooltip: 'Regenerate Password',
                  onPressed: () {
                    setState(() {
                      _passwordController.text =
                          PasswordPolicy.generateSecurePassword();
                      _obscurePassword = false;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
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
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
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
    );
  }

  Widget _buildSpecializationField() {
    return Column(
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
            ? const Center(child: CircularProgressIndicator())
            : CustomDropdownSearch(
                label: '',
                hint: 'Select specialization',
                dropdownMap: {
                  for (var spec in _specializations)
                    spec['id'].toString(): spec['name'].toString(),
                },
                value: _selectedSpecializationId?.toString(),
                fillColor: AppTheme.backgroundColor,
                popupBgColor: Colors.white,
                borderColor: const Color(0xFFE2E8F0),
                focusedBorderColor: AppTheme.primaryColor,
                height: 52,
                hintFontSize: 11,
                onChanged: (val) {
                  setState(() {
                    _selectedSpecializationId =
                        val != null ? int.tryParse(val) : null;
                  });
                },
                validator: (val) {
                  if (_selectedRole != 'Doctor') {
                    return null;
                  }
                  if (val == null || val.isEmpty) {
                    return 'Please select a specialization';
                  }
                  final validSpecIds =
                      _specializations.map((s) => s['id'].toString()).toSet();
                  if (!validSpecIds.contains(val)) {
                    return 'Please select a valid specialization from the list';
                  }
                  return null;
                },
              ),
      ],
    );
  }

  Widget _buildLicenseField() {
    return Column(
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
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
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
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isMobile = screenWidth < 640;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: mediaQuery.size.height * (isMobile ? 0.9 : 0.85),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Register New Staff',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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

                      // Row 1: Full Name | Email
                      if (isMobile) ...[
                        _buildFullNameField(),
                        const SizedBox(height: 16),
                        _buildEmailField(),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildFullNameField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildEmailField()),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Row 2: Mobile | Password
                      if (isMobile) ...[
                        _buildMobileField(),
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildMobileField()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPasswordField()),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Row 3: Role (full width)
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
                              label: '',
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
                                setState(() {
                                  _errorMessage = null;
                                  _selectedRole = val;
                                  if (_selectedRole != 'Doctor') {
                                    _selectedSpecializationId = null;
                                  }
                                });
                              },
                              validator: (val) => val == null ||
                                      val.isEmpty ||
                                      !_roles.contains(val)
                                  ? 'Please select a valid role'
                                  : null,
                            ),

                      // Row 4: Specialization | Medical License (Doctor only)
                      if (_selectedRole == 'Doctor') ...[
                        const SizedBox(height: 20),
                        if (isMobile) ...[
                          _buildSpecializationField(),
                          const SizedBox(height: 16),
                          _buildLicenseField(),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildSpecializationField()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildLicenseField()),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: AppTheme.cancelButton,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.logoRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPatientManagementWrapper extends StatefulWidget {
  final void Function([PatientModel? prefilledPatient]) onRegister;
  final Function(PatientModel) onCompleteProfile;
  final PatientModel? viewPatient;

  const AdminPatientManagementWrapper({
    Key? key,
    required this.onRegister,
    required this.onCompleteProfile,
    this.viewPatient,
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
      initialSelectedPatient: widget.viewPatient,
      onCompleteProfile: widget.onCompleteProfile,
      onRefresh: _fetchPatients,
      onRegisterPatient: ([prefilledPatient]) => widget.onRegister(prefilledPatient),
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
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

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

class LineChartPainter extends CustomPainter {
  final List<double> data;
  LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height - 20;

    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primaryColor.withOpacity(0.15),
          AppTheme.primaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final double stepX = size.width / (data.length - 1);
    final double maxY = 40.0;

    double getX(int index) => index * stepX;
    double getY(double value) => chartHeight - (value / maxY) * chartHeight;

    path.moveTo(getX(0), getY(data[0]));
    fillPath.moveTo(getX(0), chartHeight);
    fillPath.lineTo(getX(0), getY(data[0]));

    for (int i = 0; i < data.length - 1; i++) {
      final x1 = getX(i);
      final y1 = getY(data[i]);
      final x2 = getX(i + 1);
      final y2 = getY(data[i + 1]);

      final cx1 = x1 + (x2 - x1) / 2;
      final cy1 = y1;
      final cx2 = x1 + (x2 - x1) / 2;
      final cy2 = y2;

      path.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
      fillPath.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
    }

    fillPath.lineTo(size.width, chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final pointPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      canvas.drawCircle(Offset(getX(i), getY(data[i])), 5, borderPaint);
      canvas.drawCircle(Offset(getX(i), getY(data[i])), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AdminHeaderDateTimeCard extends StatefulWidget {
  const AdminHeaderDateTimeCard({Key? key}) : super(key: key);

  @override
  State<AdminHeaderDateTimeCard> createState() =>
      _AdminHeaderDateTimeCardState();
}

class _AdminHeaderDateTimeCardState extends State<AdminHeaderDateTimeCard> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('dd MMMM yyyy').format(_now),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                DateFormat('hh:mm a').format(_now),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
