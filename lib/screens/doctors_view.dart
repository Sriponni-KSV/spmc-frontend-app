import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../controllers/admin_controller.dart';
import '../models/user_model.dart';

class DoctorsView extends StatefulWidget {
  const DoctorsView({Key? key}) : super(key: key);

  @override
  State<DoctorsView> createState() => _DoctorsViewState();
}

class _DoctorsViewState extends State<DoctorsView> {
  final AdminController _adminController = AdminController();
  Future<List<UserModel>>? _doctorsFuture;
  String _searchQuery = '';
  String _selectedDepartment = 'All';



  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  void _loadDoctors() {
    setState(() {
      _doctorsFuture = _adminController.fetchStaff(role: 'Doctor');
    });
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

              final doctors = snapshot.data ?? [];
              
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
    );
  }

  Widget _buildDoctorCard(UserModel doctor, bool isMobile) {
    // Generate some mock data for fields not in DB to match screenshot aesthetics
    final String experience = '12 years'; // Mock
    final String patients = '312'; // Mock
    final String rating = '4.9'; // Mock
    final List<String> availability = ['Mon', 'Wed', 'Fri']; // Mock
    final String nextAvailable = 'Today, 2:30 PM'; // Mock

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
                      doctor.specialization ?? 'General Medicine',
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
                  doctor.specialization ?? 'Interventional Cardiology',
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
                  availability.join(', '),
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
                  onPressed: () {},
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
                onPressed: () {},
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
}
