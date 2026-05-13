import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../models/patient_model.dart';

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
    'Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore',
    'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kancheepuram',
    'Kanyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai',
    'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai',
    'Ramanathapuram', 'Ranipet', 'Salem', 'Sivaganga', 'Tenkasi',
    'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli',
    'Tirupathur', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur',
    'Vellore', 'Viluppuram', 'Virudhunagar',
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

  // New Medical Fields
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _chronicConditionsController =
      TextEditingController();

  final TextEditingController _complaintsController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();

  // Step 3: Lifestyle Data
  String? _smokingStatus;
  String? _alcoholStatus;
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();
  final TextEditingController _foodHabitsController = TextEditingController();
  final TextEditingController _physicalActivityController =
      TextEditingController();
  String? _selectedGender;

  // Form keys for validation
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.existingPatient != null) {
      _preFillForm();
    }
  }

  void _preFillForm() {
    final p = widget.existingPatient!;
    _nameController.text = p.name;
    _dobController.text = p.dob;
    _ageController.text = p.age > 0 ? p.age.toString() : '';
    _phoneController.text = p.phone;
    _emailController.text = p.email;
    _addressController.text = p.address;
    _addressLine2Controller.text = p.addressLine2;
    _selectedDistrict = _tamilNaduDistricts.contains(p.district) ? p.district : null;
    _pincodeController.text = p.pincode;
    _selectedGender = p.gender;

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
    _allergiesController.text = p.allergies;
    _chronicConditionsController.text = p.chronicConditions;
    _complaintsController.text = p.complaints;
    _historyController.text = p.history;

    // Lifestyle
    _smokingStatus = (p.smokingStatus == 'No' || p.smokingStatus.isEmpty)
        ? 'Never'
        : p.smokingStatus;
    _alcoholStatus = (p.alcoholStatus == 'No' || p.alcoholStatus.isEmpty)
        ? 'Never'
        : p.alcoholStatus;
    _occupationController.text = p.occupation;
    _hobbiesController.text = p.hobbies;
    _foodHabitsController.text = p.foodHabits;
    _physicalActivityController.text = p.physicalActivity;
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 48.0,
        vertical: 32.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button & Header
          InkWell(
            onTap: widget.onBack,
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
          const SizedBox(height: 24),
          Text(
            widget.existingPatient != null
                ? (widget.existingPatient!.isQuickRegister
                      ? 'Complete Patient Profile'
                      : 'Edit Patient Profile')
                : 'New Patient Registration',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 4),
          Text(
            widget.existingPatient != null
                ? 'Update patient information and medical history'
                : 'Register a new patient with AI-powered voice input',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
          const SizedBox(height: 32),

          // Stepper UI
          _buildRegistrationStepper(isMobile),
          const SizedBox(height: 32),

          // Form Content
          _buildStepContent(isMobile),
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
        vertical: 24,
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
            'Medical\nIntake',
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
            width: isMobile ? 28 : 32,
            height: isMobile ? 28 : 32,
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
                        fontSize: isMobile ? 10 : 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 9 : 11,
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
        margin: const EdgeInsets.only(bottom: 24),
      ),
    );
  }

  Widget _buildBasicDetailsForm(bool isMobile) {
    return Form(
      key: _formKeyStep1,
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
              'Basic Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Full Name & Email
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
                            RegExp(r'[a-zA-Z\s]'),
                          ),
                        ],
                        validator: (val) => val == null || val.isEmpty
                            ? 'Full name is required'
                            : null,
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
                        hint: 'patient@example.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.isEmpty)
                            return 'Email is required';
                          if (!val.contains('@'))
                            return 'Enter a valid email address';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DOB & Gender
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
                            ? 'DOB is required'
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
                        validator: (val) => val == null || val.isEmpty
                            ? 'Gender is required'
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Phone Number & Emergency Contact
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
                        hint: '98765 43210',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (val) {
                          if (val == null || val.isEmpty)
                            return 'Mobile number is required';
                          if (val.length != 10)
                            return 'Enter a valid 10-digit mobile number';
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
                      _buildLabel('Emergency Contact Name *'),
                      _buildTextField(
                        controller: _emergencyContactNameController,
                        hint: 'Enter name',
                        validator: (val) => val == null || val.isEmpty
                            ? 'Emergency contact name is required'
                            : null,
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
                        hint: 'e.g. Spouse, Parent',
                        validator: (val) => val == null || val.isEmpty
                            ? 'Relation is required'
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
                      _buildLabel('Emergency Mobile Number *'),
                      _buildTextField(
                        controller: _emergencyContactPhoneController,
                        hint: '98765 43210',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (val) {
                          if (val == null || val.isEmpty)
                            return 'Emergency mobile number is required';
                          if (val.length != 10)
                            return 'Enter a valid 10-digit mobile number';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Address Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Address Line 1 *'),
                      _buildTextField(
                        controller: _addressController,
                        hint: 'Door No, Building Name',
                        validator: (val) => val == null || val.isEmpty
                            ? 'Address Line 1 is required'
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
                      _buildLabel('Address Line 2'),
                      _buildTextField(
                        controller: _addressLine2Controller,
                        hint: 'Street Name, Locality',
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
                        onChanged: (val) => setState(() => _selectedDistrict = val),
                        validator: (val) => val == null || val.isEmpty
                            ? 'District is required'
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
                      _buildLabel('Pincode *'),
                      _buildTextField(
                        controller: _pincodeController,
                        hint: '600001',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (val) {
                          if (val == null || val.isEmpty)
                            return 'Pincode is required';
                          if (val.length != 6) return 'Enter a valid 6-digit pincode';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Action Buttons
            if (isMobile)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Save as Draft'),
                      style: AppTheme.outlinedButton.copyWith(
                        minimumSize: MaterialStateProperty.all(const Size(0, 52)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKeyStep1.currentState!.validate()) {
                          setState(() => _currentStep = 2);
                        }
                      },
                      style: AppTheme.primaryButton.copyWith(
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
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Save as Draft'),
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
                  ElevatedButton(
                    onPressed: () {
                      if (_formKeyStep1.currentState!.validate()) {
                        setState(() => _currentStep = 2);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
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
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medical Intake',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'AI Voice Input: ',
                        style: TextStyle(
                          color: Color(0xFF4A5568),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.mic_none_outlined, size: 18),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D5D9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Medical Intake',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AI Voice Input: ',
                        style: TextStyle(
                          color: Color(0xFF4A5568),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.mic_none_outlined, size: 18),
                        label: const Text('Start Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D5D9A),
                          foregroundColor: Colors.white,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
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
            // Vitals Section
            const SizedBox(height: 24),
            const Text(
              'Vitals',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
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
                      hint: '170 cm',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      hint: '70 kg',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
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
                      hint: '120',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      hint: '80',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                          hint: 'mg/dL',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
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
                          hint: '°F',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Blood Group *'),
              _buildDropdownField(
                value: _bloodGroupController.text.isNotEmpty
                    ? _bloodGroupController.text
                    : null,
                hint: 'Select Blood Group',
                items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
                onChanged: (val) =>
                    setState(() => _bloodGroupController.text = val ?? ''),
                validator: (val) => val == null || val.isEmpty
                    ? 'Blood Group is required'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Known Allergies'),
              _buildTextField(
                controller: _allergiesController,
                hint: 'e.g. Penicillin, Peanuts',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildLabel('Chronic Conditions'),
              _buildTextField(
                controller: _chronicConditionsController,
                hint: 'e.g. Diabetes, Hypertension',
                maxLines: 2,
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
                                hint: '170 cm',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _weightController,
                                hint: '70 kg',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
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
                                hint: '120',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _bpDiastolicController,
                                hint: '80',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
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
                                hint: 'mg/dL',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _tempController,
                                hint: '°F',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
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
                        _buildLabel('Blood Group *'),
                        _buildDropdownField(
                          value: _bloodGroupController.text.isNotEmpty
                              ? _bloodGroupController.text
                              : null,
                          hint: 'Select Blood Group',
                          items: [
                            'A+',
                            'A-',
                            'B+',
                            'B-',
                            'O+',
                            'O-',
                            'AB+',
                            'AB-',
                          ],
                          onChanged: (val) => setState(
                            () => _bloodGroupController.text = val ?? '',
                          ),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Blood Group is required'
                              : null,
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
                          hint: 'e.g. Penicillin, Peanuts',
                          maxLines: 2,
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
                          hint: 'e.g. Diabetes, Hypertension',
                          maxLines: 2,
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
            ),
            const SizedBox(height: 24),

            // Past Medical History
            _buildLabelAccent('Past Medical History'),
            _buildTextField(
              controller: _historyController,
              hint: 'Previous conditions, surgeries, medications...',
              maxLines: 4,
            ),
            const SizedBox(height: 48),

            // Action Buttons
            if (isMobile)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                          label: const Text('Save'),
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
                    ],
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
                        backgroundColor: AppTheme.primaryColor,
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
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Save as Draft'),
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
                      backgroundColor: AppTheme.primaryColor,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),

            // Occupation & Hobbies Row
            if (isMobile) ...[
              _buildLabel('Occupation'),
              _buildTextField(
                controller: _occupationController,
                hint: 'Enter occupation',
              ),
              const SizedBox(height: 20),
              _buildLabel('Hobbies'),
              _buildTextField(
                controller: _hobbiesController,
                hint: 'e.g., gardening, walking',
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
                          hint: 'e.g., gardening, walking',
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
            ),
            const SizedBox(height: 24),

            // Smoking & Alcohol Row
            if (isMobile) ...[
              _buildLabel('Smoking'),
              _buildDropdownField(
                value: _smokingStatus,
                hint: 'Select status',
                items: ['Never', 'Former smoker', 'Current smoker'],
                onChanged: (val) => setState(() => _smokingStatus = val),
              ),
              const SizedBox(height: 16),
              _buildLabel('Alcohol Usage'),
              _buildDropdownField(
                value: _alcoholStatus,
                hint: 'Select frequency',
                items: ['Never', 'Occasional', 'Regular'],
                onChanged: (val) => setState(() => _alcoholStatus = val),
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
                          items: ['Never', 'Former smoker', 'Current smoker'],
                          onChanged: (val) =>
                              setState(() => _smokingStatus = val),
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
                          items: ['Never', 'Occasional', 'Regular'],
                          onChanged: (val) =>
                              setState(() => _alcoholStatus = val),
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
            ),
            const SizedBox(height: 48),

            // Action Buttons
            if (isMobile)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                          label: const Text('Save as Draft'),
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
                    ],
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
                        backgroundColor: AppTheme.primaryColor,
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
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Save as Draft'),
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
                      backgroundColor: AppTheme.primaryColor,
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      _buildReviewField('Address Line 1', _val(_addressController.text)),
                      if (_addressLine2Controller.text.isNotEmpty)
                        _buildReviewField('Address Line 2', _addressLine2Controller.text),
                      _buildReviewField('District / Pincode', '${_val(_selectedDistrict ?? '')} / ${_val(_pincodeController.text)}'),
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
                Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('Save as Draft'),
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
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitPatientData,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Confirm & Complete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
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
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Save as Draft'),
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
                  onPressed: _isSubmitting ? null : _submitPatientData,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text(
                    'Confirm & Complete',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A5568),
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
          fontSize: 14,
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
    int maxLines = 1,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E0), fontSize: 13),
        suffixIcon: icon != null
            ? Icon(icon, color: const Color(0xFFCBD5E0), size: 18)
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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
    // Safety check: ensure 'value' is actually in 'items' to prevent common Flutter DropdownButton crashes.
    final Set<String> uniqueItems = {...items};
    if (value != null && value.isNotEmpty) {
      uniqueItems.add(value);
    }
    final List<String> safeItems = uniqueItems.toList();

    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E0), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      icon: const Icon(Icons.expand_more_rounded, color: Color(0xFFA0AEC0)),
      isExpanded: true,
      items: safeItems.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _submitPatientData() async {
    setState(() => _isSubmitting = true);

    try {
      if (_nameController.text.trim().isEmpty ||
          _dobController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        throw Exception(
          'Please fill in name, date of birth, phone, and email before submitting.',
        );
      }

      final patient = PatientModel(
        id: widget.existingPatient?.id,
        patientId: widget.existingPatient?.patientId,
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
        isQuickRegister: widget.existingPatient?.isQuickRegister ?? false,
      );

      if (widget.existingPatient != null &&
          widget.existingPatient!.id != null) {
        await _patientController.updatePatient(
          widget.existingPatient!.id!,
          patient,
        );
      } else {
        await _patientController.registerPatient(patient);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingPatient != null
                  ? 'Patient profile completed successfully!'
                  : 'Patient registered successfully!',
            ),
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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

        // Accurate age calculation including month/day check
        final now = DateTime.now();
        int age = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _ageController.text = age.toString();
      });
    }
  }
}
