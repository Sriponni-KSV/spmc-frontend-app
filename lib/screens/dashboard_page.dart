import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/nurse_widgets.dart';
import 'login_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // Mock data for the doctor dashboard
  final List<Map<String, dynamic>> _recentPatients = [
    {'id': 'SP-2024-001', 'name': 'Rajesh Kumar', 'age': '40 yrs', 'gender': 'Male', 'time': '10:30 AM', 'status': 'Checked In', 'color': Colors.green},
    {'id': 'SP-2024-002', 'name': 'Anita Singh', 'age': '35 yrs', 'gender': 'Female', 'time': '09:15 AM', 'status': 'Waiting', 'color': Colors.orange},
    {'id': 'SP-2024-003', 'name': 'Vikram Mehta', 'age': '29 yrs', 'gender': 'Male', 'time': 'Yesterday', 'status': 'Completed', 'color': Colors.grey},
  ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      floatingActionButton: CustomSpeedDial(
        children: [
          SpeedDialChild(
            label: 'New Prescription',
            icon: Icons.add_task,
            color: Colors.indigo,
            onTap: () {},
          ),
          SpeedDialChild(
            label: 'Adjust Schedule',
            icon: Icons.calendar_month_outlined,
            color: AppTheme.primaryColor,
            onTap: () {},
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar (only on desktop)
          if (!isMobile) _buildSidebar(context),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, isMobile),
                Expanded(
                  child: _selectedIndex == 0 
                      ? _buildDashboardView(isMobile) 
                      : _buildProfileView(isMobile),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                        minimumSize: const Size(0, 48), // Overrides global double.infinity
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Form Fields
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
                      // Call backend API to save the changes
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
          if (isMobile) ...[
            _buildNotificationBanner(isMobile),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildPatientsTable(),
            const SizedBox(height: 24),
            _buildUpcomingSchedule(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildNotificationBanner(isMobile),
                      const SizedBox(height: 24),
                      _buildPatientsTable(),
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
                      _buildUpcomingSchedule(),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
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
                Container(
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/image/full_logo.png',
                    width: 100,
                    height: 89,
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Items (Scrollable Area)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  _buildSidebarItem(0, Icons.dashboard_outlined, 'My Dashboard'),
                  _buildSidebarItem(1, Icons.person_outline, 'My Profile'),
                ],
              ),
            ),
          ),
          
          // Bottom Area (Fixed)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Quick Actions Area
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
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSmallAction('Quick Search', '/'),
                      _buildSmallAction('New Prescription', 'Alt+N'),
                      _buildSmallAction('Schedule', 'Alt+S'),
                    ],
                  ),
                ),
              ),

              // User Profile Area
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
                              Text(user.fullname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                              Text(user.role, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18, color: AppTheme.textSecondaryColor),
                          onPressed: () {
                            auth.logout();
                             Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
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
      onTap: () => setState(() {
        _selectedIndex = index;
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
           Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      height: isMobile ? 80 : 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Row(
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
            child: SizedBox(
              height: 40,
              child: TextFormField(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             Expanded(
               child: Text(
                 user != null ? 'Hello, ${user.fullname}' : 'Dashboard',
                 style: const TextStyle(
                   fontSize: 28,
                   fontWeight: FontWeight.bold,
                 ),
                 overflow: TextOverflow.ellipsis,
                 maxLines: 1,
               ),
             ),
           ],
        ),
        const SizedBox(height: 4),
        const Text('Welcome back! Here\'s your schedule overview today.', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard('Active Cases', '12', '+1', Icons.pending_actions, Colors.blue, isMobile),
          _buildStatCard('Total Consultations', '342', '+15%', Icons.assignment_outlined, Colors.indigo, isMobile),
          _buildStatCard('Average Rating', '4.9', 'Excellent', Icons.star_outline, Colors.orange, isMobile),
          _buildStatCard('New Reviews', '8', '+2', Icons.rate_review_outlined, Colors.purple, isMobile),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _buildStatCard('Active Cases', '12', '+1', Icons.pending_actions, Colors.blue, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Total Consultations', '342', '+15%', Icons.assignment_outlined, Colors.indigo, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Average Rating', '4.9', 'Excellent', Icons.star_outline, Colors.orange, isMobile)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('New Reviews', '8', '+2', Icons.rate_review_outlined, Colors.purple, isMobile)),
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

  Widget _buildNotificationBanner(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.infoBgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.infoColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Record Review Required',
                  style: TextStyle(color: AppTheme.infoColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (!isMobile) TextButton(onPressed: () {}, child: const Text('Review Now')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You have 3 patient records waiting for review and 1 pending lab report.',
            style: TextStyle(color: AppTheme.infoColor, fontWeight: FontWeight.w500, fontSize: 13),
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.infoColor),
                child: const Text('Review Now', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
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
          const Text('Doctor Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildActionButton(Icons.add_task, 'New Prescription', () {}),
          _buildActionButton(Icons.calendar_month_outlined, 'Adjust Schedule', () {}),
          _buildActionButton(Icons.folder_shared_outlined, 'Access Medical Records', () {}),
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

  Widget _buildPatientsTable() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Active Patients',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._recentPatients.map((p) => _buildPatientTile(p)).toList(),
        ],
      ),
    );
  }

  Widget _buildPatientTile(Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.backgroundColor,
            child: Text(
              p['name'].substring(0, 1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${p['id']}  •  ${p['age']} ${p['gender']}',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                p['time'],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p['status'],
                  style: TextStyle(
                    color: p['color'],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildUpcomingSchedule() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Today\'s Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildScheduleItem('Morning Rounds', 'Ward A, B', '08:30 AM', Colors.blue),
          _buildScheduleItem('Patient Consultations', 'OPD Room 4', '10:00 AM', Colors.indigo),
          _buildScheduleItem('Surgery: Minor', 'OT 1', '01:30 PM', Colors.red),
          _buildScheduleItem('Evening Review', 'General Ward', '04:00 PM', Colors.teal),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String title, String location, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(location, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        ],
      ),
    );
  }
}
