import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../screens/ot_management.dart';
import '../controllers/ot_controller.dart';

class PacAssessmentDialog extends StatefulWidget {
  final OtCase otCase;
  final bool isMobile;
  final String currentUser;
  final Function(OtCase updatedCase)? onPacUpdated;

  const PacAssessmentDialog({
    Key? key,
    required this.otCase,
    required this.isMobile,
    required this.currentUser,
    this.onPacUpdated,
  }) : super(key: key);

  @override
  State<PacAssessmentDialog> createState() => _PacAssessmentDialogState();
}

class _PacAssessmentDialogState extends State<PacAssessmentDialog> {
  final OtController _otController = OtController();
  bool _isSubmitting = false;

  // PAC Form State
  late String _asaGrade;
  late bool _isEmergency;
  late String _mallampatiClass;
  late String _mouthOpening;
  late String _neckMobility;
  late String _dentition;
  late String _anaesthesiaType;
  late String _clearanceDecision;

  // Checkboxes
  bool _npoSolidsVerified = false;
  bool _npoFluidsVerified = false;
  bool _ecgVerified = false;
  bool _cxrVerified = false;
  bool _cbcHbVerified = false;
  bool _coagulationVerified = false;
  bool _renalElectrolytesVerified = false;
  bool _icuBedReserved = false;

  // Co-morbidities
  bool _hasHypertension = false;
  bool _hasDiabetes = false;
  bool _hasCad = false;
  bool _hasAsthma = false;
  bool _hasRenalDisease = false;
  bool _onAnticoagulants = false;

  late TextEditingController _notesController;
  late TextEditingController _airwayDetailsController;

