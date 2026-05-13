import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/doctor/doctor_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/nurse_widgets.dart' hide PatientModel;
import '../controllers/appointment_controller.dart';
import '../models/appointment_model.dart';
import 'login_page.dart';
import 'new_consultation.dart';
import '../utils/date_formatter.dart';
import '../utils/logout_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final AppointmentController _appointmentController = AppointmentController();
  List<AppointmentModel> _doctorAppointments = [];
  List<Map<String, dynamic>> _consultations = [];
  bool _isLoading = true;
  bool _isLoadingConsultations = false;
  DateTime? _selectedDate = DateTime.now();
  final FocusNode _mainFocusNode = FocusNode();
  AppointmentModel? _activeAppointment;
  bool _isEditingProfile = false;
  DoctorController get _doctorController => DoctorController();
  // Profile Controllers — Basic
  late TextEditingController _nameController;
  late TextEditingController _specController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _licenseController;
  late TextEditingController _qualController;
  late TextEditingController _expController;
  late TextEditingController _patientsController;
  late TextEditingController _bioController;
  // Professional Core
  late TextEditingController _areasOfExpertiseController;
  // Availability
  List<String>? _availableDays;
  late TextEditingController _slotStartController;
  late TextEditingController _slotEndController;
  late TextEditingController _slotDurationController;
  late TextEditingController _leaveBlockDatesController;
  List<String>? _weeklyOffDays;
  List<String>? _specificLeaveDates;
  // Clinic / Hospital
  late TextEditingController _clinicNameController;
  late TextEditingController _clinicLocationController;
  late TextEditingController _consultationFeeController;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _fetchDoctorData();
  }

  void _initControllers() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.fullname ?? '');
    _specController = TextEditingController(text: user?.specialization ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _mobileController = TextEditingController(text: user?.mobile ?? '');
    _licenseController = TextEditingController(
      text: user?.medicalLicense ?? '',
    );
    _qualController = TextEditingController(text: user?.qualification ?? '');
    _expController = TextEditingController(text: user?.experience ?? '');
    _patientsController = TextEditingController(
      text: user?.numberPatientsAttended?.toString() ?? '0',
    );
    _bioController = TextEditingController(text: user?.bio ?? '');

    _areasOfExpertiseController = TextEditingController(
      text: user?.areasOfExpertise ?? '',
    );

    _availableDays = user?.availableDays != null
        ? List.from(user!.availableDays!)
        : [];

    _slotStartController = TextEditingController(
      text: user?.slotStartTime ?? '',
    );
    _slotEndController = TextEditingController(text: user?.slotEndTime ?? '');
    _slotDurationController = TextEditingController(
      text: user?.slotDuration ?? '',
    );
    _leaveBlockDatesController = TextEditingController();

    _weeklyOffDays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ].where((day) => !_availableDays!.contains(day)).toList();

    _specificLeaveDates = [];
    if (user?.specificLeaveDates != null)
      _specificLeaveDates!.addAll(user!.specificLeaveDates!);

    _clinicNameController = TextEditingController(text: user?.clinicName ?? '');
    _clinicLocationController = TextEditingController(
      text: user?.clinicLocation ?? '',
    );
    _consultationFeeController = TextEditingController(
      text: user?.consultationFee ?? '',
    );
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
    _nameController.dispose();
    _specController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _licenseController.dispose();
    _qualController.dispose();
    _expController.dispose();
    _patientsController.dispose();
    _bioController.dispose();
    _areasOfExpertiseController.dispose();
    _slotStartController.dispose();
    _slotEndController.dispose();
    _slotDurationController.dispose();
    _leaveBlockDatesController.dispose();
    _clinicNameController.dispose();
    _clinicLocationController.dispose();
    _consultationFeeController.dispose();
    super.dispose();
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
          patients: _doctorAppointments
              .map((e) => {'name': e.patientName, 'phone': '', 'age': '24'})
              .toList(),
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

  Future<void> _fetchDoctorData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final allAppointments = await _appointmentController.fetchAppointments();

      if (mounted) {
        setState(() {
          _doctorAppointments = allAppointments.where((appt) {
            final docName = appt.doctorName.toLowerCase().trim();
            final userName = (user?.fullname ?? '').toLowerCase().trim();

            // Match exact name OR name before hyphen OR name before specialization
            return docName == userName ||
                docName.startsWith(userName + ' ') ||
                (docName.contains(' - ') &&
                    docName.split(' - ')[0].trim() == userName);
          }).toList();
          _isLoading = false;
        });
      }

      // Also fetch consultations
      _fetchConsultations();
    } catch (e) {
      debugPrint('Error fetching doctor data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchConsultations() async {
    if (!mounted) return;
    setState(() => _isLoadingConsultations = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        final consultations = await _appointmentController
            .fetchConsultationsByDoctor(user.fullname);
        if (mounted) {
          setState(() {
            _consultations = consultations;
            _isLoadingConsultations = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching doctor consultations: $e');
      if (mounted) setState(() => _isLoadingConsultations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final user = Provider.of<AuthProvider>(context).user;

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
        drawer: isMobile ? Drawer(child: _buildSidebar(isMobile)) : null,
        floatingActionButton: CustomSpeedDial(
          children: [
            SpeedDialChild(
              label: 'New Appointment',
              icon: Icons.calendar_month_outlined,
              color: AppTheme.primaryColor,
              onTap: () {},
            ),
          ],
        ),
        body: Row(
          children: [
            if (!isMobile) _buildSidebar(isMobile),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(isMobile, user?.fullname ?? 'Doctor'),
                  Expanded(child: _buildMainContent(isMobile)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    if (_activeAppointment != null) {
      // Find existing consultation for this appointment if any
      final existingConsul = _consultations.firstWhere(
        (c) => c['appointment_id'] == _activeAppointment!.id,
        orElse: () => {},
      );

      return NewConsultationView(
        appointment: _activeAppointment!,
        initialConsultation: existingConsul.isNotEmpty ? existingConsul : null,
        onBack: () {
          setState(() => _activeAppointment = null);
          _fetchConsultations(); // Refresh after potentially saving/updating
          _fetchDoctorData(); // Refresh appointment list status
        },
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView(isMobile);
      case 1:
        return _buildProfileView(isMobile);
      default:
        return _buildDashboardView(isMobile);
    }
  }

  Future<void> _fetchAndViewConsultation(AppointmentModel appt) async {
    setState(() => _isLoading = true);
    try {
      final consultations = await _appointmentController
          .fetchConsultationsByPatient(appt.patientId);
      final consul = consultations.firstWhere(
        (c) => c['appointment_id'] == appt.id,
        orElse: () => {},
      );

      if (consul.isNotEmpty) {
        if (mounted) _showConsultationDetail(consul);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Consultation details not found')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching consultation: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildConsultationsView(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Consultations',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'History of all consultations performed by you.',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          ),
          const SizedBox(height: 24),

          if (_isLoadingConsultations)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_consultations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_edu_outlined,
                      size: 64,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No consultations found',
                      style: TextStyle(color: AppTheme.textSecondaryColor),
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
                border: Border.all(
                  color: AppTheme.borderColor.withOpacity(0.5),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _consultations.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = _consultations[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    title: Row(
                      children: [
                        Text(
                          c['patient_name'] ?? 'Unknown Patient',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            c['appointment_type'] ?? 'Consultation',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${DateFormatter.toUi(c['appointment_date'])} at ${c['appointment_time']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              c['diagnosis'] ?? 'No diagnosis',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onTap: () => _showConsultationDetail(c),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showConsultationDetail(Map<String, dynamic> consultation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Consultation: ${consultation['patient_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Symptoms',
                consultation['symptoms'] ?? 'None recorded',
                Icons.sick_outlined,
              ),
              _buildDetailRow(
                'Diagnosis',
                consultation['diagnosis'] ?? 'None recorded',
                Icons.biotech_outlined,
              ),
              _buildDetailRow(
                'Notes',
                consultation['notes'] ?? 'None recorded',
                Icons.note_alt_outlined,
              ),
              const SizedBox(height: 16),
              const Text(
                'Medications:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (consultation['medications'] != null)
                ...(consultation['medications'] as List)
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${m['name']} - ${m['dosage']} (${m['frequency']})',
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList()
              else
                const Text('No medications prescribed'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF), // Very light blue tint
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0F5A8E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF718096), // Muted grey-blue
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748), // Darker primary text
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    // Auto-calculate weekly off days: any day not selected as available is automatically a weekly off day
    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    _weeklyOffDays = allDays
        .where((day) => !(_availableDays ?? []).contains(day))
        .toList();

    setState(() => _isLoading = true);
    try {
      final updatedUser = await _doctorController.updateProfile(
        fullname: _nameController.text,
        mobile: _mobileController.text,
        medicalLicense: _licenseController.text,
        qualification: _qualController.text,
        experience: _expController.text,
        bio: _bioController.text,
        patientsAttended: _patientsController.text,
        availableDays: _availableDays ?? [],
        slotStartTime: _slotStartController.text,
        slotEndTime: _slotEndController.text,
        slotDuration: _slotDurationController.text,
        weeklyOffDays: _weeklyOffDays ?? [],
        specificLeaveDates: _specificLeaveDates ?? [],
        clinicName: _clinicNameController.text,
        clinicLocation: _clinicLocationController.text,
        consultationFee: _consultationFeeController.text,
        areasOfExpertise: _areasOfExpertiseController.text,
      );

      if (mounted) {
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).updateUser(updatedUser);
        setState(() => _isEditingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileView(bool isMobile) {
    if (_isEditingProfile) {
      return _buildProfileEditView(isMobile);
    } else {
      return _buildProfileDisplayView(isMobile);
    }
  }

  Widget _buildProfileDisplayView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context).user;
    const sectionSpacing = SizedBox(height: 24);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Professional Profile',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Overview of your medical practice and settings',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isEditingProfile = true),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(color: Colors.white),
                ),
                style: AppTheme.primaryButton.copyWith(
                  minimumSize: MaterialStateProperty.all(const Size(0, 48)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Primary Information Card (Name, Email, Bio) ────────────────
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryColor, Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user?.fullname.isNotEmpty == true
                              ? user!.fullname[0].toUpperCase()
                              : 'D',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullname ?? 'Doctor',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (user?.specialization != null)
                            Text(
                              user!.specialization!,
                              style: const TextStyle(
                                color: Color(0xFF718096),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            user?.role ?? 'Doctor',
                            style: const TextStyle(
                              color: Color(0xFFC53030),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 24),
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    'Full Name',
                    user?.fullname ?? '-',
                    Icons.person_outline,
                  ),
                  _buildDetailRow(
                    'Email Address',
                    user?.email ?? '-',
                    Icons.alternate_email,
                  ),
                  _buildDetailRow(
                    'Mobile Number',
                    user?.mobile ?? '-',
                    Icons.phone_android_outlined,
                  ),
                  _buildDetailRow(
                    'Bio Summary',
                    user?.bio ?? '-',
                    Icons.description_outlined,
                  ),
                ],
              ],
            ),
          ),
          sectionSpacing,

          // ── Details Grid ────────────────────────────────
          if (isMobile) ...[
            _buildInfoCard('Professional Info', [
              _buildDetailRow(
                'Specialization',
                user?.specialization ?? '-',
                Icons.medical_services_outlined,
              ),
              _buildDetailRow(
                'Qualification',
                user?.qualification ?? '-',
                Icons.school_outlined,
              ),
              _buildDetailRow(
                'Medical License',
                user?.medicalLicense ?? '-',
                Icons.badge_outlined,
              ),
              _buildDetailRow(
                'Experience',
                user?.experience == null || user?.experience == '0'
                    ? '-'
                    : '${user!.experience} years',
                Icons.work_history_outlined,
              ),
            ]),
            sectionSpacing,
            _buildInfoCard('Availability', [
              _buildDetailRow(
                'Available Days',
                (user?.availableDays == null || user!.availableDays!.isEmpty)
                    ? '-'
                    : user!.availableDays!.join(', '),
                Icons.calendar_month_outlined,
              ),
              _buildDetailRow(
                'Consultation Hours',
                '${user?.slotStartTime ?? "-"} to ${user?.slotEndTime ?? "-"}',
                Icons.access_time_rounded,
              ),
              _buildDetailRow(
                'Slot Duration',
                user?.slotDuration ?? '-',
                Icons.timer_outlined,
              ),
              _buildDetailRow(
                'Weekly Off',
                (user?.weeklyOffDays ?? []).isEmpty
                    ? '-'
                    : user!.weeklyOffDays!.join(', '),
                Icons.event_busy_outlined,
              ),
            ]),
            sectionSpacing,
            _buildInfoCard('Clinic Details', [
              _buildDetailRow(
                'Clinic Name',
                user?.clinicName ?? '-',
                Icons.business_outlined,
              ),
              _buildDetailRow(
                'Location',
                user?.clinicLocation ?? '-',
                Icons.location_on_outlined,
              ),
              _buildDetailRow(
                'Consultation Fee',
                user?.consultationFee == null || user?.consultationFee == '0'
                    ? '-'
                    : '₹${user!.consultationFee}',
                Icons.payments_outlined,
              ),
            ]),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoCard('Professional Info', [
                    _buildDetailRow(
                      'Specialization',
                      user?.specialization ?? '-',
                      Icons.medical_services_outlined,
                    ),
                    _buildDetailRow(
                      'Qualification',
                      user?.qualification ?? '-',
                      Icons.school_outlined,
                    ),
                    _buildDetailRow(
                      'Medical License',
                      user?.medicalLicense ?? '-',
                      Icons.badge_outlined,
                    ),
                    _buildDetailRow(
                      'Experience',
                      user?.experience == null || user?.experience == '0'
                          ? '-'
                          : '${user!.experience} years',
                      Icons.work_history_outlined,
                    ),
                  ]),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildInfoCard('Availability', [
                    _buildDetailRow(
                      'Available Days',
                      (user?.availableDays == null ||
                              user!.availableDays!.isEmpty)
                          ? '-'
                          : user!.availableDays!.join(', '),
                      Icons.calendar_month_outlined,
                    ),
                    _buildDetailRow(
                      'Consultation Hours',
                      '${user?.slotStartTime ?? "-"} to ${user?.slotEndTime ?? "-"}',
                      Icons.access_time_rounded,
                    ),
                    _buildDetailRow(
                      'Slot Duration',
                      user?.slotDuration ?? '-',
                      Icons.timer_outlined,
                    ),
                    _buildDetailRow(
                      'Weekly Off',
                      (user?.weeklyOffDays ?? []).isEmpty
                          ? '-'
                          : user!.weeklyOffDays!.join(', '),
                      Icons.event_busy_outlined,
                    ),
                    _buildDetailRow(
                      'Specific Leave Dates',
                      (user?.specificLeaveDates == null ||
                              user!.specificLeaveDates!.isEmpty)
                          ? '-'
                          : user!.specificLeaveDates!.join(', '),
                      Icons.calendar_today_outlined,
                    ),
                  ]),
                ),
              ],
            ),
            sectionSpacing,
            _buildInfoCard('Clinic Details', [
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                      'Clinic Name',
                      user?.clinicName ?? '-',
                      Icons.business_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailRow(
                      'Location',
                      user?.clinicLocation ?? '-',
                      Icons.location_on_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailRow(
                      'Consultation Fee',
                      user?.consultationFee == null ||
                              user?.consultationFee == '0'
                          ? '-'
                          : '₹${user!.consultationFee}',
                      Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
            ]),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F5A8E),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileEditView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    const sectionSpacing = SizedBox(height: 24);
    const fieldSpacing = SizedBox(height: 16);

    Widget sectionCard(
      String number,
      String title,
      Color accentColor,
      List<Widget> fields,
    ) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: accentColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 24),
            ...fields,
          ],
        ),
      );
    }

    final allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return StatefulBuilder(
      builder: (context, setLocalState) {
        _availableDays ??= [];
        _weeklyOffDays ??= [];
        _specificLeaveDates ??= [];
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Modify your professional details and availability',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _isEditingProfile = false),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                    label: const Text('Back to Profile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Basic Info Container ────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              user?.fullname.isNotEmpty == true
                                  ? user!.fullname[0].toUpperCase()
                                  : 'D',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullname ?? 'Doctor',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user?.specialization?.isNotEmpty == true)
                              Text(
                                user!.specialization!,
                                style: const TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              (user?.role != null && user!.role.isNotEmpty)
                                  ? user.role
                                  : 'Doctor',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isMobile) ...[
                      _buildProfileTextField(
                        'Full Name',
                        _nameController,
                        Icons.person_outline,
                        isReadOnly: true,
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Email Address',
                        _emailController,
                        Icons.email_outlined,
                        isReadOnly: true,
                      ),
                      fieldSpacing,
                      _buildProfileTextField(
                        'Mobile Number',
                        _mobileController,
                        Icons.phone_android_outlined,
                        isNumeric: true,
                        maxLength: 10,
                        isReadOnly: true,
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bio / Professional Summary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _bioController,
                            maxLines: 3,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.normal,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Share a brief summary of your expertise...',
                              hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              fillColor: AppTheme.backgroundColor,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: _buildProfileTextField(
                              'Full Name',
                              _nameController,
                              Icons.person_outline,
                              isReadOnly: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProfileTextField(
                              'Email Address',
                              _emailController,
                              Icons.email_outlined,
                              isReadOnly: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProfileTextField(
                              'Mobile Number',
                              _mobileController,
                              Icons.phone_android_outlined,
                              isNumeric: true,
                              maxLength: 10,
                              isReadOnly: true,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bio / Professional Summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bioController,
                          maxLines: 3,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.normal,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Share a brief summary of your expertise...',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            fillColor: AppTheme.backgroundColor,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              sectionSpacing,

              // ── Section 1: Professional Details ─────────────────
              sectionCard(
                '1',
                'Professional Details',
                const Color(0xFF0D5D9A),
                [
                  if (isMobile) ...[
                    _buildProfileTextField(
                      'Qualification (MBBS, MD, etc.)',
                      _qualController,
                      Icons.school_outlined,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Specialization',
                      _specController,
                      Icons.medical_services_outlined,
                      isReadOnly: true,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Medical Registration Number',
                      _licenseController,
                      Icons.badge_outlined,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Total Experience (years)',
                      _expController,
                      Icons.work_outline,
                      isNumeric: true,
                      maxLength: 2,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Areas of Expertise (comma-separated)',
                      _areasOfExpertiseController,
                      Icons.star_outline,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Number of Patients Attended',
                      _patientsController,
                      Icons.people_outline,
                      isNumeric: true,
                      maxLength: 6,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Qualification (MBBS, MD, etc.)',
                            _qualController,
                            Icons.school_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Specialization',
                            _specController,
                            Icons.medical_services_outlined,
                            isReadOnly: true,
                          ),
                        ),
                      ],
                    ),
                    fieldSpacing,
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Medical Registration Number',
                            _licenseController,
                            Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Total Experience (years)',
                            _expController,
                            Icons.work_outline,
                            isNumeric: true,
                            maxLength: 2,
                          ),
                        ),
                      ],
                    ),
                    fieldSpacing,
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Areas of Expertise (comma-separated)',
                            _areasOfExpertiseController,
                            Icons.star_outline,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Number of Patients Attended',
                            _patientsController,
                            Icons.people_outline,
                            isNumeric: true,
                            maxLength: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              sectionSpacing,

              // ── Section 2: Availability ───────────────────────
              sectionCard('2', 'Availability', const Color(0xFF38A169), [
                // Available / Leave Days chips
                const Text(
                  'Weekly Schedule (Tap: Available ↔ Leave)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map((day) {
                        final isAvailable =
                            _availableDays?.contains(day) ?? false;

                        Color bgColor = isAvailable
                            ? const Color(0xFF38A169)
                            : Colors.red.shade400;
                        Color borderColor = bgColor;
                        Color textColor = Colors.white;

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setLocalState(() {
                              if (isAvailable) {
                                _availableDays?.remove(day);
                                (_weeklyOffDays ??= []).add(day);
                              } else {
                                _weeklyOffDays?.remove(day);
                                (_availableDays ??= []).add(day);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
                fieldSpacing,
                if (isMobile) ...[
                  _buildTimePickerField(
                    'Slot Start Time',
                    _slotStartController,
                    Icons.access_time_outlined,
                  ),
                  fieldSpacing,
                  _buildTimePickerField(
                    'Slot End Time',
                    _slotEndController,
                    Icons.access_time_filled,
                  ),
                  fieldSpacing,
                  _buildProfileTextField(
                    'Slot Duration (e.g. 15 min)',
                    _slotDurationController,
                    Icons.timelapse_outlined,
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerField(
                          'Slot Start Time',
                          _slotStartController,
                          Icons.access_time_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTimePickerField(
                          'Slot End Time',
                          _slotEndController,
                          Icons.access_time_filled,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildProfileTextField(
                          'Slot Duration (e.g. 15 min)',
                          _slotDurationController,
                          Icons.timelapse_outlined,
                        ),
                      ),
                    ],
                  ),
                fieldSpacing,

                // ── Specific Leave Dates ────────────────────────
                const Text(
                  'Specific Leave Dates — pick individual dates.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...(_specificLeaveDates ?? []).map(
                      (d) => Chip(
                        label: Text(d, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.orange.shade50,
                        side: BorderSide(color: Colors.orange.shade200),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () =>
                            setLocalState(() => _specificLeaveDates?.remove(d)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null) {
                          final f =
                              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                          if (_specificLeaveDates?.contains(f) == false) {
                            setLocalState(
                              () => (_specificLeaveDates ??= []).add(f),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 15,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add Date',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
              sectionSpacing,

              // ── Section 3: Clinic / Hospital Mapping ──────────
              sectionCard(
                '3',
                'Clinic / Hospital Details',
                const Color(0xFF805AD5),
                [
                  if (isMobile) ...[
                    _buildProfileTextField(
                      'Clinic / Hospital Name',
                      _clinicNameController,
                      Icons.local_hospital_outlined,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Location',
                      _clinicLocationController,
                      Icons.location_on_outlined,
                    ),
                    fieldSpacing,
                    _buildProfileTextField(
                      'Consultation Fee (₹)',
                      _consultationFeeController,
                      Icons.currency_rupee,
                      isNumeric: true,
                      maxLength: 5,
                    ),
                  ] else ...[
                    _buildProfileTextField(
                      'Clinic / Hospital Name',
                      _clinicNameController,
                      Icons.local_hospital_outlined,
                    ),
                    fieldSpacing,
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileTextField(
                            'Location',
                            _clinicLocationController,
                            Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileTextField(
                            'Consultation Fee (₹)',
                            _consultationFeeController,
                            Icons.currency_rupee,
                            isNumeric: true,
                            maxLength: 5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              sectionSpacing,

              sectionSpacing,

              // ── Section 6: Documents ──────────────────────────
              // sectionCard('6', 'Documents', AppTheme.primaryColor, [
              //   Container(
              //     width: double.infinity,
              //     padding: const EdgeInsets.all(20),
              //     decoration: BoxDecoration(
              //       color: AppTheme.primaryLight,
              //       borderRadius: BorderRadius.circular(10),
              //       border: Border.all(
              //         color: AppTheme.primaryColor.withOpacity(0.3),
              //         style: BorderStyle.solid,
              //       ),
              //     ),
              //     child: Column(
              //       children: [
              //         const Icon(
              //           Icons.upload_file_outlined,
              //           size: 36,
              //           color: AppTheme.primaryColor,
              //         ),
              //         const SizedBox(height: 8),
              //         const Text(
              //           'Registration Certificate',
              //           style: TextStyle(
              //             fontWeight: FontWeight.bold,
              //             fontSize: 14,
              //           ),
              //         ),
              //         const SizedBox(height: 4),
              //         const Text(
              //           'Upload your medical registration certificate for admin verification.',
              //           textAlign: TextAlign.center,
              //           style: TextStyle(
              //             color: AppTheme.textSecondaryColor,
              //             fontSize: 12,
              //           ),
              //         ),
              //         const SizedBox(height: 12),
              //         OutlinedButton.icon(
              //           onPressed: () {},
              //           icon: const Icon(Icons.attach_file, size: 18),
              //           label: const Text('Choose File'),
              //           style: OutlinedButton.styleFrom(
              //             foregroundColor: AppTheme.primaryColor,
              //             side: const BorderSide(color: AppTheme.primaryColor),
              //             shape: RoundedRectangleBorder(
              //               borderRadius: BorderRadius.circular(8),
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ]),
              // sectionSpacing,

              // ── Save Button ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _isEditingProfile = false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                    label: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Profile Changes',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumeric = false,
    bool isReadOnly = false,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          readOnly: isReadOnly,
          maxLength: maxLength,
          inputFormatters: isNumeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          mouseCursor: isReadOnly ? SystemMouseCursors.forbidden : null,
          style: TextStyle(
            color: isReadOnly
                ? AppTheme.textSecondaryColor.withOpacity(0.7)
                : AppTheme.textPrimaryColor,
            fontWeight: isReadOnly ? FontWeight.w500 : FontWeight.normal,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: label,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: isReadOnly
                ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
                : null,
            fillColor: isReadOnly
                ? const Color(0xFFF7FAFC)
                : AppTheme.backgroundColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: isReadOnly
                  ? BorderSide(color: Colors.grey.withOpacity(0.1))
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: isReadOnly
                  ? BorderSide(color: Colors.grey.withOpacity(0.1))
                  : BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              controller.text = picked.format(context);
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: 'Tap to pick time',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            fillColor: AppTheme.backgroundColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              final formatted =
                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
              if (controller.text.isEmpty) {
                controller.text = formatted;
              } else {
                controller.text = '${controller.text}, $formatted';
              }
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: 'Tap to pick date(s)',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            fillColor: AppTheme.backgroundColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardView(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(),
          const SizedBox(height: 24),
          _buildStatsRow(isMobile),
          const SizedBox(height: 24),
          _buildPatientsTable(),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isMobile) {
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
                  _buildSidebarItem(0, Icons.grid_view_outlined, 'Dashboard'),
                  _buildSidebarItem(1, Icons.person_outline, 'My Profile'),
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
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedIndex = index;
        _isEditingProfile = false;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
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
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, String name) {
    return Container(
      height: isMobile ? 80 : 90,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),

          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: TextField(
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
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding: const EdgeInsets.only(top: 2),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),

          if (!isMobile) ...[
            const SizedBox(width: 24),
            const Spacer(),
            const Icon(
              Icons.notifications_none_outlined,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: 16),
            const Icon(Icons.help_outline, color: AppTheme.textSecondaryColor),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(80, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Share', style: TextStyle(fontSize: 14)),
            ),
          ],
          SizedBox(width: isMobile ? 12 : 24),

          // Date & Time
          const LiveClock(),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    // Determine greeting based on time of day
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${user?.fullname ?? 'Doctor'}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Here\'s a quick look at your scheduled appointments today.',
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    // Calculate real stats
    final now = DateTime.now();
    final todayStr = DateFormat('dd/MM/yyyy').format(now);

    final int todayCount = _doctorAppointments
        .where(
          (a) =>
              a.appointmentDate == todayStr ||
              a.appointmentDate.startsWith(todayStr),
        )
        .length;
    final int confirmedCount = _doctorAppointments
        .where((a) => a.status == 'Confirmed' || a.status == 'Scheduled')
        .length;
    final int totalPatients = _doctorAppointments.length;

    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard(
            'Total Appointments',
            totalPatients.toString(),
            'All time',
            Icons.calendar_today_outlined,
            Colors.blue,
            isMobile,
          ),
          _buildStatCard(
            'Today\'s Appointments',
            todayCount.toString(),
            'Scheduled',
            Icons.calendar_month_outlined,
            Colors.indigo,
            isMobile,
          ),
          _buildStatCard(
            'Confirmed Cases',
            confirmedCount.toString(),
            'Ready',
            Icons.check_circle_outline,
            Colors.green,
            isMobile,
          ),
          _buildStatCard(
            'Average Rating',
            '4.9',
            'Excellent',
            Icons.star_outline,
            Colors.orange,
            isMobile,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Appointments',
            totalPatients.toString(),
            'All time',
            Icons.calendar_today_outlined,
            Colors.blue,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Today\'s Appointments',
            todayCount.toString(),
            'Scheduled',
            Icons.calendar_month_outlined,
            Colors.indigo,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Confirmed Cases',
            confirmedCount.toString(),
            'Ready',
            Icons.check_circle_outline,
            Colors.green,
            isMobile,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Average Rating',
            '4.9',
            'Excellent',
            Icons.star_outline,
            Colors.orange,
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

  Widget _buildPatientsTable() {
    final filteredAppts = _doctorAppointments.where((a) {
      // Show all appointments except Cancelled ones
      if (a.status.toLowerCase() == 'cancelled') return false;
      if (_selectedDate == null) return true;

      final String todayStr = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      return a.appointmentDate == todayStr ||
          a.appointmentDate.startsWith(todayStr);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Card Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointments',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (_selectedDate != null)
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!),
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      )
                    else
                      const Text(
                        'All Records',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    // Date Filter Button
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                          selectableDayPredicate: (DateTime date) {
                            final dateStr = DateFormat(
                              'dd/MM/yyyy',
                            ).format(date);
                            final isBooked = _doctorAppointments.any(
                              (a) => a.appointmentDate == dateStr,
                            );

                            // Essential: initialDate MUST satisfy the predicate or the picker won't open.
                            // We allow today's date and the currently selected date regardless of appointments.
                            final isToday =
                                date.day == DateTime.now().day &&
                                date.month == DateTime.now().month &&
                                date.year == DateTime.now().year;
                            final isCurrentSelection =
                                _selectedDate != null &&
                                date.day == _selectedDate!.day &&
                                date.month == _selectedDate!.month &&
                                date.year == _selectedDate!.year;

                            return isBooked || isToday || isCurrentSelection;
                          },
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null
                                  ? 'Filter Date'
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedDate!),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_selectedDate != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () =>
                                    setState(() => _selectedDate = null),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _fetchDoctorData,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Table Rows Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: const Color(0xFFF7FAFC),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildTableHeaderText('PATIENT')),
                Expanded(flex: 2, child: _buildTableHeaderText('TYPE')),
                Expanded(flex: 2, child: _buildTableHeaderText('TIME')),
                Expanded(flex: 2, child: _buildTableHeaderText('STATUS')),
                const SizedBox(width: 28), // Match circle button width in rows
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredAppts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedDate == null
                          ? 'No records found'
                          : 'No appointments for this date',
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                    if (_selectedDate != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedDate = null),
                        child: const Text('View All Records'),
                      ),
                  ],
                ),
              ),
            )
          else
            ...filteredAppts.take(10).map((appt) {
              return Column(
                children: [
                  _buildPatientTableRow(appt),
                  const Divider(height: 1),
                ],
              );
            }).toList(),

          if (filteredAppts.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text('View All ${filteredAppts.length} Appointments'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPatientTableRow(AppointmentModel appt) {
    Color statusColor = AppTheme.primaryColor;
    if (appt.status == 'Confirmed') statusColor = AppTheme.successColor;
    if (appt.status == 'Waiting') statusColor = Colors.orange;
    if (appt.status == 'Completed') statusColor = Colors.red;
    if (appt.status == 'Cancelled') statusColor = Colors.red;
    if (appt.status == 'Checked In') statusColor = Colors.blue;

    return InkWell(
      onTap: () => setState(() => _activeAppointment = appt),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Patient Column
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    radius: 16,
                    child: Text(
                      appt.patientName.isNotEmpty
                          ? appt.patientName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appt.patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Type Column
            Expanded(
              flex: 2,
              child: Text(
                appt.appointmentType,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ),

            // Time Column
            Expanded(
              flex: 2,
              child: Text(
                appt.appointmentTime,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
            ),

            // Status Column
            Expanded(
              flex: 2,
              child: UnconstrainedBox(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    appt.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Action Column
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
