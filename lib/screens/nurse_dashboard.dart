import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../widgets/live_clock.dart';
import 'login_page.dart';

class NurseDashboardScreen extends StatefulWidget {
  final UserModel user;
  const NurseDashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: isMobile ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          // Sidebar (only on desktop)
          if (!isMobile) _buildSidebar(context),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, isMobile),
                Expanded(
                  child: SingleChildScrollView(
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
                          _buildRecentPatients(),
                          const SizedBox(height: 24),
                          _buildUpcomingAppointments(),
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
                                    _buildRecentPatients(),
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
                                    _buildUpcomingAppointments(),
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
            ),
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
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'image/full_logo.png', width: 100, height: 89,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          
          // Navigation Items
          _buildSidebarItem(0, Icons.dashboard_outlined, 'Dashboard'),
          _buildSidebarItem(1, Icons.people_outline, 'Patients'),
          _buildSidebarItem(2, Icons.calendar_today_outlined, 'Appointments'),
          
          const Spacer(),
          
          // Bottom Quick Actions Area
          Padding(
            padding: const EdgeInsets.all(24.0),
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
                  _buildSmallAction('New Patient', 'Alt+N'),
                  _buildSmallAction('Book Appl.', 'Alt+B'),
                ],
              ),
            ),
          ),
          
          // User Profile Area
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
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
                      Text(widget.user.fullname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Text(widget.user.role, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 18, color: AppTheme.textSecondaryColor),
                  onPressed: () {
                     Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
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
          
          // Search Bar (Flexible on mobile)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Welcome back! Here\'s your hospital overview', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    if (isMobile) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildStatCard('Total Patients', '1,248', '+12%', Icons.people_outline, Colors.blue, isMobile),
          _buildStatCard('Today\'s Appointments', '32', '+5', Icons.calendar_today_outlined, Colors.indigo, isMobile),
          _buildStatCard('Active Home Care', '48', '+8%', Icons.monitor_heart_outlined, Colors.green, isMobile),
          _buildStatCard('Patient Visits', '156', '+18%', Icons.trending_up, Colors.cyan, isMobile),
        ],
      );
    }
    return Row(
      children: [
        _buildStatCard('Total Patients', '1,248', '+12%', Icons.people_outline, Colors.blue, isMobile),
        const SizedBox(width: 16),
        _buildStatCard('Today\'s Appointments', '32', '+5', Icons.calendar_today_outlined, Colors.indigo, isMobile),
        const SizedBox(width: 16),
        _buildStatCard('Active Home Care', '48', '+8%', Icons.monitor_heart_outlined, Colors.green, isMobile),
        const SizedBox(width: 16),
        _buildStatCard('Patient Visits', '156', '+18%', Icons.trending_up, Colors.cyan, isMobile),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String change, IconData icon, Color color, bool isMobile) {
    Widget card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(change, style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
        ],
      ),
    );

    if (isMobile) {
      return SizedBox(
        width: (MediaQuery.of(context).size.width - 48) / 2, // 2 cards per row on mobile
        child: card,
      );
    }
    return Expanded(child: card);
  }

  Widget _buildAlertsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.alertTextColor, size: 20),
              SizedBox(width: 8),
              Text('Alerts & Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(AppTheme.alertBgColor, AppTheme.alertTextColor, 'Low inventory: Rice stock running low (5kg remaining)', '10 mins ago'),
          const SizedBox(height: 12),
          _buildAlertItem(AppTheme.infoBgColor, AppTheme.infoColor, '3 patients awaiting lab results', '30 mins ago'),
        ],
      ),
    );
  }

  Widget _buildAlertItem(Color bg, Color textColor, String text, String time) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
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
          const Text('Quick Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildActionButton(Icons.person_add_outlined, 'Register New Patient', () {}),
          _buildActionButton(Icons.calendar_month_outlined, 'Book Appointment', () {}),
          _buildActionButton(Icons.medical_services_outlined, 'Check Inventory', () {}),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPatients() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Patients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildPatientItem('John Smith', '45y • Male', '10:30 AM', 'Checked In', Colors.green),
          _buildPatientItem('Sarah Johnson', '32y • Female', '9:15 AM', 'Waiting', Colors.orange),
          _buildPatientItem('Robert Brown', '58y • Male', 'Yesterday', 'Completed', Colors.grey),
          _buildPatientItem('Emily Davis', '28y • Female', '2 days ago', 'Completed', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildPatientItem(String name, String info, String time, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.backgroundColor,
            child: Text(name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(info, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upcoming Appointments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 16),
          _buildAppointmentItem('Michael Wilson', 'Dr. Amanda Lee', '11:00 AM', 'Cardiology'),
          _buildAppointmentItem('Jessica Taylor', 'Dr. Robert Chen', '11:30 AM', 'General Medicine'),
          _buildAppointmentItem('David Martinez', 'Dr. Sarah Kumar', '12:00 PM', 'Orthopedics'),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(String name, String doctor, String time, String dept) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(doctor, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(4)),
            child: Text(dept, style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderColor),
        ],
      ),
    );
  }
}


