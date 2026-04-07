import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../controllers/patient_controller.dart';

class PatientsView extends StatefulWidget {
  final List<PatientModel> patients;
  final bool isLoading;
  final String? error;
  final VoidCallback onRegisterPatient;
  final VoidCallback? onRefresh;

  const PatientsView({
    Key? key,
    required this.patients,
    required this.isLoading,
    this.error,
    required this.onRegisterPatient,
    this.onRefresh,
  }) : super(key: key);


  @override
  State<PatientsView> createState() => _PatientsViewState();
}

class _PatientsViewState extends State<PatientsView> {
  String _searchQuery = '';
  PatientModel? _selectedPatient;

  List<PatientModel> get _filteredPatients {
    if (_searchQuery.isEmpty) return widget.patients;
    final q = _searchQuery.toLowerCase();
    return widget.patients.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.phone.toLowerCase().contains(q) ||
          p.department.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Show patient detail when a patient is selected
    if (_selectedPatient != null) {
      return PatientDetailView(
        patient: _selectedPatient!,
        onBack: () => setState(() => _selectedPatient = null),
      );
    }

    final bool isMobile = MediaQuery.of(context).size.width < 900;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientsHeader(isMobile),
          const SizedBox(height: 24),
          _buildPatientsSearch(isMobile),
          const SizedBox(height: 32),
          const Text(
            'Recent Patients',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentPatientsRow(isMobile),
          const SizedBox(height: 32),
          _buildPatientsTable(isMobile),
        ],
      ),
    );
  }

  Widget _buildPatientsHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patients',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage patient records and information',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: widget.onRegisterPatient,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New Patient'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPatientsSearch(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search patients...',
                      hintStyle: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildFilterButton('Gender')),
              const SizedBox(width: 8),
              Expanded(child: _buildFilterButton('Department')),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, phone number, or department...',
                      hintStyle: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _showQuickRegisterDialog(context),
          icon: const Icon(Icons.flash_on, size: 18),
          label: const Text(
            'Quick Register',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D5D9A),
            foregroundColor: Colors.white,
            minimumSize: const Size(160, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 12),
        _buildFilterButton('Gender'),
        const SizedBox(width: 8),
        _buildFilterButton('Department'),
      ],
    );
  }

  Widget _buildRecentPatientsRow(bool isMobile) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.patients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('No recent patients found.'),
      );
    }

    final recentPatients = widget.patients.take(3).toList();
    List<Widget> cards = [];

    for (int i = 0; i < recentPatients.length; i++) {
      final patient = recentPatients[i];
      final String name = patient.name;
      final String age = patient.age.toString();
      final String gender = patient.gender;

      String initials = '?';
      if (name.trim().isNotEmpty) {
        final parts = name.trim().split(' ').where((p) => p.isNotEmpty).take(2).toList();
        if (parts.isNotEmpty) {
          initials = parts.map((p) => p[0].toUpperCase()).join('');
        }
      }

      cards.add(PatientInfoCard(
        name: name,
        info: '${age}y • $gender',
        initials: initials,
        tags: const [],
        onView: () => setState(() => _selectedPatient = patient),
        onBook: () {},
      ));

      if (i < recentPatients.length - 1) {
        cards.add(const SizedBox(width: 16));
      }
    }

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: cards),
      );
    }
    return Row(
      children: cards
          .map((c) => c is SizedBox ? c : Flexible(child: c))
          .toList(),
    );
  }

  Widget _buildPatientsTable(bool isMobile) {
    final patients = _filteredPatients;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFEDF2F7),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildTableHeaderText('Name')),
                Expanded(child: _buildTableHeaderText('Age')),
                if (!isMobile) Expanded(child: _buildTableHeaderText('Gender')),
                if (!isMobile)
                  Expanded(flex: 2, child: _buildTableHeaderText('Contact')),
                if (!isMobile)
                  Expanded(flex: 2, child: _buildTableHeaderText('Department')),
                Expanded(child: _buildTableHeaderText('Status')),
                Expanded(flex: 2, child: _buildTableHeaderText('Actions')),
              ],
            ),
          ),
          // Table Rows
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (patients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No patients found')),
            )
          else
            ...patients.map((patient) {
              final String name = patient.name;
              final parts = name
                  .trim()
                  .split(' ')
                  .where((p) => p.isNotEmpty)
                  .take(2)
                  .toList();
              final String initials = parts.isNotEmpty
                  ? parts.map((p) => p[0].toUpperCase()).join('')
                  : '?';

              return Column(
                children: [
                  _buildPatientTableRow(
                    patient,
                    name,
                    '${patient.age}y',
                    patient.gender,
                    patient.phone,
                    patient.department,
                    'Active',
                    initials,
                    patient.isQuickRegister ? ['Quick'] : [],
                    isMobile,
                  ),

                  const Divider(height: 1),
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Color(0xFF4A5568),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPatientTableRow(
    PatientModel patient,
    String name,
    String age,
    String gender,
    String contact,
    String department,
    String status,
    String initials,
    List<String> tags,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF0D5D9A),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF2D3748),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            children: tags.map((t) => HealthTag(label: t)).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              age,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
            ),
          ),
          if (!isMobile)
            Expanded(
              child: Text(
                gender,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
              ),
            ),
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                contact,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
              ),
            ),
          if (!isMobile)
            Expanded(
              flex: 2,
              child: Text(
                department,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
              ),
            ),
          Expanded(child: StatusChip(status: status)),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _buildActionLabel(
                  Icons.visibility_outlined,
                  'View',
                  const Color(0xFF3182CE),
                  onTap: () => setState(() => _selectedPatient = patient),
                ),
                const SizedBox(width: 12),
                _buildActionLabel(
                  Icons.calendar_month_outlined,
                  'Book',
                  const Color(0xFF38A169),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLabel(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppTheme.textSecondaryColor,
          ),
        ],
      ),
    );
  }

  void _showQuickRegisterDialog(BuildContext context) {
    final PatientController patientController = PatientController();
    String? selectedGender;
    String? selectedDepartment;
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController dobCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController reasonCtrl = TextEditingController();

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Patient Registration',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fast check-in with minimal details',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, size: 20, color: AppTheme.textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderColor),
                    // Form body
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickFieldLabel('Full Name'),
                          _buildQuickTextField(controller: nameCtrl, hint: 'Enter patient\'s full name'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildQuickFieldLabel('Date of Birth'),
                                    _buildQuickTextField(
                                      controller: dobCtrl, 
                                      hint: 'YYYY-MM-DD',
                                      icon: Icons.calendar_today_outlined,
                                      readOnly: true,
                                      onTap: () async {
                                        DateTime? pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            dobCtrl.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                                          });
                                        }
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
                                    _buildQuickFieldLabel('Phone Number'),
                                    _buildQuickTextField(
                                      controller: phoneCtrl, 
                                      hint: '98765 43210',
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                    ),

                                  ],
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
                                    _buildQuickFieldLabel('Department'),
                                    Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppTheme.borderColor),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: selectedDepartment,
                                          hint: const Text('Select', style: TextStyle(fontSize: 14)),
                                          items: const [
                                            DropdownMenuItem(value: 'Cardiology', child: Text('Cardiology', style: TextStyle(fontSize: 14))),
                                            DropdownMenuItem(value: 'Neurology', child: Text('Neurology', style: TextStyle(fontSize: 14))),
                                            DropdownMenuItem(value: 'Orthopedics', child: Text('Orthopedics', style: TextStyle(fontSize: 14))),
                                            DropdownMenuItem(value: 'General', child: Text('General', style: TextStyle(fontSize: 14))),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              selectedDepartment = val;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildQuickFieldLabel('Gender'),
                                    Container(
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppTheme.borderColor),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: selectedGender,
                                          hint: const Text('Select', style: TextStyle(fontSize: 14)),
                                          items: const [
                                            DropdownMenuItem(value: 'Male', child: Text('Male', style: TextStyle(fontSize: 14))),
                                            DropdownMenuItem(value: 'Female', child: Text('Female', style: TextStyle(fontSize: 14))),
                                            DropdownMenuItem(value: 'Other', child: Text('Other', style: TextStyle(fontSize: 14))),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              selectedGender = val;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      const SizedBox(height: 16),
                      _buildQuickFieldLabel('Reason for Visit'),
                      _buildQuickTextField(controller: reasonCtrl, hint: 'Brief description of symptoms or reason...', maxLines: 3),

                      const SizedBox(height: 24),
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: const BorderSide(color: AppTheme.borderColor),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                           Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving ? null : () async {
                                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || dobCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter name, dob, and phone number')),
                                  );
                                  return;
                                }


                                setState(() => isSaving = true);

                                try {
                                  int calculatedAge = 0;
                                  if (dobCtrl.text.isNotEmpty) {
                                    try {
                                      // Use DateFormat to parse precisely
                                      final dob = DateFormat('yyyy-MM-dd').parse(dobCtrl.text);
                                      final now = DateTime.now();
                                      calculatedAge = now.year - dob.year;
                                      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
                                        calculatedAge--;
                                      }
                                    } catch (e) {
                                      debugPrint('Error parsing DOB for age: $e');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Invalid Date Format: ${dobCtrl.text}')),
                                        );
                                      }
                                      setState(() => isSaving = false);
                                      return;
                                    }
                                  }

                                  final newPatient = PatientModel(
                                    name: nameCtrl.text.trim(),
                                    dob: dobCtrl.text.trim(),
                                    age: calculatedAge,
                                    gender: selectedGender ?? 'Other',
                                    phone: phoneCtrl.text.trim(),
                                    department: selectedDepartment ?? 'General',
                                    address: '',
                                    height: 0.0,
                                    weight: 0.0,
                                    bpSystolic: 0,
                                    bpDiastolic: 0,
                                    sugar: 0.0,
                                    temp: 0.0,
                                    complaints: reasonCtrl.text.trim(),
                                    history: '',
                                    smokingStatus: 'No',
                                    alcoholStatus: 'No',
                                    occupation: '',
                                    hobbies: '',
                                    foodHabits: '',
                                    physicalActivity: '',
                                    isQuickRegister: true,
                                  );


                                  await patientController.registerPatient(newPatient);

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Patient registered successfully!')),
                                    );
                                    // Trigger a refresh if possible
                                    if (widget.onRefresh != null) {
                                      widget.onRefresh!();
                                    }
                                  }

                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: ${e.toString()}')),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setState(() => isSaving = false);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53E3E), // Red color from design
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: isSaving 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Register & Check In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
                // Footer link
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                  ),
                  child: Center(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onRegisterPatient();
                      },
                      child: const Text(
                        'Need full registration with complete details?',
                        style: TextStyle(
                          color: Color(0xFF3182CE),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildQuickFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryColor),
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: Color(0xFFE53E3E))),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: icon != null ? Icon(icon, size: 18, color: AppTheme.textSecondaryColor) : null,
          isDense: true,
        ),
      ),
    );
  }


}
class PatientDetailView extends StatefulWidget {
  final PatientModel patient;
  final VoidCallback onBack;

