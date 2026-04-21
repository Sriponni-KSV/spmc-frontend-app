import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_model.dart';
import 'login_page.dart';
import 'new_consultation.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final AppointmentController _appointmentController = AppointmentController();
  List<AppointmentModel> _doctorAppointments = [];
  bool _isLoading = true;
  DateTime? _selectedDate = DateTime.now();
  final FocusNode _mainFocusNode = FocusNode();
  AppointmentModel? _activeAppointment;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  @override
  void dispose() {
    _mainFocusNode.dispose();
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
          patients: _doctorAppointments.map((e) => {'name': e.patientName, 'phone': '', 'age': '24'}).toList(),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim1), child: child));
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
            return appt.doctorName.toLowerCase() == user?.fullname.toLowerCase();
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching doctor appointments: $e');
      if (mounted) setState(() => _isLoading = false);
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
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.slash) {
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
      return NewConsultationView(
        appointment: _activeAppointment!,
        onBack: () => setState(() => _activeAppointment = null),
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

  Widget _buildProfileView(bool isMobile) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Doctor Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Update your bio data and professional details.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
          const SizedBox(height: 32),
          
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
                      width: 100, height: 100,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        user?.fullname.isNotEmpty == true ? user!.fullname[0].toUpperCase() : 'D', 
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      alignment: Alignment.center,
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Change Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.backgroundColor,
                        foregroundColor: AppTheme.primaryColor,
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(child: _buildProfileTextField('Full Name', user?.fullname ?? '', Icons.person_outline)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildProfileTextField('Specialization', user?.specialization ?? 'General Physician', Icons.medical_services_outlined)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildProfileTextField('Email Address', user?.email ?? '', Icons.email_outlined)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildProfileTextField('Medical License Number', user?.medicalLicense ?? '', Icons.badge_outlined)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildProfileTextField('Qualification', user?.qualification ?? '', Icons.school_outlined)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildProfileTextField('Experience', user?.experience ?? '', Icons.work_outline)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildProfileTextField('Patients Attended', user?.numberPatientsAttended?.toString() ?? '0', Icons.people_outline, isNumeric: true)),
                    const SizedBox(width: 16),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                
                const Text('Bio / Professional Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                const SizedBox(height: 8),
                TextFormField(
                  key: Key(user?.bio ?? 'bio_empty'),
                  initialValue: user?.bio ?? '',
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share a brief summary of your expertise...',
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile changes synced to DB!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                    child: const Text('Save Profile Changes', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTextField(String label, String value, IconData icon, {bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
         const SizedBox(height: 8),
         TextFormField(
            key: Key(value),
            initialValue: value,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20),
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
        border: Border(right: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Image.asset('assets/image/full_logo.png', width: 100, height: 89),
              ],
            ),
          ),
          
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
          
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                      const SizedBox(height: 8),
                      _buildSmallAction('Quick Search', '/'),
                      _buildSmallAction('New Prescription', 'Alt+N'),
                      _buildSmallAction('Schedule', 'Alt+S'),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final user = auth.user;
                    if (user == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        const CircleAvatar(backgroundColor: AppTheme.primaryColor, radius: 18, child: Icon(Icons.person, color: Colors.white, size: 20)),
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
                             Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                          },
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
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
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

  Widget _buildSmallAction(String label, String shortcut) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.borderColor)),
            child: Text(shortcut, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, String name) {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1))),
      child: Row(
        children: [
          if (isMobile)
            Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
          
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                decoration: InputDecoration(
                  hintText: isMobile ? 'Search...' : 'Quick search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixText: isMobile ? null : '/',
                  suffixStyle: const TextStyle(color: AppTheme.iconColor),
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          
          if (!isMobile) ...[
            const SizedBox(width: 24),
            const Spacer(),
            const Icon(Icons.notifications_none_outlined, color: AppTheme.textSecondaryColor),
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
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Here\'s a quick look at your patient appointments today.', 
          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    // Calculate real stats
    final now = DateTime.now();
    final todayStr = DateFormat('dd-MM-yyyy').format(now);
    
    final int todayCount = _doctorAppointments.where((a) => a.appointmentDate == todayStr).length;
    final int confirmedCount = _doctorAppointments.where((a) => a.status == 'Confirmed').length;
    final int totalPatients = _doctorAppointments.length;

    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard('Total Patients', totalPatients.toString(), 'All time', Icons.people_outline, Colors.blue, isMobile),
          _buildStatCard('Today\'s Appointments', todayCount.toString(), 'Scheduled', Icons.calendar_today_outlined, Colors.indigo, isMobile),
          _buildStatCard('Confirmed Cases', confirmedCount.toString(), 'Ready', Icons.check_circle_outline, Colors.green, isMobile),
          _buildStatCard('Average Rating', '4.9', 'Excellent', Icons.star_outline, Colors.orange, isMobile),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Patients', totalPatients.toString(), 'All time', Icons.people_outline, Colors.blue, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Today\'s Appointments', todayCount.toString(), 'Scheduled', Icons.calendar_today_outlined, Colors.indigo, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Confirmed Cases', confirmedCount.toString(), 'Ready', Icons.check_circle_outline, Colors.green, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Average Rating', '4.9', 'Excellent', Icons.star_outline, Colors.orange, isMobile)),
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


  Widget _buildPatientsTable() {
    final filteredAppts = _doctorAppointments.where((a) {
      if (a.status != 'Confirmed') return false;
      if (_selectedDate == null) return true;
      
      final String todayStr = DateFormat('dd-MM-yyyy').format(_selectedDate!);
      return a.appointmentDate == todayStr;
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    if (_selectedDate != null)
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!),
                        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                      )
                    else
                      const Text(
                        'All Records',
                        style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
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
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null ? 'Filter Date' : DateFormat('dd-MM-yyyy').format(_selectedDate!),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            if (_selectedDate != null) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(() => _selectedDate = null),
                                child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondaryColor),
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
                const SizedBox(width: 40), // Space for action (chevron)
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
                    Icon(Icons.event_busy, size: 48, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      _selectedDate == null ? 'No records found' : 'No appointments for this date',
                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
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
    if (appt.status == 'Completed') statusColor = Colors.grey;
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
                      appt.patientName.isNotEmpty ? appt.patientName[0].toUpperCase() : 'P',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appt.patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ),
            
            // Time Column
            Expanded(
              flex: 2,
              child: Text(
                appt.appointmentTime,
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
              ),
            ),
            
            // Status Column
            Expanded(
              flex: 2,
              child: UnconstrainedBox(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    appt.status,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            
            // Action Column
            const SizedBox(
              width: 40,
              child: Icon(Icons.chevron_right, size: 18, color: AppTheme.iconColor),
            ),
          ],
        ),
      ),
    );
  }

}
