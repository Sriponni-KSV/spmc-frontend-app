import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';

/// Clinical Daily Doctor Rounds with Structured SOAP Notes
class IpdDoctorRoundsSoapWidget extends StatefulWidget {
  final Map<String, dynamic> admission;
  final List<Map<String, dynamic>> rounds;
  final Map<String, dynamic>? latestVitals;
  final Map<String, dynamic>? fluidSummary;
  final String currentDoctorName;
  final bool isMobile;
  final VoidCallback? onRefresh;
  final Future<void> Function({
    required String roundType,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
    required Map<String, dynamic>? vitalsSnapshot,
    DateTime? roundDate,
  }) onAddSoapRound;

  const IpdDoctorRoundsSoapWidget({
    super.key,
    required this.admission,
    required this.rounds,
    required this.currentDoctorName,
    required this.isMobile,
    required this.onAddSoapRound,
    this.latestVitals,
    this.fluidSummary,
    this.onRefresh,
  });

  @override
  State<IpdDoctorRoundsSoapWidget> createState() => _IpdDoctorRoundsSoapWidgetState();
}

class _IpdDoctorRoundsSoapWidgetState extends State<IpdDoctorRoundsSoapWidget> {
  String _selectedRoundTypeFilter = 'All';

  int _calculateHospitalDay() {
    try {
      final admDate = DateTime.parse(widget.admission['admission_date'].toString()).toLocal();
      final diff = DateTime.now().difference(admDate).inDays + 1;
      return diff > 0 ? diff : 1;
    } catch (_) {
      return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitalDay = _calculateHospitalDay();
    final filteredRounds = widget.rounds.where((r) {
      if (_selectedRoundTypeFilter == 'All') return true;
      final type = (r['round_type'] ?? 'Morning Round').toString();
      return type == _selectedRoundTypeFilter;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header & Round Action ─────────────────────────────────────────
          _buildHeroHeader(hospitalDay),
          const SizedBox(height: 16),

          // ─── Filter Bar ───────────────────────────────────────────────────
          _buildFilterBar(),
          const SizedBox(height: 16),

          // ─── Rounds Timeline & Cards ───────────────────────────────────────
          _buildRoundsTimeline(filteredRounds),
        ],
      ),
    );
  }

  // ─── Header Card ─────────────────────────────────────────────────────────