  const PatientDetailView({
    Key? key,
    required this.patient,
    required this.onBack,
  }) : super(key: key);

  @override
  State<PatientDetailView> createState() => _PatientDetailViewState();
}

class _PatientDetailViewState extends State<PatientDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.patient.name
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    return parts.isNotEmpty
        ? parts.map((p) => p[0].toUpperCase()).join('')
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final p = widget.patient;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 18, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Back to Patients',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Patient Header Card
          _buildHeaderCard(p, isMobile),
          const SizedBox(height: 20),

          // Current Vitals
          _buildVitalsCard(p, isMobile),
          const SizedBox(height: 20),

          // Tabs Section
          _buildTabsSection(p, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(PatientModel p, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0D5D9A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isMobile
          ? _buildHeaderMobile(p)
          : _buildHeaderDesktop(p),
    );
  }

  Widget _buildHeaderDesktop(PatientModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Name + Tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${p.age} years â€¢ ${p.gender}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                        ),
                      ),
                      if (p.department.isNotEmpty) ...[
                        Text(
                          ' â€¢ ',
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                        Text(
                          p.department,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _buildHealthTags(p),
                  ),
                ],
              ),
            ),
            // Action Buttons
            Row(
              children: [
                _buildHeaderButton(Icons.calendar_month_outlined, 'Book Appointment'),
                const SizedBox(width: 12),
                _buildHeaderButton(Icons.note_add_outlined, 'Add Notes'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 16),
        // Contact Info Row
        Row(
          children: [
            if (p.phone.isNotEmpty) ...[
              _buildContactItem(Icons.phone_outlined, p.phone),
              const SizedBox(width: 32),
            ],
            if (p.dob.isNotEmpty) ...[
              _buildContactItem(Icons.cake_outlined, 'DOB: ${p.dob}'),
              const SizedBox(width: 32),
            ],
            if (p.address.isNotEmpty)
              Flexible(child: _buildContactItem(Icons.location_on_outlined, p.address)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderMobile(PatientModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.age} years â€¢ ${p.gender}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: _buildHealthTags(p)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildHeaderButton(Icons.calendar_month_outlined, 'Book Appt.'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHeaderButton(Icons.note_add_outlined, 'Add Notes'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 12),
        if (p.phone.isNotEmpty) _buildContactItem(Icons.phone_outlined, p.phone),
        if (p.address.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildContactItem(Icons.location_on_outlined, p.address),
        ],
      ],
    );
  }

  List<Widget> _buildHealthTags(PatientModel p) {
    final tags = <Widget>[];
    if (p.smokingStatus.toLowerCase() != 'never' &&
        p.smokingStatus.isNotEmpty &&
        p.smokingStatus.toLowerCase() != 'no') {
      tags.add(_buildTag('Smoker'));
    }
    if (p.alcoholStatus.toLowerCase() == 'regular') {
      tags.add(_buildTag('Alcohol'));
    }
    if (p.history.toLowerCase().contains('diabet')) {
      tags.add(_buildTag('Diabetic'));
    }
    if (p.complaints.isNotEmpty) {
      tags.add(_buildTag('Active Complaints'));
    }
    if (tags.isEmpty) {
      tags.add(_buildTag(p.department.isNotEmpty ? p.department : 'General'));
    }
    return tags;
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsCard(PatientModel p, bool isMobile) {
    final vitals = [
      _VitalItem(
        label: 'Blood Pressure',
        value: (p.bpSystolic == 0 && p.bpDiastolic == 0)
            ? 'â€”'
            : '${p.bpSystolic}/${p.bpDiastolic} mmHg',
        unit: 'Systolic / Diastolic',
        color: const Color(0xFFEBF8FF),
        textColor: const Color(0xFF2B6CB0),
      ),
      _VitalItem(
        label: 'Sugar Level',
        value: '${p.sugar} mg/dL',
        color: const Color(0xFFFFF5F5),
        textColor: const Color(0xFFC53030),
      ),
      _VitalItem(
        label: 'Temperature',
        value: '${p.temp}Â°F',
        color: const Color(0xFFFFFAF0),
        textColor: const Color(0xFFDD6B20),
      ),
      _VitalItem(
        label: 'Occupation',
        value: p.occupation.isNotEmpty ? p.occupation : 'â€”',
        color: const Color(0xFFF0FFF4),
        textColor: const Color(0xFF276749),
      ),
      _VitalItem(
        label: 'Department',
        value: p.department.isNotEmpty ? p.department : 'â€”',
        color: const Color(0xFFFAF5FF),
        textColor: const Color(0xFF6B46C1),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Vitals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (isMobile)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: vitals
                  .map((v) => SizedBox(width: 150, child: _buildVitalBox(v)))
                  .toList(),
            )
          else
            Row(
              children: vitals
                  .map((v) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildVitalBox(v),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildVitalBox(_VitalItem vital) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: vital.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vital.label,
            style: TextStyle(
              fontSize: 11,
              color: vital.textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vital.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: vital.textColor,
            ),
          ),
          if (vital.unit != null) ...[
            const SizedBox(height: 4),
            Text(
              vital.unit!,
              style: TextStyle(
                fontSize: 10,
                color: vital.textColor.withOpacity(0.55),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabsSection(PatientModel p, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Medical History'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timeline_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Visits Timeline'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.self_improvement_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Lifestyle Data'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Content
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMedicalHistoryTab(p),
                _buildVisitsTimelineTab(p),
                _buildLifestyleTab(p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryTab(PatientModel p) {
    final hasHistory = p.history.isNotEmpty;
    final hasComplaints = p.complaints.isNotEmpty;

    if (!hasHistory && !hasComplaints) {
      return const Center(
        child: Text(
          'No medical history recorded.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasComplaints) ...[
            const Text(
              'Chief Complaints',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildHistoryItem(
              icon: Icons.error_outline,
              iconColor: const Color(0xFFE53E3E),
              title: p.complaints,
              subtitle: 'Current',
              status: 'Active',
              statusColor: const Color(0xFFE53E3E),
              statusBg: const Color(0xFFFFF5F5),
            ),
            const SizedBox(height: 20),
          ],
          if (hasHistory) ...[
            const Text(
              'Past Medical History',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            ...p.history
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHistoryItem(
                        icon: Icons.info_outline,
                        iconColor: const Color(0xFFE53E3E),
                        title: line.trim(),
                        subtitle: 'Past record',
                        status: 'Managed',
                        statusColor: const Color(0xFF38A169),
                        statusBg: const Color(0xFFF0FFF4),
                      ),
                    ))
                .toList(),
            if (p.history.split('\n').where((l) => l.trim().isNotEmpty).length == 1 &&
                !p.history.contains('\n'))
              _buildHistoryItem(
                icon: Icons.info_outline,
                iconColor: const Color(0xFFE53E3E),
                title: p.history,
                subtitle: 'Past record',
                status: 'Managed',
                statusColor: const Color(0xFF38A169),
                statusBg: const Color(0xFFF0FFF4),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required Color statusBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
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
        ],
      ),
    );
  }

  Widget _buildVisitsTimelineTab(PatientModel p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineItem(
            date: p.dob.isNotEmpty ? 'Registration Visit' : 'Initial Visit',
            time: p.dob.isNotEmpty ? p.dob : 'â€”',
            dept: p.department,
            description: p.complaints.isNotEmpty
                ? p.complaints
                : 'General consultation',
            isFirst: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String date,
    required String time,
    required String dept,
    required String description,
    bool isFirst = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isFirst ? AppTheme.primaryColor : AppTheme.borderColor,
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 2, height: 80, color: AppTheme.borderColor),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    dept,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLifestyleTab(PatientModel p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildLifestyleCard(
                  'Occupation',
                  p.occupation.isNotEmpty ? p.occupation : 'â€”',
                  const Color(0xFFEEF2F7),
                  const Color(0xFF4A5568),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLifestyleCard(
                  'Hobbies',
                  p.hobbies.isNotEmpty ? p.hobbies : 'â€”',
                  const Color(0xFFEEF2F7),
                  const Color(0xFF4A5568),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLifestyleCard(
            'Food Habits',
            p.foodHabits.isNotEmpty ? p.foodHabits : 'â€”',
            const Color(0xFFEEF2F7),
            const Color(0xFF4A5568),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildLifestyleCard(
                  'Smoking',
                  p.smokingStatus.isNotEmpty ? p.smokingStatus : 'â€”',
                  const Color(0xFFFFF7ED),
                  const Color(0xFF9A3412),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLifestyleCard(
                  'Alcohol Usage',
                  p.alcoholStatus.isNotEmpty ? p.alcoholStatus : 'â€”',
                  const Color(0xFFFEFCE8),
                  const Color(0xFF713F12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLifestyleCard(
            'Physical Activity',
            p.physicalActivity.isNotEmpty ? p.physicalActivity : 'â€”',
            const Color(0xFFEEF2F7),
            const Color(0xFF4A5568),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleCard(
    String label,
    String value,
    Color bgColor,
    Color labelColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: labelColor.withOpacity(0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalItem {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final Color textColor;

  _VitalItem({
    required this.label,
    required this.value,
    this.unit,
    required this.color,
    required this.textColor,
  });
}

