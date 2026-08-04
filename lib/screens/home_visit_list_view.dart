import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../models/patient_model.dart';
import '../controllers/home_visit_controller.dart';
import '../controllers/patient_controller.dart';
import 'home_visit_execution_screen.dart';

class HomeVisitListView extends StatefulWidget {
  final Function(int visitId)? onExecuteVisit;

  const HomeVisitListView({super.key, this.onExecuteVisit});

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
                      ElevatedButton.icon(
                        style: AppTheme.primaryButton,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Schedule Home Visit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () => _showScheduleVisitDialog(context),
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
                  children: ['All', 'Scheduled', 'In-Progress', 'Verified'].map((status) {
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
    Color badgeBg = const Color(0xFFDBEAFE);
    Color badgeText = const Color(0xFF1E40AF);

    if (visit.status == 'In-Progress') {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
    } else if (visit.status == 'Verified' || visit.status == 'Completed') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
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
                      child: Text(visit.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeText)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Visit #: ${visit.visitNumber} • Date: ${visit.scheduledDate} (${visit.scheduledTime ?? "10:00 AM"})',
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
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              style: AppTheme.primaryButton,
              icon: const Icon(Icons.medical_services_outlined, size: 18),
              label: Text(visit.status == 'Verified' ? 'View Details' : 'Execute Visit'),
              onPressed: () {
                if (widget.onExecuteVisit != null) {
                  widget.onExecuteVisit!(visit.id);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HomeVisitExecutionScreen(visitId: visit.id),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleVisitDialog(BuildContext context) {
    PatientModel? selectedPatient = _patientsList.isNotEmpty ? _patientsList.first : null;
    final addressCtrl = TextEditingController(
      text: selectedPatient != null && selectedPatient.fullAddress.isNotEmpty
          ? selectedPatient.fullAddress
          : (selectedPatient?.address ?? 'No. 12, Home Street, City'),
    );
    final dateCtrl = TextEditingController(text: DateTime.now().toString().split(' ')[0]);

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
              else if (_patientsList.isEmpty)
                TextFormField(
                  initialValue: '1',
                  decoration: AppTheme.standardInputDecoration(hintText: 'Enter Patient ID'),
                )
              else
                DropdownButtonFormField<PatientModel>(
                  initialValue: selectedPatient,
                  isExpanded: true,
                  decoration: AppTheme.standardInputDecoration(),
                  items: _patientsList.map((p) {
                    final displayId = (p.patientId != null && p.patientId!.isNotEmpty) ? p.patientId! : 'ID: ${p.id}';
                    return DropdownMenuItem<PatientModel>(
                      value: p,
                      child: Text(
                        '${p.name} ($displayId)',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedPatient = val;
                      if (val != null) {
                        addressCtrl.text = val.fullAddress.isNotEmpty ? val.fullAddress : val.address;
                      }
                    });
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
                      dateCtrl.text = picked.toString().split(' ')[0];
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
              style: AppTheme.primaryButton,
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

                final homeVisitCtrl = Provider.of<HomeVisitController>(context, listen: false);
                final newVisit = await homeVisitCtrl.createVisit({
                  'patient_id': targetPatient.id,
                  'scheduled_date': dateCtrl.text,
                  'scheduled_time': '10:00 AM',
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
}