  Widget _buildHeroHeader(int hospitalDay) {
    final patientName = (widget.admission['patient_name'] ?? 'Patient').toString();
    final bedNum = (widget.admission['bed_number'] ?? '--').toString();
    final ward = (widget.admission['ward_type'] ?? 'General').toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_ind_outlined, color: AppTheme.secondaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.tr('daily_rounds_title', fallback: 'Daily Physician Rounds (SOAP Notes)'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Hospital Day $hospitalDay',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$patientName • Bed $bedNum ($ward) • Attending: Dr. ${widget.currentDoctorName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(widget.isMobile ? 'Round' : 'Conduct Round (SOAP)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showConductRoundModal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Filter Bar ──────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'All Rounds (${widget.rounds.length})'),
          const SizedBox(width: 8),
          _buildFilterChip('Morning Round', 'Morning Rounds'),
          const SizedBox(width: 8),
          _buildFilterChip('Evening Round', 'Evening Rounds'),
          const SizedBox(width: 8),
          _buildFilterChip('Special Review', 'Special Reviews'),
          const SizedBox(width: 8),
          _buildFilterChip('ICU Review', 'ICU Rounds'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedRoundTypeFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedRoundTypeFilter = key);
      },
    );
  }

  // ─── Rounds Timeline & Cards ─────────────────────────────────────────────

  Widget _buildRoundsTimeline(List<Map<String, dynamic>> rounds) {
    if (rounds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 50),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(Icons.notes_outlined, size: 50, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No doctor rounds recorded yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Click "Conduct Round (SOAP)" to log clinical rounds with S-O-A-P sections.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: rounds.map((r) => _buildSoapCard(r)).toList(),
    );
  }

  Widget _buildSoapCard(Map<String, dynamic> r) {
    final doctor = (r['doctor_name'] ?? 'Doctor').toString();
    final roundType = (r['round_type'] ?? 'Morning Round').toString();
    final rawDate = r['round_date'] ?? r['created_at'];

    String dateStr = '--';
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString()).toLocal();
        dateStr = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(dt);
      } catch (_) {}
    }

    final subjective = (r['subjective'] ?? '').toString();
    final objective = (r['objective'] ?? '').toString();
    final assessment = (r['assessment'] ?? r['observation'] ?? '').toString();
    final plan = (r['plan'] ?? r['treatment_changes'] ?? '').toString();
    final notes = (r['notes'] ?? '').toString();

    final vitals = r['vitals_snapshot'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roundType.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined, size: 15, color: AppTheme.secondaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Dr. $doctor',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vitals Snapshot Bar (if saved with round)
          if (vitals != null && vitals.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
              child: Row(
                children: [
                  const Text('Rounds Vitals: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  if (vitals['bp'] != null) Text('BP: ${vitals['bp']}  ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  if (vitals['pulse'] != null) Text('HR: ${vitals['pulse']} bpm  ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  if (vitals['temp'] != null) Text('Temp: ${vitals['temp']} °F  ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  if (vitals['spo2'] != null) Text('SpO2: ${vitals['spo2']}%  ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          // SOAP Content Sections
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subjective.isNotEmpty)
                  _buildSoapSection('S', 'Subjective', subjective, const Color(0xFF0284C7)),
                if (objective.isNotEmpty)
                  _buildSoapSection('O', 'Objective', objective, const Color(0xFF059669)),
                if (assessment.isNotEmpty)
                  _buildSoapSection('A', 'Assessment', assessment, const Color(0xFF7C3AED)),
                if (plan.isNotEmpty)
                  _buildSoapSection('P', 'Plan', plan, const Color(0xFFD97706)),

                // Fallback for older unstructured notes
                if (subjective.isEmpty && objective.isEmpty && assessment.isEmpty && plan.isEmpty && notes.isNotEmpty)
                  Text(notes, style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textPrimaryColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoapSection(String letter, String title, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              letter,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Conduct Daily Round Modal ───────────────────────────────────────────

  void _showConductRoundModal() {
    String roundType = 'Morning Round';
    int painScore = 0;
    final subjCtrl = TextEditingController();
    final objCtrl = TextEditingController();
    final assessCtrl = TextEditingController();
    final planCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Auto-populate Objective with latest clinical context if available
    final latestVitals = widget.latestVitals;
    final fluidSummary = widget.fluidSummary;
    final List<String> objectivePresets = [];

    if (latestVitals != null) {
      final bp = latestVitals['blood_pressure'] ?? '--';
      final pulse = latestVitals['pulse'] ?? '--';
      final temp = latestVitals['temperature'] ?? '--';
      final spo2 = latestVitals['spo2'] ?? '--';
      objectivePresets.add('Vitals: BP $bp mmHg, HR $pulse bpm, Temp $temp°F, SpO2 $spo2%.');
    }
    if (fluidSummary != null) {
      final inVol = fluidSummary['total_intake_ml'] ?? 0;
      final outVol = fluidSummary['total_output_ml'] ?? 0;
      final bal = fluidSummary['net_balance_ml'] ?? 0;
      objectivePresets.add('24h Fluid Balance: Intake ${inVol}ml, Output ${outVol}ml (Net: ${bal >= 0 ? '+' : ''}${bal}ml).');
    }
    objectivePresets.add('General: Alert, conscious, oriented to time/place/person. S1 S2 heard, B/L air entry clear. Abdomen soft.');

    objCtrl.text = objectivePresets.join('\n');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 680,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Modal Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.assignment_ind_outlined, color: AppTheme.secondaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Physician Daily Round & SOAP Assessment',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(modalCtx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Round Type Picker
                        Row(
                          children: [
                            const Text('Round Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: roundType,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
                                  items: const [
                                    DropdownMenuItem(value: 'Morning Round', child: Text('Morning Consultant Round')),
                                    DropdownMenuItem(value: 'Evening Round', child: Text('Evening Review Round')),
                                    DropdownMenuItem(value: 'Special Review', child: Text('Special Clinical Review')),
                                    DropdownMenuItem(value: 'ICU Review', child: Text('ICU Critical Care Review')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => roundType = val);
                                  },
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text('Attending: Dr. ${widget.currentDoctorName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pain Score Slider / Chips
                        Row(
                          children: [
                            const Text('Patient Pain Score (0 - 10):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            ...[0, 2, 4, 6, 8, 10].map((score) {
                              final isSel = painScore == score;
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: ChoiceChip(
                                  label: Text('$score', style: const TextStyle(fontSize: 11)),
                                  selected: isSel,
                                  selectedColor: score > 6 ? Colors.red : (score > 3 ? Colors.orange : AppTheme.secondaryColor),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
                                  onSelected: (val) {
                                    if (val) setModalState(() => painScore = score);
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── S (Subjective) ──────────────────────────────────
                        _buildModalSectionHeader('S', 'Subjective (Patient Complaints, Symptoms, Overnight Events)', const Color(0xFF0284C7)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: subjCtrl,
                          maxLines: 2,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            hintText: 'e.g. Patient feels better, slept well, pain decreased (score $painScore/10), tolerated oral breakfast without nausea...',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Subjective observations are required' : null,
                        ),
                        const SizedBox(height: 14),

                        // ── O (Objective) ───────────────────────────────────
                        _buildModalSectionHeader('O', 'Objective (Physical Exam, Systemic Exam, Vitals, Wound/Drains)', const Color(0xFF059669)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: objCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'e.g. Conscious, oriented, afebrile. CVS: S1 S2 heard. RS: Clear. Abdomen: Soft, dressing intact...',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── A (Assessment) ──────────────────────────────────
                        _buildModalSectionHeader('A', 'Assessment (Diagnostic Impression, Clinical Progression)', const Color(0xFF7C3AED)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: assessCtrl,
                          maxLines: 2,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            hintText: 'e.g. Post-op Day 2 resolving satisfactorily; Hemodynamically stable; Sepsis responding well to IV antibiotics...',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Clinical assessment is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // ── P (Plan) ────────────────────────────────────────
                        _buildModalSectionHeader('P', 'Plan (Medications, Lab Orders, Diet, Mobilization, Discharge Target)', const Color(0xFFD97706)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: planCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. Step down IV analgesics to oral; check repeat CBC in evening; start soft oral diet; encourage ambulation; planned discharge in 24h...',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(modalCtx).pop(),
                              style: AppTheme.cancelButton,
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                Navigator.of(modalCtx).pop();

                                Map<String, dynamic>? vitalsSnap;
                                if (latestVitals != null) {
                                  vitalsSnap = {
                                    'bp': latestVitals['blood_pressure'],
                                    'pulse': latestVitals['pulse'],
                                    'temp': latestVitals['temperature'],
                                    'spo2': latestVitals['spo2'],
                                  };
                                }

                                await widget.onAddSoapRound(
                                  roundType: roundType,
                                  subjective: subjCtrl.text.trim(),
                                  objective: objCtrl.text.trim(),
                                  assessment: assessCtrl.text.trim(),
                                  plan: planCtrl.text.trim(),
                                  vitalsSnapshot: vitalsSnap,
                                  roundDate: DateTime.now(),
                                );
                              },
                              child: const Text('Sign & Save SOAP Round'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalSectionHeader(String letter, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ),
      ],
    );
  }
}
