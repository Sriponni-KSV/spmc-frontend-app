import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../models/patient_model.dart';
import '../controllers/home_visit_controller.dart';
import '../controllers/patient_controller.dart';
import '../widgets/custom_dropdown_search.dart';
import 'home_visit_execution_screen.dart';

class HomeVisitListView extends StatefulWidget {
  final Function(int visitId)? onExecuteVisit;
  final Function(int visitId)? onViewSummary;

  const HomeVisitListView({super.key, this.onExecuteVisit, this.onViewSummary});

  @override
  State<HomeVisitListView> createState() => _HomeVisitListViewState();
}

class _HomeVisitListViewState extends State<HomeVisitListView> {
  String _selectedStatusFilter = 'All';
  List<PatientModel> _patientsList = [];
  bool _isLoadingPatients = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
      _fetchPatients();
    });
  }

  Future<void> _fetchPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final list = await PatientController().fetchPatients();
      if (mounted) {
        setState(() {
          _patientsList = list;
          _isLoadingPatients = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeVisitController>(
      builder: (context, controller, child) {
        List<HomeVisitModel> visits = controller.visits;
        if (_selectedStatusFilter != 'All') {
          visits = visits
              .where((v) => v.status.toLowerCase() == _selectedStatusFilter.toLowerCase())
              .toList();
        }

        return Container(
          color: AppTheme.backgroundColor,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_work_outlined, color: AppTheme.primaryColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Home Visit Care & Services',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                              fontFamily: 'Inter',
                            ),
                          ),
                          Text(
                            'Manage patient home care, vitals, dressing procedures, kit items & attender billing',
                            style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Inter'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                        tooltip: 'Refresh visits',
                        onPressed: () {
                          Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
                          _fetchPatients();
                        },
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          style: AppTheme.dangerButton,
                          icon: const Icon(Icons.add, color: Colors.white, size: 15),
                          label: const Text(
                            'Schedule Home Visit',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          onPressed: () => _showScheduleVisitDialog(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Scheduled', 'In-Progress', 'Verified', 'Cancelled'].map((status) {
                    final isSelected = _selectedStatusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(status, style: TextStyle(color: isSelected ? Colors.white : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryColor,
                        backgroundColor: Colors.white,
                        onSelected: (val) {
                          if (val) setState(() => _selectedStatusFilter = status);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Content Body
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : controller.errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerColor),
                                const SizedBox(height: 12),
                                Text(
                                  controller.errorMessage!,
                                  style: const TextStyle(fontSize: 14, color: AppTheme.dangerColor),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: AppTheme.primaryButton,
                                  onPressed: () {
                                    Provider.of<HomeVisitController>(context, listen: false).fetchVisits();
                                    _fetchPatients();
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry Loading Visits'),
                                ),
                              ],
                            ),
                          )
                        : visits.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.home_work, size: 48, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text(
                                      'No home visits found matching filter.',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: visits.length,
                                itemBuilder: (context, idx) {
                                  final visit = visits[idx];
                                  return _buildVisitCard(context, visit);
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitCard(BuildContext context, HomeVisitModel visit) {
    final bool canExecute = _isExecuteButtonEnabled(visit);

    String effectiveStatus = visit.status;
    if (canExecute && (visit.status == 'Verified' || visit.status == 'Completed')) {
      effectiveStatus = 'Scheduled';
    }

    final now = DateTime.now();
    final todayFormatted = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    final String displayDate = (effectiveStatus == 'Scheduled' && canExecute) ? todayFormatted : visit.formattedScheduledDate;

    Color badgeBg = const Color(0xFFDBEAFE);
    Color badgeText = const Color(0xFF1E40AF);

    if (effectiveStatus == 'In-Progress') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
    } else if (effectiveStatus == 'Verified' || effectiveStatus == 'Completed') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
    } else if (effectiveStatus == 'Cancelled') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFF991B1B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      visit.patientName ?? 'Patient #${visit.patientId}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(effectiveStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeText)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Visit #: ${visit.visitNumber} • Date: $displayDate (${(visit.scheduledTime == null || visit.scheduledTime == "10:00 AM") ? "9:00 AM" : visit.scheduledTime})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (visit.visitAddress != null && visit.visitAddress!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          visit.visitAddress!,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visit.status != 'Cancelled') ...[
                IconButton(
                  icon: const Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.dangerColor, size: 22),
                  tooltip: 'Stop / Discontinue Care (Patient Cured)',
                  onPressed: () => _showDiscontinueDialog(context, visit),
                ),
                const SizedBox(width: 4),
              ],
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: AppTheme.primaryButton,
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('View Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    if (widget.onViewSummary != null) {
                      widget.onViewSummary!(visit.id);
                    } else {
                      context.go('/nurse/home-visits/summary/${visit.id}');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (visit.status != 'Cancelled')
                Builder(
                  builder: (context) {
                    final bool canExecute = _isExecuteButtonEnabled(visit);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            style: canExecute
                                ? AppTheme.dangerButton
                                : ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCBD5E1),
                                    foregroundColor: const Color(0xFF64748B),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                            icon: Icon(canExecute ? Icons.medical_services_outlined : Icons.lock_clock_outlined, size: 15),
                            label: Text(
                              'Execute Visit',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: canExecute ? Colors.white : const Color(0xFF64748B)),
                            ),
                            onPressed: canExecute
                                ? () {
                                    if (widget.onExecuteVisit != null) {
                                      widget.onExecuteVisit!(visit.id);
                                    } else {
                                      context.go('/nurse/home-visits/execute/${visit.id}');
                                    }
                                  }
                                : () {
                                    final String displayTime = (visit.scheduledTime == null || visit.scheduledTime == "10:00 AM") ? "9:00 AM" : visit.scheduledTime!;
                                    final String msg = (visit.status == 'Verified' || visit.status == 'Completed')
                                        ? 'This visit has already been ${visit.status.toLowerCase()}.'
                                        : 'Duty time has not started yet. Execute Visit unlocks at 8:50 AM (10 mins before $displayTime).';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(msg),
                                        backgroundColor: AppTheme.primaryColor,
                                      ),
                                    );
                                  },
                          ),
                        ),
                        if (!canExecute && visit.status != 'Verified' && visit.status != 'Completed')
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Unlocks at 8:50 AM (10m before ${(visit.scheduledTime == null || visit.scheduledTime == "10:00 AM") ? "9:00 AM" : visit.scheduledTime})',
                              style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDiscontinueDialog(BuildContext context, HomeVisitModel visit) {
    String selectedReason = 'Patient Cured / Fully Recovered';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.dangerColor, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stop / Discontinue Home Visit Care',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to stop/discontinue home visit care for ${visit.patientName ?? "Patient #${visit.patientId}"}?',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              const Text('Select Discontinuation Reason:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              CustomDropdownSearch(
                label: '',
                hint: 'Select Reason',
                dropdownMap: const {
                  'Patient Cured / Fully Recovered': 'Patient Cured / Fully Recovered',
                  'Patient / Attender Requested Discontinuation': 'Patient / Attender Requested Discontinuation',
                  'Admitted to Hospital / IPD Care': 'Admitted to Hospital / IPD Care',
                  'Doctor Advice / Care Plan Ended': 'Doctor Advice / Care Plan Ended',
                  'Other Reason': 'Other Reason',
                },
                value: selectedReason,
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedReason = val);
                  }
                },
              ),
              const SizedBox(height: 14),
              const Text('Additional Notes / Remarks (Optional):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: AppTheme.standardInputDecoration(hintText: 'Enter reason notes (e.g. Cured and recovered)...'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: AppTheme.dangerButton,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Stop Care'),
              onPressed: () async {
                final homeVisitCtrl = Provider.of<HomeVisitController>(context, listen: false);
                final success = await homeVisitCtrl.cancelVisit(visit.id, selectedReason, notesCtrl.text);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Home visit care for ${visit.patientName ?? "Patient"} stopped/discontinued successfully.'),
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleVisitDialog(BuildContext context) {
    final homeVisitCtrl = Provider.of<HomeVisitController>(context, listen: false);

    final scheduledPatientIds = homeVisitCtrl.visits
        .where((v) => v.status != 'Cancelled')
        .map((v) => v.patientId)
        .toSet();

    final availablePatients = _patientsList
        .where((p) => p.id != null && !scheduledPatientIds.contains(p.id))
        .toList();

    PatientModel? selectedPatient = availablePatients.isNotEmpty ? availablePatients.first : null;
    final addressCtrl = TextEditingController(
      text: selectedPatient != null && selectedPatient.fullAddress.isNotEmpty
          ? selectedPatient.fullAddress
          : (selectedPatient?.address ?? 'No. 12, Home Street, City'),
    );
    final now = DateTime.now();
    final formattedNow = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    final dateCtrl = TextEditingController(text: formattedNow);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.home_work, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text('Schedule New Home Visit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Patient (Name & ID):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              if (_isLoadingPatients)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Loading patients list...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              else if (availablePatients.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'All patients already have active home visits scheduled.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                CustomDropdownSearch(
                  label: '',
                  hint: 'Select Patient (Name & ID)',
                  dropdownMap: {
                    for (var p in availablePatients)
                      p.id.toString(): '${p.name} (${(p.patientId != null && p.patientId!.isNotEmpty) ? p.patientId! : "ID: ${p.id}"})'
                  },
                  value: selectedPatient?.id.toString(),
                  onChanged: (val) {
                    if (val != null) {
                      final pId = int.tryParse(val);
                      final found = availablePatients.firstWhere(
                        (p) => p.id == pId,
                        orElse: () => availablePatients.first,
                      );
                      setDialogState(() {
                        selectedPatient = found;
                        addressCtrl.text = found.fullAddress.isNotEmpty ? found.fullAddress : found.address;
                      });
                    }
                  },
                ),
              const SizedBox(height: 16),
              const Text('Visit Address:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: addressCtrl,
                decoration: AppTheme.standardInputDecoration(hintText: 'Enter home visit address'),
              ),
              const SizedBox(height: 16),
              const Text('Scheduled Date:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                decoration: AppTheme.standardInputDecoration(
                  suffixIcon: const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryColor),
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      dateCtrl.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: AppTheme.dangerButton,
              onPressed: () async {
                final targetPatient = selectedPatient ?? (_patientsList.isNotEmpty ? _patientsList.first : null);
                if (targetPatient == null || targetPatient.id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a valid patient to schedule a home visit.'),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                  return;
                }

                String apiDateStr = dateCtrl.text;
                final dateParts = dateCtrl.text.split('-');
                if (dateParts.length == 3 && dateParts[2].length == 4) {
                  apiDateStr = "${dateParts[2]}-${dateParts[1]}-${dateParts[0]}";
                }

                final homeVisitCtrl = Provider.of<HomeVisitController>(context, listen: false);

                // Prevent scheduling duplicate visit for same patient on same date
                final bool existingSameDay = homeVisitCtrl.visits.any(
                  (v) => v.patientId == targetPatient.id && v.scheduledDate == apiDateStr && v.status != 'Cancelled',
                );

                if (existingSameDay) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ A home visit is already scheduled for ${targetPatient.name} on ${dateCtrl.text}. Only 1 visit per patient per day is allowed.'),
                      backgroundColor: AppTheme.dangerColor,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                final newVisit = await homeVisitCtrl.createVisit({
                  'patient_id': targetPatient.id,
                  'scheduled_date': apiDateStr,
                  'scheduled_time': '9:00 AM',
                  'visit_address': addressCtrl.text,
                  'carried_items': [
                    {'item_type': 'Device', 'item_name': 'Digital BP Monitor', 'quantity_carried': 1},
                    {'item_type': 'Device', 'item_name': 'Glucometer Kit', 'quantity_carried': 1},
                    {'item_type': 'Medicine', 'item_name': 'Paracetamol 500mg', 'quantity_carried': 10},
                    {'item_type': 'Consumable', 'item_name': 'Sterile Dressing Bandage', 'quantity_carried': 5},
                  ],
                });

                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                if (newVisit != null) {
                  await homeVisitCtrl.fetchVisits();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Home visit ${newVisit.visitNumber} scheduled successfully!'),
                        backgroundColor: AppTheme.secondaryColor,
                      ),
                    );
                  }
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(homeVisitCtrl.errorMessage ?? 'Failed to schedule home visit.'),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                }
              },
              child: const Text('Schedule Visit'),
            ),
          ],
        ),
      ),
    );
  }



  bool _isExecuteButtonEnabled(HomeVisitModel visit) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    bool isPastDate = false;
    bool isToday = false;

    if (visit.scheduledDate.isNotEmpty) {
      final dateParts = visit.scheduledDate.split('-');
      if (dateParts.length == 3) {
        int y, m, d;
        if (dateParts[0].length == 4) {
          y = int.parse(dateParts[0]);
          m = int.parse(dateParts[1]);
          d = int.parse(dateParts[2]);
        } else {
          d = int.parse(dateParts[0]);
          m = int.parse(dateParts[1]);
          y = int.parse(dateParts[2]);
        }
        final vDate = DateTime(y, m, d);
        if (vDate.isBefore(todayDate)) {
          isPastDate = true;
        } else if (vDate.isAtSameMomentAs(todayDate)) {
          isToday = true;
        }
      }
    }

    if (visit.status == 'Verified' || visit.status == 'Completed') {
      if (isToday) {
        return false;
      }
      if (isPastDate) {
        final unlockTime = DateTime(now.year, now.month, now.day, 8, 50);
        return now.isAfter(unlockTime) || now.isAtSameMomentAs(unlockTime);
      }
      return false;
    }
    try {
      if (visit.scheduledDate.isEmpty) return true;

      DateTime? scheduledDateTime;
      final dateParts = visit.scheduledDate.split('-');
      if (dateParts.length == 3) {
        if (dateParts[0].length == 4) {
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          scheduledDateTime = DateTime(year, month, day, 9, 0);
        } else if (dateParts[2].length == 4) {
          final day = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final year = int.parse(dateParts[2]);
          scheduledDateTime = DateTime(year, month, day, 9, 0);
        }
      }

      if (scheduledDateTime != null) {
        String timeStr = (visit.scheduledTime != null && visit.scheduledTime!.isNotEmpty)
            ? visit.scheduledTime!.trim()
            : '9:00 AM';
        if (timeStr == '10:00 AM') {
          timeStr = '9:00 AM';
        }
        final isPm = timeStr.toUpperCase().contains('PM');
        final isAm = timeStr.toUpperCase().contains('AM');
        final cleanTime = timeStr.replaceAll(RegExp(r'[^\d:]'), '');
        final timeParts = cleanTime.split(':');
        if (timeParts.length >= 2) {
          int hour = int.tryParse(timeParts[0]) ?? 9;
          int minute = int.tryParse(timeParts[1]) ?? 0;
          if (isPm && hour < 12) hour += 12;
          if (isAm && hour == 12) hour = 0;
          scheduledDateTime = DateTime(
            scheduledDateTime.year,
            scheduledDateTime.month,
            scheduledDateTime.day,
            hour,
            minute,
          );
        }
      }

      if (scheduledDateTime == null) return true;

      final now = DateTime.now();
      final unlockTime = scheduledDateTime.subtract(const Duration(minutes: 10));
      return now.isAfter(unlockTime) || now.isAtSameMomentAs(unlockTime);
    } catch (e) {
      return true;
    }
  }
}
