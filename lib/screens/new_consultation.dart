import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../controllers/patient_controller.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/ipd_controller.dart';
import '../controllers/admin_controller.dart';
import '../widgets/custom_dropdown_search.dart';
import '../services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';
import 'package:file_picker/file_picker.dart';
import '../services/media_service.dart';
import '../widgets/document_view_dialog.dart';
import '../utils/unsaved_changes_helper.dart';
import 'dart:io' as io;

class NewConsultationView extends StatefulWidget {
  final AppointmentModel appointment;
  final Map<String, dynamic>? initialConsultation;
  final VoidCallback onBack;

  const NewConsultationView({
    Key? key,
    required this.appointment,
    required this.onBack,
    this.initialConsultation,
  }) : super(key: key);

  @override
  State<NewConsultationView> createState() => _NewConsultationViewState();
}

class _NewConsultationViewState extends State<NewConsultationView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<Map<String, String>> _medications = [];
  DateTime? _followUpDate;

  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _freqController = TextEditingController(
    text: '1-0-1',
  );
  final TextEditingController _durController = TextEditingController();

  List<String> _medicineCatalog = [];

  // Lab test state
  final Map<String, bool> _standardLabs = {
    'Complete Blood Count (CBC)': false,
    'Basic Metabolic Panel (BMP)': false,
    'Lipid Panel': false,
    'Thyroid Panel (TSH)': false,
    'Urinalysis': false,
    'Chest X-Ray': false,
    'ECG/EKG': false,
    'Urine Culture & Sensitivity': false,
    'Blood Culture & Sensitivity': false,
    'Biopsy / Histopathology': false,
  };
  final List<String> _customLabs = [];
  final TextEditingController _customLabController = TextEditingController();

  // New Controllers
  final TextEditingController _historyController = TextEditingController();
  final TextEditingController _examinationController = TextEditingController();
  final TextEditingController _familyHistoryController =
      TextEditingController();
  final TextEditingController _socialHistoryController =
      TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _procedureController = TextEditingController();
  final TextEditingController _allergyController = TextEditingController();
  final TextEditingController _leadingQuestionsController =
      TextEditingController();
  final TextEditingController _planController = TextEditingController();

  // Referral Controllers
  final TextEditingController _referredDoctorController =
      TextEditingController();
  final TextEditingController _referredDeptController = TextEditingController();
  final TextEditingController _referralNotesController =
      TextEditingController();

  // Document attachments list
  final List<Map<String, String>> _documents = [];
  final TextEditingController _docTitleController = TextEditingController();

  bool _isUploadingFile = false;
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  String? _selectedFileSizeStr;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
  
  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        List<int>? fileBytes = file.bytes;
        
        // Fallback for mobile devices where file.bytes can be null
        if (fileBytes == null && file.path != null) {
          fileBytes = io.File(file.path!).readAsBytesSync();
        }

        if (fileBytes != null) {
          final bytesCount = fileBytes.length;
          if (bytesCount > 5 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File exceeds 5MB limit. Please choose a smaller file.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          setState(() {
            _selectedFileName = file.name;
            _selectedFileBytes = fileBytes;
            _selectedFileSizeStr = _formatFileSize(bytesCount);
          });
        }
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> _uploadAndAddDocument() async {
    final title = _docTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a document title.')),
      );
      return;
    }

    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUploadingFile = true);

    try {
      final secureUrl = await MediaService.uploadToCloudinary(
        fileBytes: _selectedFileBytes!,
        fileName: _selectedFileName!,
        folder: 'consultations',
      );

      if (secureUrl != null) {
        setState(() {
          _documents.add({
            'title': title,
            'file_name': _selectedFileName!,
            'file_url': secureUrl,
            'file_size': _selectedFileSizeStr ?? '',
            'date': DateFormat('dd/MM/yyyy').format(DateTime.now()),
          });
          _docTitleController.clear();
          _selectedFileName = null;
          _selectedFileBytes = null;
          _selectedFileSizeStr = null;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('File uploaded and added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  final PatientController _patientController = PatientController();
  final AppointmentController _appointmentController = AppointmentController();
  final IpdController _ipdController = IpdController();
  final AdminController _adminController = AdminController();

  List<UserModel> _rawDoctors = [];
  List<String> _doctorsList = [];
  List<String> _departmentsList = [];
  bool _isLoadingReferralData = false;

  late AppointmentModel _currentAppointment;
  bool _isLoadingVitals = true;
  bool _isLoadingHistory = true;
  bool _isSaving = false;
  int _currentStep = 0;
  List<Map<String, dynamic>> _previousConsultations = [];

  @override
  void initState() {
    super.initState();
    UnsavedChangesHelper.setUnsavedChanges(true);
    _currentAppointment = widget.appointment;
    _fetchLatestVitals();
    _fetchPreviousConsultations();
    _initializeData();
    _loadMedicineCatalog();
    _loadReferralDropdowns();
  }

  @override
  void dispose() {
    UnsavedChangesHelper.setUnsavedChanges(false);
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    _customLabController.dispose();
    _historyController.dispose();
    _examinationController.dispose();
    _familyHistoryController.dispose();
    _socialHistoryController.dispose();
    _commentController.dispose();
    _procedureController.dispose();
    _allergyController.dispose();
    _leadingQuestionsController.dispose();
    _planController.dispose();
    _referredDoctorController.dispose();
    _referredDeptController.dispose();
    _referralNotesController.dispose();
    _docTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicineCatalog() async {
    try {
      final baseUrl = ApiEndpoints.baseUrl;
      final response = await ApiService.get(
        '$baseUrl/inventory/medicine-catalog',
      );
      final body = ApiService.decodeJsonResponse(response);
      if (body['success'] == true && mounted) {
        final data = body['data'] as List<dynamic>;
        setState(() {
          _medicineCatalog = data
              .map((item) => item['name'].toString())
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading medicine catalog: $e');
    }
  }

  Future<void> _loadReferralDropdowns() async {
    setState(() {
      _isLoadingReferralData = true;
    });
    try {
      final doctors = await _adminController.fetchStaff(role: 'Doctor');
      final specs = await _adminController.fetchSpecializations();
      if (mounted) {
        setState(() {
          _rawDoctors = doctors
              .where((d) => d.status.toLowerCase() == 'active' && !d.isDeleted)
              .toList();
          _doctorsList = _rawDoctors
              .map((d) => d.fullname)
              .toList();
          _departmentsList = specs.map((s) => s['name'].toString()).toList();

          // Format existing doctor referral value if it exists and is plain text
          if (_referredDoctorController.text.isNotEmpty) {
            final docName = _referredDoctorController.text;
            final matched = _rawDoctors.where((d) => d.fullname == docName).toList();
            if (matched.isNotEmpty) {
              final d = matched.first;
              _referredDoctorController.text = d.fullname;
            }
          }

          _isLoadingReferralData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading referral dropdown data: $e');
      if (mounted) {
        setState(() {
          _isLoadingReferralData = false;
        });
      }
    }
  }

  void _initializeData() {
    if (widget.initialConsultation != null) {
      _symptomsController.text = widget.initialConsultation!['symptoms'] ?? '';
      _diagnosisController.text =
          widget.initialConsultation!['diagnosis'] ?? '';
      _notesController.text = widget.initialConsultation!['notes'] ?? '';

      _historyController.text = widget.initialConsultation!['history'] ?? '';
      _examinationController.text =
          widget.initialConsultation!['examination'] ?? '';
      _familyHistoryController.text =
          widget.initialConsultation!['family_history'] ?? '';
      _socialHistoryController.text =
          widget.initialConsultation!['social'] ?? '';
      _commentController.text = widget.initialConsultation!['comment'] ?? '';
      _procedureController.text =
          widget.initialConsultation!['procedure'] ?? '';
      _allergyController.text = widget.initialConsultation!['allergy'] ?? '';
      _leadingQuestionsController.text =
          widget.initialConsultation!['leading_questions'] ?? '';
      _planController.text = widget.initialConsultation!['plan'] ?? '';

      final ref = widget.initialConsultation!['referral'];
      if (ref is Map) {
        _referredDoctorController.text =
            ref['referred_doctor']?.toString() ?? '';
        _referredDeptController.text =
            ref['referred_department']?.toString() ?? '';
        _referralNotesController.text = ref['referral_notes']?.toString() ?? '';
      } else if (ref is String && ref.isNotEmpty) {
        try {
          final decoded = jsonDecode(ref);
          if (decoded is Map) {
            _referredDoctorController.text =
                decoded['referred_doctor']?.toString() ?? '';
            _referredDeptController.text =
                decoded['referred_department']?.toString() ?? '';
            _referralNotesController.text =
                decoded['referral_notes']?.toString() ?? '';
          }
        } catch (_) {}
      }

      final docs = widget.initialConsultation!['documents'];
      if (docs is List) {
        for (var d in docs) {
          if (d is Map) {
            _documents.add({
              'title': d['title']?.toString() ?? '',
              'file_name': d['file_name']?.toString() ?? '',
              'date': d['date']?.toString() ?? '',
            });
          }
        }
      } else if (docs is String && docs.isNotEmpty) {
        try {
          final decoded = jsonDecode(docs);
          if (decoded is List) {
            for (var d in decoded) {
              if (d is Map) {
                _documents.add({
                  'title': d['title']?.toString() ?? '',
                  'file_name': d['file_name']?.toString() ?? '',
                  'date': d['date']?.toString() ?? '',
                });
              }
            }
          }
        } catch (_) {}
      }

      final meds = widget.initialConsultation!['medications'];
      if (meds is List) {
        for (var m in meds) {
          if (m is Map) {
            _medications.add({
              'name': m['name']?.toString() ?? '',
              'dosage': m['dosage']?.toString() ?? '',
              'frequency': m['frequency']?.toString() ?? '',
              'duration': m['duration']?.toString() ?? '',
            });
          }
        }
      }

      final labs = widget.initialConsultation!['lab_tests'];
      if (labs is List) {
        for (var l in labs) {
          final str = l.toString();
          if (_standardLabs.containsKey(str)) {
            _standardLabs[str] = true;
          } else {
            _customLabs.add(str);
          }
        }
      } else if (labs is String) {
        try {
          final decoded = jsonDecode(labs);
          if (decoded is List) {
            for (var l in decoded) {
              final str = l.toString();
              if (_standardLabs.containsKey(str)) {
                _standardLabs[str] = true;
              } else {
                _customLabs.add(str);
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  // ─── Full Admit to IPD card — shown in consultation left panel ──────────
  Widget _buildAdmitToIPDCard() {
    // Don't show for completed/cancelled/discharged appointments
    final status = _currentAppointment.status;
    if (status == 'Completed' ||
        status == 'Cancelled' ||
        status == 'Discharged') {
      return const SizedBox.shrink();
    }

    // If already admitted and no bed assigned yet → show orange allocation banner
    if (status == 'Admitted') {
      return _buildPendingAllocationBanner();
    }

    // Otherwise → show the Admit to IPD action card
    return _buildRecommendAdmitCard();
  }

  Widget _buildPendingAllocationBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_hospital, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'IPD Admission Pending',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_currentAppointment.patientName} has been recommended for IPD by Dr. ${_currentAppointment.doctorName}. Awaiting bed allocation.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendAdmitCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D5F96).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admit to IPD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      'Choose admission method',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Action buttons
            _buildIPDActionButton(
              icon: Icons.send_outlined,
              color: AppTheme.primaryColor,
              label: 'Request IPD Admission',
              subtitle: 'Front Desk will verify details and allocate a bed',
              onTap: _showAdmitDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIPDActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Admit Dialog ─────────────────────────────────────────────────────────
  void _showAdmitDialog() {
    bool isSubmitting = false;
    final TextEditingController reasonController = TextEditingController(
      text: _currentAppointment.reasonForVisit ?? '',
    );
    final TextEditingController diagnosisController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_hospital_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request IPD Admission',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _currentAppointment.patientName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Admission request will be sent to the Front Desk for verification and processing.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Reason ──
                        const Text.rich(
                          TextSpan(
                            text: 'Reason for Admission',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: reasonController,
                          maxLines: 3,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText:
                                'Enter medical reason for IPD admission...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter reason for admission'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Diagnosis ──
                        const Text(
                          'Diagnosis / Provisional Diagnosis',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: diagnosisController,
                          maxLines: 2,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Acute Appendicitis, Type 2 Diabetes...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: AppTheme.cancelButton,
                  child: const Text('Cancel'),
                ),
                StatefulBuilder(
                  builder: (ctx2, setBtn) => ElevatedButton.icon(
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                    label: Text(
                      isSubmitting ? 'Submitting...' : 'Send Request',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.dangerColor,
                      minimumSize: const Size(130, 48),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setBtn(() => isSubmitting = true);
                            // Capture context-dependent objects before async gap
                            final nav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await _ipdController.createPendingAdmission({
                                'patient_id': _currentAppointment.patientId,
                                'appointment_id': _currentAppointment.id,
                                'doctor_name': _currentAppointment.doctorName,
                                'reason_for_admission': reasonController.text
                                    .trim(),
                                'diagnosis': diagnosisController.text.trim(),
                              });
                              nav.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Admission request sent to Front Desk',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _currentAppointment = _currentAppointment
                                      .copyWith(status: 'Admission Requested');
                                });
                              }
                            } catch (e) {
                              setBtn(() => isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchLatestVitals() async {
    try {
      final vitals = await _patientController.fetchLatestVitals(
        widget.appointment.patientId,
        appointmentId: widget.appointment.id,
      );
      if (vitals != null && mounted) {
        setState(() {
          _currentAppointment = _currentAppointment.copyWith(
            bloodPressureSystolic: vitals['blood_pressure_systolic'],
            bloodPressureDiastolic: vitals['blood_pressure_diastolic'],
            sugarLevel: double.tryParse(
              vitals['sugar_level']?.toString() ?? '',
            ),
            temperature: double.tryParse(
              vitals['temperature']?.toString() ?? '',
            ),
            reasonForVisit: vitals['reason_for_visit'],
          );
          _isLoadingVitals = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingVitals = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVitals = false);
    }
  }

  Future<void> _fetchPreviousConsultations() async {
    try {
      final history = await _appointmentController.fetchConsultationsByPatient(
        widget.appointment.patientId,
      );
      if (mounted) {
        setState(() {
          // exclude current consultation if editing
          _previousConsultations = history
              .where((c) => c['appointment_id'] != widget.appointment.id)
              .toList();
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _addMedication() {
    if (_medNameController.text.trim().isNotEmpty) {
      setState(() {
        _medications.add({
          'name': _medNameController.text.trim(),
          'dosage': _dosageController.text.trim(),
          'frequency': _freqController.text.isEmpty
              ? '1-0-1'
              : _freqController.text,
          'duration': _durController.text.trim(),
        });
        _medNameController.clear();
        _dosageController.clear();
        _freqController.text = '1-0-1';
        _durController.clear();
      });
    }
  }

  Future<bool> _onWillPop() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Consultation?'),
        content: const Text('Are you sure you want to exit? The consultation is not completed yet. You can resume it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  List<String> getFinalOrderedLabs() {
    final List<String> result = [];
    _standardLabs.forEach((key, val) {
      if (val) result.add(key);
    });
    result.addAll(_customLabs);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    Widget buildHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button above title
          InkWell(
            onTap: () async {
              if (await _onWillPop()) {
                widget.onBack();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back,
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Back to Queue',
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
          const SizedBox(height: 12),
          // Header Title
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.initialConsultation != null
                        ? 'Edit Consultation: ${_currentAppointment.patientName}'
                        : 'Consultation: ${_currentAppointment.patientName}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Appt Date: ${_currentAppointment.appointmentDate} • Status: ${_currentAppointment.status}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    if (isMobile) {
      return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHeader(),
                const SizedBox(height: 24),
                _buildAdmitToIPDCard(),
                _buildPatientInfoSummary(),
                const SizedBox(height: 16),
                _buildClinicalHistoryCard(),
                const SizedBox(height: 24),
                _buildConsultationForm(),
              ],
            ),
          ),
        ),
      ),
    );
    }

    // Desktop split layout
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildHeader(),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobileView = constraints.maxWidth < 800;
                    if (isMobileView) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            _buildAdmitToIPDCard(),
                            const SizedBox(height: 16),
                            _buildPatientInfoSummary(),
                            const SizedBox(height: 16),
                            _buildClinicalHistoryCard(),
                            const SizedBox(height: 24),
                            _buildConsultationForm(),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Admit to IPD + Vitals + History
                        SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildAdmitToIPDCard(),
                                _buildPatientInfoSummary(),
                                const SizedBox(height: 16),
                                _buildClinicalHistoryCard(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column: Active Consult Form (Scrollable)
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildConsultationForm(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPatientInfoSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Nurse Vitals Intake',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingVitals)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _buildVitalRow(
              'Blood Pressure',
              '${_currentAppointment.bloodPressureSystolic ?? '--'}/${_currentAppointment.bloodPressureDiastolic ?? '--'} mmHg',
              Icons.speed,
              Colors.blue.shade700,
            ),
            const SizedBox(height: 12),
            _buildVitalRow(
              'Sugar Level',
              '${_currentAppointment.sugarLevel ?? '--'} mg/dL',
              Icons.bloodtype_outlined,
              Colors.red.shade700,
            ),
            const SizedBox(height: 12),
            _buildVitalRow(
              'Temperature',
              '${_currentAppointment.temperature ?? '--'} °F',
              Icons.thermostat_outlined,
              Colors.orange.shade700,
            ),
          ],
          const Divider(height: 24),
          const Text(
            'Chief Complaint',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            _currentAppointment.reasonForVisit ?? 'No complaints registered',
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildClinicalHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Clinical History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_previousConsultations.isEmpty)
            const Text(
              'No previous consultations found.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _previousConsultations.length,
              itemBuilder: (c, idx) {
                final hist = _previousConsultations[idx];
                final dateStr = hist['created_at'] != null
                    ? DateFormat(
                        'dd/MM/yyyy',
                      ).format(DateTime.parse(hist['created_at']))
                    : 'Past Visit';
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    subtitle: Text(
                      hist['diagnosis']?.toString() ?? 'No diagnosis recorded',
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    childrenPadding: const EdgeInsets.all(10),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hist['doctor_name'] != null &&
                          hist['doctor_name'].toString().isNotEmpty) ...[
                        const Text(
                          'Doctor:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          hist['doctor_name'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hist['symptoms'] != null &&
                          hist['symptoms'].toString().isNotEmpty) ...[
                        const Text(
                          'Symptoms:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          hist['symptoms'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hist['leading_questions'] != null &&
                          hist['leading_questions'].toString().isNotEmpty) ...[
                        const Text(
                          'Leading Questions:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          hist['leading_questions'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hist['diagnosis'] != null &&
                          hist['diagnosis'].toString().isNotEmpty) ...[
                        const Text(
                          'Diagnosis:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          hist['diagnosis'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hist['plan'] != null &&
                          hist['plan'].toString().isNotEmpty) ...[
                        const Text(
                          'Plan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          hist['plan'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hist['notes'] != null &&
                          hist['notes'].toString().isNotEmpty) ...[
                        const Text(
                          'Recommendations:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          hist['notes'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _saveConsultation() async {
    if (_symptomsController.text.trim().isEmpty) {
      setState(() => _currentStep = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Subjective Symptoms in the Complaint tab.'),
          backgroundColor: Colors.orange,
        ),
      );
      _formKey.currentState!.validate();
      return;
    }

    if (_diagnosisController.text.trim().isEmpty) {
      setState(() => _currentStep = 4);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Diagnosis in the Diagnosis tab.'),
          backgroundColor: Colors.orange,
        ),
      );
      _formKey.currentState!.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final finalLabs = getFinalOrderedLabs();
      String finalNotes = _notesController.text.trim();
      if (_followUpDate != null) {
        finalNotes +=
            '\n[FOLLOW-UP] Scheduled Date: ${DateFormat('dd/MM/yyyy').format(_followUpDate!)} (System reminder queued)';
      }
      final data = {
        'appointment_id': widget.appointment.id,
        'patient_id': widget.appointment.patientId,
        'symptoms': _symptomsController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'medications': _medications,
        'lab_tests': finalLabs,
        'pharmacy_status': _medications.isNotEmpty ? 'Notified' : 'Pending',
        'notes': finalNotes,
        'history': _historyController.text.trim(),
        'examination': _examinationController.text.trim(),
        'family_history': _familyHistoryController.text.trim(),
        'social': _socialHistoryController.text.trim(),
        'comment': _commentController.text.trim(),
        'procedure': _procedureController.text.trim(),
        'allergy': _allergyController.text.trim(),
        'leading_questions': _leadingQuestionsController.text.trim(),
        'plan': _planController.text.trim(),
        'referral': {
          'referred_doctor': _referredDoctorController.text.trim(),
          'referred_department': _referredDeptController.text.trim(),
          'referral_notes': _referralNotesController.text.trim(),
        },
        'documents': _documents,
      };

      if (widget.initialConsultation != null) {
        final int consulId = widget.initialConsultation!['id'];
        await _appointmentController.updateConsultation(consulId, data);
      } else {
        await _appointmentController.saveConsultation(data);
      }

      if (widget.appointment.id != null) {
        await _appointmentController.updateStatus(
          widget.appointment.id!,
          'Completed',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialConsultation != null
                  ? 'Consultation Updated Successfully!'
                  : 'Consultation Completed & Saved!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const Divider(height: 24),
          content,
        ],
      ),
    );
  }


  bool _validateCurrentTab() {
    if (_currentStep == 0 && _symptomsController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter Subjective Symptoms before proceeding to the next step.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (_currentStep == 4 && _diagnosisController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter Diagnosis before proceeding to the next step.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return false;
    }

    return true;
  }

  Widget _buildMocDocTabBar() {
    final tabs = [
      {'title': 'Complaint', 'badge': null},
      {'title': 'Examination', 'badge': null},
      {
        'title': 'Investigation',
        'badge': getFinalOrderedLabs().isNotEmpty
            ? getFinalOrderedLabs().length.toString()
            : null,
      },
      {
        'title': 'Docket',
        'badge': _documents.isNotEmpty ? _documents.length.toString() : null,
      },
      {'title': 'Diagnosis', 'badge': null},
      {'title': 'Treatment', 'badge': null},
      {
        'title': 'Prescription',
        'badge': _medications.isNotEmpty
            ? _medications.length.toString()
            : null,
      },
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(tabs.length, (index) {
            final isSelected = _currentStep == index;
            final tab = tabs[index];
            final title = tab['title'] as String;
            final String? badge = tab['badge'];

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (index > _currentStep && !_validateCurrentTab()) {
                    return;
                  }
                  setState(() {
                    _currentStep = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 2, top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  decoration: isSelected
                      ? const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(6.0),
                          ),
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                          ),
                        )
                      : const BoxDecoration(
                          color: Colors.transparent,
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFC26100),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildComplaintTab() {
    return Column(
      key: const ValueKey('complaint_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          '1. Chief Complaint & Symptoms',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextArea(
                'Subjective Symptoms',
                _symptomsController,
                'Describe clinical history, symptoms reported by patient...',
                required: true,
              ),
              const SizedBox(height: 16),
              _buildTextArea(
                'Leading questions related to symptoms',
                _leadingQuestionsController,
                'Enter leading questions related to symptoms...',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          '2. Clinical History',
          _buildTextArea(
            'Clinical History',
            _historyController,
            'Enter clinical history, past medical history, surgery history...',
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          '3. Family & Social History',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextArea(
                'Family History',
                _familyHistoryController,
                'Enter family medical history, chronic diseases in relatives...',
              ),
              const SizedBox(height: 16),
              _buildTextArea(
                'Social History',
                _socialHistoryController,
                'Enter social background, lifestyle, habits, occupation status...',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          '4. Known Allergies',
          _buildTextArea(
            'Patient Allergies',
            _allergyController,
            'Describe drug allergies, food allergies, environmental/latex allergies...',
          ),
        ),
      ],
    );
  }

  Widget _buildExaminationTab() {
    return Column(
      key: const ValueKey('examination_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'Physical Examination & Vitals Summary',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recorded Nurse Vitals Intake',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    _buildVitalRow(
                      'Blood Pressure',
                      '${_currentAppointment.bloodPressureSystolic ?? '--'}/${_currentAppointment.bloodPressureDiastolic ?? '--'} mmHg',
                      Icons.speed,
                      Colors.blue.shade700,
                    ),
                    const SizedBox(height: 8),
                    _buildVitalRow(
                      'Sugar Level',
                      '${_currentAppointment.sugarLevel ?? '--'} mg/dL',
                      Icons.bloodtype_outlined,
                      Colors.red.shade700,
                    ),
                    const SizedBox(height: 8),
                    _buildVitalRow(
                      'Temperature',
                      '${_currentAppointment.temperature ?? '--'} °F',
                      Icons.thermostat_outlined,
                      Colors.orange.shade700,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildTextArea(
                'Physical / Systemic Examination',
                _examinationController,
                'Describe physical examination findings, general condition, organ systems...',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvestigationTab() {
    return Column(
      key: const ValueKey('investigation_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'Investigation & Lab Orders',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lab Orders',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Text(
                'Lab receives order directly upon submission',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0D9488),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildLabOrdersSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocketTab() {
    return Column(
      key: const ValueKey('docket_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          '1. Diagnostic Documents & Attachments',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cloudinary Document Attachments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Text(
                'Select and upload actual patient diagnostic files, scan reports or external letters to Cloudinary.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.borderColor.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildSmallField(
                            'Document Title',
                            _docTitleController,
                            'e.g. Chest X-Ray Report',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select File',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: _isUploadingFile ? null : _pickFile,
                                icon: Icon(
                                  _selectedFileName != null
                                      ? Icons.check_circle_outline
                                      : Icons.file_present_outlined,
                                  size: 16,
                                  color: _selectedFileName != null
                                      ? Colors.green
                                      : AppTheme.primaryColor,
                                ),
                                label: Text(
                                  _selectedFileName != null
                                      ? _selectedFileName!
                                      : 'Choose File (PDF/Image)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _selectedFileName != null
                                        ? Colors.green.shade800
                                        : AppTheme.textPrimaryColor,
                                    fontWeight: _selectedFileName != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _selectedFileName != null
                                        ? Colors.green.shade300
                                        : AppTheme.borderColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              if (_selectedFileName != null && _selectedFileSizeStr != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Selected file size: $_selectedFileSizeStr',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: _isUploadingFile
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Uploading to Cloudinary...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                              ],
                            )
                          : ElevatedButton.icon(
                              onPressed: _uploadAndAddDocument,
                              icon: const Icon(
                                Icons.cloud_upload_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Upload & Add Document',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_documents.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No documents reference attached yet.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _documents.length,
                  itemBuilder: (context, idx) {
                    final doc = _documents[idx];
                    final fileUrl = doc['file_url'];
                    final hasUrl = fileUrl != null && fileUrl.isNotEmpty;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            color: hasUrl ? AppTheme.primaryColor : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc['title']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${doc['file_name']}${doc['file_size'] != null && doc['file_size']!.isNotEmpty ? ' (${doc['file_size']})' : ''} • Attached on: ${doc['date']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasUrl)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_red_eye_outlined,
                                color: Colors.blue,
                                size: 18,
                              ),
                              tooltip: 'View Document',
                              onPressed: () {
                                showDocumentViewer(context, fileUrl, doc['title'] ?? 'Document');
                              },
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _documents.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          '2. Doctor & Department Referral',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Doctor / Department Referral',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              CustomDropdownSearch(
                label: 'Referred Doctor Name',
                hint: 'e.g. Dr. Gayathri',
                value: _referredDoctorController.text.isEmpty
                    ? null
                    : _referredDoctorController.text,
                dropdownItems: _doctorsList,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _referredDoctorController.text = val;
                      final matchedDocs = _rawDoctors
                          .where((d) => d.fullname == val)
                          .toList();
                      if (matchedDocs.isNotEmpty) {
                        final spec = matchedDocs.first.specialization;
                        if (spec != null && spec.isNotEmpty) {
                          _referredDeptController.text = spec;
                        }
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              CustomDropdownSearch(
                label: 'Referred Department',
                hint: 'e.g. Cardiology, Paediatrics',
                value: _referredDeptController.text.isEmpty
                    ? null
                    : _referredDeptController.text,
                dropdownItems: _departmentsList,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _referredDeptController.text = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildTextArea(
                'Referral Reason & Clinical Notes',
                _referralNotesController,
                'Provide details for the receiving doctor...',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          '3. General Docket Remarks',
          _buildTextArea(
            'Comments / General Remarks',
            _commentController,
            'Enter general remarks, advice notes...',
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosisTab() {
    return Column(
      key: const ValueKey('diagnosis_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          '1. Diagnosis & Impression',
          _buildTextArea(
            'Diagnosis / Impression',
            _diagnosisController,
            'Enter the diagnostic decision or impression...',
            required: true,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          '2. Procedure Details',
          _buildTextArea(
            'Procedure Details',
            _procedureController,
            'Describe procedures performed or scheduled (e.g. sutures, dressings)...',
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentTab() {
    return Column(
      key: const ValueKey('treatment_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          '1. Treatment Plan',
          _buildTextArea(
            'Plan',
            _planController,
            'Enter plan details (e.g. diagnostic, therapeutic, educational plan)...',
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          '2. Recommendations & Follow-Up',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextArea(
                'Additional Follow-Up Advice / Instructions',
                _notesController,
                'Specific follow-up instruction notes...',
              ),
              const SizedBox(height: 20),
              const Text(
                'Schedule Follow-Up Date',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        _followUpDate ??
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _followUpDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _followUpDate == null
                            ? 'Select Date (Optional)'
                            : DateFormat('dd/MM/yyyy').format(_followUpDate!),
                        style: TextStyle(
                          color: _followUpDate == null
                              ? AppTheme.textSecondaryColor
                              : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (_followUpDate != null)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 16,
                            color: Colors.red,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() => _followUpDate = null);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionTab() {
    return Column(
      key: const ValueKey('prescription_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'Prescribed Medications',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prescription Flow',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Text(
                'Automatically sent to Pharmacy upon submission',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0D9488),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildMedicationInput(),
              const SizedBox(height: 16),
              _buildMedicationList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabFooterNavigation() {
    final tabTitles = [
      'Complaint',
      'Examination',
      'Investigation',
      'Docket',
      'Diagnosis',
      'Treatment',
      'Prescription',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text('Previous: ${tabTitles[_currentStep - 1]}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.borderColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          Row(
            children: [
              OutlinedButton(
                onPressed: () async {
                  if (await _onWillPop()) {
                    widget.onBack();
                  }
                },
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              if (_currentStep < 6) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    if (_validateCurrentTab()) {
                      setState(() => _currentStep++);
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Next: ${tabTitles[_currentStep + 1]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConsultation,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                label: Text(
                  widget.initialConsultation != null
                      ? 'Update & Save'
                      : 'Complete & Submit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.logoRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  minimumSize: const Size(140, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationForm() {
    Widget activeTabContent;
    switch (_currentStep) {
      case 0:
        activeTabContent = _buildComplaintTab();
        break;
      case 1:
        activeTabContent = _buildExaminationTab();
        break;
      case 2:
        activeTabContent = _buildInvestigationTab();
        break;
      case 3:
        activeTabContent = _buildDocketTab();
        break;
      case 4:
        activeTabContent = _buildDiagnosisTab();
        break;
      case 5:
        activeTabContent = _buildTreatmentTab();
        break;
      case 6:
        activeTabContent = _buildPrescriptionTab();
        break;
      default:
        activeTabContent = _buildComplaintTab();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMocDocTabBar(),
        const SizedBox(height: 16),
        activeTabContent,
        const SizedBox(height: 24),
        _buildTabFooterNavigation(),
      ],
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController controller,
    String hint, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: 3,
          maxLength: 100,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty)
                    ? 'This field is required'
                    : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            fillColor: AppTheme.backgroundColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomDropdownSearch(
                  label: 'Medication Name',
                  value: _medNameController.text.isEmpty
                      ? null
                      : _medNameController.text,
                  dropdownItems: _medicineCatalog,
                  height: 38,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _medNameController.text = val;
                        // Auto-extract and populate dosage if found in the catalog name
                        final match = RegExp(
                          r'\d+\s*(?:mg/ml|IU/ml|mg|mcg|g|ml|IU)',
                          caseSensitive: false,
                        ).firstMatch(val);
                        if (match != null) {
                          _dosageController.text = match.group(0) ?? '';
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallField(
                  'Dosage',
                  _dosageController,
                  'e.g. 500mg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomDropdownSearch(
                  label: 'Frequency',
                  value: _freqController.text.isEmpty
                      ? '1-0-1'
                      : _freqController.text,
                  dropdownItems: const [
                    '1-0-1',
                    '1-0-0',
                    '0-0-1',
                    '1-1-1',
                    'Once daily',
                    'Twice daily',
                    'Thrice daily',
                    'As needed (PRN)',
                  ],
                  height: 38,
                  onChanged: (v) {
                    if (v != null) setState(() => _freqController.text = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallField(
                  'Duration',
                  _durController,
                  'e.g. 5 days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text(
                'Add Drug',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationList() {
    if (_medications.isEmpty) return const SizedBox.shrink();
    return Column(
      children: _medications.asMap().entries.map((entry) {
        int idx = entry.key;
        Map<String, String> med = entry.value;
        final durStr = med['duration'] != null && med['duration']!.isNotEmpty
            ? ' for ${med['duration']}'
            : '';
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.medication,
                color: AppTheme.primaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${med['name']} - ${med['dosage']} (${med['frequency']})$durStr',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 18,
                ),
                onPressed: () => setState(() => _medications.removeAt(idx)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Standard Investigations:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: _standardLabs.keys.map((test) {
                  return SizedBox(
                    width: 220,
                    child: CheckboxListTile(
                      title: Text(test, style: const TextStyle(fontSize: 12)),
                      value: _standardLabs[test],
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _standardLabs[test] = v);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildSmallField(
                      'Other Custom Lab Test',
                      _customLabController,
                      'e.g. Liver Function Test (LFT)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_customLabController.text.trim().isEmpty) return;
                      setState(() {
                        _customLabs.add(_customLabController.text.trim());
                        _customLabController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      backgroundColor: AppTheme.secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Add Test',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_customLabs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _customLabs.map((l) {
                    return Chip(
                      label: Text(l, style: const TextStyle(fontSize: 10)),
                      deleteIcon: const Icon(Icons.close, size: 10),
                      onDeleted: () {
                        setState(() => _customLabs.remove(l));
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
