import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/app_localizations.dart';
import '../utils/modal_history_helper.dart';
import '../utils/date_formatter.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../controllers/patient_controller.dart';
import '../controllers/appointment_controller.dart';
import '../controllers/ipd_controller.dart';
import '../controllers/admin_controller.dart';
import '../widgets/custom_dropdown_search.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'package:file_picker/file_picker.dart';
import '../services/media_service.dart';
import '../widgets/document_view_dialog.dart';
import '../widgets/consultation_documents_view.dart';
import '../utils/unsaved_changes_helper.dart';
import 'dart:io' as io;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/live_speech_service.dart';

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

  // Voice to Text State
  TextEditingController? _activeListeningController;
  bool _isSpeechPaused = false;
  String _speechBaseText = '';

  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<Map<String, String>> _medications = [];
  DateTime? _followUpDate;

  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  String? _dosageError;
  String? _durationError;
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
  String? _customLabError;

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
        final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
        const allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

        if (!allowedExtensions.contains(ext)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Invalid file format. Only PDF, JPG, JPEG, and PNG files are supported.',
                ),
                backgroundColor: AppTheme.dangerColor,
              ),
            );
          }
          return;
        }

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
                  backgroundColor: AppTheme.dangerColor,
                ),
              );
            }
            return;
          }

          setState(() {
            _selectedFileName = file.name;
            _selectedFileBytes = fileBytes;
            _selectedFileSizeStr = _formatFileSize(bytesCount);
            if (_docTitleController.text.trim().isEmpty) {
              final nameWithoutExt = file.name.contains('.')
                  ? file.name.substring(0, file.name.lastIndexOf('.'))
                  : file.name;
              _docTitleController.text = nameWithoutExt;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _uploadAndAddDocument() async {
    final title = _docTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a document title.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file to upload.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    final ext = (_selectedFileName!.split('.').last).toLowerCase();
    const allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
    if (!allowedExtensions.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid file format. Only PDF, JPG, JPEG, and PNG files are supported.',
          ),
          backgroundColor: AppTheme.dangerColor,
        ),
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
  bool _isLoadingReferralData = false;

  late AppointmentModel _currentAppointment;
  bool _isLoadingVitals = true;
  bool _isLoadingHistory = true;
  bool _isSaving = false;
  int _currentStep = 0;
  List<Map<String, dynamic>> _previousConsultations = [];
  int? _existingConsultationId;

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = {
        'symptoms': _symptomsController.text,
        'leading_questions': _leadingQuestionsController.text,
        'history': _historyController.text,
        'diagnosis': _diagnosisController.text,
        'notes': _notesController.text,
        'examination': _examinationController.text,
        'family_history': _familyHistoryController.text,
        'social': _socialHistoryController.text,
        'comment': _commentController.text,
        'procedure': _procedureController.text,
        'allergy': _allergyController.text,
        'plan': _planController.text,
        'medications': _medications,
        'lab_tests': getFinalOrderedLabs(),
        'documents': _documents,
        'referral': {
          'referred_doctor': _referredDoctorController.text,
          'referred_department': _referredDeptController.text,
          'referral_notes': _referralNotesController.text,
        },
      };
      await prefs.setString(
        'consultation_draft_${widget.appointment.id}',
        jsonEncode(draftData),
      );
    } catch (e) {
      debugPrint('Error saving consultation draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('consultation_draft_${widget.appointment.id}');
    } catch (e) {
      debugPrint('Error clearing consultation draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    if (widget.initialConsultation != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('consultation_draft_${widget.appointment.id}');
      if (draftStr != null && draftStr.isNotEmpty) {
        final draft = jsonDecode(draftStr);
        if (draft is Map<String, dynamic>) {
          setState(() {
            _symptomsController.text = draft['symptoms'] ?? '';
            _leadingQuestionsController.text = draft['leading_questions'] ?? '';
            _historyController.text = draft['history'] ?? '';
            _diagnosisController.text = draft['diagnosis'] ?? '';
            _notesController.text = draft['notes'] ?? '';
            _examinationController.text = draft['examination'] ?? '';
            _familyHistoryController.text = draft['family_history'] ?? '';
            _socialHistoryController.text = draft['social'] ?? '';
            _commentController.text = draft['comment'] ?? '';
            _procedureController.text = draft['procedure'] ?? '';
            _allergyController.text = draft['allergy'] ?? '';
            _planController.text = draft['plan'] ?? '';

            final meds = draft['medications'];
            if (meds is List) {
              _medications.clear();
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

            final labs = draft['lab_tests'];
            if (labs is List) {
              for (var l in labs) {
                final str = l.toString().trim();
                if (str.isEmpty) continue;
                if (_standardLabs.containsKey(str)) {
                  _standardLabs[str] = true;
                } else if (!_customLabs.any((c) => c.trim().toLowerCase() == str.toLowerCase())) {
                  _customLabs.add(str);
                }
              }
            }

            final docs = draft['documents'];
            if (docs is List) {
              _documents.clear();
              for (var d in docs) {
                if (d is Map) {
                  _documents.add({
                    'title': d['title']?.toString() ?? '',
                    'file_name': d['file_name']?.toString() ?? '',
                    'file_url': d['file_url']?.toString() ?? '',
                    'file_size': d['file_size']?.toString() ?? '',
                    'date': d['date']?.toString() ?? '',
                  });
                }
              }
            }

            final ref = draft['referral'];
            if (ref is Map) {
              _referredDoctorController.text =
                  ref['referred_doctor']?.toString() ?? '';
              _referredDeptController.text =
                  ref['referred_department']?.toString() ?? '';
              _referralNotesController.text =
                  ref['referral_notes']?.toString() ?? '';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading consultation draft: $e');
    }
  }

  bool _isFutureAppointmentDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return false;
    final dt = DateFormatter.toDateTime(dateStr);
    if (dt != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final apptDateOnly = DateTime(dt.year, dt.month, dt.day);
      return apptDateOnly.isAfter(today);
    }
    final clean = dateStr.replaceAll('/', '-').trim();
    final parts = clean.split('-');
    if (parts.length == 3) {
      int? y, m, d;
      if (parts[0].length == 4) {
        y = int.tryParse(parts[0]);
        m = int.tryParse(parts[1]);
        d = int.tryParse(parts[2].split(' ')[0]);
      } else if (parts[2].split(' ')[0].length == 4) {
        d = int.tryParse(parts[0]);
        m = int.tryParse(parts[1]);
        y = int.tryParse(parts[2].split(' ')[0]);
      }
      if (y != null && m != null && d != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final apptDateOnly = DateTime(y, m, d);
        return apptDateOnly.isAfter(today);
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (_isFutureAppointmentDate(widget.appointment.appointmentDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot start consultation before the appointment date'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
          widget.onBack();
        }
      });
      return;
    }
    UnsavedChangesHelper.setUnsavedChanges(true);
    _currentAppointment = widget.appointment;
    if (widget.initialConsultation != null && widget.initialConsultation!['id'] != null) {
      final rawId = widget.initialConsultation!['id'];
      _existingConsultationId = rawId is int ? rawId : int.tryParse(rawId.toString());
    }
    _initSpeech();
    _fetchLatestVitals();
    _fetchPreviousConsultations();
    _initializeData();
    _loadDraft();
    _loadMedicineCatalog();
    _loadReferralDropdowns();
  }

  @override
  void dispose() {
    UnsavedChangesHelper.setUnsavedChanges(false);
    _stopSpeech(disposing: true);
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

  Future<void> _initSpeech() async {
    await LiveSpeechService().initialize();
  }

  Future<void> _startSpeech(
    TextEditingController targetController,
    String fieldName,
  ) async {
    // If active on another field, stop it first
    if (_activeListeningController != null) {
      await _stopSpeech();
    }

    final initialText = targetController.text.trim();
    if (mounted) {
      setState(() {
        _activeListeningController = targetController;
        _isSpeechPaused = false;
        _speechBaseText = initialText;
      });
    }

    final success = await LiveSpeechService().startListening(
      onResult: (liveWords) {
        if (_isSpeechPaused) return;
        final words = liveWords.trim();
        if (words.isNotEmpty &&
            mounted &&
            _activeListeningController == targetController) {
          final newText =
              _speechBaseText.isEmpty ? words : '$_speechBaseText $words';
          targetController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted &&
              !_isSpeechPaused &&
              _activeListeningController == targetController) {
            setState(() {
              _activeListeningController = null;
            });
          }
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _activeListeningController = null;
            _isSpeechPaused = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice input: $err'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _activeListeningController = null;
        _isSpeechPaused = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone / Speech recognition is not available or permission was denied.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pauseSpeech() async {
    if (_activeListeningController == null) return;
    if (mounted) {
      setState(() {
        _isSpeechPaused = true;
        _speechBaseText = _activeListeningController!.text.trim();
      });
    }
    await LiveSpeechService().stopListening();
  }

  Future<void> _resumeSpeech() async {
    final controller = _activeListeningController;
    if (controller == null) return;

    final initialText = controller.text.trim();
    if (mounted) {
      setState(() {
        _isSpeechPaused = false;
        _speechBaseText = initialText;
      });
    }

    await LiveSpeechService().startListening(
      onResult: (liveWords) {
        if (_isSpeechPaused) return;
        final words = liveWords.trim();
        if (words.isNotEmpty &&
            mounted &&
            _activeListeningController == controller) {
          final newText =
              _speechBaseText.isEmpty ? words : '$_speechBaseText $words';
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted &&
              !_isSpeechPaused &&
              _activeListeningController == controller) {
            setState(() {
              _activeListeningController = null;
            });
          }
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _activeListeningController = null;
            _isSpeechPaused = false;
          });
        }
      },
    );
  }

  Future<void> _stopSpeech({bool disposing = false}) async {
    _isSpeechPaused = false;
    _speechBaseText = '';
    _activeListeningController = null;
    if (!disposing && mounted) {
      setState(() {});
    }
    await LiveSpeechService().stopListening();
  }

  Future<void> _loadMedicineCatalog() async {
    try {
      final baseUrl = ApiEndpoints.baseUrl;
      final response = await ApiService.get(
        '$baseUrl/inventory/medicine-catalog?in_stock_only=true',
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
      if (mounted) {
        UserModel? currentUser;
        try {
          currentUser = Provider.of<AuthProvider>(context, listen: false).user;
        } catch (_) {}

        final currentDocName = (currentUser?.fullname ?? widget.appointment.doctorName).trim().toLowerCase();
        final currentDocId = currentUser?.id;
        final apptDocId = widget.appointment.doctorId;
        final apptDocName = widget.appointment.doctorName.trim().toLowerCase();

        setState(() {
          // Exclude the logged-in doctor / consulting doctor from self-referral
          _rawDoctors = doctors.where((d) {
            if (d.status.toLowerCase() != 'active' || d.isDeleted) return false;
            if (currentDocId != null && d.id == currentDocId) return false;
            if (apptDocId != null && d.id == apptDocId) return false;
            if (currentDocName.isNotEmpty && d.fullname.trim().toLowerCase() == currentDocName) return false;
            if (apptDocName.isNotEmpty && d.fullname.trim().toLowerCase() == apptDocName) return false;
            return true;
          }).toList();
          _doctorsList = _getReferralDoctorDeptItems();

          // Format existing doctor referral value if it exists or clear if self-referral
          if (_referredDoctorController.text.isNotEmpty) {
            final docName = _referredDoctorController.text.trim().toLowerCase();
            if (docName == currentDocName || docName == apptDocName) {
              _referredDoctorController.clear();
              _referredDeptController.clear();
            } else {
              final matched = _rawDoctors.where((d) => d.fullname.trim().toLowerCase() == docName).toList();
              if (matched.isNotEmpty) {
                final d = matched.first;
                _referredDoctorController.text = d.fullname;
                if (_referredDeptController.text.isEmpty && d.specialization != null && d.specialization!.isNotEmpty) {
                  _referredDeptController.text = d.specialization!;
                }
              }
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

  List<String> _getReferralDoctorDeptItems() {
    return _rawDoctors.map((d) {
      if (d.specialization != null && d.specialization!.trim().isNotEmpty) {
        return '${d.fullname} - ${d.specialization!.trim()}';
      }
      return d.fullname;
    }).toList();
  }

  String? _getSelectedReferralDisplay() {
    if (_referredDoctorController.text.trim().isEmpty) return null;
    final docName = _referredDoctorController.text.trim();
    final matched = _rawDoctors.where((d) => d.fullname.trim().toLowerCase() == docName.toLowerCase()).toList();
    if (matched.isNotEmpty) {
      final d = matched.first;
      if (d.specialization != null && d.specialization!.trim().isNotEmpty) {
        return '${d.fullname} - ${d.specialization!.trim()}';
      }
      return d.fullname;
    }
    if (_referredDeptController.text.trim().isNotEmpty) {
      return '$docName - ${_referredDeptController.text.trim()}';
    }
    return docName;
  }

  Future<void> _confirmDeleteDocument(int idx) async {
    final doc = _documents[idx];
    final docTitle = doc['title'] ?? doc['file_name'] ?? 'this document';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$docTitle"? This document will be removed from the consultation.',
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _documents.removeAt(idx);
      });
      _saveDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document deleted successfully'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    }
  }

  Future<void> _confirmDeleteSelectedFile() async {
    final fileName = _selectedFileName ?? 'this file';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 24),
            SizedBox(width: 8),
            Text(
              'Delete File',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$fileName"?',
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nameWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      setState(() {
        _selectedFileName = null;
        _selectedFileBytes = null;
        _selectedFileSizeStr = null;
        if (_docTitleController.text.trim() == nameWithoutExt) {
          _docTitleController.clear();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected file removed successfully'),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
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
              'file_url': d['file_url']?.toString() ?? '',
              'file_size': d['file_size']?.toString() ?? '',
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
                  'file_url': d['file_url']?.toString() ?? '',
                  'file_size': d['file_size']?.toString() ?? '',
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
          final str = l.toString().trim();
          if (str.isEmpty) continue;
          if (_standardLabs.containsKey(str)) {
            _standardLabs[str] = true;
          } else if (!_customLabs.any((c) => c.trim().toLowerCase() == str.toLowerCase())) {
            _customLabs.add(str);
          }
        }
      } else if (labs is String) {
        try {
          final decoded = jsonDecode(labs);
          if (decoded is List) {
            for (var l in decoded) {
              final str = l.toString().trim();
              if (str.isEmpty) continue;
              if (_standardLabs.containsKey(str)) {
                _standardLabs[str] = true;
              } else if (!_customLabs.any((c) => c.trim().toLowerCase() == str.toLowerCase())) {
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
                        const Text(
                          'Reason for Admission',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: reasonController,
                          maxLines: 3,
                          maxLength: 100,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.dangerColor,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.dangerColor,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) return null; // Not required!
                            if (RegExp(r'[^a-zA-Z0-9\s.,/#\-\(\):;]').hasMatch(val)) {
                              return 'Invalid special characters. Only letters, numbers and .,/#-():; are allowed';
                            }
                            if (!RegExp(r'[a-zA-Z]').hasMatch(val)) {
                              return 'Reason must contain at least one letter';
                            }
                            return null;
                          },
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
                          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.dangerColor,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.dangerColor,
                              ),
                            ),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) return null;
                            if (RegExp(r'[^a-zA-Z0-9\s.,/#\-\(\):;]').hasMatch(val)) {
                              return 'Invalid special characters. Only letters, numbers and .,/#-():; are allowed';
                            }
                            if (!RegExp(r'[a-zA-Z]').hasMatch(val)) {
                              return 'Diagnosis must contain at least one letter';
                            }
                            return null;
                          },
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

  Future<void> _showEnterVitalsDialog() async {
    final formKey = GlobalKey<FormState>();
    final systolicCtrl = TextEditingController(
      text: _currentAppointment.bloodPressureSystolic?.toString() ?? '',
    );
    final diastolicCtrl = TextEditingController(
      text: _currentAppointment.bloodPressureDiastolic?.toString() ?? '',
    );
    final sugarCtrl = TextEditingController(
      text: _currentAppointment.sugarLevel != null
          ? (_currentAppointment.sugarLevel! % 1 == 0
              ? _currentAppointment.sugarLevel!.toInt().toString()
              : _currentAppointment.sugarLevel!.toString())
          : '',
    );
    final tempCtrl = TextEditingController(
      text: _currentAppointment.temperature != null
          ? (_currentAppointment.temperature! % 1 == 0
              ? _currentAppointment.temperature!.toInt().toString()
              : _currentAppointment.temperature!.toString())
          : '',
    );

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.monitor_heart,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Patient Vitals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter patient vitals observed during consultation',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Blood Pressure (mmHg)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: systolicCtrl,
                                keyboardType: TextInputType.number,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Systolic (e.g. 120)',
                                  hintText: '90 - 300',
                                  suffixText: 'mmHg',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.dangerColor),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.dangerColor),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                validator: (v) {
                                  final val = v?.trim() ?? '';
                                  if (val.isEmpty) {
                                    if (diastolicCtrl.text.trim().isNotEmpty) {
                                      return 'Systolic is required when Diastolic is given';
                                    }
                                    return null;
                                  }
                                  final num = int.tryParse(val);
                                  if (num == null || num < 90 || num > 300) {
                                    return 'Enter 90 - 300 mmHg';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: diastolicCtrl,
                                keyboardType: TextInputType.number,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Diastolic (e.g. 80)',
                                  hintText: '50 - 180',
                                  suffixText: 'mmHg',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.dangerColor),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.dangerColor),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                validator: (v) {
                                  final val = v?.trim() ?? '';
                                  if (val.isEmpty) {
                                    if (systolicCtrl.text.trim().isNotEmpty) {
                                      return 'Diastolic is required when Systolic is given';
                                    }
                                    return null;
                                  }
                                  final num = int.tryParse(val);
                                  if (num == null || num < 50 || num > 180) {
                                    return 'Enter 50 - 180 mmHg';
                                  }
                                  final sysVal = int.tryParse(systolicCtrl.text.trim());
                                  if (sysVal != null && num >= sysVal) {
                                    return 'Must be less than Systolic';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sugar Level (mg/dL)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: sugarCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Random / Fasting Blood Sugar',
                            hintText: '30 - 600',
                            suffixText: 'mg/dL',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.dangerColor),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.dangerColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) return null;
                            final num = double.tryParse(val);
                            if (num == null || num < 30 || num > 600) {
                              return 'Enter 30 - 600 mg/dL';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Body Temperature (°F)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: tempCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Temperature',
                            hintText: '90 - 115',
                            suffixText: '°F',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.dangerColor),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.dangerColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) {
                            final val = v?.trim() ?? '';
                            if (val.isEmpty) return null;
                            final num = double.tryParse(val);
                            if (num == null || num < 90 || num > 115) {
                              return 'Enter 90 - 115 °F';
                            }
                            return null;
                          },
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final sysText = systolicCtrl.text.trim();
                          final diaText = diastolicCtrl.text.trim();
                          final sugarText = sugarCtrl.text.trim();
                          final tempText = tempCtrl.text.trim();

                          if (sysText.isEmpty && diaText.isEmpty && sugarText.isEmpty && tempText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter at least one vital parameter to save.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);

                          final sysVal = sysText.isNotEmpty ? int.tryParse(sysText) : null;
                          final diaVal = diaText.isNotEmpty ? int.tryParse(diaText) : null;
                          final sugarVal = sugarText.isNotEmpty ? double.tryParse(sugarText) : null;
                          final tempVal = tempText.isNotEmpty ? double.tryParse(tempText) : null;

                          final vitalsData = <String, dynamic>{
                            'blood_pressure_systolic': sysVal,
                            'blood_pressure_diastolic': diaVal,
                            'sugar_level': sugarVal,
                            'temperature': tempVal,
                          };

                          try {
                            await _appointmentController.updateVitals(
                              widget.appointment.id!,
                              vitalsData,
                            );

                            if (mounted) {
                              setState(() {
                                _currentAppointment = _currentAppointment.copyWith(
                                  bloodPressureSystolic: sysVal ?? _currentAppointment.bloodPressureSystolic,
                                  bloodPressureDiastolic: diaVal ?? _currentAppointment.bloodPressureDiastolic,
                                  sugarLevel: sugarVal ?? _currentAppointment.sugarLevel,
                                  temperature: tempVal ?? _currentAppointment.temperature,
                                );
                              });
                            }

                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Patient vitals saved successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error saving vitals: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 16, color: Colors.white),
                  label: Text(
                    isSaving ? 'Saving...' : 'Save Vitals',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(120, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
          // Detect if a consultation already exists for this appointment
          if (_existingConsultationId == null) {
            final match = history.firstWhere(
              (c) => c['appointment_id'] == widget.appointment.id,
              orElse: () => {},
            );
            if (match.isNotEmpty && match['id'] != null) {
              final rawId = match['id'];
              _existingConsultationId = rawId is int ? rawId : int.tryParse(rawId.toString());
            }
          }
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

  String? _validateDosage(String? value) {
    final val = value?.trim() ?? '';
    if (val.isEmpty) {
      return 'Dosage is required';
    }
    if (val.length > 20) {
      return 'Dosage cannot exceed 20 characters';
    }
    if (RegExp(r'[^a-zA-Z0-9\s./\-]').hasMatch(val)) {
      return 'Special characters are not allowed in dosage';
    }
    if (!RegExp(r'\d').hasMatch(val)) {
      return 'Dosage must contain a numeric value (e.g. 10mg, 5ml)';
    }

    // Check if numbers appear after the unit (e.g. 10mg5464654465)
    final numbersAfterUnit = RegExp(
      r'(?:mg|mcg|g|ml|iu|tab|tablets?|caps?|capsules?|drops?|puffs?|units?)\s*\d+',
      caseSensitive: false,
    );
    if (numbersAfterUnit.hasMatch(val)) {
      return 'Invalid dosage: numbers cannot follow the unit (e.g. 10mg)';
    }

    // Strict dosage pattern: <number/range/fraction> [optional space] [valid unit]
    // e.g. 10mg, 500 mg, 0.5 ml, 1000 IU, 1-2 tabs, 1/2 tab, 5, 2.5ml
    final dosagePattern = RegExp(
      r'^\d+(?:\.\d+)?(?:\s*-\s*\d+(?:\.\d+)?)?(?:\s*\/\s*\d+)?\s*(?:mg(?:\/ml)?|mcg|g|ml|iu(?:\/ml)?|tabs?|tablets?|caps?|capsules?|drops?|puffs?|sachets?|units?|patches?)?$',
      caseSensitive: false,
    );
    if (!dosagePattern.hasMatch(val)) {
      return 'Invalid dosage format (e.g. 10mg, 500mg, 5ml)';
    }
    return null;
  }

  String? _validateDuration(String? value) {
    final val = value?.trim() ?? '';
    if (val.isEmpty) {
      return 'Duration is required (e.g. 5 days)';
    }
    if (val.length > 20) {
      return 'Duration cannot exceed 20 characters';
    }
    if (RegExp(r'[^a-zA-Z0-9\s\-]').hasMatch(val)) {
      return 'Special characters are not allowed in duration';
    }
    if (!RegExp(r'\d').hasMatch(val)) {
      return 'Duration must contain a number (e.g. 5 days)';
    }

    // Check if numbers appear after the duration unit (e.g. 5days123)
    final numbersAfterUnit = RegExp(
      r'(?:days?|weeks?|months?|d|w|m|hours?|hrs?)\s*\d+',
      caseSensitive: false,
    );
    if (numbersAfterUnit.hasMatch(val)) {
      return 'Invalid duration: numbers cannot follow the unit (e.g. 5 days)';
    }

    // Strict duration pattern: <number/range> [optional space] [valid unit]
    // e.g. 5 days, 5days, 1 week, 2 weeks, 1 month, 3-5 days, 5 d, 5
    final durationPattern = RegExp(
      r'^\d+(?:\s*-\s*\d+)?\s*(?:days?|weeks?|months?|d|w|m|hours?|hrs?)?$',
      caseSensitive: false,
    );
    if (!durationPattern.hasMatch(val)) {
      return 'Invalid duration format (e.g. 5 days, 2 weeks)';
    }
    return null;
  }

  void _addMedication() {
    final medName = _medNameController.text.trim();
    final dosage = _dosageController.text.trim();
    final duration = _durController.text.trim();

    if (medName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a medication name.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    final dError = _validateDosage(dosage);
    if (dError != null) {
      setState(() {
        _dosageError = dError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dError),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    final durError = _validateDuration(duration);
    if (durError != null) {
      setState(() {
        _durationError = durError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(durError),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    setState(() {
      _medications.add({
        'name': medName,
        'dosage': dosage,
        'frequency': _freqController.text.isEmpty
            ? '1-0-1'
            : _freqController.text,
        'duration': duration,
      });
      _medNameController.clear();
      _dosageController.clear();
      _durController.clear();
      _dosageError = null;
      _durationError = null;
      _freqController.text = '1-0-1';
    });
  }

  Future<bool> _onWillPop() async {
    final int? choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Exit Consultation?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'The consultation is not completed yet. Do you want to save as draft to resume later, or exit and discard your unsaved changes?',
          style: TextStyle(fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(0),
            style: AppTheme.outlinedButton,
            child: const Text('Stay'),
          ),
          OutlinedButton(
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(context).pop(1);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.dangerColor,
              side: const BorderSide(color: AppTheme.dangerColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Discard & Exit'),
          ),
          ElevatedButton(
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(context).pop(2);
            },
            style: AppTheme.primaryButton,
            child: const Text('Save Draft & Exit'),
          ),
        ],
      ),
    );

    if (choice == null || choice == 0) return false;

    if (choice == 1) {
      await _clearDraft();
    } else if (choice == 2) {
      await _saveDraft();
    }
    UnsavedChangesHelper.setUnsavedChanges(false);
    UnsavedChangesHelper.clear();
    widget.onBack();
    return false;
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
              await _onWillPop();
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialConsultation != null
                    ? 'Edit Consultation: ${_currentAppointment.patientName}'
                    : 'Consultation: ${_currentAppointment.patientName}',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                softWrap: true,
              ),
              const SizedBox(height: 4),
              Text(
                'Appt Date: ${_currentAppointment.appointmentDate} • Status: ${_currentAppointment.status}',
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                ),
                softWrap: true,
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
    final bool hasMissingVitals = _currentAppointment.bloodPressureSystolic == null &&
        _currentAppointment.bloodPressureDiastolic == null &&
        _currentAppointment.sugarLevel == null &&
        _currentAppointment.temperature == null;

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
          Row(
            children: [
              const Icon(Icons.monitor_heart, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Nurse Vitals Intake',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              InkWell(
                onTap: _showEnterVitalsDialog,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasMissingVitals ? Icons.add_circle_outline : Icons.edit_outlined,
                        size: 13,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasMissingVitals ? 'Add Vitals' : 'Edit Vitals',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
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
            if (hasMissingVitals) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vitals not recorded by nurse. Click "Add Vitals" to enter.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildHistoryDetailItem(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppTheme.primaryColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Clinical History',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (!_isLoadingHistory && _previousConsultations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_previousConsultations.length} ${_previousConsultations.length == 1 ? "record" : "records"}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_previousConsultations.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 28,
                    color: Colors.blueGrey.shade300,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No previous consultations found.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
                final diagnosis = hist['diagnosis']?.toString();
                final hasDiagnosis = diagnosis != null && diagnosis.trim().isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      expandedAlignment: Alignment.topLeft,
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      collapsedShape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      title: Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      subtitle: Text(
                        hasDiagnosis ? diagnosis : 'General Consultation',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      children: [
                        if (hist['doctor_name'] != null &&
                            hist['doctor_name'].toString().trim().isNotEmpty)
                          _buildHistoryDetailItem(
                            'DOCTOR',
                            hist['doctor_name'].toString().trim(),
                            Icons.person_outline_rounded,
                          ),
                        if (hist['symptoms'] != null &&
                            hist['symptoms'].toString().trim().isNotEmpty)
                          _buildHistoryDetailItem(
                            'SYMPTOMS',
                            hist['symptoms'].toString().trim(),
                            Icons.sick_outlined,
                          ),
                        if (hist['leading_questions'] != null &&
                            hist['leading_questions'].toString().trim().isNotEmpty)
                          _buildHistoryDetailItem(
                            'LEADING QUESTIONS',
                            hist['leading_questions'].toString().trim(),
                            Icons.help_outline_rounded,
                          ),
                        if (hist['diagnosis'] != null &&
                            hist['diagnosis'].toString().trim().isNotEmpty)
                          _buildHistoryDetailItem(
                            'DIAGNOSIS',
                            hist['diagnosis'].toString().trim(),
                            Icons.assignment_outlined,
                          ),
                        if (hist['plan'] != null &&
                            hist['plan'].toString().trim().isNotEmpty)
                          _buildHistoryDetailItem(
                            'PLAN',
                            hist['plan'].toString().trim(),
                            Icons.playlist_add_check_rounded,
                          ),
                        if (hist['notes'] != null &&
                            hist['notes'].toString().trim().isNotEmpty)
                          _buildHistoryDetailItem(
                            'RECOMMENDATIONS',
                            hist['notes'].toString().trim(),
                            Icons.description_outlined,
                          ),
                        if (ConsultationDocumentsView.hasDocuments(hist['documents'])) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.attachment_rounded, size: 14, color: AppTheme.primaryColor),
                              SizedBox(width: 6),
                              Text(
                                'ATTACHED DOCUMENTS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ConsultationDocumentsView(
                            documents: hist['documents'],
                            isCompact: true,
                          ),
                        ],
                      ],
                    ),
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
      _formKey.currentState?.validate();
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
      _formKey.currentState?.validate();
      return;
    }

    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final referredDoc = _referredDoctorController.text.trim();
    final referredDept = _referredDeptController.text.trim();
    if (referredDoc.isNotEmpty) {
      UserModel? currentUser;
      try {
        currentUser = Provider.of<AuthProvider>(context, listen: false).user;
      } catch (_) {}
      final currentDocName = (currentUser?.fullname ?? widget.appointment.doctorName).trim().toLowerCase();
      final apptDocName = widget.appointment.doctorName.trim().toLowerCase();

      if ((currentDocName.isNotEmpty && referredDoc.toLowerCase() == currentDocName) ||
          (apptDocName.isNotEmpty && referredDoc.toLowerCase() == apptDocName)) {
        setState(() => _currentStep = 3);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A doctor cannot refer a patient to himself. Please select another doctor or clear the referral.'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }

      if (referredDept.isNotEmpty) {
        final matchedDocs = _rawDoctors.where((d) => d.fullname.trim().toLowerCase() == referredDoc.toLowerCase()).toList();
        if (matchedDocs.isNotEmpty) {
          final docSpec = matchedDocs.first.specialization?.trim().toLowerCase();
          if (docSpec != null && docSpec.isNotEmpty && docSpec != referredDept.toLowerCase()) {
            setState(() => _currentStep = 3);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected doctor "$referredDoc" belongs to department "$docSpec", not "$referredDept".'),
                backgroundColor: AppTheme.dangerColor,
              ),
            );
            return;
          }
        }
      }
    }

    for (final med in _medications) {
      final dError = _validateDosage(med['dosage']);
      if (dError != null) {
        setState(() => _currentStep = 6);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription "${med['name']}": $dError'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
      final durError = _validateDuration(med['duration']);
      if (durError != null) {
        setState(() => _currentStep = 6);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription "${med['name']}": $durError'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      }
    }

    if (_medNameController.text.trim().isNotEmpty ||
        _dosageController.text.trim().isNotEmpty ||
        _durController.text.trim().isNotEmpty) {
      setState(() => _currentStep = 6);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please click "Add Drug" to add the pending medication or clear the medication fields before saving.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
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

      final consulId = widget.initialConsultation?['id'] != null
          ? (widget.initialConsultation!['id'] is int
              ? widget.initialConsultation!['id'] as int
              : int.tryParse(widget.initialConsultation!['id'].toString()))
          : _existingConsultationId;

      if (consulId != null) {
        await _appointmentController.updateConsultation(consulId, data);
      } else {
        await _appointmentController.saveConsultation(data);
      }

      if (mounted) {
        await _clearDraft();
        UnsavedChangesHelper.setUnsavedChanges(false);
        UnsavedChangesHelper.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              consulId != null
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
        final errText = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText.isNotEmpty ? errText : 'Failed to save consultation. Please try again.'),
            backgroundColor: AppTheme.dangerColor,
          ),
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
                validateContent: true,
                maxLen: 500,
              ),
              const SizedBox(height: 16),
              _buildTextArea(
                'Leading questions related to symptoms',
                _leadingQuestionsController,
                'Enter leading questions related to symptoms...',
                validateContent: true,
                maxLen: 500,
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
            validateContent: true,
            maxLen: 500,
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
    final bool hasMissingVitals = _currentAppointment.bloodPressureSystolic == null &&
        _currentAppointment.bloodPressureDiastolic == null &&
        _currentAppointment.sugarLevel == null &&
        _currentAppointment.temperature == null;

    return Column(
      key: const ValueKey('examination_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          'Physical Examination & Vitals Summary',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recorded Nurse Vitals Intake',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  InkWell(
                    onTap: _showEnterVitalsDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasMissingVitals ? Icons.add_circle_outline : Icons.edit_outlined,
                            size: 13,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasMissingVitals ? 'Add Vitals' : 'Edit Vitals',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildSmallField(
                            'Document Title',
                            _docTitleController,
                            'e.g. Chest X-Ray Report',
                            enableVoice: true,
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
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _selectedFileName != null
                                      ? Colors.white
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _selectedFileName != null
                                        ? Colors.green.shade400
                                        : AppTheme.borderColor,
                                    width: 1.0,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: _isUploadingFile ? null : _pickFile,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _selectedFileName != null
                                                ? Icons.check_circle_outline
                                                : Icons.file_present_outlined,
                                            size: 16,
                                            color: _selectedFileName != null
                                                ? Colors.green
                                                : AppTheme.primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _selectedFileName != null
                                                  ? _selectedFileName!
                                              : context.tr(
                                                  'choose_file_pdf_image',
                                                  fallback: 'Choose File (PDF/Image)',
                                                ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _selectedFileName != null
                                                    ? Colors.green.shade800
                                                    : AppTheme.textPrimaryColor,
                                                fontWeight: _selectedFileName != null
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_selectedFileName != null)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppTheme.dangerColor,
                                                size: 18,
                                              ),
                                              tooltip: 'Delete Selected File',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 28,
                                                minHeight: 28,
                                              ),
                                              splashRadius: 16,
                                              onPressed: _isUploadingFile
                                                  ? null
                                                  : _confirmDeleteSelectedFile,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_selectedFileName != null && _selectedFileSizeStr != null) ...[
                                const SizedBox(height: 4),
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
                    final fileName = doc['file_name'] ?? '';
                    final hasUrl = fileUrl != null && fileUrl.isNotEmpty;
                    final isPdf = fileName.toLowerCase().endsWith('.pdf') || (fileUrl?.toLowerCase().endsWith('.pdf') ?? false);
                    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
                        fileName.toLowerCase().endsWith('.jpeg') ||
                        fileName.toLowerCase().endsWith('.png') ||
                        fileName.toLowerCase().endsWith('.webp') ||
                        (fileUrl?.toLowerCase().contains('/image/upload/') ?? false);
                    final iconColor = isPdf
                        ? AppTheme.dangerColor
                        : isImage
                            ? AppTheme.primaryColor
                            : AppTheme.secondaryColor;
                    final iconData = isPdf
                        ? Icons.picture_as_pdf_rounded
                        : isImage
                            ? Icons.image_rounded
                            : Icons.insert_drive_file_outlined;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: hasUrl
                              ? () => showDocumentViewer(
                                    context,
                                    fileUrl,
                                    doc['title'] ?? 'Document',
                                    fileName: fileName.isNotEmpty ? fileName : null,
                                  )
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: iconColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc['title'] ?? 'Document',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${fileName}${doc['file_size'] != null && doc['file_size']!.isNotEmpty ? ' (${doc['file_size']})' : ''} • Attached on: ${doc['date']}',
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
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                    tooltip: 'View Document',
                                    onPressed: () {
                                      showDocumentViewer(
                                        context,
                                        fileUrl,
                                        doc['title'] ?? 'Document',
                                        fileName: fileName.isNotEmpty ? fileName : null,
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.dangerColor,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete Document',
                                  onPressed: () => _confirmDeleteDocument(idx),
                                ),
                              ],
                            ),
                          ),
                        ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Doctor / Department Referral',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (_isLoadingReferralData)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Referred Doctor & Department',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  if (_referredDoctorController.text.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _referredDoctorController.clear();
                          _referredDeptController.clear();
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.close, size: 14, color: AppTheme.dangerColor),
                            SizedBox(width: 2),
                            Text(
                              'Clear Referral',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.dangerColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              CustomDropdownSearch(
                label: '',
                hint: 'Select Doctor & Department (e.g. Gayathri B - General Medicine)',
                value: _getSelectedReferralDisplay(),
                dropdownItems: _doctorsList.isNotEmpty ? _doctorsList : _getReferralDoctorDeptItems(),
                onChanged: (val) {
                  UserModel? currentUser;
                  try {
                    currentUser = Provider.of<AuthProvider>(context, listen: false).user;
                  } catch (_) {}
                  final currentDocName = (currentUser?.fullname ?? widget.appointment.doctorName).trim().toLowerCase();
                  final apptDocName = widget.appointment.doctorName.trim().toLowerCase();

                  if (val == null || val.trim().isEmpty) {
                    setState(() {
                      _referredDoctorController.clear();
                      _referredDeptController.clear();
                    });
                    return;
                  }

                  // Find matching doctor
                  UserModel? matchedDoc;
                  for (final d in _rawDoctors) {
                    final itemText = (d.specialization != null && d.specialization!.trim().isNotEmpty)
                        ? '${d.fullname} - ${d.specialization!.trim()}'
                        : d.fullname;
                    if (itemText == val || d.fullname == val) {
                      matchedDoc = d;
                      break;
                    }
                  }

                  final chosenDocName = (matchedDoc?.fullname ?? val.split(' - ').first).trim();
                  final chosenDept = (matchedDoc?.specialization ?? (val.contains(' - ') ? val.split(' - ').last : '')).trim();

                  if ((currentDocName.isNotEmpty && chosenDocName.toLowerCase() == currentDocName) ||
                      (apptDocName.isNotEmpty && chosenDocName.toLowerCase() == apptDocName)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A doctor cannot refer a patient to himself.'),
                        backgroundColor: AppTheme.dangerColor,
                      ),
                    );
                    setState(() {
                      _referredDoctorController.clear();
                      _referredDeptController.clear();
                    });
                    return;
                  }

                  setState(() {
                    _referredDoctorController.text = chosenDocName;
                    _referredDeptController.text = chosenDept;
                  });
                },
              ),
              if (_referredDoctorController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline, size: 13, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Doctor: ${_referredDoctorController.text}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                            ),
                            if (_referredDeptController.text.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.local_hospital_outlined, size: 13, color: AppTheme.secondaryColor),
                              const SizedBox(width: 4),
                              Text(
                                'Dept: ${_referredDeptController.text}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final tabTitles = [
      'Complaint',
      'Examination',
      'Investigation',
      'Docket',
      'Diagnosis',
      'Treatment',
      'Prescription',
    ];

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: Text(
                        'Previous: ${tabTitles[_currentStep - 1]}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_currentStep < 6)
                  Expanded(
                    child: ElevatedButton.icon(
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
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () async {
                      await _onWillPop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondaryColor,
                      side: const BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
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
                            size: 16,
                            color: Colors.white,
                          ),
                    label: Text(
                      widget.initialConsultation != null
                          ? 'Update & Save'
                          : 'Complete & Submit',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.logoRed,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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

          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await _onWillPop();
                },
                style: AppTheme.cancelButton,
                child: const Text('Cancel'),
              ),
              if (_currentStep < 6)
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
    bool validateContent = false,
    int maxLen = 500,
  }) {
    final isCurrentActive = _activeListeningController == controller;
    final isListening = isCurrentActive && !_isSpeechPaused;
    final isPaused = isCurrentActive && _isSpeechPaused;

    // Regex for medical intake text fields
    final medicalTextRegex = RegExp(r'^[a-zA-Z0-9 .,/#\-\(\):;\n\r]*$');
    final hasAlphaRegex = RegExp(r'[a-zA-Z]');

    String? fieldValidator(String? v) {
      final trimmed = v?.trim() ?? '';
      if (required && trimmed.isEmpty) {
        return 'This field is required';
      }
      if (validateContent && trimmed.isNotEmpty) {
        if (!medicalTextRegex.hasMatch(trimmed)) {
          return 'Only letters, numbers and . , / # - ( ) : ; are allowed';
        }
        if (!hasAlphaRegex.hasMatch(trimmed)) {
          return 'Must contain at least one letter';
        }
      }
      if (trimmed.length > maxLen) {
        return 'Maximum $maxLen characters allowed';
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black,
                ),
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
        Container(
          decoration: BoxDecoration(
            color: isListening
                ? Colors.red.withValues(alpha: 0.02)
                : (isPaused
                    ? Colors.amber.withValues(alpha: 0.02)
                    : AppTheme.backgroundColor),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isListening
                  ? Colors.red.shade400
                  : (isPaused
                      ? Colors.orange.shade400
                      : AppTheme.borderColor),
              width: (isListening || isPaused) ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: controller,
                maxLines: 3,
                maxLength: maxLen,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                inputFormatters: validateContent
                    ? [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9 .,/#\-\(\):;\n\r]'),
                        ),
                        LengthLimitingTextInputFormatter(maxLen),
                      ]
                    : [
                        LengthLimitingTextInputFormatter(maxLen),
                      ],
                validator: fieldValidator,
                decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  fillColor: Colors.transparent,
                  filled: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorStyle: const TextStyle(
                    color: AppTheme.dangerColor,
                    fontSize: 12,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              // Integrated bottom Voice-to-Text toolbar directly inside the text field
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isListening
                      ? Colors.red.withValues(alpha: 0.06)
                      : (isPaused
                          ? Colors.orange.withValues(alpha: 0.06)
                          : Colors.grey.shade50),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(7),
                    bottomRight: Radius.circular(7),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isListening
                          ? Colors.red.shade200
                          : (isPaused
                              ? Colors.orange.shade200
                              : Colors.grey.shade200),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status indicator
                    if (isListening)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Listening... Speak now',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      )
                    else if (isPaused)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.pause_circle_filled,
                            size: 13,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Voice Paused',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Voice to Text',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    // Control buttons (Start, Pause, Resume, Stop)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isCurrentActive) ...[
                          InkWell(
                            onTap: () => _startSpeech(controller, label),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.mic_none_rounded,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Start Voice',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          if (isListening) ...[
                            // Pause button
                            InkWell(
                              onTap: _pauseSpeech,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pause_rounded,
                                      size: 14,
                                      color: Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pause',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Stop button
                            InkWell(
                              onTap: _stopSpeech,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.stop_rounded,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Stop',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (isPaused) ...[
                            // Resume button
                            InkWell(
                              onTap: _resumeSpeech,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      size: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Resume',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Stop button
                            InkWell(
                              onTap: _stopSpeech,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.stop_rounded,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Stop',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: CustomDropdownSearch(
                  label: 'Medication Name',
                  requiredMark: true,
                  value: _medNameController.text.isEmpty
                      ? null
                      : _medNameController.text,
                  dropdownItems: _medicineCatalog,
                  height: 38,
                  borderColor: const Color(0xFFE2E8F0),
                  borderWidth: 1.0,
                  focusedBorderColor: AppTheme.primaryColor,
                  focusedBorderWidth: 1.4,
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
                          _dosageError = _validateDosage(_dosageController.text);
                        } else if (_dosageController.text.isNotEmpty) {
                          _dosageError = _validateDosage(_dosageController.text);
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
                  isRequired: true,
                  maxLength: 20,
                  height: 38,
                  errorText: _dosageError,
                  onChanged: (val) {
                    setState(() {
                      if (_dosageError != null || val.isNotEmpty) {
                        _dosageError = _validateDosage(val);
                      }
                    });
                  },
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
                  borderColor: const Color(0xFFE2E8F0),
                  borderWidth: 1.0,
                  focusedBorderColor: AppTheme.primaryColor,
                  focusedBorderWidth: 1.4,
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
                  isRequired: true,
                  maxLength: 20,
                  height: 38,
                  errorText: _durationError,
                  onChanged: (val) {
                    setState(() {
                      if (_durationError != null || val.isNotEmpty) {
                        _durationError = _validateDuration(val);
                      }
                    });
                  },
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
    String hint, {
    bool enableVoice = false,
    bool isRequired = false,
    String? errorText,
    int? maxLength,
    double height = 38,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    final isCurrentActive = _activeListeningController == controller;
    final isListening = isCurrentActive && !_isSpeechPaused;
    final isPaused = isCurrentActive && _isSpeechPaused;
    final hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                color: AppTheme.isDark(context)
                    ? AppTheme.darkTextPrimaryColor
                    : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Focus(
          child: Builder(
            builder: (fContext) {
              final isFocused = Focus.of(fContext).hasFocus;
              return Container(
                height: height,
                decoration: BoxDecoration(
                  color: hasError
                      ? AppTheme.dangerColor.withValues(alpha: 0.05)
                      : (isListening
                          ? Colors.red.withValues(alpha: 0.04)
                          : (isPaused
                              ? Colors.amber.withValues(alpha: 0.04)
                              : const Color(0xFFF1F5F9))),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    width: hasError ? 1.5 : (isFocused ? 1.4 : 1.0),
                    color: hasError
                        ? AppTheme.dangerColor
                        : (isFocused
                            ? AppTheme.primaryColor
                            : const Color(0xFFE2E8F0)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLength: maxLength,
                        inputFormatters: inputFormatters,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          hintText: hint,
                          hintStyle: const TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    if (enableVoice) ...[
                      if (isCurrentActive) ...[
                        if (isListening)
                          IconButton(
                            icon: const Icon(Icons.pause_rounded, size: 16, color: Colors.orange),
                            tooltip: 'Pause voice input',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            onPressed: _pauseSpeech,
                          ),
                        if (isPaused)
                          IconButton(
                            icon: const Icon(Icons.play_arrow_rounded, size: 16, color: AppTheme.primaryColor),
                            tooltip: 'Resume voice input',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            onPressed: _resumeSpeech,
                          ),
                        IconButton(
                          icon: const Icon(Icons.stop_rounded, size: 16, color: Colors.red),
                          tooltip: 'Stop voice input',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: _stopSpeech,
                        ),
                      ] else
                        IconButton(
                          icon: const Icon(Icons.mic_none_rounded, size: 16, color: AppTheme.primaryColor),
                          tooltip: 'Start Voice Input',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => _startSpeech(controller, label),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              errorText,
              style: const TextStyle(
                color: AppTheme.dangerColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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

  void _addCustomLabTest() {
    final rawText = _customLabController.text.trim();
    if (rawText.isEmpty) {
      setState(() => _customLabError = 'Please enter a test or scan name');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a custom lab test or scan name.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (rawText.length < 2) {
      setState(() => _customLabError = 'Test name must be at least 2 characters');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom lab test name must be at least 2 characters.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    if (rawText.length > 80) {
      setState(() => _customLabError = 'Test name cannot exceed 80 characters');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom lab test name cannot exceed 80 characters.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    if (RegExp(r'[^a-zA-Z0-9\s.,/#\-\(\):;%+]').hasMatch(rawText)) {
      setState(() => _customLabError = 'Special characters are not allowed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Special characters are not allowed in test name.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    if (!RegExp(r'[a-zA-Z]').hasMatch(rawText)) {
      setState(() => _customLabError = 'Must contain at least one letter');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom lab test name must contain alphabetic characters.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    // 1. Prevent duplicate custom test entries (case-insensitive check)
    final isDuplicate = _customLabs.any(
      (item) => item.trim().toLowerCase() == rawText.toLowerCase(),
    );
    if (isDuplicate) {
      setState(() => _customLabError = 'This test has already been added');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Custom lab test "$rawText" has already been added.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    // 2. Prevent duplicate with standard investigations
    final standardMatch = _standardLabs.keys.firstWhere(
      (item) => item.trim().toLowerCase() == rawText.toLowerCase(),
      orElse: () => '',
    );
    if (standardMatch.isNotEmpty) {
      if (_standardLabs[standardMatch] == true) {
        setState(() => _customLabError = '"$standardMatch" has already been selected');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$standardMatch" has already been selected under Standard Investigations.'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
        return;
      } else {
        setState(() {
          _standardLabs[standardMatch] = true;
          _customLabError = null;
          _customLabController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$standardMatch" selected under Standard Investigations.'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        return;
      }
    }

    setState(() {
      _customLabs.add(rawText);
      _customLabError = null;
      _customLabController.clear();
    });
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
                      enableVoice: true,
                      errorText: _customLabError,
                      onChanged: (val) {
                        if (_customLabError != null) {
                          setState(() => _customLabError = null);
                        }
                      },
                      onSubmitted: (_) => _addCustomLabTest(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addCustomLabTest,
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
