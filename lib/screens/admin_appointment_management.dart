import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/admin_controller.dart';
import '../providers/auth_provider.dart';

class AdminAppointmentManagement extends StatefulWidget {
  const AdminAppointmentManagement({Key? key}) : super(key: key);

  @override
  State<AdminAppointmentManagement> createState() =>
      _AdminAppointmentManagementState();
}

class _AdminAppointmentManagementState
    extends State<AdminAppointmentManagement> {
  final AppointmentController _apptCtrl = AppointmentController();
  final AdminController _adminCtrl = AdminController();

  List<AppointmentModel> _appointments = [];
  List<UserModel> _doctors = [];
  List<String> _departments = [];
  bool _isLoading = false;
  String? _errorMsg;

  // Filter state
  DateTime? _filterDate;
  String? _filterDoctor;
  String _filterStatus = 'All';

  final List<String> _statusOptions = [
    'All', 'Confirmed', 'Waiting', 'In Consultation', 'Completed', 'Cancelled', 'No-Show', 'Rescheduled'
  ];

  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  List<String> _generateSlotsForSession(int startHour, int startMin, int endHour, int endMin) {
    List<String> sessionSlots = [];
    DateTime start = DateTime(2026, 1, 1, startHour, startMin);
    DateTime end = DateTime(2026, 1, 1, endHour, endMin);
    while (start.isBefore(end)) {
      sessionSlots.add(DateFormat('hh:mm a').format(start));
      start = start.add(const Duration(minutes: 30));
    }
    return sessionSlots;
  }

  List<String> _getAllSlots() {
    List<String> slots = [];
    slots.addAll(_generateSlotsForSession(9, 0, 13, 0));
    slots.addAll(_generateSlotsForSession(14, 0, 17, 0));
    return slots;
  }

  List<String> _getFilteredTimeSlots(DateTime? date) {
    if (date == null) return [];
    List<String> slots = _getAllSlots();
    DateTime now = DateTime.now();
    bool isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (!isToday) return slots;
    return slots.where((slot) {
      try {
        DateTime slotTime = DateFormat('hh:mm a').parse(slot);
        DateTime fullSlotTime = DateTime(date.year, date.month, date.day, slotTime.hour, slotTime.minute);
        return fullSlotTime.isAfter(now);
      } catch (e) {
        return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final String? dateStr = _filterDate != null
          ? DateFormat('yyyy-MM-dd').format(_filterDate!)
          : null;
      final results = await Future.wait([
        _apptCtrl.fetchAdminAppointments(
          date: dateStr,
          doctor: _filterDoctor,
          status: _filterStatus == 'All' ? null : (_filterStatus == 'Waiting' ? 'Checked-in' : _filterStatus),
        ),
        _adminCtrl.fetchStaff(role: 'Doctor'),
        _adminCtrl.fetchSpecializations(),
      ]);
      setState(() {
        _appointments = results[0] as List<AppointmentModel>;
        _doctors = results[1] as List<UserModel>;
        final specs = results[2] as List<dynamic>;
        _departments = specs.map((e) => e['name'].toString()).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMsg = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Confirmed': return const Color(0xFF3B82F6);
      case 'Waiting':
      case 'Checked-in': return const Color(0xFF0D9488);
      case 'In Consultation': return const Color(0xFFF59E0B);
      case 'Completed': return const Color(0xFF22C55E);
      case 'Cancelled': return const Color(0xFFEF4444);
      case 'No-Show':   return const Color(0xFFF97316);
      case 'Rescheduled': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  void _showOverrideDialog(AppointmentModel appt, {required String mode}) {
    // mode: 'edit' | 'cancel' | 'reschedule' | 'view' | 'reopen'
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final reasonCtrl = TextEditingController();
    String? selectedStatus = appt.status;
    String? selectedDoctor = appt.doctorName;
    DateTime? newDate;
    try { newDate = DateFormat('dd-MM-yyyy').parse(appt.appointmentDate); } catch(e){}
    String? newTime = appt.appointmentTime;
    String? patientName = appt.patientName;
    String? department = appt.department;
    String? appointmentType = appt.appointmentType;
    bool isSaving = false;

    List<String> availableStatuses = ['Confirmed', 'Checked-in', 'In Consultation', 'Completed', 'Cancelled', 'No-Show', 'Rescheduled'];
    if (appt.status == 'Completed') {
      availableStatuses = ['Confirmed', 'Completed', 'No-Show'];
    } else if (appt.status == 'Cancelled') {
      availableStatuses = ['Confirmed', 'Cancelled'];
    } else if (appt.status == 'No-Show') {
      availableStatuses = ['Confirmed', 'Completed', 'No-Show'];
    }
    
    final List<String> apptTypes = ['Routine', 'Follow Up', 'New Visit', 'Scheduled', 'Emergency'];
    
    // Initial doctor filtering
    List<String> filteredDoctors = _doctors
        .where((d) => d.specialization == department)
        .map((d) => d.fullname)
        .toList();
    if (!filteredDoctors.contains(selectedDoctor)) {
      filteredDoctors.insert(0, selectedDoctor);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Widget buildField(String label, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 6),
            child,
            const SizedBox(height: 14),
          ],
        );

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(
                mode == 'view' ? Icons.visibility_outlined :
                mode == 'cancel' ? Icons.cancel_outlined :
                mode == 'reschedule' ? Icons.schedule_outlined :
                mode == 'reopen' ? Icons.restore_outlined :
                Icons.edit_outlined,
                color: AppTheme.primaryColor, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              mode == 'view' ? 'Appointment Detail' :
              mode == 'cancel' ? 'Cancel Appointment' :
              mode == 'reschedule' ? 'Reschedule Appointment' :
              mode == 'reopen' ? 'Change Status' :
              'Edit Appointment',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ]),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),
                // Info card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(children: [
                    _infoRow('Patient', appt.patientName, Icons.person_outline),
                    _infoRow('Doctor', appt.doctorName, Icons.medical_services_outlined),
                    _infoRow('Date', appt.appointmentDate, Icons.calendar_today_outlined),
                    _infoRow('Time', appt.appointmentTime, Icons.access_time_outlined),
                    _infoRow('Status', appt.status, Icons.info_outline),
                    if (appt.reasonForVisit != null)
                      _infoRow('Reason', appt.reasonForVisit!, Icons.notes_outlined),
                  ]),
                ),

                if (mode == 'view' && appt.overrideReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDBA74))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFF97316)),
                        const SizedBox(width: 8),
                        Text('Admin Correction by ${appt.overrideByName ?? "Unknown"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
                      ]),
                      const SizedBox(height: 8),
                      Text('Reason: ${appt.overrideReason}', style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                    ]),
                  ),
                ],

                if (mode != 'view') ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('Admin Correction', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 15)),
                  const SizedBox(height: 14),

                  // Status field (edit/cancel/reopen)
                  if (mode == 'edit' || mode == 'cancel' || mode == 'reopen')
                    buildField('Force Status Change', DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: availableStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s == 'Checked-in' ? 'Waiting' : s))).toList(),
                      onChanged: mode == 'view' ? null : (v) => setS(() => selectedStatus = v),
                    )),

                  // Edit Fields
                  if (mode == 'edit') ...[
                    buildField('Patient Name', TextFormField(
                      initialValue: patientName,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      onChanged: (v) => patientName = v,
                    )),
                    buildField('Department', DropdownButtonFormField<String>(
                      value: _departments.contains(department) ? department : null,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      hint: const Text('Select department'),
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) {
                        setS(() {
                          department = v;
                          filteredDoctors = _doctors
                              .where((d) => d.specialization == v)
                              .map((d) => d.fullname)
                              .toList();
                          if (filteredDoctors.isNotEmpty) {
                            selectedDoctor = filteredDoctors[0];
                          } else {
                            selectedDoctor = null;
                          }
                        });
                      },
                    )),
                    buildField('Appointment Type', DropdownButtonFormField<String>(
                      value: apptTypes.contains(appointmentType) ? appointmentType : null,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: apptTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setS(() => appointmentType = v),
                    )),
                    buildField('Reassign Doctor', DropdownButtonFormField<String>(
                      value: filteredDoctors.contains(selectedDoctor) ? selectedDoctor : null,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      hint: const Text('Select doctor'),
                      items: filteredDoctors.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) => setS(() => selectedDoctor = v),
                    )),
                  ],

                  // Date/time (edit/reschedule)
                  if (mode == 'edit' || mode == 'reschedule') ...[
                    buildField('New Date', InkWell(
                      onTap: () async {
                        DateTime initDate = newDate ?? DateTime.now();
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        if (initDate.isBefore(today)) initDate = today;

                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: initDate,
                          firstDate: today,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setS(() => newDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 8),
                          Text(newDate != null ? DateFormat('dd-MM-yyyy').format(newDate!) : 'Pick a date',
                              style: TextStyle(color: newDate != null ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor)),
                        ]),
                      ),
                    )),
                    buildField('New Time Slot', Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _getFilteredTimeSlots(newDate).map((slot) {
                        final isSelected = newTime == slot;
                        return InkWell(
                          onTap: () => setS(() => newTime = slot),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
                            ),
                            child: Text(slot, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimaryColor, fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    )),
                  ],

                  // Override reason (mandatory)
                  buildField('Override Reason *', TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for this override (required)',
                      contentPadding: const EdgeInsets.all(12),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                    ),
                    onChanged: (_) => setS(() {}),
                  )),

                  // Audit who
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDBA74))),
                    child: Row(children: [
                      const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFF97316)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Override by: ${user?.fullname ?? ''} (${user?.role ?? ''})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (mode != 'view')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mode == 'cancel' ? Colors.red : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSaving ? null : () async {
                  if (reasonCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Override reason is required.'),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }
                  setS(() => isSaving = true);
                  try {
                    await _apptCtrl.adminOverrideAppointment(
                      id: appt.id!,
                      status: mode == 'cancel' ? 'Cancelled' : selectedStatus,
                      doctorName: (mode == 'edit' || mode == 'reschedule') ? selectedDoctor : null,
                      appointmentDate: (mode == 'reschedule' || mode == 'edit') && newDate != null
                          ? DateFormat('dd-MM-yyyy').format(newDate!)
                          : null,
                      appointmentTime: (mode == 'reschedule' || mode == 'edit') ? newTime : null,
                      patientName: mode == 'edit' ? patientName : null,
                      department: mode == 'edit' ? department : null,
                      appointmentType: mode == 'edit' ? appointmentType : null,
                      overrideReason: reasonCtrl.text.trim(),
                    );
                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Appointment updated successfully.'),
                        backgroundColor: Colors.green.shade600,
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red,
                      ));
                    }
                  } finally {
                    if (mounted) setS(() => isSaving = false);
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(mode == 'cancel' ? 'Confirm Cancel' : mode == 'reschedule' ? 'Reschedule' : mode == 'reopen' ? 'Confirm Change' : 'Save Override'),
              ),
          ],
        );
      }),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Column(children: [
      // Header
      Container(
        padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 24, isMobile ? 16 : 24, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Appointment Management', style: TextStyle(fontSize: isMobile ? 20 : 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
            const SizedBox(height: 4),
            const Text('View, edit, cancel and reschedule appointments', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
          ]),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_outlined, color: AppTheme.primaryColor),
            tooltip: 'Refresh',
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Filters
      Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          // Date filter
          SizedBox(
            width: isMobile ? double.infinity : 200,
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _filterDate ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _filterDate = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondaryColor),
                  const SizedBox(width: 8),
                  Text(
                    _filterDate != null ? DateFormat('dd-MM-yyyy').format(_filterDate!) : 'Filter by date',
                    style: TextStyle(fontSize: 13, color: _filterDate != null ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor),
                  ),
                  if (_filterDate != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _filterDate = null),
                      child: const Icon(Icons.close, size: 14, color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ]),
              ),
            ),
          ),

          // Doctor filter
          SizedBox(
            width: isMobile ? double.infinity : 200,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _filterDoctor,
              decoration: const InputDecoration(
                hintText: 'Filter by doctor',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: Icon(Icons.medical_services_outlined, size: 16),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Doctors')),
                ..._doctors.map((d) => DropdownMenuItem(value: d.fullname, child: Text(d.fullname, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _filterDoctor = v),
            ),
          ),

          // Status filter
          SizedBox(
            width: isMobile ? double.infinity : 180,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _filterStatus,
              decoration: const InputDecoration(
                hintText: 'Filter by status',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: Icon(Icons.circle_outlined, size: 16),
              ),
              items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _filterStatus = v ?? 'All'),
            ),
          ),

          // Apply button
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Apply Filters'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // Clear filters
          if (_filterDate != null || _filterDoctor != null || _filterStatus != 'All')
            OutlinedButton.icon(
              onPressed: () => setState(() { _filterDate = null; _filterDoctor = null; _filterStatus = 'All'; }),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(100, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ]),
      ),

      const SizedBox(height: 16),

      // Stats bar
      Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
        child: Row(children: [
          for (final s in ['Confirmed', 'Completed', 'Cancelled', 'No-Show'])
            Expanded(child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _statusColor(s).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _statusColor(s).withOpacity(0.3)),
              ),
              child: Column(children: [
                Text(
                  '${_appointments.where((a) => a.status == s).length}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _statusColor(s)),
                ),
                Text(s, style: TextStyle(fontSize: 10, color: _statusColor(s))),
              ]),
            )),
        ]),
      ),

      const SizedBox(height: 16),

      // Table
      Expanded(child: _buildTable(isMobile)),
    ]);
  }

  Widget _buildTable(bool isMobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
      ]));
    }
    if (_appointments.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event_busy_outlined, size: 56, color: AppTheme.textSecondaryColor.withOpacity(0.4)),
        const SizedBox(height: 12),
        const Text('No appointments found', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Try adjusting your filters', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
      ]));
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(builder: (ctx, constraints) => Scrollbar(
          controller: _vScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vScroll,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  headingRowHeight: 52,
                  dataRowMinHeight: 58,
                  dataRowMaxHeight: 72,
                  headingRowColor: WidgetStateProperty.all(AppTheme.backgroundColor),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 12),
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Patient')),
                    DataColumn(label: Text('Doctor')),
                    DataColumn(label: Text('Department')),
                    DataColumn(label: Text('Date & Time')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Override')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _appointments.map((appt) {
                    final sc = _statusColor(appt.status);
                    final hasOverride = appt.overrideReason != null && appt.overrideReason!.isNotEmpty;
                    return DataRow(cells: [
                      DataCell(Text('${appt.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryColor))),
                      DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(appt.patientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('ID: ${appt.patientDisplayId ?? appt.patientId}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                      ])),
                      DataCell(Text(appt.doctorName, style: const TextStyle(fontSize: 13))),
                      DataCell(Text(appt.department, style: const TextStyle(fontSize: 13))),
                      DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(appt.appointmentDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(appt.appointmentTime, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
                      ])),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: Text(appt.appointmentType, style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                      )),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(appt.status == 'Checked-in' ? 'Waiting' : appt.status, style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      )),
                      DataCell(hasOverride
                          ? Tooltip(
                              message: 'Correction applied: ${appt.overrideReason ?? ""}',
                              child: Icon(Icons.admin_panel_settings_outlined, size: 16, color: const Color(0xFFF97316)),
                            )
                          : const Text('—', style: TextStyle(color: AppTheme.textSecondaryColor))),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        // View
                        _actionBtn(Icons.visibility_outlined, 'View', const Color(0xFF6366F1), () => _showOverrideDialog(appt, mode: 'view')),
                        // Edit
                        if (appt.status == 'Confirmed' || appt.status == 'Completed')
                          _actionBtn(Icons.edit_outlined, 'Edit', AppTheme.primaryColor, () => _showOverrideDialog(appt, mode: 'edit')),
                        // Reschedule
                        if (appt.status == 'Confirmed')
                          _actionBtn(Icons.schedule_outlined, 'Reschedule', const Color(0xFF8B5CF6), () => _showOverrideDialog(appt, mode: 'reschedule')),
                        // Cancel
                        if (appt.status == 'Confirmed')
                          _actionBtn(Icons.cancel_outlined, 'Cancel', Colors.redAccent, () => _showOverrideDialog(appt, mode: 'cancel')),
                        // Reopen
                        if (appt.status == 'Cancelled' || appt.status == 'No-Show')
                          _actionBtn(Icons.restore_outlined, 'Change Status', const Color(0xFF22C55E), () => _showOverrideDialog(appt, mode: 'reopen')),
                      ])),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        )),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
