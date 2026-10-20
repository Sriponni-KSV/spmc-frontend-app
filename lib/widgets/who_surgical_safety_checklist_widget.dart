import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../screens/ot_management.dart';
import '../controllers/ot_controller.dart';

class WhoSurgicalSafetyChecklistWidget extends StatefulWidget {
  final OtCase otCase;
  final bool isMobile;
  final String currentUser;
  final bool isPopup;
  final Function(OtCase updatedCase)? onChecklistUpdated;

  const WhoSurgicalSafetyChecklistWidget({
    Key? key,
    required this.otCase,
    required this.isMobile,
    required this.currentUser,
    this.isPopup = false,
    this.onChecklistUpdated,
  }) : super(key: key);

  @override
  State<WhoSurgicalSafetyChecklistWidget> createState() => _WhoSurgicalSafetyChecklistWidgetState();
}

class _WhoSurgicalSafetyChecklistWidgetState extends State<WhoSurgicalSafetyChecklistWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OtController _otController = OtController();
  bool _isSaving = false;

  // Local checklist copy
  late Map<String, dynamic> _checklist;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checklist = Map<String, dynamic>.from(widget.otCase.whoChecklist);
  }

  @override
  void didUpdateWidget(covariant WhoSurgicalSafetyChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.otCase.whoChecklist != oldWidget.otCase.whoChecklist) {
      setState(() {
        _checklist = Map<String, dynamic>.from(widget.otCase.whoChecklist);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isStageComplete(String stage) {
    final stageData = _checklist[stage];
    return stageData != null && stageData['is_completed'] == true;
  }

  Future<void> _saveStage(String stage, Map<String, dynamic> data) async {
    if (widget.otCase.dbId == null) return;
    setState(() => _isSaving = true);
    try {
      final updatedCase = await _otController.updateWhoChecklist(
        widget.otCase.dbId!,
        stage: stage,
        checklistData: data,
        updatedBy: widget.currentUser,
      );

      setState(() {
        _checklist = Map<String, dynamic>.from(updatedCase.whoChecklist);
      });

      if (widget.onChecklistUpdated != null) {
        widget.onChecklistUpdated!(updatedCase);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('WHO Checklist [${_getStageTitle(stage)}] verified and recorded successfully.'),
              ],
            ),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving checklist: $e'),
            backgroundColor: AppTheme.dangerColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _getStageTitle(String stage) {
    switch (stage) {
      case 'sign_in':
        return 'Stage 1: Sign-In';
      case 'time_out':
        return 'Stage 2: Time-Out';
      case 'sign_out':
        return 'Stage 3: Sign-Out';
      default:
        return stage;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 12 : 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
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
            child: const Icon(Icons.fact_check_outlined, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHO Surgical Safety Checklist',
                  style: TextStyle(
                    fontSize: widget.isMobile ? 13 : 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Three-Stage Safety Protocol • Case: ${widget.otCase.id}',
                  style: TextStyle(
                    fontSize: widget.isMobile ? 10 : 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _buildOverallProgressBadge(),
          if (widget.isPopup) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              visualDensity: VisualDensity.compact,
              tooltip: 'Close Checklist',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 3,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: TextStyle(fontSize: widget.isMobile ? 11 : 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontSize: widget.isMobile ? 11 : 12, fontWeight: FontWeight.w500),
        labelPadding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 4 : 16),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStageIcon('sign_in'),
                const SizedBox(width: 4),
                const Flexible(child: Text('1. Sign-In', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStageIcon('time_out'),
                const SizedBox(width: 4),
                const Flexible(child: Text('2. Time-Out', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStageIcon('sign_out'),
                const SizedBox(width: 4),
                const Flexible(child: Text('3. Sign-Out', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPopup) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSignInStage(isNested: true),
                  _buildTimeOutStage(isNested: true),
                  _buildSignOutStage(isNested: true),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Live Dashboard Mode: render directly without nested scroll trap or fixed height
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          _buildTabs(),
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              switch (_tabController.index) {
                case 1:
                  return _buildTimeOutStage(isNested: false);
                case 2:
                  return _buildSignOutStage(isNested: false);
                case 0:
                default:
                  return _buildSignInStage(isNested: false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageIcon(String stage) {
    final complete = _isStageComplete(stage);
    return Icon(
      complete ? Icons.check_circle : Icons.radio_button_unchecked,
      color: complete ? AppTheme.secondaryColor : const Color(0xFF94A3B8),
      size: 16,
    );
  }

  Widget _buildOverallProgressBadge() {
    int count = 0;
    if (_isStageComplete('sign_in')) count++;
    if (_isStageComplete('time_out')) count++;
    if (_isStageComplete('sign_out')) count++;

    final allComplete = count == 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: allComplete
            ? AppTheme.secondaryColor.withOpacity(0.12)
            : AppTheme.primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: allComplete
              ? AppTheme.secondaryColor.withOpacity(0.3)
              : AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        '$count / 3 Verified',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: allComplete ? AppTheme.secondaryColor : AppTheme.primaryColor,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 1: SIGN-IN (Before induction of anaesthesia)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSignInStage({bool isNested = false}) {
    final data = Map<String, dynamic>.from(_checklist['sign_in'] ?? {});
    final isDone = data['is_completed'] == true;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageBanner(
          title: 'Stage 1: Sign-In',
          subtitle: 'Before induction of anaesthesia • Conducted by Anaesthetist & Nurse',
          isComplete: isDone,
          completedBy: data['completed_by'],
          completedAt: data['completed_at'],
        ),
        const SizedBox(height: 14),

        _buildCheckItem(
          title: 'Patient identity, site, procedure and consent confirmed',
          subtitle: 'Patient verbally confirms name, DOB, procedure, and consent form is signed',
          value: data['patient_confirmed'] ?? false,
          onChanged: (val) => setState(() {
            data['patient_confirmed'] = val;
            _checklist['sign_in'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Surgical site marked / Not applicable',
          subtitle: 'Incision site is physically marked with indelible ink by surgical team',
          value: data['site_marked'] ?? false,
          onChanged: (val) => setState(() {
            data['site_marked'] = val;
            _checklist['sign_in'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Anaesthesia machine & medication check complete',
          subtitle: 'Vaporizers, suction, ventilator, alarms, drugs, and emergency tray inspected',
          value: data['anaesthesia_check_complete'] ?? false,
          onChanged: (val) => setState(() {
            data['anaesthesia_check_complete'] = val;
            _checklist['sign_in'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Pulse oximeter on patient and functioning',
          subtitle: 'Continuous audible pulse tone and SpO2 reading verified',
          value: data['pulse_oximeter_functioning'] ?? false,
          onChanged: (val) => setState(() {
            data['pulse_oximeter_functioning'] = val;
            _checklist['sign_in'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Does the patient have a known allergy?',
          subtitle: 'Check latex, antibiotics, iodinated contrast, and general anaesthetic agents',
          value: data['allergy_checked'] ?? false,
          onChanged: (val) => setState(() {
            data['allergy_checked'] = val;
            _checklist['sign_in'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Difficult airway / Aspiration risk assessed?',
          subtitle: 'Equipment & video laryngoscope / fibreoptic bronchoscope assistance ready if required',
          value: data['airway_risk_assessed'] ?? false,
          onChanged: (val) => setState(() {
            data['airway_risk_assessed'] = val;
            _checklist['sign_in'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Risk of >500ml blood loss (7ml/kg in children)?',
          subtitle: 'Two large-bore IV lines/central access and matched blood products cross-matched and available',
          value: data['blood_loss_risk_prepared'] ?? false,
          onChanged: (val) => setState(() {
            data['blood_loss_risk_prepared'] = val;
            _checklist['sign_in'] = data;
          }),
        ),

        const SizedBox(height: 16),
        _buildSaveStageButton(
          stageKey: 'sign_in',
          currentData: data,
          allRequiredChecked: (data['patient_confirmed'] == true) &&
              (data['site_marked'] == true) &&
              (data['anaesthesia_check_complete'] == true) &&
              (data['pulse_oximeter_functioning'] == true) &&
              (data['allergy_checked'] == true) &&
              (data['airway_risk_assessed'] == true) &&
              (data['blood_loss_risk_prepared'] == true),
        ),
        const SizedBox(height: 16),
      ],
    );

    if (isNested) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
        child: content,
      );
    }
    return Padding(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
      child: content,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 2: TIME-OUT (Before skin incision)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTimeOutStage({bool isNested = false}) {
    final data = Map<String, dynamic>.from(_checklist['time_out'] ?? {});
    final isDone = data['is_completed'] == true;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageBanner(
          title: 'Stage 2: Time-Out',
          subtitle: 'Before skin incision • Complete team verbal pause led by Lead Surgeon',
          isComplete: isDone,
          completedBy: data['completed_by'],
          completedAt: data['completed_at'],
        ),
        const SizedBox(height: 14),

        _buildCheckItem(
          title: 'Team introduction by name and role',
          subtitle: 'Lead Surgeon (${widget.otCase.leadSurgeon ?? widget.otCase.surgeon ?? "Dr."}), Assistant, Anaesthetist (${widget.otCase.anaesthetist ?? "Dr."}), Scrub & Circulating Nurses',
          value: data['team_introduced'] ?? false,
          onChanged: (val) => setState(() {
            data['team_introduced'] = val;
            _checklist['time_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Patient identity, surgical procedure, and incision site verbalized',
          subtitle: 'All members unanimously confirm patient: ${widget.otCase.patientName}, procedure: ${widget.otCase.surgeryType ?? widget.otCase.diagnosis}',
          value: data['patient_site_procedure_verbalized'] ?? false,
          onChanged: (val) => setState(() {
            data['patient_site_procedure_verbalized'] = val;
            _checklist['time_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Antibiotic prophylaxis administered within past 60 minutes?',
          subtitle: 'Or explicitly confirmed not applicable / already infused',
          value: data['antibiotic_prophylaxis_verified'] ?? false,
          onChanged: (val) => setState(() {
            data['antibiotic_prophylaxis_verified'] = val;
            _checklist['time_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Surgeon reviews: critical steps, duration, expected blood loss',
          subtitle: 'Surgeon states planned operative course, potential hazards, and anticipated duration',
          value: data['surgeon_review_done'] ?? false,
          onChanged: (val) => setState(() {
            data['surgeon_review_done'] = val;
            _checklist['time_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Anaesthetist reviews: patient-specific concerns and vitals plan',
          subtitle: 'Hemodynamic stability, blood product requirement, vasopressor readiness',
          value: data['anaesthetist_review_done'] ?? false,
          onChanged: (val) => setState(() {
            data['anaesthetist_review_done'] = val;
            _checklist['time_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Nursing team reviews: sterility confirmed and equipment ready',
          subtitle: 'Sterilization indicators verified, implants and specialty instruments inspected',
          value: data['nursing_sterility_confirmed'] ?? false,
          onChanged: (val) => setState(() {
            data['nursing_sterility_confirmed'] = val;
            _checklist['time_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Essential imaging displayed on viewbox / digital monitors?',
          subtitle: 'CT, MRI, X-rays, or laparoscopic feeds correctly oriented and displayed',
          value: data['essential_imaging_displayed'] ?? false,
          onChanged: (val) => setState(() {
            data['essential_imaging_displayed'] = val;
            _checklist['time_out'] = data;
          }),
        ),

        const SizedBox(height: 16),
        _buildSaveStageButton(
          stageKey: 'time_out',
          currentData: data,
          allRequiredChecked: (data['team_introduced'] == true) &&
              (data['patient_site_procedure_verbalized'] == true) &&
              (data['antibiotic_prophylaxis_verified'] == true) &&
              (data['surgeon_review_done'] == true) &&
              (data['anaesthetist_review_done'] == true) &&
              (data['nursing_sterility_confirmed'] == true) &&
              (data['essential_imaging_displayed'] == true),
        ),
        const SizedBox(height: 16),
      ],
    );

    if (isNested) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
        child: content,
      );
    }
    return Padding(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
      child: content,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 3: SIGN-OUT (Before patient leaves the operating room)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSignOutStage({bool isNested = false}) {
    final data = Map<String, dynamic>.from(_checklist['sign_out'] ?? {});
    final isDone = data['is_completed'] == true;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageBanner(
          title: 'Stage 3: Sign-Out',
          subtitle: 'Before patient leaves the operating room • Lead Nurse & Surgical Team',
          isComplete: isDone,
          completedBy: data['completed_by'],
          completedAt: data['completed_at'],
        ),
        const SizedBox(height: 14),

        _buildCheckItem(
          title: 'Name of the procedure performed is verbally confirmed & recorded',
          subtitle: 'Accurate surgical wording written in intra-op notes',
          value: data['procedure_name_recorded'] ?? false,
          onChanged: (val) => setState(() {
            data['procedure_name_recorded'] = val;
            _checklist['sign_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Instrument, needle, sponge and gauze counts are CORRECT',
          subtitle: 'Verified by scrub nurse and circulating nurse prior to final wound closure',
          value: data['counts_correct'] ?? false,
          onChanged: (val) => setState(() {
            data['counts_correct'] = val;
            _checklist['sign_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Specimen correctly labelled with patient name, ID, and anatomical site',
          subtitle: 'Specimen containers read aloud and verified against surgical pathology form',
          value: data['specimen_labelled'] ?? false,
          onChanged: (val) => setState(() {
            data['specimen_labelled'] = val;
            _checklist['sign_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Any equipment problems or malfunctions addressed and recorded',
          subtitle: 'Diathermy, laparoscopy stack, instruments, or suction issues documented for biomedical engineering',
          value: data['equipment_issues_addressed'] ?? false,
          onChanged: (val) => setState(() {
            data['equipment_issues_addressed'] = val;
            _checklist['sign_out'] = data;
          }),
        ),
        _buildCheckItem(
          title: 'Surgeon, Anaesthetist & Nurse review recovery and post-op care plan',
          subtitle: 'Airway extubation status, analgesia, vital monitoring, and transfer destination agreed',
          value: data['post_op_concerns_reviewed'] ?? false,
          onChanged: (val) => setState(() {
            data['post_op_concerns_reviewed'] = val;
            _checklist['sign_out'] = data;
          }),
        ),

        const SizedBox(height: 16),
        _buildSaveStageButton(
          stageKey: 'sign_out',
          currentData: data,
          allRequiredChecked: (data['procedure_name_recorded'] == true) &&
              (data['counts_correct'] == true) &&
              (data['specimen_labelled'] == true) &&
              (data['equipment_issues_addressed'] == true) &&
              (data['post_op_concerns_reviewed'] == true),
        ),
        const SizedBox(height: 16),
      ],
    );

    if (isNested) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
        child: content,
      );
    }
    return Padding(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
      child: content,
    );
  }

  Widget _buildStageBanner({
    required String title,
    required String subtitle,
    required bool isComplete,
    String? completedBy,
    String? completedAt,
  }) {
    String formattedTime = '';
    if (completedAt != null) {
      try {
        formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(completedAt).toLocal());
      } catch (_) {}
    }

    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: isComplete ? AppTheme.secondaryColor.withOpacity(0.08) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isComplete ? AppTheme.secondaryColor.withOpacity(0.3) : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.verified_user : Icons.schedule,
            color: isComplete ? AppTheme.secondaryColor : const Color(0xFF64748B),
            size: widget.isMobile ? 20 : 24,
          ),
          SizedBox(width: widget.isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.isMobile ? 13 : 14,
                    color: isComplete ? AppTheme.secondaryColor : AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: widget.isMobile ? 11 : 12, color: AppTheme.textSecondaryColor),
                ),
                if (isComplete && completedBy != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Verified by $completedBy • $formattedTime',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isComplete ? AppTheme.secondaryColor : const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isComplete ? 'VERIFIED' : 'PENDING',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value ? AppTheme.primaryColor.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? AppTheme.primaryColor.withOpacity(0.3) : AppTheme.borderColor,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (val) => onChanged(val ?? false),
        activeColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 8 : 12, vertical: 2),
        title: Text(
          title,
          style: TextStyle(
            fontSize: widget.isMobile ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: value ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: widget.isMobile ? 10 : 11, color: AppTheme.textSecondaryColor),
        ),
      ),
    );
  }

  Widget _buildSaveStageButton({
    required String stageKey,
    required Map<String, dynamic> currentData,
    required bool allRequiredChecked,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isSaving
            ? null
            : () {
                currentData['is_completed'] = allRequiredChecked;
                _saveStage(stageKey, currentData);
              },
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                allRequiredChecked ? Icons.check_circle : Icons.save_outlined,
                size: 18,
              ),
        label: Text(
          allRequiredChecked
              ? 'Complete & Sign Off Stage'
              : 'Save Progress (Items Incomplete)',
          style: TextStyle(fontSize: widget.isMobile ? 13 : 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: allRequiredChecked ? AppTheme.secondaryColor : AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }
}
