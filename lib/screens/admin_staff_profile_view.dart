import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class AdminStaffProfileView extends StatelessWidget {
  final UserModel user;
  final VoidCallback onBack;

  const AdminStaffProfileView({Key? key, required this.user, required this.onBack}) : super(key: key);

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF718096)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                ),
              ],
            ),
          ),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F5A8E)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    const sectionSpacing = SizedBox(height: 24);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: AppTheme.primaryColor, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Back to Staff List',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Professional Profile',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Overview of staff details and settings',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
          const SizedBox(height: 32),
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
                      width: 110, height: 110,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF1E3A8A)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text((user.rawFullname ?? '').isNotEmpty ? user.rawFullname![0].toUpperCase() : 'S', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.rawFullname ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3748))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                user.role,
                                style: const TextStyle(
                                  color: Color(0xFFC53030),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.status == 'active' ? Colors.green.withOpacity(0.1) : (user.status == 'suspended' ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(color: user.status == 'active' ? Colors.green : (user.status == 'suspended' ? Colors.red : Colors.grey), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.status.isNotEmpty ? user.status[0].toUpperCase() + user.status.substring(1) : '-',
                                      style: TextStyle(
                                        color: user.status == 'active' ? Colors.green : (user.status == 'suspended' ? Colors.red : Colors.grey), 
                                        fontSize: 12, 
                                        fontWeight: FontWeight.w600
                                      )
                                    ),
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
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),
                _buildDetailRow('Full Name', user.rawFullname ?? '-', Icons.person_outline),
                _buildDetailRow('Email Address', user.email, Icons.alternate_email),
                _buildDetailRow('Mobile Number', user.mobile ?? '-', Icons.phone_android_outlined),
                if (user.bio != null && user.bio!.isNotEmpty)
                  _buildDetailRow('Bio Summary', user.bio!, Icons.description_outlined),
              ],
            ),
          ),
          sectionSpacing,
          if (user.role == 'Doctor') ...[
            if (isMobile) ...[
              _buildInfoCard('Professional Details', [
                _buildDetailRow('Specialization', user.specialization ?? '-', Icons.medical_services_outlined),
                _buildDetailRow('Qualification', user.qualification ?? '-', Icons.school_outlined),
                _buildDetailRow('Medical License', user.medicalLicense ?? '-', Icons.badge_outlined),
                _buildDetailRow(
                  'Experience',
                  user.experience == null || user.experience == '0'
                      ? '-'
                      : '${user.experience} years',
                  Icons.work_history_outlined,
                ),
              ]),
              sectionSpacing,
              _buildInfoCard('Availability', [
                _buildDetailRow(
                  'Available Days',
                  (user.availableDays == null || user.availableDays!.isEmpty)
                      ? '-'
                      : user.availableDays!.join(', '),
                  Icons.calendar_month_outlined,
                ),
                _buildDetailRow('Consultation Hours', '${user.slotStartTime ?? "-"} to ${user.slotEndTime ?? "-"}', Icons.access_time_rounded),
                _buildDetailRow('Slot Duration', user.slotDuration ?? '-', Icons.timer_outlined),
                _buildDetailRow(
                  'Weekly Off',
                  (user.weeklyOffDays ?? []).isEmpty
                      ? '-'
                      : user.weeklyOffDays!.join(', '),
                  Icons.event_busy_outlined,
                ),
              ]),
              sectionSpacing,
              _buildInfoCard('Clinic Details', [
                _buildDetailRow('Clinic Name', user.clinicName ?? '-', Icons.business_outlined),
                _buildDetailRow('Location', user.clinicLocation ?? '-', Icons.location_on_outlined),
                _buildDetailRow('Consultation Fee', user.consultationFee == null || user.consultationFee == '0' ? '-' : '₹${user.consultationFee}', Icons.payments_outlined),
              ]),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildInfoCard('Professional Details', [
                      _buildDetailRow('Specialization', user.specialization ?? '-', Icons.medical_services_outlined),
                      _buildDetailRow('Qualification', user.qualification ?? '-', Icons.school_outlined),
                      _buildDetailRow('Medical License', user.medicalLicense ?? '-', Icons.badge_outlined),
                      _buildDetailRow(
                        'Experience',
                        user.experience == null || user.experience == '0'
                            ? '-'
                            : '${user.experience} years',
                        Icons.work_history_outlined,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildInfoCard('Availability', [
                      _buildDetailRow(
                        'Available Days',
                        (user.availableDays == null || user.availableDays!.isEmpty)
                            ? '-'
                            : user.availableDays!.join(', '),
                        Icons.calendar_month_outlined,
                      ),
                      _buildDetailRow('Consultation Hours', '${user.slotStartTime ?? "-"} to ${user.slotEndTime ?? "-"}', Icons.access_time_rounded),
                      _buildDetailRow('Slot Duration', user.slotDuration ?? '-', Icons.timer_outlined),
                      _buildDetailRow(
                        'Weekly Off',
                        (user.weeklyOffDays ?? []).isEmpty
                            ? '-'
                            : user.weeklyOffDays!.join(', '),
                        Icons.event_busy_outlined,
                      ),
                    ]),
                  ),
                ],
              ),
              sectionSpacing,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildInfoCard('Clinic Details', [
                      _buildDetailRow('Clinic Name', user.clinicName ?? '-', Icons.business_outlined),
                      _buildDetailRow('Location', user.clinicLocation ?? '-', Icons.location_on_outlined),
                      _buildDetailRow('Consultation Fee', user.consultationFee == null || user.consultationFee == '0' ? '-' : '₹${user.consultationFee}', Icons.payments_outlined),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ] else if (user.role == 'Nurse') ...[
             if (isMobile) ...[
              _buildInfoCard('Professional Details', [
                _buildDetailRow('Qualification', user.qualification ?? '-', Icons.school_outlined),
                _buildDetailRow('Nursing Registration Number', user.nursingRegistrationNumber ?? '-', Icons.badge_outlined),
                _buildDetailRow(
                  'Years of Experience',
                  user.yearsOfExperience == null || user.yearsOfExperience == '0'
                      ? '-'
                      : '${user.yearsOfExperience} years',
                  Icons.work_history_outlined,
                ),
              ]),
              sectionSpacing,
              _buildInfoCard('Availability / Duty', [
                _buildDetailRow(
                  'Working Days',
                  (user.workingDays == null || user.workingDays!.isEmpty)
                      ? '-'
                      : user.workingDays!.join(', '),
                  Icons.calendar_month_outlined,
                ),
                _buildDetailRow('Shift Hours', '${user.shiftStartTime ?? "-"} to ${user.shiftEndTime ?? "-"}', Icons.access_time_rounded),
                _buildDetailRow('Shift Type', user.shiftType ?? '-', Icons.event_available_outlined),
                _buildDetailRow(
                  'Weekly Off',
                  (user.weeklyOffDays ?? []).isEmpty
                      ? '-'
                      : user.weeklyOffDays!.join(', '),
                  Icons.event_busy_outlined,
                ),
                _buildDetailRow(
                  'Specific Leave Dates',
                  (user.specificLeaveDates == null || user.specificLeaveDates!.isEmpty)
                      ? '-'
                      : user.specificLeaveDates!.join(', '),
                  Icons.calendar_today_outlined,
                ),
              ]),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildInfoCard('Professional Details', [
                      _buildDetailRow('Qualification', user.qualification ?? '-', Icons.school_outlined),
                      _buildDetailRow('Nursing Registration Number', user.nursingRegistrationNumber ?? '-', Icons.badge_outlined),
                      _buildDetailRow(
                        'Years of Experience',
                        user.yearsOfExperience == null || user.yearsOfExperience == '0'
                            ? '-'
                            : '${user.yearsOfExperience} years',
                        Icons.work_history_outlined,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildInfoCard('Availability / Duty', [
                      _buildDetailRow(
                        'Working Days',
                        (user.workingDays == null || user.workingDays!.isEmpty)
                            ? '-'
                            : user.workingDays!.join(', '),
                        Icons.calendar_month_outlined,
                      ),
                      _buildDetailRow('Shift Hours', '${user.shiftStartTime ?? "-"} to ${user.shiftEndTime ?? "-"}', Icons.access_time_rounded),
                      _buildDetailRow('Shift Type', user.shiftType ?? '-', Icons.event_available_outlined),
                      _buildDetailRow(
                        'Weekly Off',
                        (user.weeklyOffDays ?? []).isEmpty
                            ? '-'
                            : user.weeklyOffDays!.join(', '),
                        Icons.event_busy_outlined,
                      ),
                      _buildDetailRow(
                        'Specific Leave Dates',
                        (user.specificLeaveDates == null || user.specificLeaveDates!.isEmpty)
                            ? '-'
                            : user.specificLeaveDates!.join(', '),
                        Icons.calendar_today_outlined,
                      ),
                    ]),
                  ),
                ],
              ),
            ],
          ] else ...[ 
             _buildInfoCard('System Details', [
                _buildDetailRow('Staff ID', user.staffUniqueId ?? '-', Icons.badge_outlined),
                _buildDetailRow('Role', user.role, Icons.security_outlined),
                _buildDetailRow(
                  'Status',
                  user.status[0].toUpperCase() + user.status.substring(1),
                  user.status == 'active' ? Icons.check_circle_outline : Icons.error_outline,
                ),
              ]),
          ],
        ],
      ),
    );
  }
}
