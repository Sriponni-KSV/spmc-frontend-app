import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class NewPatientRegistrationView extends StatefulWidget {
  final VoidCallback onBack;
  const NewPatientRegistrationView({Key? key, required this.onBack}) : super(key: key);

  @override
  State<NewPatientRegistrationView> createState() => _NewPatientRegistrationViewState();
}

class _NewPatientRegistrationViewState extends State<NewPatientRegistrationView> {
  int _currentStep = 1;

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  // Step 2 Controllers
  final TextEditingController _bpController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _complaintsController = TextEditingController();
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();

  // Step 3: Lifestyle Data
  String? _smokingStatus;
  String? _alcoholStatus;
  String? _dietType;
  String? _exerciseStatus;
  
  String? _selectedGender;
  String? _selectedDepartment;

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bpController.dispose();
    _sugarController.dispose();
    _tempController.dispose();
    _complaintsController.dispose();
    _historyController.dispose();
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
            const Text(
              'New Patient Registration',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Register a new patient with AI-powered voice input',
              style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
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
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: isMobile ? 12 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepItem(1, 'Basic', _currentStep >= 1, isCompleted: _currentStep > 1, isMobile: isMobile),
          _buildStepDivider(_currentStep > 1),
          _buildStepItem(2, 'Intake', _currentStep >= 2, isCompleted: _currentStep > 2, isMobile: isMobile),
          _buildStepDivider(_currentStep > 2),
          _buildStepItem(3, 'Lifestyle', _currentStep >= 3, isCompleted: _currentStep > 3, isMobile: isMobile),
          _buildStepDivider(_currentStep > 3),
          _buildStepItem(4, 'Review', _currentStep >= 4, isCompleted: _currentStep > 4, isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String label, bool isActive, {bool isCompleted = false, bool isMobile = false}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: isMobile ? 28 : 32,
            height: isMobile ? 28 : 32,
            decoration: BoxDecoration(
              color: (isActive || isCompleted) ? AppTheme.infoColor : const Color(0xFFEDF2F7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, color: Colors.white, size: isMobile ? 14 : 16)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF718096),
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
              fontWeight: (isActive || isCompleted) ? FontWeight.bold : FontWeight.normal,
              color:
                  (isActive || isCompleted) ? AppTheme.textPrimaryColor : const Color(0xFF718096),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
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
    return Container(
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

          // Full Name
          _buildLabel('Full Name *'),
          _buildTextField(
            controller: _nameController,
            hint: 'Enter patient\'s full name',
          ),
          const SizedBox(height: 24),

          // DOB & Age
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Date of Birth *'),
                    _buildTextField(
                      controller: _dobController,
                      hint: 'dd-mm-yyyy',
                      icon: Icons.calendar_today_outlined,
                      onTap: () => _selectDate(context),
                      readOnly: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Age *'),
                    _buildTextField(
                      controller: _ageController,
                      hint: 'Enter age',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gender & Phone
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Gender *'),
                    _buildDropdownField(
                      value: _selectedGender,
                      hint: 'Select gender',
                      items: ['Male', 'Female', 'Other'],
                      onChanged: (val) => setState(() => _selectedGender = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Phone Number *'),
                    _buildTextField(
                      controller: _phoneController,
                      hint: '+1 555-0100',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Department
          _buildLabel('Department *'),
          _buildDropdownField(
            value: _selectedDepartment,
            hint: 'Select department',
            items: ['General Medicine', 'Cardiology', 'Pediatrics', 'Orthopedics'],
            onChanged: (val) => setState(() => _selectedDepartment = val),
          ),
          const SizedBox(height: 24),

          // Address
          _buildLabel('Address'),
          _buildTextField(
            controller: _addressController,
            hint: 'Enter full address',
            maxLines: 4,
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
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53E3E),
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
                        Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                  child: const Row(
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
    );
  }

  Widget _buildMedicalIntakeForm(bool isMobile) {
    return Container(
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
                      style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
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
                  children: [
                    const Text(
                      'AI Voice Input: ',
                      style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.mic_none_outlined, size: 18),
                      label: const Text('Start Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D5D9A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const Text(
            'Vitals',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
          ),
          const SizedBox(height: 20),
          if (isMobile) ...[
            _buildLabel('Blood Pressure'),
            _buildTextField(controller: _bpController, hint: '120/80'),
            const SizedBox(height: 16),
            _buildLabel('Sugar Level'),
            _buildTextField(controller: _sugarController, hint: '100 mg/dL'),
            const SizedBox(height: 16),
            _buildLabel('Temperature'),
            _buildTextField(controller: _tempController, hint: '98.6°F'),
          ] else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Blood Pressure'),
                      _buildTextField(controller: _bpController, hint: '120/80'),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Sugar Level'),
                      _buildTextField(controller: _sugarController, hint: '100 mg/dL'),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Temperature'),
                      _buildTextField(controller: _tempController, hint: '98.6°F'),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Allergies and Medications Row
          if (isMobile) ...[
            _buildLabel('Allergies'),
            _buildTextField(
              controller: _allergiesController,
              hint: 'List any allergies (drugs, food, etc.)...',
            ),
            const SizedBox(height: 24),
            _buildLabel('Current Medications'),
            _buildTextField(
              controller: _medicationsController,
              hint: 'List current medications and dosages...',
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Allergies'),
                      _buildTextField(
                        controller: _allergiesController,
                        hint: 'List any allergies...',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Current Medications'),
                      _buildTextField(
                        controller: _medicationsController,
                        hint: 'List current medications...',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Chief Complaints
          _buildLabel('Chief Complaints'),
          _buildTextField(
            controller: _complaintsController,
            hint: 'Describe current health complaints...',
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Past Medical History
          _buildLabel('Past Medical History'),
          _buildTextField(
            controller: _historyController,
            hint: 'Previous conditions, surgeries, medications...',
            maxLines: 3,
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
                        icon: const Icon(Icons.description_outlined, size: 18),
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
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53E3E),
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
                        Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                  child: const Row(
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
    );
  }

  Widget _buildLifestyleDataForm(bool isMobile) {
    return Container(
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
            'Lifestyle Assessment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Lifestyle Grid
          if (isMobile) ...[
            _buildLabel('Smoking Status'),
            _buildDropdownField(
              value: _smokingStatus,
              hint: 'Select status',
              items: ['Never', 'Former', 'Current'],
              onChanged: (val) => setState(() => _smokingStatus = val),
            ),
            const SizedBox(height: 16),
            _buildLabel('Alcohol Consumption'),
            _buildDropdownField(
              value: _alcoholStatus,
              hint: 'Select frequency',
              items: ['None', 'Social', 'Regular', 'Occasional'],
              onChanged: (val) => setState(() => _alcoholStatus = val),
            ),
            const SizedBox(height: 16),
            _buildLabel('Diet Type'),
            _buildDropdownField(
              value: _dietType,
              hint: 'Select diet',
              items: ['Vegetarian', 'Non-Vegetarian', 'Vegan', 'Other'],
              onChanged: (val) => setState(() => _dietType = val),
            ),
            const SizedBox(height: 16),
            _buildLabel('Physical Activity'),
            _buildDropdownField(
              value: _exerciseStatus,
              hint: 'Select activity level',
              items: ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'],
              onChanged: (val) => setState(() => _exerciseStatus = val),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Smoking Status'),
                      _buildDropdownField(
                        value: _smokingStatus,
                        hint: 'Select status',
                        items: ['Never', 'Former', 'Current'],
                        onChanged: (val) => setState(() => _smokingStatus = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Alcohol Consumption'),
                      _buildDropdownField(
                        value: _alcoholStatus,
                        hint: 'Select frequency',
                        items: ['None', 'Social', 'Regular', 'Occasional'],
                        onChanged: (val) => setState(() => _alcoholStatus = val),
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
                      _buildLabel('Diet Type'),
                      _buildDropdownField(
                        value: _dietType,
                        hint: 'Select diet',
                        items: ['Vegetarian', 'Non-Vegetarian', 'Vegan', 'Other'],
                        onChanged: (val) => setState(() => _dietType = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Physical Activity'),
                      _buildDropdownField(
                        value: _exerciseStatus,
                        hint: 'Select activity level',
                        items: ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'],
                        onChanged: (val) => setState(() => _exerciseStatus = val),
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
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53E3E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Continue to Review', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                  child: const Text('Continue to Review', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReviewForm(bool isMobile) {
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
            'Review Patient Registration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          _buildReviewSection('Basic Details', [
            'Name: ${_nameController.text}',
            'Gender: ${_selectedGender ?? "Not Specified"}',
            'Age: ${_ageController.text}',
            'Department: ${_selectedDepartment ?? "Not Specified"}',
          ]),
          const SizedBox(height: 16),
          _buildReviewSection('Vitals Summary', [
            'BP: ${_bpController.text}',
            'Sugar: ${_sugarController.text}',
            'Temp: ${_tempController.text}',
          ]),
          const SizedBox(height: 16),
          _buildReviewSection('Medical Flags', [
            'Allergies: ${_allergiesController.text.isEmpty ? "None" : _allergiesController.text}',
            'Diet: ${_dietType ?? "Regular"}',
          ]),

          const SizedBox(height: 48),

          // Action Buttons
          if (isMobile)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep = 3),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Back to Edit'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38A169),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Finalize Registration', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 3),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Back to Edit'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Finalize Registration', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38A169),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF718096)),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(d, style: const TextStyle(fontSize: 14)),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A5568),
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
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              hint,
              style: const TextStyle(color: Color(0xFFCBD5E0), fontSize: 13),
            ),
          ),
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(item, style: const TextStyle(fontSize: 14)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.expand_more_rounded, color: Color(0xFFA0AEC0)),
          ),
        ),
      ),
    );
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
        _dobController.text = "${picked.day}-${picked.month}-${picked.year}";
        // Auto-calculate age
        _ageController.text = (DateTime.now().year - picked.year).toString();
      });
    }
  }
}
