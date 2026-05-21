import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../models/patient_model.dart';
import '../models/user_model.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/admin_controller.dart';
import '../utils/date_formatter.dart';

/// Nurse-only OPD Assistance screen.
/// Flow: Patient Arrives → Mark Arrived → Record Vitals → Send to Doctor
class NurseOPDAssistanceScreen extends StatefulWidget {
  final bool isMobile;
  const NurseOPDAssistanceScreen({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<NurseOPDAssistanceScreen> createState() => _NurseOPDAssistanceScreenState();
}

class _NurseOPDAssistanceScreenState extends State<NurseOPDAssistanceScreen>
    with SingleTickerProviderStateMixin {
  final AppointmentController _ctrl = AppointmentController();
  final PatientController _patientController = PatientController();
  final AdminController _adminController = AdminController();

  late TabController _tabController;

  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';

  // Tab labels + status filters
  static const _tabs = [
    {'label': 'Awaiting Arrival',  'status': 'Confirmed'},
    {'label': 'Triaged / Waiting', 'status': 'Checked-in'},
    {'label': 'In Consultation',   'status': 'In Consultation'},
    {'label': 'Completed',         'status': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final data = await _ctrl.fetchAdminAppointments(date: today);
      if (mounted) setState(() { _appointments = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
    }
  }

  List<AppointmentModel> _forTab(int idx) {
    final status = _tabs[idx]['status']!;
    return _appointments.where((a) {
      final matchStatus = a.status == status;
      if (_search.trim().isEmpty) return matchStatus;
      final q = _search.toLowerCase();
      return matchStatus &&
          (a.patientName.toLowerCase().contains(q) ||
           (a.patientDisplayId?.toLowerCase().contains(q) ?? false) ||
           a.doctorName.toLowerCase().contains(q));
    }).toList();
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
                    child: const Icon(Icons.local_hospital_outlined, color: Color(0xFF0D9488), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OPD Assistance', style: Theme.of(context).textTheme.displayLarge),
                      const Text("Today's patient arrival & triage queue",
                          style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _showWalkInDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(widget.isMobile ? 'Walk-in' : 'New Walk-in Entry', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: AppTheme.textSecondaryColor),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search patient name or ID...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                          isDense: true,
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
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: List.generate(_tabs.length, (i) {
                  final count = _forTab(i).length;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_tabs[i]['label']!),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
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
            Icon(Icons.check_circle_outline, size: 56,
                color: AppTheme.textSecondaryColor.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No patients in "${_tabs[tabIdx]['label']}"',
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
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
    final bool isConfirmed   = app.status == 'Confirmed';
    final bool isCheckedIn   = app.status == 'Checked-in';
    final bool inConsult     = app.status == 'In Consultation';
    final bool isCompleted   = app.status == 'Completed';

    Color lineColor;
    if (isConfirmed)   lineColor = const Color(0xFF3B82F6);
    else if (isCheckedIn) lineColor = const Color(0xFF0D9488);
    else if (inConsult) lineColor = const Color(0xFFF59E0B);
    else lineColor = const Color(0xFF22C55E);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: lineColor, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
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
                    app.patientName.isNotEmpty ? app.patientName[0].toUpperCase() : 'P',
                    style: TextStyle(color: avatarColors['text'], fontWeight: FontWeight.bold, fontSize: 18),
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
                            child: Text(app.patientName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          if (app.patientDisplayId != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(app.patientDisplayId!,
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 10,
                                      fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.medical_services_outlined, size: 13, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 4),
                          Text('Dr. ${app.doctorName}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                          const SizedBox(width: 8),
                          Text('• ${app.department}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMutedColor)),
                        ],
                      ),
                      if (app.patientPhone != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 13, color: AppTheme.textMutedColor),
                            const SizedBox(width: 4),
                            Text(app.patientPhone!,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMutedColor)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Time pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 12, color: lineColor),
                      const SizedBox(width: 4),
                      Text(app.appointmentTime,
                          style: TextStyle(fontWeight: FontWeight.bold, color: lineColor, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            // Vitals row (if any recorded)
            if (app.bloodPressureSystolic != null || app.temperature != null || app.sugarLevel != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (app.bloodPressureSystolic != null)
                    _vitalChip(Icons.speed, 'BP: ${app.bloodPressureSystolic}/${app.bloodPressureDiastolic ?? "--"} mmHg', Colors.blue.shade700),
                  if (app.temperature != null)
                    _vitalChip(Icons.thermostat_outlined, 'Temp: ${app.temperature} °F', Colors.orange.shade700),
                  if (app.sugarLevel != null)
                    _vitalChip(Icons.bloodtype_outlined, 'Sugar: ${app.sugarLevel} mg/dL', Colors.red.shade700),
                ],
              ),
            ],

            // Complaint
            if (app.reasonForVisit != null && app.reasonForVisit!.isNotEmpty) ...[
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
                      child: Text('Complaint: ${app.reasonForVisit}',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
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
                // Tab 0: Awaiting Arrival → Mark Arrived
                if (isConfirmed) ...[
                  ElevatedButton.icon(
                    onPressed: () => _markArrived(app),
                    icon: const Icon(Icons.where_to_vote_outlined, size: 15),
                    label: const Text('Mark Arrived', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                  ),
                ],

                // Tab 1: Triaged/Waiting → Edit Vitals + Send to Doctor
                if (isCheckedIn) ...[
                  ElevatedButton.icon(
                    onPressed: () => _sendToDoctor(app),
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: const Text('Send to Doctor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                  ),
                ],

                // Capture / Edit Vitals (Confirmed or Checked-in)
                if (isConfirmed || isCheckedIn)
                  OutlinedButton.icon(
                    onPressed: () => _showTriageDialog(app),
                    icon: Icon(isCheckedIn ? Icons.edit_note : Icons.add_chart_outlined, size: 15),
                    label: Text(isCheckedIn ? 'Edit Vitals' : 'Capture Vitals',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D9488),
                      side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

                // Read-only status chip for In Consultation / Completed
                if (inConsult || isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: lineColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: lineColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 7, height: 7,
                            decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(app.status,
                            style: TextStyle(color: lineColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
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
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _markArrived(AppointmentModel app) async {
    try {
      await _ctrl.adminOverrideAppointment(
        id: app.id!,
        status: 'Checked-in',
        overrideReason: 'Patient arrived at OPD',
      );
      _load();
      _tabController.animateTo(1); // jump to Triaged tab
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app.patientName} marked as Arrived ✓'),
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

  Future<void> _sendToDoctor(AppointmentModel app) async {
    try {
      await _ctrl.adminOverrideAppointment(
        id: app.id!,
        status: 'In Consultation',
        overrideReason: 'Patient sent to consulting room',
      );
      _load();
      _tabController.animateTo(2); // jump to In Consultation tab
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${app.patientName} sent to Doctor ✓'),
            backgroundColor: AppTheme.primaryColor,
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

  void _showTriageDialog(AppointmentModel app) {
    final sysCtrl  = TextEditingController(text: app.bloodPressureSystolic?.toString() ?? '');
    final diaCtrl  = TextEditingController(text: app.bloodPressureDiastolic?.toString() ?? '');
    final sugCtrl  = TextEditingController(text: app.sugarLevel?.toString() ?? '');
    final tmpCtrl  = TextEditingController(text: app.temperature?.toString() ?? '');
    final cmpCtrl  = TextEditingController(text: app.reasonForVisit ?? '');
    bool isSaving  = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_chart_outlined, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Capture Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(app.patientName,
                        style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12,
                            fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Blood Pressure
                  const Text('Blood Pressure (mmHg)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: sysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Systolic', hintText: '120', isDense: true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('/', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryColor)),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: diaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Diastolic', hintText: '80', isDense: true),
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
                            const Text('Sugar Level (mg/dL)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: sugCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '95.5', isDense: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Temperature (°F)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: tmpCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '98.6', isDense: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chief Complaint
                  const Text('Chief Complaint',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: cmpCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Describe symptoms or reason for visit...'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              style: AppTheme.cancelButton,
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      setS(() => isSaving = true);
                      try {
                        await _ctrl.adminOverrideAppointment(
                          id: app.id!,
                          status: 'Checked-in',
                          bloodPressureSystolic: int.tryParse(sysCtrl.text),
                          bloodPressureDiastolic: int.tryParse(diaCtrl.text),
                          sugarLevel: double.tryParse(sugCtrl.text),
                          temperature: double.tryParse(tmpCtrl.text),
                          reasonForVisit: cmpCtrl.text.trim(),
                          overrideReason: 'Triage vitals recorded by nurse',
                        );
                        Navigator.pop(ctx);
                        _load();
                        _tabController.animateTo(1);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vitals saved & patient triaged ✓'),
                              backgroundColor: Color(0xFF0D9488),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setS(() => isSaving = false);
                      }
                    },
              icon: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save & Triage', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  List<String> _generateSlotsForDoctor(UserModel doctor) {
    if (doctor.slotStartTime == null || doctor.slotEndTime == null) {
      // Default fallback slots
      List<String> slots = [];
      DateTime start = DateTime(2026, 1, 1, 9, 0); // 9 AM
      DateTime end = DateTime(2026, 1, 1, 13, 0); // 1 PM
      while (start.isBefore(end)) {
        slots.add(DateFormat('hh:mm a').format(start));
        start = start.add(const Duration(minutes: 30));
      }
      return slots;
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
      return slots;
    } catch (e) {
      return [];
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
              _adminController.fetchStaff(role: 'Doctor')
            ]).then((results) {
              if (mounted) {
                setDialogState(() {
                  allPatients = results[0] as List<PatientModel>;
                  allDoctors = (results[1] as List<UserModel>).where((d) => d.status.toLowerCase() == 'active').toList();
                  isLoadingInitial = false;
                });
              }
            }).catchError((e) {
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
                Text('New Walk-in Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                      else ...[
                        const Text('Select Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<PatientModel>(
                          value: selectedPatient,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Search or select patient...',
                            prefixIcon: const Icon(Icons.person_outline, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: allPatients.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.patientId ?? "N/A"})', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setDialogState(() => selectedPatient = val),
                          validator: (val) => val == null ? 'Please select patient' : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Assign Doctor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<UserModel>(
                          value: selectedDoctor,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Select doctor...',
                            prefixIcon: const Icon(Icons.medical_services_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: allDoctors.map((d) => DropdownMenuItem(value: d, child: Text(d.fullname, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedDoctor = val;
                              selectedTime = null;
                              if (val != null) {
                                DateTime now = DateTime.now();
                                final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                final dayName = weekDays[now.weekday - 1];
                                final dateStr = DateFormat('dd/MM/yyyy').format(now);

                                bool isAvailable = false; // Default to unavailable unless explicitly available
                                if (val.availableDays != null && val.availableDays!.contains(dayName)) {
                                  isAvailable = true;
                                } 
                                
                                if (val.weeklyOffDays != null && val.weeklyOffDays!.contains(dayName)) {
                                  isAvailable = false;
                                } 
                                
                                if (val.specificLeaveDates != null && val.specificLeaveDates!.contains(dateStr)) {
                                  isAvailable = false;
                                }

                                if (!isAvailable) {
                                  availableSlots = [];
                                } else {
                                  availableSlots = _generateSlotsForDoctor(val);
                                  availableSlots = availableSlots.where((slot) {
                                    // 1. Check if booked
                                    bool isBooked = _appointments.any((a) => 
                                        a.doctorName == val.fullname && 
                                        a.appointmentTime == slot && 
                                        a.status != 'Cancelled' && 
                                        a.status != 'No-Show'
                                    );
                                    if (isBooked) return false;

                                    // 2. Check if past time
                                    try {
                                      DateTime slotTime = DateFormat('hh:mm a').parse(slot);
                                      DateTime fullSlotTime = DateTime(now.year, now.month, now.day, slotTime.hour, slotTime.minute);
                                      // Only show slots that are strictly after current time
                                      return fullSlotTime.isAfter(now);
                                    } catch (e) {
                                      return true;
                                    }
                                  }).toList();
                                }
                              } else {
                                availableSlots = [];
                              }
                            });
                          },
                          validator: (val) => val == null ? 'Please select doctor' : null,
                        ),
                        const SizedBox(height: 16),
                        if (selectedDoctor != null) ...[
                          const Text('Available Time Slots (Today)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryColor)),
                          const SizedBox(height: 8),
                          if (availableSlots.isEmpty)
                            const Text('No slots available for this doctor today.', style: TextStyle(color: Colors.red, fontSize: 12))
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  onTap: () => setDialogState(() => selectedTime = time),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF0D9488) : Colors.white,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF0D9488) : AppTheme.borderColor,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      time,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (selectedTime == null && availableSlots.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text('Please select a time slot', style: TextStyle(color: Colors.red, fontSize: 11)),
                            ),
                        ],
                      ]
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (isSaving || selectedTime == null || selectedDoctor == null || selectedPatient == null)
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final newApp = AppointmentModel(
                            patientId: selectedPatient!.id!,
                            patientName: selectedPatient!.name,
                            department: selectedDoctor!.specialization ?? 'General',
                            doctorName: selectedDoctor!.fullname,
                            appointmentDate: DateFormatter.toUi(DateTime.now()),
                            appointmentTime: selectedTime!,
                            status: 'Confirmed', // Walk-ins go into queue in Confirmed state to be triaged
                            appointmentType: 'Walk-in',
                          );
                          await _ctrl.bookAppointment(newApp);
                          Navigator.pop(ctx);
                          _load();
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Walk-in registered successfully!'), backgroundColor: Colors.green));
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                        } finally {
                          if (mounted) setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Register Walk-in'),
              ),
            ],
          );
        },
      ),
    );
  }
}
