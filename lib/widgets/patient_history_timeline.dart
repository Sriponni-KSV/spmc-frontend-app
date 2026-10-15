import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/patient_controller.dart';
import '../widgets/consultation_documents_view.dart';
import '../utils/modal_history_helper.dart';

enum TimelineFilter { all, consultations, prescriptions, vitals }

class TimelineItem {
  final DateTime date;
  final String category; // 'consultation', 'vitals', 'prescription', 'triage'
  final String title;
  final String? subtitle;
  final String? doctorName;
  final String? department;
  final Map<String, dynamic> data;

  const TimelineItem({
    required this.date,
    required this.category,
    required this.title,
    this.subtitle,
    this.doctorName,
    this.department,
    required this.data,
  });
}

class PatientHistoryTimeline extends StatefulWidget {
  final int patientId;
  final String patientName;
  final Function(String diagnosis)? onCopyDiagnosis;
  final Function(List<Map<String, String>> medications)? onCopyPrescription;

  const PatientHistoryTimeline({
    Key? key,
    required this.patientId,
    required this.patientName,
    this.onCopyDiagnosis,
    this.onCopyPrescription,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required int patientId,
    required String patientName,
    Function(String diagnosis)? onCopyDiagnosis,
    Function(List<Map<String, String>> medications)? onCopyPrescription,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: PatientHistoryTimeline(
            patientId: patientId,
            patientName: patientName,
            onCopyDiagnosis: onCopyDiagnosis,
            onCopyPrescription: onCopyPrescription,
          ),
        ),
      ),
    );
  }

  @override
  State<PatientHistoryTimeline> createState() => _PatientHistoryTimelineState();
}

class _PatientHistoryTimelineState extends State<PatientHistoryTimeline> {
  final AppointmentController _appointmentController = AppointmentController();
  final PatientController _patientController = PatientController();

  bool _isLoading = true;
  String? _errorMessage;
  List<TimelineItem> _allItems = [];
  TimelineFilter _selectedFilter = TimelineFilter.all;

  @override
  void initState() {
    super.initState();
    _loadUnifiedHistory();
  }

  Future<void> _loadUnifiedHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<TimelineItem> items = [];

