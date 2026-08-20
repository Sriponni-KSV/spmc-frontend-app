import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../models/patient_model.dart';
import '../widgets/custom_dropdown_search.dart';
import '../utils/unsaved_changes_helper.dart';

class NewPatientRegistrationView extends StatefulWidget {
  final VoidCallback onBack;
  final PatientModel? existingPatient;
  const NewPatientRegistrationView({
    Key? key,
    required this.onBack,
    this.existingPatient,
  }) : super(key: key);

  @override
  State<NewPatientRegistrationView> createState() =>
      _NewPatientRegistrationViewState();
}

class _NewPatientRegistrationViewState
    extends State<NewPatientRegistrationView> {
  int _currentStep = 1;
  bool _isSubmitting = false;

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  String? _selectedDistrict;
  final TextEditingController _pincodeController = TextEditingController();

  static const List<String> _tamilNaduDistricts = [
    'Ariyalur',
    'Chengalpattu',
    'Chennai',
    'Coimbatore',
    'Cuddalore',
    'Dharmapuri',
    'Dindigul',
    'Erode',
    'Kallakurichi',
    'Kancheepuram',
    'Kanyakumari',
    'Karur',
    'Krishnagiri',
    'Madurai',
    'Mayiladuthurai',
    'Nagapattinam',
    'Namakkal',
    'Nilgiris',
    'Perambalur',
    'Pudukkottai',
    'Ramanathapuram',
    'Ranipet',
    'Salem',
    'Sivaganga',
    'Tenkasi',
    'Thanjavur',
    'Theni',
    'Thoothukudi',
    'Tiruchirappalli',
    'Tirunelveli',
    'Tirupathur',
    'Tiruppur',
    'Tiruvallur',
    'Tiruvannamalai',
    'Tiruvarur',
    'Vellore',
    'Viluppuram',
    'Virudhunagar',
  ];

  // Emergency Contact Controllers
  final TextEditingController _emergencyContactNameController =
      TextEditingController();
  final TextEditingController _emergencyContactRelationController =
      TextEditingController();
  final TextEditingController _emergencyContactPhoneController =
      TextEditingController();

  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();

  List<String> _departments = [];
  bool _isLoadingDepartments = true;

  // Step 2 Controllers
  final TextEditingController _bpSystolicController = TextEditingController();
  final TextEditingController _bpDiastolicController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  static const List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
    'A1+',
    'A1-',
    'A2+',
    'A2-',
    'A1B+',
    'A1B-',
    'A2B+',
    'A2B-',
    'Bombay Blood Group (Oh)',
    'INRA',
    'Rh-null',
  ];

  String? _selectedBloodGroup;
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _chronicConditionsController =
      TextEditingController();

  final TextEditingController _complaintsController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();

  // Step 3: Lifestyle Data
  static const List<String> _smokingOptions = [
    'Never',
    'Former smoker',
    'Current smoker',
  ];

  static const List<String> _alcoholOptions = [
    'Never',
    'Occasional',
    'Regular',
  ];

  String? _smokingStatus;
  String? _alcoholStatus;
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();
  final TextEditingController _foodHabitsController = TextEditingController();
  final TextEditingController _physicalActivityController =
      TextEditingController();
  String? _selectedGender;
  PatientModel? _matchedExistingPatient;
  String _lastCheckedPhone = '';
  bool _isSearchingPhone = false;
  String? _phoneDuplicateError;

  // Form keys for validation
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    UnsavedChangesHelper.setUnsavedChanges(true);
    if (widget.existingPatient != null) {
      _preFillForm();
    }
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    if (phone.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      if (phone != _lastCheckedPhone) {
        _lastCheckedPhone = phone;
        _checkExistingPatient(phone);
      }
    } else {
      if (_phoneDuplicateError != null || _matchedExistingPatient != null) {
        setState(() {
          _phoneDuplicateError = null;
          _matchedExistingPatient = null;
        });
      }
      if (phone.length < 10) {
        _lastCheckedPhone = '';
      }
    }
  }

  Future<void> _checkExistingPatient(String phone) async {
    // If editing existing patient with same phone, skip check
    if (widget.existingPatient != null && widget.existingPatient!.phone == phone) {
      if (_phoneDuplicateError != null) {
        setState(() {
          _phoneDuplicateError = null;
        });
      }
      return;
    }

    setState(() {
      _isSearchingPhone = true;
    });

    try {
      final patients = await _patientController.fetchPatientsByPhone(phone);
      final duplicates = patients.where((p) => widget.existingPatient == null || p.id != widget.existingPatient!.id).toList();

      if (duplicates.isNotEmpty && mounted) {
        final existing = duplicates.first;
        setState(() {
          _matchedExistingPatient = existing;
          _phoneDuplicateError = 'This mobile number is already registered to ${existing.name} (${existing.patientId ?? "ID: N/A"}). Only one patient is allowed per mobile number.';
        });
        _formKeyStep1.currentState?.validate();
        _showExistingPatientsDialog(duplicates);
      } else if (mounted) {
        setState(() {
          _matchedExistingPatient = null;
          _phoneDuplicateError = null;
        });
        _formKeyStep1.currentState?.validate();
      }
    } catch (e) {
      print('Error searching patient by phone: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingPhone = false;
        });
      }
    }
  }

  void _showExistingPatientsDialog(List<PatientModel> patients) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final patient = patients.first;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.dangerColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mobile Number Already Registered',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This mobile number is already assigned to a registered patient. Only one patient record is permitted per mobile number.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogDetailRow(
                        'Patient ID',
                        patient.patientId ?? '-',
                      ),
                      _buildDialogDetailRow('Name', patient.name),
                      _buildDialogDetailRow(
                        'Gender / Age',
                        '${patient.gender} / ${patient.displayAge}',
                      ),
                      _buildDialogDetailRow('DOB', patient.dob),
                      _buildDialogDetailRow('Mobile', patient.phone),
                      if (patient.fullAddress.isNotEmpty)
                        _buildDialogDetailRow(
                          'Address',
                          patient.fullAddress,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please load this patient\'s record to update their profile or enter a different mobile number for a new registration.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop('clear');
              },
              style: AppTheme.cancelButton,
              child: const Text('Enter Different Number'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop('load');
              },
              style: AppTheme.primaryButton,
              child: const Text('Load Existing Patient'),
            ),
          ],
        );
      },
    ).then((action) {
      if (action == 'load') {
        if (patients.isNotEmpty) {
          final p = patients.first;
          setState(() {
            _matchedExistingPatient = p;
            _phoneDuplicateError = null;
            _loadMatchedPatient(p);
          });
        }
      } else if (action == 'clear') {
        setState(() {
          _phoneController.clear();
          _lastCheckedPhone = '';
          _phoneDuplicateError = null;
          _matchedExistingPatient = null;
        });
      }
    });
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _preFillForm() {
    _loadPatientIntoForm(widget.existingPatient!);
  }

  void _loadMatchedPatient(PatientModel p) {
    _loadPatientIntoForm(p);
  }

  void _loadPatientIntoForm(PatientModel p) {
    _nameController.text = p.name;
    _dobController.text = p.dob;
    if (p.dob.isNotEmpty) {
      try {
        final dob = DateFormat('dd/MM/yyyy').parse(p.dob);
        final now = DateTime.now();
        int years = now.year - dob.year;
        int months = now.month - dob.month;
        int days = now.day - dob.day;
        if (days < 0) {
          months--;
          final prevMonth = DateTime(now.year, now.month, 0);
          days += prevMonth.day;
        }
        if (months < 0) {
          years--;
          months += 12;
        }
        if (years >= 1) {
          _ageController.text = years.toString();
        } else if (months >= 1) {
          _ageController.text = '$months month${months == 1 ? '' : 's'}';
        } else {
          _ageController.text = '$days day${days == 1 ? '' : 's'}';
        }
      } catch (_) {
        _ageController.text = p.age > 0 ? p.age.toString() : '';
      }
    } else {
      _ageController.text = p.age > 0 ? p.age.toString() : '';
    }
    _phoneController.text = p.phone;
    if (p.phone.length == 10) {
      _lastCheckedPhone = p.phone;
    }
    _emailController.text = p.email;
    _addressController.text = p.address;
    _addressLine2Controller.text = p.addressLine2;
    _selectedDistrict = _tamilNaduDistricts.contains(p.district)
        ? p.district
        : null;
    _pincodeController.text = p.pincode;
    _selectedGender = ['Male', 'Female', 'Other'].contains(p.gender)
        ? p.gender
        : null;

    _emergencyContactNameController.text = p.emergencyContactName;
    _emergencyContactRelationController.text = p.emergencyContactRelation;
    _emergencyContactPhoneController.text = p.emergencyContactPhone;

    // Medical Intake
    _bpSystolicController.text = p.bpSystolic > 0
        ? p.bpSystolic.toString()
        : '';
    _bpDiastolicController.text = p.bpDiastolic > 0
        ? p.bpDiastolic.toString()
        : '';
    _sugarController.text = p.sugar > 0 ? p.sugar.toString() : '';
    _tempController.text = p.temp > 0 ? p.temp.toString() : '';
    _heightController.text = p.height > 0 ? p.height.toString() : '';
    _weightController.text = p.weight > 0 ? p.weight.toString() : '';
    _bloodGroupController.text = p.bloodGroup;
    _selectedBloodGroup = _bloodGroupOptions.contains(p.bloodGroup)
        ? p.bloodGroup
        : null;
    _allergiesController.text = p.allergies;
    _chronicConditionsController.text = p.chronicConditions;
    _complaintsController.text = p.complaints;
    _historyController.text = p.history;

    // Lifestyle
    _smokingStatus = _smokingOptions.contains(p.smokingStatus)
        ? p.smokingStatus
        : 'Never';
    _alcoholStatus = _alcoholOptions.contains(p.alcoholStatus)
        ? p.alcoholStatus
        : 'Never';
    _occupationController.text = p.occupation;
    _hobbiesController.text = p.hobbies;
    _foodHabitsController.text = p.foodHabits;
    _physicalActivityController.text = p.physicalActivity;
  }

  @override
  void dispose() {
    UnsavedChangesHelper.setUnsavedChanges(false);
    _nameController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _addressLine2Controller.dispose();
    _pincodeController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactRelationController.dispose();
    _emergencyContactPhoneController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _sugarController.dispose();
    _tempController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _chronicConditionsController.dispose();
    _complaintsController.dispose();
    _historyController.dispose();
    _occupationController.dispose();
    _hobbiesController.dispose();
    _foodHabitsController.dispose();
    _physicalActivityController.dispose();
    super.dispose();
  }

  bool _hasFormChanges() {
    final bool anyFieldEntered =
        _nameController.text.trim().isNotEmpty ||
        _dobController.text.trim().isNotEmpty ||
        _ageController.text.trim().isNotEmpty ||
        _phoneController.text.trim().isNotEmpty ||
        _emailController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _addressLine2Controller.text.trim().isNotEmpty ||
        _selectedDistrict != null ||
        _pincodeController.text.trim().isNotEmpty ||
        _selectedGender != null ||
        _emergencyContactNameController.text.trim().isNotEmpty ||
        _emergencyContactRelationController.text.trim().isNotEmpty ||
        _emergencyContactPhoneController.text.trim().isNotEmpty ||
        _bpSystolicController.text.trim().isNotEmpty ||
        _bpDiastolicController.text.trim().isNotEmpty ||
        _sugarController.text.trim().isNotEmpty ||
        _tempController.text.trim().isNotEmpty ||
        _heightController.text.trim().isNotEmpty ||
        _weightController.text.trim().isNotEmpty ||
        _bloodGroupController.text.trim().isNotEmpty ||
        _allergiesController.text.trim().isNotEmpty ||
        _chronicConditionsController.text.trim().isNotEmpty ||
        _complaintsController.text.trim().isNotEmpty ||
        _historyController.text.trim().isNotEmpty ||
        _occupationController.text.trim().isNotEmpty ||
        _hobbiesController.text.trim().isNotEmpty ||
        _foodHabitsController.text.trim().isNotEmpty ||
        _physicalActivityController.text.trim().isNotEmpty ||
        (_smokingStatus != null && _smokingStatus != 'Never') ||
        (_alcoholStatus != null && _alcoholStatus != 'Never');

    if (widget.existingPatient != null) {
      final p = widget.existingPatient!;
      final bool basicInfoChanged =
          _nameController.text.trim() != p.name ||
          _dobController.text.trim() != p.dob ||
          _ageController.text.trim() != (p.age > 0 ? p.age.toString() : '') ||
          _phoneController.text.trim() != p.phone ||
          _emailController.text.trim() != p.email ||
          _addressController.text.trim() != p.address ||
          _addressLine2Controller.text.trim() != p.addressLine2 ||
          _selectedDistrict != (p.district.isNotEmpty ? p.district : null) ||
          _pincodeController.text.trim() != p.pincode ||
          _selectedGender != p.gender;

      final bool emergencyContactChanged =
          _emergencyContactNameController.text.trim() !=
              p.emergencyContactName ||
          _emergencyContactRelationController.text.trim() !=
              p.emergencyContactRelation ||
          _emergencyContactPhoneController.text.trim() !=
              p.emergencyContactPhone;

      final bool vitalsChanged =
          _bpSystolicController.text.trim() !=
              (p.bpSystolic > 0 ? p.bpSystolic.toString() : '') ||
          _bpDiastolicController.text.trim() !=
              (p.bpDiastolic > 0 ? p.bpDiastolic.toString() : '') ||
          _sugarController.text.trim() !=
              (p.sugar > 0 ? p.sugar.toString() : '') ||
          _tempController.text.trim() !=
              (p.temp > 0 ? p.temp.toString() : '') ||
          _heightController.text.trim() !=
              (p.height > 0 ? p.height.toString() : '') ||
          _weightController.text.trim() !=
              (p.weight > 0 ? p.weight.toString() : '') ||
          _bloodGroupController.text.trim() != p.bloodGroup ||
          _allergiesController.text.trim() != p.allergies ||
          _chronicConditionsController.text.trim() != p.chronicConditions ||
          _complaintsController.text.trim() != p.complaints ||
          _historyController.text.trim() != p.history;

      return basicInfoChanged ||
          emergencyContactChanged ||
          vitalsChanged ||
          anyFieldEntered;
    }

    return anyFieldEntered;
  }

  void _showDiscardDialog() {
    if (!_hasFormChanges()) {
      UnsavedChangesHelper.clear();
      widget.onBack();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.dangerColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Discard Unsaved Changes?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'You have unsaved form entries. Are you sure you want to discard changes and go back?',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.4,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: AppTheme.cancelButton,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Stay on Form'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: AppTheme.dangerButton,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      UnsavedChangesHelper.clear();
                      Future.delayed(const Duration(milliseconds: 60), () {
                        widget.onBack();
                      });
                    },
                    child: const Text('Discard & Leave'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        _showDiscardDialog();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Top Section: Header & Stepper
          Container(
            color: AppTheme.backgroundColor,
            padding: EdgeInsets.only(
              left: isMobile ? 16.0 : 48.0,
              right: isMobile ? 16.0 : 48.0,
              top: 24.0,
              bottom: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button & Header
                InkWell(
                  onTap: _showDiscardDialog,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Back to Patients',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.existingPatient != null ||
                                    _matchedExistingPatient != null)
                                ? (((widget.existingPatient?.isQuickRegister ??
                                          _matchedExistingPatient
                                              ?.isQuickRegister ??
                                          false))
                                      ? 'Complete Patient Profile'
                                      : 'Edit Patient Profile')
                                : 'New Patient Registration',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(fontSize: isMobile ? 20 : 28),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(height: 4),
                            Text(
                              (widget.existingPatient != null ||
                                      _matchedExistingPatient != null)
                                  ? 'Update patient information and medical history'
                                  : 'Fill in patient information and medical history',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stepper UI
                _buildRegistrationStepper(isMobile),
              ],
            ),
          ),

          // Scrollable Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: isMobile ? 16.0 : 48.0,
                right: isMobile ? 16.0 : 48.0,
                top: 8.0,
                bottom: 32.0,
              ),
              child: _buildStepContent(isMobile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(bool isMobile) {
    switch (_currentStep) {
      case 1:
        return _buildBasicDetailsForm(isMobile);
      case 2:
        return _buildMedicalIntakeForm(isMobile);
      case 3:
        return _buildLifestyleDataForm(isMobile);
      case 4:
        return _buildReviewForm(isMobile);
      default:
        return _buildBasicDetailsForm(isMobile);
    }
  }

  Widget _buildRegistrationStepper(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 6 : 8,
        horizontal: isMobile ? 12 : 32,
      ),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          _buildStepItem(
            1,
            'Basic Details',
            _currentStep >= 1,
            isCompleted: _currentStep > 1,
            isMobile: isMobile,
          ),
          _buildStepDivider(_currentStep > 1),
          _buildStepItem(
            2,
            'Medical Intake',
            _currentStep >= 2,
            isCompleted: _currentStep > 2,
            isMobile: isMobile,
          ),
          _buildStepDivider(_currentStep > 2),
          _buildStepItem(
            3,
            'Lifestyle Data',
            _currentStep >= 3,
            isCompleted: _currentStep > 3,
            isMobile: isMobile,
          ),
          _buildStepDivider(_currentStep > 3),
          _buildStepItem(
            4,
            'Review',
            _currentStep >= 4,
            isCompleted: _currentStep > 4,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(
    int step,
    String label,
    bool isActive, {
    bool isCompleted = false,
    bool isMobile = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: isMobile ? 20 : 24,
            height: isMobile ? 20 : 24,
            decoration: BoxDecoration(
              color: (isActive || isCompleted)
                  ? AppTheme.infoColor
                  : const Color(0xFFEDF2F7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: isMobile ? 14 : 16,
                    )
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF718096),
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 8 : 10,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 8 : 10,
              fontWeight: (isActive || isCompleted)
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: (isActive || isCompleted)
                  ? AppTheme.textPrimaryColor
                  : const Color(0xFF718096),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppTheme.infoColor : const Color(0xFFE2E8F0),
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  Widget _buildBasicDetailsForm(bool isMobile) {
    return Form(
      key: _formKeyStep1,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),

            if (isMobile) ...[
              _buildLabel('Full Name *'),
              _buildTextField(
                controller: _nameController,
                hint: 'Enter patient\'s full name',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z\s.]'),
                  ),
                  LengthLimitingTextInputFormatter(60),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Please enter Full Name';
                  if (val.trim().length < 3)
                    return 'Name must be at least 3 characters';
                  if (val.trim().length > 60)
                    return 'Full Name cannot exceed 60 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Email Address *'),
              _buildTextField(
                controller: _emailController,
                hint: 'Enter Email Address',
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(254),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter Email Address';
                  }
                  if (val.trim().length > 254) {
                    return 'Email address cannot exceed 254 characters';
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

              _buildLabel('Date of Birth *'),
              _buildTextField(
                controller: _dobController,
                hint: 'dd/mm/yyyy',
                icon: Icons.calendar_today_outlined,
                onTap: () => _selectDate(context),
                readOnly: true,
                validator: (val) => val == null || val.isEmpty
                    ? 'Please enter Date of Birth'
                    : null,
              ),
              const SizedBox(height: 16),

              _buildLabel('Gender *'),
              _buildDropdownField(
                value: _selectedGender,
                hint: 'Select gender',
                items: ['Male', 'Female', 'Other'],
                onChanged: (val) =>
                    setState(() => _selectedGender = val),
                validator: (val) {
                  if (val == null ||
                      val.trim().isEmpty ||
                      !['Male', 'Female', 'Other'].contains(val)) {
                    return 'Please select gender';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Mobile Number *'),
              _buildTextField(
                controller: _phoneController,
                hint: 'Enter Mobile Number',
                keyboardType: TextInputType.phone,
                suffixIcon: _isSearchingPhone
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    : null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter Mobile Number';
                  }
                  final clean = val.trim();
                  if (!RegExp(r'^[6-9]').hasMatch(clean)) {
                    return 'Mobile number must start with 6, 7, 8, or 9';
                  }
                  if (clean.length != 10) {
                    return 'Mobile number must be exactly 10 digits';
                  }
                  if (_phoneDuplicateError != null) {
                    return _phoneDuplicateError;
                  }
                  return null;
                },
              ),
              if (_phoneDuplicateError != null && _matchedExistingPatient != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.dangerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.dangerColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Registered to: ${_matchedExistingPatient!.name} (${_matchedExistingPatient!.patientId ?? "ID: N/A"}). Only one patient allowed per mobile number.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.dangerColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              _buildLabel('Emergency Contact Name *'),
              _buildTextField(
                controller: _emergencyContactNameController,
                hint: 'Enter name',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z\s.]'),
                  ),
                  LengthLimitingTextInputFormatter(60),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Please enter Emergency Contact Name';
                  if (val.trim().length < 3)
                    return 'Name must be at least 3 characters';
                  if (val.trim().length > 60)
                    return 'Emergency Contact Name cannot exceed 60 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Relation *'),
              _buildTextField(
                controller: _emergencyContactRelationController,
                hint: 'Enter Relationship',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z\s]'),
                  ),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Please enter Relation';
                  if (val.trim().length > 20)
                    return 'Relation cannot exceed 20 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Emergency Mobile Number *'),
              _buildTextField(
                controller: _emergencyContactPhoneController,
                hint: 'Enter Mobile Number',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter Emergency Mobile Number';
                  }
                  final clean = val.trim();
                  if (!RegExp(r'^[6-9]').hasMatch(clean)) {
                    return 'Emergency mobile number must start with 6, 7, 8, or 9';
                  }
                  if (clean.length != 10) {
                    return 'Emergency mobile number must be exactly 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Address Line 1 *'),
              _buildTextField(
                controller: _addressController,
                hint: 'Enter Address Line 1',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):]'),
                  ),
                  LengthLimitingTextInputFormatter(150),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter Address Line 1';
                  }
                  if (!RegExp(
                    r'^[a-zA-Z0-9\s.,/#\-\(\):]+$',
                  ).hasMatch(val.trim())) {
                    return 'Address Line 1 contains invalid special characters';
                  }
                  if (val.trim().length > 150) {
                    return 'Address Line 1 cannot exceed 150 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Address Line 2'),
              _buildTextField(
                controller: _addressLine2Controller,
                hint: 'Enter Address Line 2',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):]'),
                  ),
                  LengthLimitingTextInputFormatter(120),
                ],
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    if (!RegExp(
                      r'^[a-zA-Z0-9\s.,/#\-\(\):]+$',
                    ).hasMatch(val.trim())) {
                      return 'Address Line 2 contains invalid special characters';
                    }
                    if (val.trim().length > 120) {
                      return 'Address Line 2 cannot exceed 120 characters';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('District *'),
              _buildDropdownField(
                value: _selectedDistrict,
                hint: 'Select district',
                items: _tamilNaduDistricts,
                onChanged: (val) =>
                    setState(() => _selectedDistrict = val),
                validator: (val) {
                  if (val == null ||
                      val.trim().isEmpty ||
                      !_tamilNaduDistricts.contains(val.trim())) {
                    return 'Please select a valid District';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Pincode *'),
              _buildTextField(
                controller: _pincodeController,
                hint: 'Enter Pincode',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter Pincode';
                  }
                  final clean = val.trim();
                  if (clean.length != 6) {
                    return 'Pincode must be exactly 6 digits';
                  }
                  if (!clean.startsWith('6')) {
                    return 'Please enter a valid Tamil Nadu Pincode (starts with 6)';
                  }
                  if (!RegExp(r'^6[0-4]\d{4}$').hasMatch(clean)) {
                    return 'Please enter a valid Tamil Nadu Pincode (starts with 60-64)';
                  }
                  return null;
                },
              ),
            ] else ...[
              // Desktop 2-column layout
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Full Name *'),
                        _buildTextField(
                          controller: _nameController,
                          hint: 'Enter patient\'s full name',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s.]'),
                            ),
                            LengthLimitingTextInputFormatter(60),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Please enter Full Name';
                            if (val.trim().length < 3)
                              return 'Name must be at least 3 characters';
                            if (val.trim().length > 60)
                              return 'Full Name cannot exceed 60 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Email Address *'),
                        _buildTextField(
                          controller: _emailController,
                          hint: 'Enter Email Address',
                          keyboardType: TextInputType.emailAddress,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(254),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter Email Address';
                            }
                            if (val.trim().length > 254) {
                              return 'Email address cannot exceed 254 characters';
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
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Date of Birth *'),
                        _buildTextField(
                          controller: _dobController,
                          hint: 'dd/mm/yyyy',
                          icon: Icons.calendar_today_outlined,
                          onTap: () => _selectDate(context),
                          readOnly: true,
                          validator: (val) => val == null || val.isEmpty
                              ? 'Please enter Date of Birth'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Gender *'),
                        _buildDropdownField(
                          value: _selectedGender,
                          hint: 'Select gender',
                          items: ['Male', 'Female', 'Other'],
                          onChanged: (val) =>
                              setState(() => _selectedGender = val),
                          validator: (val) {
                            if (val == null ||
                                val.trim().isEmpty ||
                                !['Male', 'Female', 'Other'].contains(val)) {
                              return 'Please select gender';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Mobile Number *'),
                        _buildTextField(
                          controller: _phoneController,
                          hint: 'Enter Mobile Number',
                          keyboardType: TextInputType.phone,
                          suffixIcon: _isSearchingPhone
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                )
                              : null,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter Mobile Number';
                            }
                            final clean = val.trim();
                            if (!RegExp(r'^[6-9]').hasMatch(clean)) {
                              return 'Mobile number must start with 6, 7, 8, or 9';
                            }
                            if (clean.length != 10) {
                              return 'Mobile number must be exactly 10 digits';
                            }
                            if (_phoneDuplicateError != null) {
                              return _phoneDuplicateError;
                            }
                            return null;
                          },
                        ),
                        if (_phoneDuplicateError != null && _matchedExistingPatient != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.dangerColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.dangerColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Registered to: ${_matchedExistingPatient!.name} (${_matchedExistingPatient!.patientId ?? "ID: N/A"}). Only one patient allowed per mobile number.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.dangerColor,
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
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Emergency Contact Name *'),
                        _buildTextField(
                          controller: _emergencyContactNameController,
                          hint: 'Enter name',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s.]'),
                            ),
                            LengthLimitingTextInputFormatter(60),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Please enter Emergency Contact Name';
                            if (val.trim().length < 3)
                              return 'Name must be at least 3 characters';
                            if (val.trim().length > 60)
                              return 'Emergency Contact Name cannot exceed 60 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Relation *'),
                        _buildTextField(
                          controller: _emergencyContactRelationController,
                          hint: 'Enter Relationship',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                            LengthLimitingTextInputFormatter(20),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Please enter Relation';
                            if (val.trim().length > 20)
                              return 'Relation cannot exceed 20 characters';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Emergency Mobile Number *'),
                        _buildTextField(
                          controller: _emergencyContactPhoneController,
                          hint: 'Enter Mobile Number',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter Emergency Mobile Number';
                            }
                            final clean = val.trim();
                            if (!RegExp(r'^[6-9]').hasMatch(clean)) {
                              return 'Emergency mobile number must start with 6, 7, 8, or 9';
                            }
                            if (clean.length != 10) {
                              return 'Emergency mobile number must be exactly 10 digits';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Address Line 1 *'),
                        _buildTextField(
                          controller: _addressController,
                          hint: 'Enter Address Line 1',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):]'),
                            ),
                            LengthLimitingTextInputFormatter(150),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter Address Line 1';
                            }
                            if (!RegExp(
                              r'^[a-zA-Z0-9\s.,/#\-\(\):]+$',
                            ).hasMatch(val.trim())) {
                              return 'Address Line 1 contains invalid special characters';
                            }
                            if (val.trim().length > 150) {
                              return 'Address Line 1 cannot exceed 150 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Address Line 2'),
                        _buildTextField(
                          controller: _addressLine2Controller,
                          hint: 'Enter Address Line 2',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):]'),
                            ),
                            LengthLimitingTextInputFormatter(120),
                          ],
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              if (!RegExp(
                                r'^[a-zA-Z0-9\s.,/#\-\(\):]+$',
                              ).hasMatch(val.trim())) {
                                return 'Address Line 2 contains invalid special characters';
                              }
                              if (val.trim().length > 120) {
                                return 'Address Line 2 cannot exceed 120 characters';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('District *'),
                        _buildDropdownField(
                          value: _selectedDistrict,
                          hint: 'Select district',
                          items: _tamilNaduDistricts,
                          onChanged: (val) =>
                              setState(() => _selectedDistrict = val),
                          validator: (val) {
                            if (val == null ||
                                val.trim().isEmpty ||
                                !_tamilNaduDistricts.contains(val.trim())) {
                              return 'Please select a valid District';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Pincode *'),
                        _buildTextField(
                          controller: _pincodeController,
                          hint: 'Enter Pincode',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter Pincode';
                            }
                            final clean = val.trim();
                            if (clean.length != 6) {
                              return 'Pincode must be exactly 6 digits';
                            }
                            if (!clean.startsWith('6')) {
                              return 'Please enter a valid Tamil Nadu Pincode (starts with 6)';
                            }
                            if (!RegExp(r'^6[0-4]\d{4}$').hasMatch(clean)) {
                              return 'Please enter a valid Tamil Nadu Pincode (starts with 60-64)';
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
            const SizedBox(height: 48),

            // Action Buttons
            if (isMobile)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKeyStep1.currentState!.validate()) {
                      setState(() => _currentStep = 2);
                    }
                  },
                  style: AppTheme.logoRedButton.copyWith(
                    minimumSize: MaterialStateProperty.all(const Size(0, 52)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_formKeyStep1.currentState!.validate()) {
                        setState(() => _currentStep = 2);
                      }
                    },
                    style: AppTheme.logoRedButton.copyWith(
                      minimumSize: MaterialStateProperty.all(const Size(0, 52)),
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalIntakeForm(bool isMobile) {
    return Form(
      key: _formKeyStep2,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medical Intake',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            // Vitals Section
            const SizedBox(height: 24),
            const Text(
              'Vitals',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            if (isMobile) ...[
              _buildLabel('Height & Weight'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _heightController,
                      hint: 'Enter Height (cm)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final num = double.tryParse(text);
                        if (num == null) return 'Height must be a valid number';
                        if (num <= 0) return 'Height must be greater than 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      hint: 'Enter Weight (kg)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final num = double.tryParse(text);
                        if (num == null) return 'Weight must be a valid number';
                        if (num <= 0) return 'Weight must be greater than 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Blood Pressure'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _bpSystolicController,
                      hint: 'Enter Systolic',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final num = int.tryParse(text);
                        if (num == null) return 'Systolic BP must be an integer';
                        if (num == 0) return 'Systolic BP cannot be 0';
                        if (num < 90 || num > 300) return 'Systolic BP must be between 90 and 300 mmHg';
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      '/',
                      style: TextStyle(fontSize: 20, color: Color(0xFF4A5568)),
                    ),
                  ),
                  Expanded(
                    child: _buildTextField(
                      controller: _bpDiastolicController,
                      hint: 'Enter Diastolic',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final num = int.tryParse(text);
                        if (num == null) return 'Diastolic BP must be an integer';
                        if (num == 0) return 'Diastolic BP cannot be 0';
                        if (num < 50 || num > 180) return 'Diastolic BP must be between 50 and 180 mmHg';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Sugar Level'),
                        _buildTextField(
                          controller: _sugarController,
                          hint: 'Enter Sugar Level',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final num = double.tryParse(text);
                            if (num == null) return 'Sugar Level must be a number';
                            if (num == 0) return 'Sugar Level cannot be 0';
                            if (num < 30 || num > 600) return 'Sugar Level must be between 30 and 600 mg/dL';
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
                        _buildLabel('Temperature'),
                        _buildTextField(
                          controller: _tempController,
                          hint: 'Enter Temperature',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final num = double.tryParse(text);
                            if (num == null) return 'Temperature must be a number';
                            if (num == 0) return 'Temperature cannot be 0';
                            if (num < 90 || num > 115) return 'Temperature must be between 90 and 115 °F';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Blood Group'),
              _buildDropdownField(
                value: _selectedBloodGroup,
                hint: 'Select Blood Group',
                items: _bloodGroupOptions,
                onChanged: (val) {
                  setState(() {
                    _selectedBloodGroup = val;
                    _bloodGroupController.text = val ?? '';
                  });
                },
                validator: (val) {
                  if (val != null &&
                      val.trim().isNotEmpty &&
                      !_bloodGroupOptions.contains(val.trim())) {
                    return 'Please select a valid Blood Group';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Known Allergies'),
              _buildTextField(
                controller: _allergiesController,
                hint: 'Enter Allergies',
                maxLines: 2,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                  ),
                  LengthLimitingTextInputFormatter(100),
                ],
                validator: (val) {
                  final clean = val?.trim() ?? '';
                  if (clean.isEmpty) return null;
                  if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                    return 'Must contain alphabetic characters';
                  }
                  if (!RegExp(
                    r'^[a-zA-Z0-9\s.,/#\-\(\):;]+$',
                  ).hasMatch(clean)) {
                    return 'Contains invalid special characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Chronic Conditions'),
              _buildTextField(
                controller: _chronicConditionsController,
                hint: 'Enter Pre-existing Conditions',
                maxLines: 2,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                  ),
                  LengthLimitingTextInputFormatter(100),
                ],
                validator: (val) {
                  final clean = val?.trim() ?? '';
                  if (clean.isEmpty) return null;
                  if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                    return 'Must contain alphabetic characters';
                  }
                  if (!RegExp(
                    r'^[a-zA-Z0-9\s.,/#\-\(\):;]+$',
                  ).hasMatch(clean)) {
                    return 'Contains invalid special characters';
                  }
                  return null;
                },
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Height & Weight'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _heightController,
                                hint: 'Enter Height (cm)',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = double.tryParse(text);
                                  if (num == null) return 'Height must be a valid number';
                                  if (num <= 0) return 'Height must be greater than 0';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _weightController,
                                hint: 'Enter Weight (kg)',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = double.tryParse(text);
                                  if (num == null) return 'Weight must be a valid number';
                                  if (num <= 0) return 'Weight must be greater than 0';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Blood Pressure (Sys / Dia)'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _bpSystolicController,
                                hint: 'Enter Systolic',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = int.tryParse(text);
                                  if (num == null) return 'Enter a number';
                                  if (num == 0) return 'Cannot be 0';
                                  if (num < 70 || num > 300) return '70 to 300';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _bpDiastolicController,
                                hint: 'Enter Diastolic',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = int.tryParse(text);
                                  if (num == null) return 'Enter a number';
                                  if (num == 0) return 'Cannot be 0';
                                  if (num < 40 || num > 180) return '40 to 180';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Sugar & Temp'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _sugarController,
                                hint: 'Enter Sugar Level',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = double.tryParse(text);
                                  if (num == null) return 'Enter a number';
                                  if (num == 0) return 'Cannot be 0';
                                  if (num < 30 || num > 600) return '30 to 600';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _tempController,
                                hint: 'Enter Temperature',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) return null;
                                  final num = double.tryParse(text);
                                  if (num == null) return 'Enter a number';
                                  if (num == 0) return 'Cannot be 0';
                                  if (num < 90 || num > 115)
                                    return '90 to 115 °F';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Blood Group'),
                        _buildDropdownField(
                          value: _selectedBloodGroup,
                          hint: 'Select Blood Group',
                          items: _bloodGroupOptions,
                          onChanged: (val) {
                            setState(() {
                              _selectedBloodGroup = val;
                              _bloodGroupController.text = val ?? '';
                            });
                          },
                          validator: (val) {
                            if (val != null &&
                                val.trim().isNotEmpty &&
                                !_bloodGroupOptions.contains(val.trim())) {
                              return 'Please select a valid Blood Group';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Known Allergies'),
                        _buildTextField(
                          controller: _allergiesController,
                          hint: 'Enter Allergies',
                          maxLines: 2,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                            ),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: (val) {
                            final clean = val?.trim() ?? '';
                            if (clean.isEmpty) return null;
                            if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                              return 'Must contain alphabetic characters';
                            }
                            if (!RegExp(
                              r'^[a-zA-Z0-9\s.,/#\-\(\):;]+$',
                            ).hasMatch(clean)) {
                              return 'Contains invalid special characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Chronic Conditions'),
                        _buildTextField(
                          controller: _chronicConditionsController,
                          hint: 'Enter Pre-existing Conditions',
                          maxLines: 2,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                            ),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          validator: (val) {
                            final clean = val?.trim() ?? '';
                            if (clean.isEmpty) return null;
                            if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                              return 'Must contain alphabetic characters';
                            }
                            if (!RegExp(
                              r'^[a-zA-Z0-9\s.,/#\-\(\):;]+$',
                            ).hasMatch(clean)) {
                              return 'Contains invalid special characters';
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
            const SizedBox(height: 32),
            // Reason for Visit
            _buildLabel('Reason for Visit'),
            _buildTextField(
              controller: _complaintsController,
              hint: 'Describe current health complaints...',
              maxLines: 4,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                ),
                LengthLimitingTextInputFormatter(500),
              ],
              validator: (val) {
                final clean = val?.trim() ?? '';
                if (clean.isEmpty) return null;
                if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                  return 'Must contain alphabetic characters';
                }
                if (!RegExp(r'^[a-zA-Z0-9\s.,/#\-\(\):;]+$').hasMatch(clean)) {
                  return 'Contains invalid special characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Past Medical History
            _buildLabel('Past Medical History'),
            _buildTextField(
              controller: _historyController,
              hint: 'Previous conditions, surgeries, medications...',
              maxLines: 4,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                ),
                LengthLimitingTextInputFormatter(500),
              ],
              validator: (val) {
                final clean = val?.trim() ?? '';
                if (clean.isEmpty) return null;
                if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                  return 'Must contain alphabetic characters';
                }
                if (!RegExp(r'^[a-zA-Z0-9\s.,/#\-\(\):;]+$').hasMatch(clean)) {
                  return 'Contains invalid special characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 48),

            // Action Buttons
            if (isMobile)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep = 1),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A5568),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKeyStep2.currentState!.validate()) {
                          setState(() => _currentStep = 3);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.logoRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStep = 1),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A5568),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKeyStep2.currentState!.validate()) {
                        setState(() => _currentStep = 3);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.logoRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 52),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_forward_rounded, size: 18),
                        SizedBox(width: 12),
                        Text(
                          'Next',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLifestyleDataForm(bool isMobile) {
    return Form(
      key: _formKeyStep3,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 20 : 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lifestyle & Behavioral Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 28),

            // Occupation & Hobbies Row
            if (isMobile) ...[
              _buildLabel('Occupation'),
              _buildTextField(
                controller: _occupationController,
                hint: 'Enter occupation',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  LengthLimitingTextInputFormatter(50),
                ],
                validator: (val) {
                  final clean = val?.trim() ?? '';
                  if (clean.isEmpty) return null;
                  if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                    return 'Must contain alphabetic characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildLabel('Hobbies'),
              _buildTextField(
                controller: _hobbiesController,
                hint: 'Enter Physical Activities',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  LengthLimitingTextInputFormatter(50),
                ],
                validator: (val) {
                  final clean = val?.trim() ?? '';
                  if (clean.isEmpty) return null;
                  if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                    return 'Must contain alphabetic characters';
                  }
                  return null;
                },
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Occupation'),
                        _buildTextField(
                          controller: _occupationController,
                          hint: 'Enter occupation',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                            LengthLimitingTextInputFormatter(50),
                          ],
                          validator: (val) {
                            final clean = val?.trim() ?? '';
                            if (clean.isEmpty) return null;
                            if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                              return 'Must contain alphabetic characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Hobbies'),
                        _buildTextField(
                          controller: _hobbiesController,
                          hint: 'Enter Physical Activities',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                            LengthLimitingTextInputFormatter(50),
                          ],
                          validator: (val) {
                            final clean = val?.trim() ?? '';
                            if (clean.isEmpty) return null;
                            if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                              return 'Must contain alphabetic characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Food Habits
            _buildLabel('Food Habits'),
            _buildTextField(
              controller: _foodHabitsController,
              hint: 'Dietary preferences and eating patterns...',
              maxLines: 4,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                LengthLimitingTextInputFormatter(100),
              ],
              validator: (val) {
                final clean = val?.trim() ?? '';
                if (clean.isEmpty) return null;
                if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                  return 'Must contain alphabetic characters';
                }
                if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(clean)) {
                  return 'Only letters, spaces, and hyphens (-) are allowed';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Smoking & Alcohol Row
            if (isMobile) ...[
              _buildLabel('Smoking'),
              _buildDropdownField(
                value: _smokingStatus,
                hint: 'Select status',
                items: _smokingOptions,
                onChanged: (val) => setState(() => _smokingStatus = val),
                validator: (val) {
                  if (val != null &&
                      val.trim().isNotEmpty &&
                      !_smokingOptions.contains(val.trim())) {
                    return 'Please select a valid smoking status from the list';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Alcohol Usage'),
              _buildDropdownField(
                value: _alcoholStatus,
                hint: 'Select frequency',
                items: _alcoholOptions,
                onChanged: (val) => setState(() => _alcoholStatus = val),
                validator: (val) {
                  if (val != null &&
                      val.trim().isNotEmpty &&
                      !_alcoholOptions.contains(val.trim())) {
                    return 'Please select a valid alcohol usage from the list';
                  }
                  return null;
                },
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Smoking'),
                        _buildDropdownField(
                          value: _smokingStatus,
                          hint: 'Select status',
                          items: _smokingOptions,
                          onChanged: (val) =>
                              setState(() => _smokingStatus = val),
                          validator: (val) {
                            if (val != null &&
                                val.trim().isNotEmpty &&
                                !_smokingOptions.contains(val.trim())) {
                              return 'Please select a valid smoking status from the list';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Alcohol Usage'),
                        _buildDropdownField(
                          value: _alcoholStatus,
                          hint: 'Select frequency',
                          items: _alcoholOptions,
                          onChanged: (val) =>
                              setState(() => _alcoholStatus = val),
                          validator: (val) {
                            if (val != null &&
                                val.trim().isNotEmpty &&
                                !_alcoholOptions.contains(val.trim())) {
                              return 'Please select a valid alcohol usage from the list';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Physical Activity Level
            _buildLabel('Physical Activity Level'),
            _buildTextField(
              controller: _physicalActivityController,
              hint: 'Describe daily physical activities...',
              maxLines: 1,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                LengthLimitingTextInputFormatter(100),
              ],
              validator: (val) {
                final clean = val?.trim() ?? '';
                if (clean.isEmpty) return null;
                if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                  return 'Must contain alphabetic characters';
                }
                if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(clean)) {
                  return 'Only letters, spaces, and hyphens (-) are allowed';
                }
                return null;
              },
            ),
            const SizedBox(height: 48),

            // Action Buttons
            if (isMobile)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep = 2),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A5568),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_formKeyStep3.currentState!.validate()) {
                          setState(() => _currentStep = 4);
                        }
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'Next',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.logoRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStep = 2),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A5568),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKeyStep3.currentState!.validate()) {
                        setState(() => _currentStep = 4);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Next',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.logoRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewForm(bool isMobile) {
    String _val(String v) => v.isEmpty ? '-' : v;
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review & Confirmation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),

          // Basic Information Card
          _buildReviewCard(
            title: 'Basic Information',
            color: const Color(0xFFEBF8FF),
            borderColor: const Color(0xFFBEE3F8),
            onEdit: () => setState(() => _currentStep = 1),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReviewField('Name', _val(_nameController.text)),
                      _buildReviewField('Email', _val(_emailController.text)),
                      _buildReviewField(
                        'Age / DOB',
                        '${_val(_ageController.text)} / ${_val(_dobController.text)}',
                      ),
                      _buildReviewField('Gender', _val(_selectedGender ?? '')),
                      _buildReviewField('Phone', _val(_phoneController.text)),
                      _buildReviewField(
                        'Emergency Contact',
                        '${_val(_emergencyContactNameController.text)} (${_val(_emergencyContactRelationController.text)}) - ${_val(_emergencyContactPhoneController.text)}',
                      ),
                      _buildReviewField(
                        'Address Line 1',
                        _val(_addressController.text),
                      ),
                      if (_addressLine2Controller.text.isNotEmpty)
                        _buildReviewField(
                          'Address Line 2',
                          _addressLine2Controller.text,
                        ),
                      _buildReviewField(
                        'District / Pincode',
                        '${_val(_selectedDistrict ?? '')} / ${_val(_pincodeController.text)}',
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Name',
                              _val(_nameController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Email',
                              _val(_emailController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Age / DOB',
                              '${_val(_ageController.text)} / ${_val(_dobController.text)}',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Gender',
                              _val(_selectedGender ?? ''),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Phone',
                              _val(_phoneController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Emergency Contact',
                              '${_val(_emergencyContactNameController.text)} (${_val(_emergencyContactRelationController.text)})',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Emergency Mobile Number',
                              _val(_emergencyContactPhoneController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Address',
                              '${_val(_addressController.text)}${_addressLine2Controller.text.isNotEmpty ? ", " + _addressLine2Controller.text : ""}',
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'District / Pincode',
                              '${_val(_selectedDistrict ?? '')} / ${_val(_pincodeController.text)}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Medical Data Card
          _buildReviewCard(
            title: 'Medical Data',
            color: const Color(0xFFEBF8FF),
            borderColor: const Color(0xFFBEE3F8),
            onEdit: () => setState(() => _currentStep = 2),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReviewField(
                        'Height / Weight',
                        '${_val(_heightController.text)} cm / ${_val(_weightController.text)} kg',
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'BP',
                              _bpSystolicController.text.isEmpty &&
                                      _bpDiastolicController.text.isEmpty
                                  ? '-'
                                  : '${_bpSystolicController.text}/${_bpDiastolicController.text}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildReviewField(
                              'Sugar',
                              _val(_sugarController.text),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildReviewField(
                              'Temp',
                              _val(_tempController.text),
                            ),
                          ),
                        ],
                      ),
                      _buildReviewField(
                        'Blood Group',
                        _val(_bloodGroupController.text),
                      ),
                      _buildReviewField(
                        'Allergies',
                        _val(_allergiesController.text),
                      ),
                      _buildReviewField(
                        'Chronic Conditions',
                        _val(_chronicConditionsController.text),
                      ),
                      _buildReviewField(
                        'Reason for Visit',
                        _val(_complaintsController.text),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Height / Weight',
                              '${_val(_heightController.text)} cm / ${_val(_weightController.text)} kg',
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'BP',
                              _bpSystolicController.text.isEmpty &&
                                      _bpDiastolicController.text.isEmpty
                                  ? '-'
                                  : '${_bpSystolicController.text}/${_bpDiastolicController.text}',
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Sugar',
                              _val(_sugarController.text),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Temp',
                              _val(_tempController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Blood Group',
                              _val(_bloodGroupController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Allergies',
                              _val(_allergiesController.text),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Chronic Conditions',
                              _val(_chronicConditionsController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Reason for Visit',
                              _val(_complaintsController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Lifestyle Data Card
          _buildReviewCard(
            title: 'Lifestyle Data',
            color: const Color(0xFFF0FFF4),
            borderColor: const Color(0xFFC6F6D5),
            onEdit: () => setState(() => _currentStep = 3),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReviewField(
                        'Occupation',
                        _val(_occupationController.text),
                      ),
                      _buildReviewField(
                        'Hobbies',
                        _val(_hobbiesController.text),
                      ),
                      _buildReviewField(
                        'Food Habits',
                        _val(_foodHabitsController.text),
                      ),
                      _buildReviewField(
                        'Physical Activity',
                        _val(_physicalActivityController.text),
                      ),
                      _buildReviewField(
                        'Smoking Status',
                        _val(_smokingStatus ?? ''),
                      ),
                      _buildReviewField(
                        'Alcohol Status',
                        _val(_alcoholStatus ?? ''),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Occupation',
                              _val(_occupationController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Hobbies',
                              _val(_hobbiesController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Food Habits',
                              _val(_foodHabitsController.text),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildReviewField(
                              'Physical Activity',
                              _val(_physicalActivityController.text),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Smoking Status',
                              _val(_smokingStatus ?? ''),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildReviewField(
                              'Alcohol Status',
                              _val(_alcoholStatus ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 48),

          // Action Buttons
          if (isMobile)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _currentStep = 3),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A5568),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitPatientData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.logoRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Confirm & Complete',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep = 3),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A5568),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPatientData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.logoRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm & Complete',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required String title,
    required Color color,
    required Color borderColor,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildReviewField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2D3748)),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    final bool hasStar = label.endsWith(' *');
    final String baseText = hasStar
        ? label.substring(0, label.length - 2)
        : label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: RichText(
        text: TextSpan(
          text: baseText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Inter', // Ensuring consistency with theme
          ),
          children: [
            if (hasStar)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelAccent(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    int maxLines = 1,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E0), fontSize: 13),
        suffixIcon:
            suffixIcon ??
            (icon != null
                ? Icon(icon, color: const Color(0xFFCBD5E0), size: 18)
                : null),
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
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1),
        ),
        errorMaxLines: 2,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontSize: 11,
          color: AppTheme.dangerColor,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    final List<String> safeItems = items.toList();

    return CustomDropdownSearch(
      label: '', // Label is handled externally in this form via _buildLabel
      hint: hint,
      dropdownItems: safeItems,
      value: (value != null && safeItems.contains(value)) ? value : null,
      onChanged: onChanged,
      validator: validator,
      height: 52, // Match the height of text fields in the form
      borderColor: const Color(0xFFE2E8F0),
      focusedBorderColor: AppTheme.primaryColor,
    );
  }

  void _validateVitals() {
    final sysText = _bpSystolicController.text.trim();
    final diaText = _bpDiastolicController.text.trim();
    final sugarText = _sugarController.text.trim();
    final tempText = _tempController.text.trim();
    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    if (sysText.isNotEmpty) {
      final val = int.tryParse(sysText);
      if (val == null) throw 'BP Systolic must be an integer';
      if (val == 0) throw 'BP Systolic cannot be 0';
      if (val < 90 || val > 300)
        throw 'BP Systolic must be between 90 and 300 mmHg';
    }
    if (diaText.isNotEmpty) {
      final val = int.tryParse(diaText);
      if (val == null) throw 'BP Diastolic must be an integer';
      if (val == 0) throw 'BP Diastolic cannot be 0';
      if (val < 50 || val > 180)
        throw 'BP Diastolic must be between 50 and 180 mmHg';
    }
    if (sugarText.isNotEmpty) {
      final val = double.tryParse(sugarText);
      if (val == null) throw 'Sugar Level must be a number';
      if (val == 0) throw 'Sugar Level cannot be 0';
      if (val < 30 || val > 600)
        throw 'Sugar Level must be between 30 and 600 mg/dL';
    }
    if (tempText.isNotEmpty) {
      final val = double.tryParse(tempText);
      if (val == null) throw 'Temperature must be a number';
      if (val == 0) throw 'Temperature cannot be 0';
      if (val < 90 || val > 115)
        throw 'Temperature must be between 90 and 115 °F';
    }
    if (heightText.isNotEmpty) {
      final val = double.tryParse(heightText);
      if (val == null) throw 'Height must be a valid number';
      if (val <= 0) throw 'Height must be greater than 0';
    }
    if (weightText.isNotEmpty) {
      final val = double.tryParse(weightText);
      if (val == null) throw 'Weight must be a valid number';
      if (val <= 0) throw 'Weight must be greater than 0';
    }
  }

  Future<void> _submitPatientData() async {
    setState(() => _isSubmitting = true);

    try {
      _validateVitals();
      if (_nameController.text.trim().isEmpty ||
          _dobController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        throw Exception(
          'Please fill in name, date of birth, phone, and email before submitting.',
        );
      }

      final existing = _matchedExistingPatient ?? widget.existingPatient;
      final patient = PatientModel(
        id: existing?.id,
        patientId: existing?.patientId,
        name: _nameController.text.trim(),
        dob: _dobController.text.trim(),
        age: int.tryParse(_ageController.text.trim()) ?? 0,
        gender: _selectedGender ?? 'Unknown',
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        addressLine2: _addressLine2Controller.text.trim(),
        district: _selectedDistrict ?? '',
        pincode: _pincodeController.text.trim(),
        emergencyContactName: _emergencyContactNameController.text.trim(),
        emergencyContactRelation: _emergencyContactRelationController.text
            .trim(),
        emergencyContactPhone: _emergencyContactPhoneController.text.trim(),
        height: double.tryParse(_heightController.text.trim()) ?? 0.0,
        weight: double.tryParse(_weightController.text.trim()) ?? 0.0,
        bpSystolic: int.tryParse(_bpSystolicController.text.trim()) ?? 0,
        bpDiastolic: int.tryParse(_bpDiastolicController.text.trim()) ?? 0,
        sugar: double.tryParse(_sugarController.text.trim()) ?? 0.0,
        temp: double.tryParse(_tempController.text.trim()) ?? 0.0,
        bloodGroup: _bloodGroupController.text.trim(),
        allergies: _allergiesController.text.trim(),
        chronicConditions: _chronicConditionsController.text.trim(),
        complaints: _complaintsController.text.trim(),
        history: _historyController.text.trim(),
        smokingStatus: _smokingStatus ?? 'Never',
        alcoholStatus: _alcoholStatus ?? 'Never',
        occupation: _occupationController.text.trim(),
        hobbies: _hobbiesController.text.trim(),
        foodHabits: _foodHabitsController.text.trim(),
        physicalActivity: _physicalActivityController.text.trim(),
        isQuickRegister: existing?.isQuickRegister ?? false,
      );

      if (existing != null && existing.id != null) {
        await _patientController.updatePatient(existing.id!, patient);
      } else {
        // Pre-check for duplicate patient records by phone and name/email
        if (patient.phone != null && patient.phone!.trim().isNotEmpty) {
          final existingList = await _patientController.fetchPatientsByPhone(patient.phone!.trim());
          final duplicate = existingList.where((p) {
            final sameName = p.name != null &&
                patient.name != null &&
                p.name!.trim().toLowerCase() == patient.name!.trim().toLowerCase();
            final sameEmail = patient.email != null &&
                patient.email!.trim().isNotEmpty &&
                p.email != null &&
                p.email!.trim().isNotEmpty &&
                p.email!.trim().toLowerCase() == patient.email!.trim().toLowerCase();
            return sameName || sameEmail;
          }).toList();

          if (duplicate.isNotEmpty && mounted) {
            final dup = duplicate.first;
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.dangerColor,
                      size: 26,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Duplicate Patient Record',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A patient with identical details is already registered in the database:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• Patient ID: ${dup.patientId ?? "N/A"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Name: ${dup.name ?? "N/A"}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Mobile: ${dup.phone ?? "N/A"}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (dup.email != null && dup.email!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '• Email: ${dup.email}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Creating duplicate patient records with identical details is prevented.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.dangerColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: AppTheme.primaryButton,
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK, Review Details'),
                  ),
                ],
              ),
            );
            return;
          }
        }

        await _patientController.registerPatient(patient);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing != null
                  ? 'Patient Profile Updated successfully!'
                  : 'Patient registered successfully!',
            ),
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.toLowerCase().contains('already exists') ||
            errorMsg.toLowerCase().contains('duplicate')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.dangerColor,
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Duplicate Patient Record',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              content: Text(
                errorMsg,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                  height: 1.4,
                ),
              ),
              actions: [
                ElevatedButton(
                  style: AppTheme.primaryButton,
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK, Review Form'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);

        // Accurate age calculation including month/day/infant check
        final now = DateTime.now();
        int years = now.year - picked.year;
        int months = now.month - picked.month;
        int days = now.day - picked.day;
        if (days < 0) {
          months--;
          final prevMonth = DateTime(now.year, now.month, 0);
          days += prevMonth.day;
        }
        if (months < 0) {
          years--;
          months += 12;
        }

        if (years >= 1) {
          _ageController.text = years.toString();
        } else if (months >= 1) {
          _ageController.text = '$months month${months == 1 ? '' : 's'}';
        } else {
          _ageController.text = '$days day${days == 1 ? '' : 's'}';
        }
      });
    }
  }
}