  @override
  void initState() {
    super.initState();
    final pac = widget.otCase.pacDetails;

    _asaGrade = pac['asa_grade'] ?? 'ASA I';
    _isEmergency = pac['is_emergency'] ?? false;
    _mallampatiClass = pac['mallampati_class'] ?? 'Class I';
    _mouthOpening = pac['mouth_opening'] ?? 'Adequate (> 3 fingers)';
    _neckMobility = pac['neck_mobility'] ?? 'Normal Full Range';
    _dentition = pac['dentition'] ?? 'Intact';
    _anaesthesiaType = widget.otCase.anaesthesiaType ?? pac['anaesthesia_type'] ?? 'General Anaesthesia';
    _clearanceDecision = widget.otCase.pacStatus.isNotEmpty && widget.otCase.pacStatus != 'Pending'
        ? widget.otCase.pacStatus
        : 'Cleared';

    _npoSolidsVerified = pac['npo_solids_verified'] ?? true;
    _npoFluidsVerified = pac['npo_fluids_verified'] ?? true;
    _ecgVerified = pac['ecg_verified'] ?? true;
    _cxrVerified = pac['cxr_verified'] ?? true;
    _cbcHbVerified = pac['cbc_hb_verified'] ?? true;
    _coagulationVerified = pac['coagulation_verified'] ?? true;
    _renalElectrolytesVerified = pac['renal_electrolytes_verified'] ?? true;
    _icuBedReserved = pac['icu_bed_reserved'] ?? false;

    final comorbidities = List<String>.from(pac['comorbidities'] ?? []);
    _hasHypertension = comorbidities.contains('Hypertension');
    _hasDiabetes = comorbidities.contains('Diabetes Mellitus');
    _hasCad = comorbidities.contains('CAD / IHD');
    _hasAsthma = comorbidities.contains('Asthma / COPD');
    _hasRenalDisease = comorbidities.contains('Renal Impairment');
    _onAnticoagulants = comorbidities.contains('On Anticoagulants');

    _notesController = TextEditingController(text: widget.otCase.anaesthesiaNotes ?? pac['clinical_notes'] ?? '');
    _airwayDetailsController = TextEditingController(text: pac['airway_details'] ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    _airwayDetailsController.dispose();
    super.dispose();
  }

  Color _getDecisionColor(String status) {
    switch (status) {
      case 'Cleared':
        return AppTheme.secondaryColor;
      case 'High Risk Clearance':
        return const Color(0xFFD97706); // Amber
      case 'Deferred':
        return const Color(0xFFE11D48); // Rose
      case 'Rejected':
        return AppTheme.dangerColor;
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _submitClearance() async {
    if (widget.otCase.dbId == null) return;
    setState(() => _isSubmitting = true);

    final List<String> comorbidities = [];
    if (_hasHypertension) comorbidities.add('Hypertension');
    if (_hasDiabetes) comorbidities.add('Diabetes Mellitus');
    if (_hasCad) comorbidities.add('CAD / IHD');
    if (_hasAsthma) comorbidities.add('Asthma / COPD');
    if (_hasRenalDisease) comorbidities.add('Renal Impairment');
    if (_onAnticoagulants) comorbidities.add('On Anticoagulants');

    final pacDetails = {
      'asa_grade': _asaGrade,
      'is_emergency': _isEmergency,
      'effective_asa': '$_asaGrade${_isEmergency ? "E" : ""}',
      'mallampati_class': _mallampatiClass,
      'mouth_opening': _mouthOpening,
      'neck_mobility': _neckMobility,
      'dentition': _dentition,
      'airway_details': _airwayDetailsController.text.trim(),
      'anaesthesia_type': _anaesthesiaType,
      'npo_solids_verified': _npoSolidsVerified,
      'npo_fluids_verified': _npoFluidsVerified,
      'ecg_verified': _ecgVerified,
      'cxr_verified': _cxrVerified,
      'cbc_hb_verified': _cbcHbVerified,
      'coagulation_verified': _coagulationVerified,
      'renal_electrolytes_verified': _renalElectrolytesVerified,
      'icu_bed_reserved': _icuBedReserved,
      'comorbidities': comorbidities,
      'clinical_notes': _notesController.text.trim(),
      'assessed_by': widget.currentUser,
      'assessed_at': DateTime.now().toIso8601String(),
    };

    try {
      final updatedCase = await _otController.updatePacClearance(
        widget.otCase.dbId!,
        pacStatus: _clearanceDecision,
        pacDetails: pacDetails,
        pacClearedBy: widget.currentUser,
        anaesthesiaNotes: _notesController.text.trim(),
        anaesthesiaType: _anaesthesiaType,
      );

      if (widget.onPacUpdated != null) {
        widget.onPacUpdated!(updatedCase);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('PAC Assessment recorded: [$_clearanceDecision] for ${widget.otCase.patientName}'),
              ],
            ),
            backgroundColor: _getDecisionColor(_clearanceDecision),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording PAC clearance: $e'),
            backgroundColor: AppTheme.dangerColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAsa = '$_asaGrade${_isEmergency ? "E" : ""}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(widget.isMobile ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.medical_services_outlined, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pre-Anaesthetic Checkup (PAC) & Clearance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Patient: ${widget.otCase.patientName} (${widget.otCase.age}y, ${widget.otCase.gender}) • ${widget.otCase.surgeryType ?? widget.otCase.diagnosis}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondaryColor),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: ASA Physical Status
                    _buildSectionCard(
                      title: '1. ASA Physical Status Classification',
                      icon: Icons.health_and_safety_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildAsaChip('ASA I', 'Normal Healthy'),
                              _buildAsaChip('ASA II', 'Mild Systemic'),
                              _buildAsaChip('ASA III', 'Severe Systemic'),
                              _buildAsaChip('ASA IV', 'Life Threatening'),
                              _buildAsaChip('ASA V', 'Moribund'),
                              _buildAsaChip('ASA VI', 'Organ Donor'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _isEmergency,
                                activeColor: AppTheme.dangerColor,
                                onChanged: (val) => setState(() => _isEmergency = val ?? false),
                              ),
                              const Expanded(
                                child: Text(
                                  'Emergency Procedure (Adds "E" modifier to ASA score)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dangerColor),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Text('Assigned ASA Classification: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                Text(
                                  effectiveAsa,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Mallampati & Airway Assessment
                    _buildSectionCard(
                      title: '2. Mallampati Airway Assessment',
                      icon: Icons.face_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mallampati Score (Tongue protrusion, sitting position):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMallampatiChip('Class I', 'Soft palate, fauces, uvula, pillars visible'),
                              _buildMallampatiChip('Class II', 'Soft palate, fauces, uvula visible'),
                              _buildMallampatiChip('Class III', 'Soft palate, base of uvula visible'),
                              _buildMallampatiChip('Class IV', 'Only hard palate visible (High Difficulty)'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          widget.isMobile
                              ? Column(
                                  children: [
                                    _buildDropdownField(
                                      label: 'Mouth Opening',
                                      value: _mouthOpening,
                                      items: ['Adequate (> 3 fingers)', 'Restricted (2-3 fingers)', 'Severe Limitation (< 2 fingers)'],
                                      onChanged: (val) => setState(() => _mouthOpening = val!),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildDropdownField(
                                      label: 'Neck Mobility',
                                      value: _neckMobility,
                                      items: ['Normal Full Range', 'Slightly Restricted', 'Severely Restricted / Fused'],
                                      onChanged: (val) => setState(() => _neckMobility = val!),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildDropdownField(
                                      label: 'Dentition',
                                      value: _dentition,
                                      items: ['Intact', 'Loose Teeth', 'Dentures / Edentulous', 'Prominent Maxillary Incisors'],
                                      onChanged: (val) => setState(() => _dentition = val!),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField(
                                        label: 'Mouth Opening',
                                        value: _mouthOpening,
                                        items: ['Adequate (> 3 fingers)', 'Restricted (2-3 fingers)', 'Severe Limitation (< 2 fingers)'],
                                        onChanged: (val) => setState(() => _mouthOpening = val!),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownField(
                                        label: 'Neck Mobility',
                                        value: _neckMobility,
                                        items: ['Normal Full Range', 'Slightly Restricted', 'Severely Restricted / Fused'],
                                        onChanged: (val) => setState(() => _neckMobility = val!),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownField(
                                        label: 'Dentition',
                                        value: _dentition,
                                        items: ['Intact', 'Loose Teeth', 'Dentures / Edentulous', 'Prominent Maxillary Incisors'],
                                        onChanged: (val) => setState(() => _dentition = val!),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Pre-Op Fasting & Investigations
                    _buildSectionCard(
                      title: '3. Mandatory Fasting (NPO) & Investigations Verification',
                      icon: Icons.checklist_outlined,
                      child: Column(
                        children: [
                          widget.isMobile
                              ? Column(
                                  children: [
                                    _buildCheckTile(
                                      'Solids NPO > 6 Hours Confirmed',
                                      _npoSolidsVerified,
                                      (val) => setState(() => _npoSolidsVerified = val),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildCheckTile(
                                      'Clear Fluids NPO > 2 Hours Confirmed',
                                      _npoFluidsVerified,
                                      (val) => setState(() => _npoFluidsVerified = val),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _buildCheckTile(
                                        'Solids NPO > 6 Hours Confirmed',
                                        _npoSolidsVerified,
                                        (val) => setState(() => _npoSolidsVerified = val),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildCheckTile(
                                        'Clear Fluids NPO > 2 Hours Confirmed',
                                        _npoFluidsVerified,
                                        (val) => setState(() => _npoFluidsVerified = val),
                                      ),
                                    ),
                                  ],
                                ),
                          const Divider(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildSmallCheck('ECG Normal / Reviewed', _ecgVerified, (v) => setState(() => _ecgVerified = v)),
                              _buildSmallCheck('Chest X-Ray Normal', _cxrVerified, (v) => setState(() => _cxrVerified = v)),
                              _buildSmallCheck('CBC / Hb Adequate', _cbcHbVerified, (v) => setState(() => _cbcHbVerified = v)),
                              _buildSmallCheck('PT / INR Coagulation OK', _coagulationVerified, (v) => setState(() => _coagulationVerified = v)),
                              _buildSmallCheck('Renal & Electrolytes OK', _renalElectrolytesVerified, (v) => setState(() => _renalElectrolytesVerified = v)),
                              _buildSmallCheck('ICU Bed Reserved (if high risk)', _icuBedReserved, (v) => setState(() => _icuBedReserved = v)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Co-morbidities & Anaesthesia Plan
                    _buildSectionCard(
                      title: '4. Systemic Co-morbidities & Proposed Anaesthetic Plan',
                      icon: Icons.monitor_heart_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                label: const Text('Hypertension'),
                                selected: _hasHypertension,
                                onSelected: (s) => setState(() => _hasHypertension = s),
                              ),
                              FilterChip(
                                label: const Text('Diabetes Mellitus'),
                                selected: _hasDiabetes,
                                onSelected: (s) => setState(() => _hasDiabetes = s),
                              ),
                              FilterChip(
                                label: const Text('CAD / IHD'),
                                selected: _hasCad,
                                onSelected: (s) => setState(() => _hasCad = s),
                              ),
                              FilterChip(
                                label: const Text('Asthma / COPD'),
                                selected: _hasAsthma,
                                onSelected: (s) => setState(() => _hasAsthma = s),
                              ),
                              FilterChip(
                                label: const Text('Renal Impairment'),
                                selected: _hasRenalDisease,
                                onSelected: (s) => setState(() => _hasRenalDisease = s),
                              ),
                              FilterChip(
                                label: const Text('On Anticoagulants'),
                                selected: _onAnticoagulants,
                                onSelected: (s) => setState(() => _onAnticoagulants = s),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Proposed Anaesthesia Technique',
                                  value: _anaesthesiaType,
                                  items: [
                                    'General Anaesthesia',
                                    'Spinal Anaesthesia',
                                    'Epidural Anaesthesia',
                                    'Combined Spinal-Epidural (CSE)',
                                    'Regional Nerve Block',
                                    'Monitored Anaesthesia Care (MAC)',
                                    'Local Anaesthesia + Sedation',
                                  ],
                                  onChanged: (val) => setState(() => _anaesthesiaType = val!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Anaesthetist Clinical Notes & Airway Management Strategy:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _notesController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Enter clinical findings, premedication orders, difficult airway plans...',
                              filled: true,
                              fillColor: Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 5: Mandatory Clearance Decision Gate
                    _buildSectionCard(
                      title: '5. Mandatory PAC Clearance Decision (Gate for OT Entry)',
                      icon: Icons.verified_user_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select the final anaesthetic clearance verdict for this patient:',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildDecisionRadio('Cleared', 'Cleared - Fit for OR', AppTheme.secondaryColor),
                              _buildDecisionRadio('High Risk Clearance', 'High Risk Clearance (ICU Backup)', const Color(0xFFD97706)),
                              _buildDecisionRadio('Deferred', 'Deferred (Needs tests / control)', const Color(0xFFE11D48)),
                              _buildDecisionRadio('Rejected', 'Rejected (Unfit for Surgery)', AppTheme.dangerColor),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getDecisionColor(_clearanceDecision).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _getDecisionColor(_clearanceDecision).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  ['Cleared', 'High Risk Clearance'].contains(_clearanceDecision)
                                      ? Icons.check_circle
                                      : Icons.warning_amber_rounded,
                                  color: _getDecisionColor(_clearanceDecision),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    ['Cleared', 'High Risk Clearance'].contains(_clearanceDecision)
                                        ? 'Patient will be PERMITTED to enter the Operation Theatre and proceed to surgery.'
                                        : 'GATE ENFORCED: Patient will be BLOCKED from transferring to OT until cleared.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getDecisionColor(_clearanceDecision),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 14 : 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: widget.isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Anaesthetist: ${widget.currentUser}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _submitClearance,
                                icon: _isSubmitting
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check, size: 16),
                                label: Text(
                                  _isSubmitting ? 'Recording...' : 'Authorize PAC',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getDecisionColor(_clearanceDecision),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Anaesthetist: ${widget.currentUser}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _submitClearance,
                              icon: _isSubmitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 18),
                              label: Text(_isSubmitting ? 'Recording...' : 'Save & Authorize PAC Decision'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getDecisionColor(_clearanceDecision),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAsaChip(String grade, String description) {
    final isSelected = _asaGrade == grade;
    return InkWell(
      onTap: () => setState(() => _asaGrade = grade),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Text(
              grade,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white.withOpacity(0.9) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMallampatiChip(String mClass, String desc) {
    final isSelected = _mallampatiClass == mClass;
    return InkWell(
      onTap: () => setState(() => _mallampatiClass = mClass),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Text(
          '$mClass ($desc)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionRadio(String value, String label, Color color) {
    final isSelected = _clearanceDecision == value;
    return InkWell(
      onTap: () => setState(() => _clearanceDecision = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppTheme.borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? color : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: isSelected ? color : AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckTile(String title, bool val, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: val ? AppTheme.secondaryColor.withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: val ? AppTheme.secondaryColor.withOpacity(0.3) : AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(val ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: val ? AppTheme.secondaryColor : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: val ? FontWeight.bold : FontWeight.normal))),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCheck(String title, bool val, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!val),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(val ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: val ? AppTheme.primaryColor : const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor)),
        ],
      ),
    );
  }
}