      // 1. Fetch Past Consultations
      try {
        final consultations = await _appointmentController
            .fetchConsultationsByPatient(widget.patientId);

        for (var c in consultations) {
          DateTime dt = DateTime.now();
          if (c['created_at'] != null) {
            dt = DateTime.tryParse(c['created_at'].toString()) ?? DateTime.now();
          }

          final diagnosis = c['diagnosis']?.toString().trim();
          final symptoms = c['symptoms']?.toString().trim();
          final doctor = c['doctor_name']?.toString().trim();

          // Consultation encounter event
          items.add(
            TimelineItem(
              date: dt,
              category: 'consultation',
              title: (diagnosis != null && diagnosis.isNotEmpty)
                  ? 'Consultation: $diagnosis'
                  : 'Medical Consultation',
              subtitle: (symptoms != null && symptoms.isNotEmpty)
                  ? 'Symptoms: $symptoms'
                  : null,
              doctorName: doctor,
              data: c,
            ),
          );

          // If consultation has medications, create associated prescription event
          final rawMeds = c['medications'];
          if (rawMeds is List && rawMeds.isNotEmpty) {
            items.add(
              TimelineItem(
                date: dt,
                category: 'prescription',
                title: 'Prescription (${rawMeds.length} medications)',
                subtitle: 'Prescribed by ${doctor ?? "Doctor"}',
                doctorName: doctor,
                data: c,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Timeline error loading consultations: $e');
      }

      // 2. Fetch Vitals History
      try {
        final vitalsList =
            await _patientController.fetchVitalsHistory(widget.patientId);
        for (var v in vitalsList) {
          DateTime dt = DateTime.now();
          if (v['recorded_at'] != null) {
            dt = DateTime.tryParse(v['recorded_at'].toString()) ?? DateTime.now();
          } else if (v['created_at'] != null) {
            dt = DateTime.tryParse(v['created_at'].toString()) ?? DateTime.now();
          }

          items.add(
            TimelineItem(
              date: dt,
              category: 'vitals',
              title: 'Clinical Vitals Recorded',
              subtitle: 'BP, Sugar & Physiological Parameters',
              doctorName: v['nurse_name'] ?? v['recorded_by'],
              data: v,
            ),
          );
        }
      } catch (e) {
        debugPrint('Timeline error loading vitals: $e');
      }

      // Sort all items in reverse chronological order (newest first)
      items.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<TimelineItem> get _filteredItems {
    switch (_selectedFilter) {
      case TimelineFilter.consultations:
        return _allItems.where((i) => i.category == 'consultation').toList();
      case TimelineFilter.prescriptions:
        return _allItems.where((i) => i.category == 'prescription').toList();
      case TimelineFilter.vitals:
        return _allItems.where((i) => i.category == 'vitals').toList();
      case TimelineFilter.all:
        return _allItems;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildFilterBar(),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorState()
                  : _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : _buildTimelineList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Clinical Timeline',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Unified Longitudinal Record: ${widget.patientName}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close_rounded, size: 22),
            color: Colors.blueGrey,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All Events', TimelineFilter.all, _allItems.length),
            const SizedBox(width: 8),
            _buildFilterChip(
              '🩺 Consultations',
              TimelineFilter.consultations,
              _allItems.where((i) => i.category == 'consultation').length,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              '💊 Prescriptions',
              TimelineFilter.prescriptions,
              _allItems.where((i) => i.category == 'prescription').length,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              '📊 Vitals & Triage',
              TimelineFilter.vitals,
              _allItems.where((i) => i.category == 'vitals').length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, TimelineFilter filter, int count) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    final items = _filteredItems;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFirst = index == 0;
        final isLast = index == items.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline track on left
              _buildTimelineTrack(item, isFirst, isLast),
              const SizedBox(width: 16),
              // Timeline card on right
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildTimelineCard(item),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineTrack(TimelineItem item, bool isFirst, bool isLast) {
    Color nodeColor;
    IconData nodeIcon;

    switch (item.category) {
      case 'consultation':
        nodeColor = AppTheme.primaryColor;
        nodeIcon = Icons.medical_services_rounded;
        break;
      case 'prescription':
        nodeColor = const Color(0xFF059669); // Emerald Green
        nodeIcon = Icons.medication_rounded;
        break;
      case 'vitals':
        nodeColor = const Color(0xFFD97706); // Amber
        nodeIcon = Icons.monitor_heart_rounded;
        break;
      default:
        nodeColor = const Color(0xFF64748B);
        nodeIcon = Icons.circle;
    }

    return SizedBox(
      width: 36,
      child: Column(
        children: [
          // Top connecting line
          Container(
            width: 2,
            height: 12,
            color: isFirst ? Colors.transparent : const Color(0xFFCBD5E1),
          ),
          // Node icon circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: nodeColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: nodeColor, width: 2),
            ),
            child: Icon(nodeIcon, size: 16, color: nodeColor),
          ),
          // Bottom connecting line
          Expanded(
            child: Container(
              width: 2,
              color: isLast ? Colors.transparent : const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(TimelineItem item) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.date);

    switch (item.category) {
      case 'consultation':
        return _buildConsultationCard(item, dateStr);
      case 'prescription':
        return _buildPrescriptionCard(item, dateStr);
      case 'vitals':
        return _buildVitalsCard(item, dateStr);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildConsultationCard(TimelineItem item, String dateStr) {
    final c = item.data;
    final diagnosis = c['diagnosis']?.toString().trim() ?? '';
    final symptoms = c['symptoms']?.toString().trim() ?? '';
    final plan = c['plan']?.toString().trim() ?? '';
    final notes = c['notes']?.toString().trim() ?? '';
    final doctor = item.doctorName ?? 'Treating Doctor';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CONSULTATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diagnosis.isNotEmpty ? diagnosis : 'General Examination',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Dr. $doctor',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 16, color: Color(0xFFF1F5F9)),
            if (symptoms.isNotEmpty) ...[
              _buildDetailSection('Chief Complaints & Symptoms', symptoms, Icons.sick_outlined),
              const SizedBox(height: 10),
            ],
            if (plan.isNotEmpty) ...[
              _buildDetailSection('Clinical Treatment Plan', plan, Icons.playlist_add_check_rounded),
              const SizedBox(height: 10),
            ],
            if (notes.isNotEmpty) ...[
              _buildDetailSection('Doctor Recommendations & Advice', notes, Icons.description_outlined),
              const SizedBox(height: 10),
            ],
            if (ConsultationDocumentsView.hasDocuments(c['documents'])) ...[
              const SizedBox(height: 6),
              const Text(
                'ATTACHED CLINICAL DOCKETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              ConsultationDocumentsView(documents: c['documents']),
              const SizedBox(height: 10),
            ],
            if (widget.onCopyDiagnosis != null && diagnosis.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    widget.onCopyDiagnosis!(diagnosis);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied diagnosis: $diagnosis'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy Diagnosis', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(TimelineItem item, String dateStr) {
    final c = item.data;
    final rawMeds = c['medications'] as List<dynamic>? ?? [];
    final List<Map<String, String>> medsList = [];

    for (var m in rawMeds) {
      if (m is Map) {
        medsList.add({
          'name': m['name']?.toString() ?? '',
          'dosage': m['dosage']?.toString() ?? '',
          'frequency': m['frequency']?.toString() ?? '',
          'duration': m['duration']?.toString() ?? '',
        });
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRESCRIPTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${medsList.length} Prescribed Medications',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: medsList.map((med) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        med['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (med['dosage'] != null && med['dosage']!.isNotEmpty) ...[
                      Text(
                        med['dosage']!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        med['frequency'] ?? '1-0-1',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (med['duration'] != null && med['duration']!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${med['duration']})',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          if (widget.onCopyPrescription != null && medsList.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  widget.onCopyPrescription!(medsList);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copied ${medsList.length} medications to current prescription',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                },
                icon: const Icon(Icons.playlist_add_rounded, size: 16),
                label: const Text('Duplicate to Current Prescription', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsCard(TimelineItem item, String dateStr) {
    final v = item.data;
    final bpSys = v['bp_systolic'] ?? v['blood_pressure_systolic'];
    final bpDia = v['bp_diastolic'] ?? v['blood_pressure_diastolic'];
    final hr = v['heart_rate'] ?? v['pulse'];
    final temp = v['temperature'];
    final sugar = v['sugar_level'] ?? v['blood_sugar'];
    final pain = v['pain_score'];
    final bmi = v['bmi'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEF3C7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'VITALS & INTAKE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (bpSys != null && bpDia != null)
                _buildVitalMetric(
                  'BP',
                  '$bpSys/$bpDia mmHg',
                  (int.tryParse(bpSys.toString()) ?? 120) >= 140
                      ? AppTheme.dangerColor
                      : const Color(0xFF0F172A),
                ),
              if (hr != null)
                _buildVitalMetric('Pulse', '$hr bpm', const Color(0xFF0F172A)),
              if (temp != null)
                _buildVitalMetric(
                  'Temp',
                  '$temp °F',
                  (double.tryParse(temp.toString()) ?? 98.6) >= 100.4
                      ? AppTheme.dangerColor
                      : const Color(0xFF0F172A),
                ),
              if (sugar != null)
                _buildVitalMetric(
                  'Sugar',
                  '$sugar mg/dL',
                  (int.tryParse(sugar.toString()) ?? 100) >= 200
                      ? AppTheme.dangerColor
                      : const Color(0xFF0F172A),
                ),
              if (pain != null)
                _buildVitalMetric(
                  'Pain Score',
                  '$pain / 10',
                  (int.tryParse(pain.toString()) ?? 0) >= 7
                      ? AppTheme.dangerColor
                      : const Color(0xFFD97706),
                ),
              if (bmi != null)
                _buildVitalMetric('BMI', '$bmi kg/m²', const Color(0xFF0F172A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalMetric(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Timeline Records Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'There are no historical consultations or recorded vitals for this filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppTheme.dangerColor),
            const SizedBox(height: 12),
            Text(
              'Failed to load timeline records',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUnifiedHistory,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
