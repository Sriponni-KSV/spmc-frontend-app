import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';
import '../models/appointment_model.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../utils/date_formatter.dart';
import '../widgets/custom_dropdown_search.dart';

/// Nurse-only OPD Assistance screen.
/// Flow: Patient Arrives → Mark Arrived → Record Vitals → Send to Doctor
class NurseOPDAssistanceScreen extends StatefulWidget {
  final bool isMobile;
  const NurseOPDAssistanceScreen({Key? key, required this.isMobile})
    : super(key: key);

  @override
  State<NurseOPDAssistanceScreen> createState() =>
      _NurseOPDAssistanceScreenState();
}

class _NurseOPDAssistanceScreenState extends State<NurseOPDAssistanceScreen>
    with SingleTickerProviderStateMixin {
  final AppointmentController _ctrl = AppointmentController();
  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();

  late TabController _tabController;

  List<AppointmentModel> _appointments = [];
  List<Map<String, dynamic>> _consultations = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Tab labels + status filters
  static const _tabs = [
    {'label': 'Awaiting Arrival', 'status': 'Confirmed'},
    {'label': 'Triaged / Waiting', 'status': 'Checked-in'},
    {'label': 'In Consultation', 'status': 'In Consultation'},
    {'label': 'Completed', 'status': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Fetch today's appointments for the active-queue tabs
      final data = await _ctrl.fetchAdminAppointments(date: today);
      // Fetch ALL consultations (no date filter) so Completed tab shows history
      final consultationsData = await _ctrl.fetchConsultations();
      if (mounted)
        setState(() {
          _appointments = data.where(_isWalkIn).toList();
          _consultations = consultationsData;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
    }
  }

  bool _isWalkIn(AppointmentModel appointment) {
    final normalized = appointment.appointmentType
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '');
    return normalized == 'walkin';
  }

  DateTime _sortDate(AppointmentModel appointment) {
    return DateTime.tryParse(
          appointment.createdAt ?? appointment.updatedAt ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _newestFirst(AppointmentModel a, AppointmentModel b) {
    final dateCompare = _sortDate(b).compareTo(_sortDate(a));
    if (dateCompare != 0) return dateCompare;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  List<AppointmentModel> _forTab(int idx) {
    final status = _tabs[idx]['status']!;

    // Completed tab: build list from consultations (all dates, not date-filtered)
    if (idx == 3) {
      final q = _search.toLowerCase().trim();
      final completedApps = _consultations.map((c) {
        // Build a lightweight AppointmentModel from the consultation join data
        return AppointmentModel(
          id: c['appointment_id'] as int?,
          patientId: c['patient_id'] as int? ?? 0,
          patientName: c['patient_name'] as String? ?? 'Unknown',
          doctorName: c['doctor_name'] as String? ?? '',
          appointmentDate: c['appointment_date'] as String? ?? '',
          appointmentTime: c['appointment_time'] as String? ?? '',
          department: c['department'] as String? ?? '',
          appointmentType: 'Walk-in',
          status: 'Completed',
          patientDisplayId: c['patient_display_id'] as String?,
          patientPhone: c['patient_phone'] as String?,
          changesLog: c['changes_log'],
          createdAt: c['created_at'] as String?,
          updatedAt: c['updated_at'] as String?,
        );
      }).where((a) {
        if (q.isEmpty) return true;
        return a.patientName.toLowerCase().contains(q) ||
            (a.patientDisplayId?.toLowerCase().contains(q) ?? false) ||
            a.doctorName.toLowerCase().contains(q);
      }).toList();
      completedApps.sort(_newestFirst);
      return completedApps;
    }

    final apps = _appointments.where((a) {
      final matchStatus = (status == 'Checked-in')
          ? (a.status == 'Checked-in' || a.status == 'Waiting')
          : a.status == status;
      if (_search.trim().isEmpty) return matchStatus;
      final q = _search.toLowerCase();
      return matchStatus &&
          (a.patientName.toLowerCase().contains(q) ||
              (a.patientDisplayId?.toLowerCase().contains(q) ?? false) ||
              a.doctorName.toLowerCase().contains(q));
    }).toList();
    apps.sort(_newestFirst);
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.isMobile ? 16.0 : 24.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_hospital_outlined,
                      color: Color(0xFF0D9488),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPD Assistance',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const Text(
                        "Today's patient arrival & triage queue",
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showWalkInDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      widget.isMobile ? 'Walk-in' : 'New Walk-in Entry',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(
                      Icons.refresh,
                      color: AppTheme.textSecondaryColor,
                    ),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 18,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search patient name or ID...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_search.isNotEmpty)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tab bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF0D9488),
                unselectedLabelColor: AppTheme.textSecondaryColor,
                indicatorColor: const Color(0xFF0D9488),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: List.generate(_tabs.length, (i) {
                  final count = _forTab(i).length;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_tabs[i]['label']!),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const Divider(height: 1),
            ],
          ),
        ),

        // ── Tab Content ──────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(_tabs.length, (i) => _buildList(i)),
                ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildList(int tabIdx) {
    final list = _forTab(tabIdx);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: AppTheme.textSecondaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No patients in "${_tabs[tabIdx]['label']}"',
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildCard(list[i], tabIdx),
    );
  }

  Widget _buildCard(AppointmentModel app, int tabIdx) {
    final avatarColors = AppTheme.getAvatarColors(app.patientName);
    final bool isConfirmed = app.status == 'Confirmed';
    final bool isCheckedIn = app.status == 'Checked-in';
    final bool inConsult = app.status == 'In Consultation';
    final bool isCompleted = app.status == 'Completed';

    Color lineColor;
    if (isConfirmed)
      lineColor = const Color(0xFF3B82F6);
    else if (isCheckedIn || app.status == 'Waiting')
      lineColor = const Color(0xFF0D9488);
    else if (inConsult)
      lineColor = const Color(0xFFF59E0B);
    else
      lineColor = const Color(0xFF22C55E);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: lineColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + info + time badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColors['bg'],
                  child: Text(
                    app.patientName.isNotEmpty
                        ? app.patientName[0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color: avatarColors['text'],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              app.patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (app.patientDisplayId != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                app.patientDisplayId!,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.medical_services_outlined,
                            size: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Dr. ${app.doctorName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${app.department}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedColor,
                            ),
                          ),
                        ],
                      ),
                      if (app.patientPhone != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: AppTheme.textMutedColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              app.patientPhone!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMutedColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Date + Time pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted ? Icons.calendar_today : Icons.access_time,
                        size: 12,
                        color: lineColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompleted
                            ? '${app.appointmentDate}  ${app.appointmentTime}'
                            : app.appointmentTime,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: lineColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Vitals row (if any recorded)
            if (app.bloodPressureSystolic != null ||
                app.temperature != null ||
                app.sugarLevel != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (app.bloodPressureSystolic != null)
                    _vitalChip(
                      Icons.speed,
                      'BP: ${app.bloodPressureSystolic}/${app.bloodPressureDiastolic ?? "--"} mmHg',
                      Colors.blue.shade700,
                    ),
                  if (app.temperature != null)
                    _vitalChip(
                      Icons.thermostat_outlined,
                      'Temp: ${app.temperature} °F',
                      Colors.orange.shade700,
                    ),
                  if (app.sugarLevel != null)
                    _vitalChip(
                      Icons.bloodtype_outlined,
                      'Sugar: ${app.sugarLevel} mg/dL',
                      Colors.red.shade700,
                    ),
                ],
              ),
            ],

            // Complaint
            if (app.reasonForVisit != null &&
                app.reasonForVisit!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Complaint: ${app.reasonForVisit}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Action Buttons ───────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (isConfirmed) ...[
                  ElevatedButton.icon(
                    onPressed: () => _showCancelAppointmentDialog(app),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                  ),
                ] else if (isCheckedIn || app.status == 'Waiting') ...[
                  ElevatedButton.icon(
                    onPressed: () => _showTriageDialog(app),
                    icon: const Icon(Icons.edit_note, size: 15),
                    label: const Text(
                      'Edit Vitals',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCancelAppointmentDialog(app),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      '-',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vitalChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  bool _hasVitals(AppointmentModel app) {
    return app.bloodPressureSystolic != null && app.temperature != null;
  }

  Future<void> _markWaiting(AppointmentModel app) async {
    try {
      await _ctrl.updateStatus(app.id!, 'Waiting');
      _load();
      _tabController.animateTo(1); // jump to Triaged tab
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app.patientName} ${context.tr('patient_marked_waiting', fallback: 'marked as Waiting ✓')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showCancelAppointmentDialog(AppointmentModel app) async {
    final cancelReasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: AppTheme.dangerColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              context.tr('cancel_appointment', fallback: 'Cancel Appointment'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('cancel_appointment_confirm', fallback: 'Are you sure you want to cancel the appointment for')} ${app.patientName}?',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('reason_for_cancellation', fallback: 'Reason for Cancellation *'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: cancelReasonController,
                  maxLines: 3,
                  maxLength: 200,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                    ),
                    LengthLimitingTextInputFormatter(200),
                  ],
                  validator: (val) {
                    final v = val?.trim() ?? '';
                    if (v.isEmpty) {
                      return context.tr('enter_cancellation_reason', fallback: 'Please enter a cancellation reason');
                    }
                    if (v.length < 3) {
                      return context.tr('reason_min_3_chars', fallback: 'Reason must be at least 3 characters');
                    }
                    if (v.length > 200) {
                      return context.tr('reason_max_200_chars', fallback: 'Reason cannot exceed 200 characters');
                    }
                    if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
                      return context.tr('reason_must_contain_letters', fallback: 'Reason must contain alphabetic characters');
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: context.tr('cancel_reason_hint', fallback: 'e.g. Patient requested cancellation due to personal emergency'),
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondaryColor,
              side: const BorderSide(color: AppTheme.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(context.tr('keep_appointment', fallback: 'Keep Appointment')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              Navigator.pop(ctx);
              try {
                await _ctrl.updateStatus(
                  app.id!,
                  'Cancelled',
                  cancellationReason: cancelReasonController.text.trim(),
                );
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${app.patientName} ${context.tr('appointment_cancelled_success', fallback: 'cancelled ✓')}'),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(context.tr('cancel_appointment', fallback: 'Cancel Appointment')),
          ),
        ],
      ),
    );
  }

  void _showTriageDialog(AppointmentModel app) {
    final apptDt = DateFormatter.toDateTime(app.appointmentDate);
    if (apptDt != null) {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final apptMidnight = DateTime(apptDt.year, apptDt.month, apptDt.day);
      if (apptMidnight.isAfter(todayMidnight)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('vitals_future_disabled', fallback: 'Vitals collection is disabled for future-dated appointments.')),
            backgroundColor: const Color(0xFFB45309),
          ),
        );
        return;
      }
    }

    final sysCtrl = TextEditingController(
      text: app.bloodPressureSystolic?.toString() ?? '',
    );
    final diaCtrl = TextEditingController(
      text: app.bloodPressureDiastolic?.toString() ?? '',
    );
    final sugCtrl = TextEditingController(
      text: app.sugarLevel?.toString() ?? '',
    );
    final tmpCtrl = TextEditingController(
      text: app.temperature?.toString() ?? '',
    );
    final cmpCtrl = TextEditingController(text: app.reasonForVisit ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_chart_outlined,
                  color: Color(0xFF0D9488),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('capture_vitals', fallback: 'Capture Vitals'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      app.patientName,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Blood Pressure
                    Text(
                      context.tr('blood_pressure_label', fallback: 'Blood Pressure (mmHg)'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: sysCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: context.tr('systolic', fallback: 'Systolic'),
                              hintText: '120',
                              isDense: true,
                              counterText: '',
                            ),
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (val) {
                              final text = val?.trim() ?? '';
                              if (text.isEmpty) {
                                return context.tr('enter_bp_systolic', fallback: 'Please enter BP systolic');
                              }
                              final num = int.tryParse(text);
                              if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                              if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                              if (num < 90 || num > 300) return context.tr('bp_systolic_range', fallback: 'BP Systolic must be between 90 and 300 mmHg');
                              return null;
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '/',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: diaCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: context.tr('diastolic', fallback: 'Diastolic'),
                              hintText: '80',
                              isDense: true,
                              counterText: '',
                            ),
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (val) {
                              final text = val?.trim() ?? '';
                              if (text.isEmpty) {
                                return context.tr('enter_bp_diastolic', fallback: 'Please enter BP diastolic');
                              }
                              final num = int.tryParse(text);
                              if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                              if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                              if (num < 50 || num > 180) return context.tr('bp_diastolic_range', fallback: 'BP Diastolic must be between 50 and 180 mmHg');
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sugar & Temperature side by side
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('sugar_level_label', fallback: 'Sugar Level (mg/dL)'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: sugCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                maxLength: 6,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                ],
                                decoration: const InputDecoration(
                                  hintText: '95.5',
                                  isDense: true,
                                  counterText: '',
                                ),
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return context.tr('enter_sugar_level', fallback: 'Please enter sugar level');
                                  }
                                  final num = double.tryParse(text);
                                  if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                                  if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                                  if (num < 30 || num > 600) return context.tr('sugar_range', fallback: 'Sugar Level must be between 30 and 600 mg/dL');
                                  return null;
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
                              Text(
                                context.tr('temperature_label', fallback: 'Temperature (°F)'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: tmpCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                maxLength: 5,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                ],
                                decoration: const InputDecoration(
                                  hintText: '98.6',
                                  isDense: true,
                                  counterText: '',
                                ),
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                validator: (val) {
                                  final text = val?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return context.tr('enter_temperature', fallback: 'Please enter temperature');
                                  }
                                  final num = double.tryParse(text);
                                  if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                                  if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                                  if (num < 90 || num > 115) return context.tr('temperature_range', fallback: 'Temperature must be between 90 and 115 °F');
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Chief Complaint
                    TextFormField(
                      controller: cmpCtrl,
                      maxLines: 3,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                        LengthLimitingTextInputFormatter(100),
                      ],
                      decoration: InputDecoration(
                        labelText: context.tr('chief_complaint', fallback: 'Chief Complaint'),
                        hintText: context.tr('chief_complaint_hint', fallback: 'Describe symptoms or reason for visit...'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              style: AppTheme.cancelButton,
              child: Text(context.tr('cancel', fallback: 'Cancel')),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => isSaving = true);
                      try {
                        final vitalsData = <String, dynamic>{
                          'reason_for_visit': cmpCtrl.text.trim(),
                        };
                        final bpSys = int.tryParse(sysCtrl.text);
                        if (bpSys != null) {
                          vitalsData['blood_pressure_systolic'] = bpSys;
                        }
                        final bpDia = int.tryParse(diaCtrl.text);
                        if (bpDia != null) {
                          vitalsData['blood_pressure_diastolic'] = bpDia;
                        }
                        final sugar = double.tryParse(sugCtrl.text);
                        if (sugar != null) {
                          vitalsData['sugar_level'] = sugar;
                        }
                        final temp = double.tryParse(tmpCtrl.text);
                        if (temp != null) {
                          vitalsData['temperature'] = temp;
                        }

                        await _ctrl.updateVitals(app.id!, vitalsData);
                        await _ctrl.updateStatus(app.id!, 'Waiting');
                        Navigator.pop(ctx);
                        _load();
                        _tabController.animateTo(1);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.tr('vitals_saved_triaged', fallback: 'Vitals saved & patient triaged ✓')),
                              backgroundColor: const Color(0xFF0D9488),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setS(() => isSaving = false);
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text(
                'Save & Triage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Walk-In Logic ──────────────────────────────────────────────────────────

  DateTime _parseTime(String timeStr) {
    final timeParts = timeStr.split(' ');
    final hms = timeParts[0].split(':');
    int hour = int.parse(hms[0]);
    int minute = hms.length > 1 ? int.parse(hms[1]) : 0;
    if (timeParts.length > 1) {
      if (timeParts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (timeParts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(2026, 1, 1, hour, minute);
  }

  String _cleanDoctorName(String? name) {
    if (name == null) return '';
    return name.replaceAll(RegExp(r'^(dr\.?|doctor)\s*', caseSensitive: false), '').trim().toLowerCase();
  }

  bool _isSameDoctor(String? doc1, String? doc2) {
    if (doc1 == null || doc2 == null) return false;
    final c1 = _cleanDoctorName(doc1);
    final c2 = _cleanDoctorName(doc2);
    return c1.isNotEmpty && (c1 == c2 || c1.contains(c2) || c2.contains(c1));
  }

  bool _isSameDate(dynamic date1, dynamic date2) {
    if (date1 == null || date2 == null) return false;
    DateTime? d1;
    DateTime? d2;

    if (date1 is DateTime) {
      d1 = date1;
    } else if (date1 is String) {
      d1 = DateFormatter.toDateTime(date1);
      if (d1 == null) {
        final clean = date1.trim().split('T')[0];
        final parts = clean.contains('/') ? clean.split('/') : clean.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            d1 = DateTime.tryParse('$clean 00:00:00');
          } else if (parts[2].length == 4) {
            d1 = DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')} 00:00:00');
          }
        }
      }
    }

    if (date2 is DateTime) {
      d2 = date2;
    } else if (date2 is String) {
      d2 = DateFormatter.toDateTime(date2);
      if (d2 == null) {
        final clean = date2.trim().split('T')[0];
        final parts = clean.contains('/') ? clean.split('/') : clean.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            d2 = DateTime.tryParse('$clean 00:00:00');
          } else if (parts[2].length == 4) {
            d2 = DateTime.tryParse('${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')} 00:00:00');
          }
        }
      }
    }

    if (d1 == null || d2 == null) return false;
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _normalizeTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '';
    try {
      final s = timeStr.trim().toUpperCase();
      final hasAm = s.contains('AM');
      final hasPm = s.contains('PM');
      
      final cleaned = s.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = cleaned.split(':');
      if (parts.isEmpty) return timeStr.trim();
      
      int h = int.parse(parts[0]);
      int m = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      if (hasPm && h < 12) h += 12;
      if (hasAm && h == 12) h = 0;
      
      final period = h >= 12 ? 'PM' : 'AM';
      int h12 = h % 12;
      if (h12 == 0) h12 = 12;
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return timeStr.trim();
    }
  }

  List<String> _generateDefaultSlots() {
    List<String> slots = [];
    DateTime mStart = DateTime(2026, 1, 1, 9, 0);
    DateTime mEnd = DateTime(2026, 1, 1, 13, 0);
    while (mStart.isBefore(mEnd)) {
      slots.add(DateFormat('hh:mm a').format(mStart));
      mStart = mStart.add(const Duration(minutes: 30));
    }
    DateTime aStart = DateTime(2026, 1, 1, 14, 0);
    DateTime aEnd = DateTime(2026, 1, 1, 17, 0);
    while (aStart.isBefore(aEnd)) {
      slots.add(DateFormat('hh:mm a').format(aStart));
      aStart = aStart.add(const Duration(minutes: 30));
    }
    return slots;
  }

  List<String> _generateSlotsForDoctor(UserModel doctor) {
    if (doctor.slotStartTime == null || doctor.slotEndTime == null) {
      return _generateDefaultSlots();
    }

    int duration = 30;
    if (doctor.slotDuration != null) {
      duration = int.tryParse(doctor.slotDuration!.split(' ')[0]) ?? 30;
    }

    try {
      DateTime start = _parseTime(doctor.slotStartTime!);
      DateTime end = _parseTime(doctor.slotEndTime!);

      List<String> slots = [];
      DateTime current = start;
      while (current.isBefore(end)) {
        slots.add(DateFormat('hh:mm a').format(current));
        current = current.add(Duration(minutes: duration));
      }
      if (slots.isEmpty) {
        return _generateDefaultSlots();
      }
      return slots;
    } catch (e) {
      return _generateDefaultSlots();
    }
  }

  void _showWalkInDialog() {
    PatientModel? selectedPatient;
    UserModel? selectedDoctor;
    String? selectedTime;
    bool isSaving = false;
    bool isLoadingInitial = false;
    List<PatientModel> allPatients = [];
    List<UserModel> allDoctors = [];
    List<String> availableSlots = [];
    final bpSysCtrl = TextEditingController();
    final bpDiaCtrl = TextEditingController();
    final sugarCtrl = TextEditingController();
    final tempCtrl = TextEditingController();
    final complaintCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (allPatients.isEmpty && allDoctors.isEmpty && !isLoadingInitial) {
            setDialogState(() => isLoadingInitial = true);
            Future.wait([
                  _patientController.fetchPatients(),
                  _adminController.fetchStaff(role: 'Doctor'),
                ])
                .then((results) {
                  if (mounted) {
                    setDialogState(() {
                      allPatients = results[0] as List<PatientModel>;
                      allDoctors = (results[1] as List<UserModel>).where((d) {
                        if (d.status.toLowerCase() != 'active') return false;
                        final dp = d.doctorProfile;
                        if (dp == null) return false;
                        if (dp.slotStartTime == null || dp.slotStartTime!.trim().isEmpty) return false;
                        if (dp.slotEndTime == null || dp.slotEndTime!.trim().isEmpty) return false;
                        if (dp.slotDuration == null || dp.slotDuration!.trim().isEmpty) return false;
                        if (dp.availableDays == null || dp.availableDays!.isEmpty) return false;
                        return true;
                      }).toList();
                      isLoadingInitial = false;
                    });
                  }
                })
                .catchError((e) {
                  if (mounted) setDialogState(() => isLoadingInitial = false);
                });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Color(0xFF0D9488)),
                SizedBox(width: 8),
                Text(
                  'New Walk-in Entry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoadingInitial)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else ...[
                        const Text(
                          'Select Patient',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Search or select patient...',
                          value: selectedPatient?.id?.toString(),
                          dropdownMap: {
                            for (var p in allPatients)
                              p.id.toString():
                                  '${p.name} (${p.patientId ?? "N/A"})',
                          },
                          onChanged: (val) {
                            if (val != null) {
                              final id = int.tryParse(val);
                              setDialogState(() {
                                selectedPatient = allPatients.firstWhere(
                                  (p) => p.id == id,
                                );
                              });
                            }
                          },
                          validator: (val) => val == null || val.isEmpty
                              ? context.tr('please_select_patient', fallback: 'Please select patient')
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('assign_doctor_label', fallback: 'Assign Doctor'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomDropdownSearch(
                          label: '',
                          hint: context.tr('select_doctor_hint', fallback: 'Select doctor...'),
                          value: selectedDoctor?.id.toString(),
                          dropdownMap: {
                            for (var d in allDoctors)
                              d.id.toString(): d.staffUniqueId != null && d.staffUniqueId!.isNotEmpty
                                  ? '${d.fullname} (${d.staffUniqueId})'
                                  : d.fullname,
                          },
                          onChanged: (val) {
                            if (val != null) {
                              final id = int.tryParse(val);
                              final doc = allDoctors.firstWhere(
                                (d) => d.id == id,
                              );
                              setDialogState(() {
                                selectedDoctor = doc;
                                selectedTime = null;
                                DateTime now = DateTime.now();
                                final weekDays = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ];
                                final dayName = weekDays[now.weekday - 1];
                                final dateStr = DateFormat(
                                  'dd/MM/yyyy',
                                ).format(now);

                                bool isAvailable =
                                    false; // Default to unavailable unless explicitly available
                                if (doc.availableDays != null &&
                                    doc.availableDays!.contains(dayName)) {
                                  isAvailable = true;
                                }

                                if (doc.weeklyOffDays != null &&
                                    doc.weeklyOffDays!.contains(dayName)) {
                                  isAvailable = false;
                                }

                                if (doc.specificLeaveDates != null &&
                                    doc.specificLeaveDates!.contains(dateStr)) {
                                  isAvailable = false;
                                }

                                if (!isAvailable) {
                                  availableSlots = [];
                                } else {
                                  availableSlots = _generateSlotsForDoctor(doc);
                                  availableSlots = availableSlots.where((slot) {
                                    bool isBooked = _appointments.any(
                                      (a) =>
                                          _isSameDoctor(a.doctorName, doc.fullname) &&
                                          _isSameDate(a.appointmentDate, now) &&
                                          _normalizeTime(a.appointmentTime) == _normalizeTime(slot) &&
                                          a.status != 'Cancelled' &&
                                          a.status != 'No-Show',
                                    );
                                    return !isBooked;
                                  }).toList();
                                }
                              });
                            }
                          },
                          validator: (val) => val == null || val.isEmpty
                              ? context.tr('please_select_doctor', fallback: 'Please select doctor')
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (selectedDoctor != null) ...[
                          Text(
                            context.tr('available_time_slots_today', fallback: 'Available Time Slots (Today)'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (availableSlots.isEmpty)
                            Text(
                              context.tr('no_slots_available_today', fallback: 'No slots available for this doctor today.'),
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 2.5,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemCount: availableSlots.length,
                              itemBuilder: (context, index) {
                                final time = availableSlots[index];
                                final isSelected = selectedTime == time;
                                return InkWell(
                                  onTap: () =>
                                      setDialogState(() => selectedTime = time),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.white,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.borderColor,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      time,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textPrimaryColor,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (selectedTime == null && availableSlots.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                context.tr('please_select_time_slot', fallback: 'Please select a time slot'),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          context.tr('patient_intake_vitals', fallback: 'Patient Intake Vitals'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'BP Systolic',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: ' *',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: bpSysCtrl,
                                    keyboardType: TextInputType.number,
                                    maxLength: 3,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(
                                      hintText: '120',
                                      isDense: true,
                                      counterText: '',
                                    ),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (val) {
                                      final text = val?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return context.tr('enter_bp_systolic', fallback: 'Please enter BP systolic');
                                      }
                                      final num = int.tryParse(text);
                                      if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                                      if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                                      if (num < 90 || num > 300) return context.tr('bp_systolic_range', fallback: 'BP Systolic must be between 90 and 300 mmHg');
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'BP Diastolic',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: ' *',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: bpDiaCtrl,
                                    keyboardType: TextInputType.number,
                                    maxLength: 3,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(
                                      hintText: '80',
                                      isDense: true,
                                      counterText: '',
                                    ),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (val) {
                                      final text = val?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return context.tr('enter_bp_diastolic', fallback: 'Please enter BP diastolic');
                                      }
                                      final num = int.tryParse(text);
                                      if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                                      if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                                      if (num < 50 || num > 180) return context.tr('bp_diastolic_range', fallback: 'BP Diastolic must be between 50 and 180 mmHg');
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Sugar Level',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: ' *',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: sugarCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    maxLength: 6,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: '95.5 mg/dL',
                                      isDense: true,
                                      counterText: '',
                                    ),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (val) {
                                      final text = val?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return context.tr('enter_sugar_level', fallback: 'Please enter sugar level');
                                      }
                                      final num = double.tryParse(text);
                                      if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                                      if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                                      if (num < 30 || num > 600) return context.tr('sugar_range', fallback: 'Sugar Level must be between 30 and 600 mg/dL');
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Temperature',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: ' *',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: tempCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    maxLength: 5,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: '98.6 °F',
                                      isDense: true,
                                      counterText: '',
                                    ),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (val) {
                                      final text = val?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return context.tr('enter_temperature', fallback: 'Please enter temperature');
                                      }
                                      final num = double.tryParse(text);
                                      if (num == null) return context.tr('enter_a_number', fallback: 'Enter a number');
                                      if (num == 0) return context.tr('cannot_be_zero', fallback: 'Cannot be 0');
                                      if (num < 90 || num > 115) return context.tr('temperature_range', fallback: 'Temperature must be between 90 and 115 °F');
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('chief_complaint', fallback: 'Chief Complaint'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: complaintCtrl,
                          maxLines: 3,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                            LengthLimitingTextInputFormatter(100),
                          ],
                          decoration: InputDecoration(
                            hintText: context.tr('chief_complaint_hint', fallback: 'Describe symptoms or reason for visit...'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: Text(context.tr('cancel', fallback: 'Cancel')),
              ),
              ElevatedButton(
                onPressed:
                    (isSaving ||
                        selectedTime == null ||
                        selectedDoctor == null ||
                        selectedPatient == null)
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final vitalsData = <String, dynamic>{
                            'blood_pressure_systolic': int.parse(
                              bpSysCtrl.text.trim(),
                            ),
                            'blood_pressure_diastolic': int.parse(
                              bpDiaCtrl.text.trim(),
                            ),
                            'sugar_level': double.parse(sugarCtrl.text.trim()),
                            'temperature': double.parse(tempCtrl.text.trim()),
                            'reason_for_visit': complaintCtrl.text.trim(),
                          };
                          final newApp = AppointmentModel(
                            doctorId: selectedDoctor?.id,
                            patientId: selectedPatient!.id!,
                            patientName: selectedPatient!.name,
                            department:
                                selectedDoctor!.specialization ?? 'General',
                            doctorName: selectedDoctor!.fullname,
                            appointmentDate: DateFormatter.toUi(DateTime.now()),
                            appointmentTime: selectedTime!,
                            bloodPressureSystolic:
                                vitalsData['blood_pressure_systolic'] as int,
                            bloodPressureDiastolic:
                                vitalsData['blood_pressure_diastolic'] as int?,
                            sugarLevel: vitalsData['sugar_level'] as double?,
                            temperature: vitalsData['temperature'] as double,
                            reasonForVisit: complaintCtrl.text.trim(),
                            status: 'Waiting',
                            appointmentType: 'Walk-in',
                          );
                          final created = await _ctrl.bookAppointment(newApp);
                          await _ctrl.updateVitals(created.id!, vitalsData);
                          await _ctrl.updateStatus(created.id!, 'Waiting');
                          Navigator.pop(ctx);
                          _load();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('walk_in_registered_waiting', fallback: 'Walk-in registered and added to waiting!'),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(context.tr('register_walk_in', fallback: 'Register Walk-in')),
              ),
            ],
          );
        },
      ),
    );
  }
}
