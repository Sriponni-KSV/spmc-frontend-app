import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../controllers/appointment_controller.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../providers/auth_provider.dart';

class DoctorsView extends StatefulWidget {
  final Function(UserModel)? onBookAppointment;
  const DoctorsView({Key? key, this.onBookAppointment}) : super(key: key);

  @override
  State<DoctorsView> createState() => _DoctorsViewState();
}

class _DoctorsViewState extends State<DoctorsView> {
  final AdminController _adminController = AdminController();
  final AppointmentController _appointmentController = AppointmentController();
  Future<List<UserModel>>? _doctorsFuture;
  List<AppointmentModel> _appointments = [];
  String _searchQuery = '';
  String _selectedDepartment = 'All';

  final ScrollController _deptScrollController = ScrollController();
  bool _showRightArrow = false;
  bool _showLeftArrow = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _deptScrollController.addListener(_scrollListener);
    // Delay check to see if content is scrollable initially
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollListener());
  }

  @override
  void dispose() {
    _deptScrollController.removeListener(_scrollListener);
    _deptScrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_deptScrollController.hasClients) {
      final bool canScrollLeft = _deptScrollController.offset > 10;
      final bool canScrollRight = _deptScrollController.offset < _deptScrollController.position.maxScrollExtent - 10;
      
      if (canScrollLeft != _showLeftArrow || canScrollRight != _showRightArrow) {
        setState(() {
          _showLeftArrow = canScrollLeft;
          _showRightArrow = canScrollRight;
        });
      }
    }
  }


  void _loadDoctors() async {
    if (mounted) {
      setState(() {
        _doctorsFuture = _adminController.fetchStaff(role: 'Doctor');
      });
    }
    try {
      final appts = await _appointmentController.fetchAppointments();
      if (mounted) {
        setState(() {
          _appointments = appts;
        });
      }
    } catch (e) {
      debugPrint('Error loading appointments in DoctorsView: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Container(
          padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 24, isMobile ? 16 : 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Doctors',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage doctor profiles and schedules',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Search Bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          child: Container(
            height: 48,
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
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search doctors by name or specialization...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Body Content
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: _doctorsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final doctors = (snapshot.data ?? [])
                  .where((d) => d.status.toLowerCase() == 'active')
                  .toList();
              
              // Calculate dynamic departments from registered doctors
              final Map<String, int> deptCounts = {};
              for (var doc in doctors) {
                final spec = doc.specialization ?? 'General Medicine';
                deptCounts[spec] = (deptCounts[spec] ?? 0) + 1;
              }
              
              final List<Map<String, dynamic>> dynamicDepartments = deptCounts.entries.map<Map<String, dynamic>>((e) {
                IconData icon;
                switch (e.key.toLowerCase()) {
                  case 'cardiology': icon = Icons.favorite_outline; break;
                  case 'endocrinology': icon = Icons.monitor_heart_outlined; break;
                  case 'orthopedics': icon = Icons.airline_seat_legroom_extra_outlined; break;
                  case 'pediatrics': icon = Icons.child_care; break;
                  case 'neurology': icon = Icons.psychology_outlined; break;
                  default: icon = Icons.medical_services_outlined; break;
                }
                return <String, dynamic>{'name': e.key, 'icon': icon, 'count': e.value};
              }).toList();

              // Sort departments alphabetically
              dynamicDepartments.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

              // Add "All" option to the beginning
              dynamicDepartments.insert(0, <String, dynamic>{
                'name': 'All',
                'icon': Icons.apps_outlined,
                'count': doctors.length,
              });

              final filteredDoctors = doctors.where((doc) {
                final matchesSearch = doc.fullname.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (doc.specialization ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
                final matchesDept = _selectedDepartment == 'All' || doc.specialization == _selectedDepartment;
                return matchesSearch && matchesDept;
              }).toList();

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Departments Section
                    if (dynamicDepartments.isNotEmpty) ...[
                      const Text(
                        'Departments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDepartmentList(isMobile, dynamicDepartments),
                      const SizedBox(height: 32),
                    ],

                    // Doctors Grid
                    if (filteredDoctors.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text('No doctors found matching your criteria.'),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: filteredDoctors.map((doc) {
                          double cardWidth;
                          if (isMobile) {
                            cardWidth = MediaQuery.of(context).size.width - (isMobile ? 32 : 48);
                          } else {
                            final screenWidth = MediaQuery.of(context).size.width - 260 - 48; // Sidebar + Screen Padding
                            if (screenWidth > 1200) {
                              cardWidth = (screenWidth - (2 * 24)) / 3;
                            } else {
                              cardWidth = (screenWidth - 24) / 2;
                            }
                          }
                          return SizedBox(
                            width: cardWidth,
                            child: _buildDoctorCard(doc, isMobile),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentList(bool isMobile, List<Map<String, dynamic>> dynamicDepartments) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _deptScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: dynamicDepartments.map((dept) {
              final isSelected = _selectedDepartment == dept['name'];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDepartment = isSelected ? 'All' : dept['name'];
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: isMobile ? 180 : 260,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor.withOpacity(0.5),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(dept['icon'] as IconData, color: AppTheme.primaryColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dept['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              Text(
                                '${dept['count']} doctor${dept['count'] == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
        if (_showLeftArrow && dynamicDepartments.length > 4)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _buildGradientArrow(isLeft: true),
          ),
        if (_showRightArrow && dynamicDepartments.length > 4)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _buildGradientArrow(isLeft: false),
          ),
      ],
    );
  }

  Widget _buildGradientArrow({required bool isLeft}) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
      child: Center(
        child: InkWell(
          onTap: () {
            final double offset = isLeft 
              ? _deptScrollController.offset - 300 
              : _deptScrollController.offset + 300;
            _deptScrollController.animateTo(
              offset.clamp(0, _deptScrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isLeft ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(UserModel doctor, bool isMobile) {
    // Use real data from DB where available, fallback to '-' for missing fields
    final String experience = (doctor.experience != null && doctor.experience!.isNotEmpty)
        ? (doctor.experience!.toLowerCase().contains('year') ? doctor.experience! : '${doctor.experience} years')
        : '-'; 
    final String patients = (doctor.numberPatientsAttended != null && doctor.numberPatientsAttended! > 0) ? doctor.numberPatientsAttended.toString() : '-';
    final String rating = '4.9'; // Mock: Rating system not yet implemented in DB
    final List<String> weekDaysOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<String> availabilityList = List<String>.from(doctor.availableDays ?? [])
      ..sort((a, b) => weekDaysOrder.indexOf(a).compareTo(weekDaysOrder.indexOf(b)));
    final String availability = availabilityList.isNotEmpty ? availabilityList.join(', ') : '-';
    final String nextAvailable = _getNextAvailable(doctor); 

    return Container(
      margin: isMobile ? const EdgeInsets.only(bottom: 24) : EdgeInsets.zero,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name, Rating
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: Text(
                  doctor.fullname.substring(0, 2).toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${doctor.fullname}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      doctor.specialization ?? '-',
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Specialization Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Specialization',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                Text(
                  doctor.specialization ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats: Experience and Patients
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Experience',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      Text(
                        experience,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Patients',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      Text(
                        patients,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Availability
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Availability',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                  ),
                ),
                Text(
                  availability,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Next Available Label
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Next available: $nextAvailable',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.onBookAppointment != null) {
                      widget.onBookAppointment!(doctor);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _showEditDoctorDialog(doctor),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
                ),
                child: const Text('Profile', style: TextStyle(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _showEditDoctorDialog(UserModel doctor) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String userRole = authProvider.user?.role ?? '';
    final bool canEdit = userRole == 'Admin' || userRole == 'Super Admin' || userRole == 'Supervisor';

    final List<Map<String, dynamic>> specializations = await _adminController.fetchSpecializations();
    
    final fullnameController = TextEditingController(text: doctor.fullname);
    final emailController = TextEditingController(text: doctor.email);
    final mobileController = TextEditingController(text: doctor.mobile ?? '');
    final experienceController = TextEditingController(text: doctor.experience ?? '');
    final patientsController = TextEditingController(text: doctor.numberPatientsAttended?.toString() ?? '0');
    final bioController = TextEditingController(text: doctor.bio ?? '');
    final licenseController = TextEditingController(text: doctor.medicalLicense ?? '');
    final qualificationController = TextEditingController(text: doctor.qualification ?? '');
    final clinicNameController = TextEditingController(text: doctor.clinicName ?? '');
    final clinicLocationController = TextEditingController(text: doctor.clinicLocation ?? '');
    final feeController = TextEditingController(text: doctor.consultationFee ?? '');
    final expertiseController = TextEditingController(text: doctor.areasOfExpertise ?? '');
    final startTimeController = TextEditingController(text: doctor.slotStartTime ?? '');
    
    int? selectedSpecId = doctor.specializationId;
    List<String> selectedDays = List<String>.from(doctor.availableDays ?? []);
    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            width: 700,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          doctor.fullname.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              canEdit ? 'Edit Doctor Profile' : 'Doctor Professional Profile',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            Text(
                              'Dr. ${doctor.fullname} • ${doctor.specialization ?? "General Medicine"}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section: Basic Info
                        _buildProfileSection(
                          title: 'Basic Information',
                          icon: Icons.person_outline,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: canEdit 
                                    ? _buildModernField('Full Name', fullnameController)
                                    : _buildDetailItem('Full Name', fullnameController.text),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Email', emailController)
                                    : _buildDetailItem('Email', emailController.text),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Mobile Number', mobileController)
                                    : _buildDetailItem('Mobile Number', mobileController.text),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Medical License', licenseController)
                                    : _buildDetailItem('Medical License', licenseController.text),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: canEdit
                                    ? _buildModernDropdown(
                                        label: 'Specialization',
                                        value: selectedSpecId,
                                        items: specializations,
                                        onChanged: (val) => setDialogState(() => selectedSpecId = val),
                                      )
                                    : _buildDetailItem(
                                        'Specialization', 
                                        selectedSpecId != null 
                                          ? specializations.firstWhere((s) => s['id'] == selectedSpecId)['name']
                                          : 'N/A'
                                      ),
                                ),
                                const SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Section: Professional Details
                        _buildProfileSection(
                          title: 'Professional Details',
                          icon: Icons.work_outline,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Experience (years)', experienceController)
                                    : _buildDetailItem('Experience', '${experienceController.text} years'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Patients Attended', patientsController, isNumeric: true)
                                    : _buildDetailItem('Patients Attended', patientsController.text),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            canEdit
                              ? _buildModernField('Qualification', qualificationController)
                              : _buildDetailItem('Qualification', qualificationController.text),
                            const SizedBox(height: 16),
                            canEdit
                              ? _buildModernField('Areas of Expertise', expertiseController, hint: 'Comma separated')
                              : _buildDetailItem('Areas of Expertise', expertiseController.text),
                            const SizedBox(height: 16),
                            canEdit
                              ? _buildModernField('Bio', bioController, maxLines: 3)
                              : _buildDetailItem('Bio', bioController.text),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Section: Clinic & Availability
                        _buildProfileSection(
                          title: 'Clinic & Availability',
                          icon: Icons.access_time,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Clinic Name', clinicNameController)
                                    : _buildDetailItem('Clinic Name', clinicNameController.text),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Clinic Location', clinicLocationController)
                                    : _buildDetailItem('Clinic Location', clinicLocationController.text),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Consultation Fee', feeController)
                                    : _buildDetailItem('Consultation Fee', feeController.text),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: canEdit
                                    ? _buildModernField('Slot Start Time', startTimeController, hint: 'e.g. 9:30 AM')
                                    : _buildDetailItem('Consultation Hours', 'Starts at ${startTimeController.text}'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (!canEdit)
                              _buildDetailItem('Available Days', selectedDays.isNotEmpty ? selectedDays.join(', ') : 'Not Provided')
                            else ...[
                              const Text(
                                'Available Days',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: weekDays.map((day) {
                                  final isSelected = selectedDays.contains(day);
                                  return InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        if (isSelected) selectedDays.remove(day);
                                        else selectedDays.add(day);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                                        ),
                                      ),
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: AppTheme.cancelButton.copyWith(
                          minimumSize: MaterialStateProperty.all(const Size(120, 48)),
                        ),
                        child: Text(canEdit ? 'Cancel' : 'Close'),
                      ),
                      if (canEdit) ...[
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await _adminController.updateStaff(
                                id: doctor.id,
                                fullname: fullnameController.text,
                                email: emailController.text,
                                mobile: mobileController.text,
                                role: 'Doctor',
                                medicalLicense: licenseController.text,
                                specializationId: selectedSpecId,
                                qualification: qualificationController.text,
                                experience: experienceController.text,
                                patientsAttended: int.tryParse(patientsController.text) ?? 0,
                                bio: bioController.text,
                                availableDays: selectedDays,
                                slotStartTime: startTimeController.text,
                                clinicName: clinicNameController.text,
                                clinicLocation: clinicLocationController.text,
                                consultationFee: double.tryParse(feeController.text.replaceAll(RegExp(r'[^0-9.]'), '')),
                                areasOfExpertise: expertiseController.text,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                _loadDoctors();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  value.trim().isEmpty ? 'Not Provided' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernField(String label, TextEditingController controller, {bool isNumeric = false, int maxLines = 1, String? hint, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            readOnly: !enabled,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.borderColor.withOpacity(0.8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.borderColor.withOpacity(0.8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required Function(int?)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: onChanged != null ? Colors.grey.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor.withOpacity(0.8)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: value,
                style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 14),
                disabledHint: value != null 
                  ? Text(
                      items.firstWhere((s) => s['id'] == value)['name'],
                      style: const TextStyle(color: AppTheme.textPrimaryColor),
                    )
                  : null,
                items: items.map((s) => DropdownMenuItem<int>(
                  value: s['id'],
                  child: Text(s['name']),
                )).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextAvailable(UserModel doctor) {
    if (doctor.availableDays == null || doctor.availableDays!.isEmpty || doctor.slotStartTime == null || doctor.slotStartTime!.isEmpty) {
      return '-';
    }

    final now = DateTime.now();
    final List<String> availableDays = List<String>.from(doctor.availableDays!);
    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    int duration = 30;
    if (doctor.slotDuration != null) {
      duration = int.tryParse(doctor.slotDuration!.split(' ')[0]) ?? 30;
    }

    // Check next 7 days for the first available slot
    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final dayName = weekDays[checkDate.weekday - 1];
      
      if (!availableDays.contains(dayName)) continue;
      if (doctor.weeklyOffDays != null && doctor.weeklyOffDays!.contains(dayName)) continue;
      
      final dateStr = DateFormat('dd/MM/yyyy').format(checkDate);
      if (doctor.specificLeaveDates != null && doctor.specificLeaveDates!.contains(dateStr)) continue;

      try {
        DateTime start = _parseTimeOnDate(checkDate, doctor.slotStartTime!);
        DateTime end = doctor.slotEndTime != null 
            ? _parseTimeOnDate(checkDate, doctor.slotEndTime!) 
            : start.add(const Duration(hours: 8)); // Fallback 8 hour window if no end time
        
        DateTime currentSlot = start;
        while (currentSlot.isBefore(end)) {
          // 1. Check if slot is in the future
          if (currentSlot.isAfter(now)) {
            final timeStr = DateFormat('hh:mm a').format(currentSlot);
            
            // 2. Check if this specific slot is already booked for this doctor
            bool isBooked = _appointments.any((a) => 
              a.doctorName == doctor.fullname && 
              a.appointmentDate == dateStr && 
              a.appointmentTime == timeStr &&
              (a.status == 'Confirmed' || a.status == 'Arrived')
            );

            if (!isBooked) {
              final prefix = i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : dayName);
              return '$prefix, $timeStr';
            }
          }
          currentSlot = currentSlot.add(Duration(minutes: duration));
        }
      } catch (e) {
        continue;
      }
    }
    
    return '-';
  }

  DateTime _parseTimeOnDate(DateTime date, String timeStr) {
    final timeParts = timeStr.split(' ');
    final hms = timeParts[0].split(':');
    int hour = int.parse(hms[0]);
    int minute = hms.length > 1 ? int.parse(hms[1]) : 0;
    
    if (timeParts.length > 1) {
      if (timeParts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (timeParts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Widget _buildDialogField(String label, TextEditingController controller, {bool isNumeric = false, int maxLines = 1, String? hint, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          TextField(
            controller: controller,
            readOnly: !enabled,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: enabled ? null : InputBorder.none,
              filled: enabled,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }
}
