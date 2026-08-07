import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../controllers/home_visit_controller.dart';
import '../services/api_service.dart';
import '../services/media_service.dart';
import '../widgets/custom_dropdown_search.dart';
import 'home_visit_invoice_dialog.dart';

class HomeVisitExecutionScreen extends StatefulWidget {
  final int visitId;
  final bool isReadOnlyView;
  final VoidCallback? onBack;

  const HomeVisitExecutionScreen({
    super.key,
    required this.visitId,
    this.isReadOnlyView = false,
    this.onBack,
  });

  @override
  State<HomeVisitExecutionScreen> createState() =>
      _HomeVisitExecutionScreenState();
}

class _HomeVisitExecutionScreenState extends State<HomeVisitExecutionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyVitals = GlobalKey<FormState>();
  final _formKeyCare = GlobalKey<FormState>();

  // Vitals Controllers
  final TextEditingController _sysBpCtrl = TextEditingController();
  final TextEditingController _diaBpCtrl = TextEditingController();
  final TextEditingController _pulseCtrl = TextEditingController();
  final TextEditingController _tempCtrl = TextEditingController();
  final TextEditingController _spo2Ctrl = TextEditingController();
  final TextEditingController _sugarCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();

  // Care Activities Controllers
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _dressingCtrl = TextEditingController();
  bool _nailTrimmingDone = false;
  final TextEditingController _otherCareCtrl = TextEditingController();

  int? _selectedSummaryVisitId;

  // Medicine Form Controllers
  final TextEditingController _medNameCtrl = TextEditingController();
  final TextEditingController _medDosageCtrl = TextEditingController();
  final TextEditingController _medRouteCtrl = TextEditingController();
  final TextEditingController _medQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _medPriceCtrl = TextEditingController();

  // Consumable Form Controllers
  final TextEditingController _consNameCtrl = TextEditingController();
  final TextEditingController _consQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _consPriceCtrl = TextEditingController();

  // Kit & Devices Form Controllers
  String? _selectedKitDropdown;
  final TextEditingController _customKitNameCtrl = TextEditingController();
  final TextEditingController _kitItemNameCtrl = TextEditingController();
  final TextEditingController _kitItemQtyCtrl = TextEditingController(
    text: '1',
  );
  String _kitItemType = 'Device';

  final List<String> _defaultKitDevices = const [
    'Digital BP Monitor',
    'Glucometer Kit',
    'Pulse Oximeter',
    'Digital Thermometer',
    'Stethoscope',
    'ECG Machine (Portable)',
    'Nebulizer Machine',
    'Suction Machine',
    'Sterile Dressing Bandage Kit',
    'IV Infusion Set',
    'Oxygen Cylinder & Regulator',
    'Syringe & Needle Kit',
    'Catheterization Kit',
    'Blood Glucose Test Strips',
    'Antiseptic Solution & Wipes',
    'Other (Type Custom Kit Item...)',
  ];

  void _clearKitForm() {
    _selectedKitDropdown = null;
    _customKitNameCtrl.clear();
    _kitItemNameCtrl.clear();
    _kitItemQtyCtrl.text = '1';
    _kitItemType = 'Device';
    setState(() {});
  }

  int _vitalsPage = 1;
  int _medsPage = 1;
  int _consPage = 1;
  int _carePage = 1;
  final int _pageSize = 6;

  List<String> _dbMedicines = [];
  List<String> _dbConsumables = [];
  Map<String, double> _medicinePrices = {};
  Map<String, double> _consumablePrices = {};

  final Map<String, double> _defaultMedicinePrices = const {
    'paracetamol 500mg': 2.00,
    'amoxicillin 250mg': 12.00,
    'ibuprofen 400mg': 5.00,
    'metformin 500mg': 6.00,
    'amlodipine 5mg': 4.00,
    'omeprazole 20mg': 6.00,
    'atorvastatin 10mg': 10.00,
    'ciprofloxacin 500mg': 15.00,
    'metronidazole 400mg': 8.00,
    'ranitidine 150mg': 3.00,
    'diclofenac 50mg': 4.00,
    'cetirizine 10mg': 3.00,
    'azithromycin 500mg': 25.00,
    'losartan 50mg': 8.00,
    'pantoprazole 40mg': 7.00,
    'dexamethasone 4mg': 5.00,
    'tramadol 50mg': 18.00,
    'normal saline 0.9% 500ml': 50.00,
  };

  final Map<String, double> _defaultConsumablePrices = const {
    'sterile bandage': 25.00,
    'syringe 5ml': 15.00,
    'cotton roll 100g': 40.00,
    'surgical gloves (pair)': 35.00,
    'surgical gloves (large)': 35.00,
    'iv cannula 20g': 60.00,
    'adhesive tape': 20.00,
    'antiseptic solution 100ml': 50.00,
    'gauge swab 10x10cm': 10.00,
    'face mask (n95)': 40.00,
    'alcohol swab': 5.00,
  };

  final List<String> _defaultMedicines = const [
    'Paracetamol 500mg',
    'Amoxicillin 250mg',
    'Ibuprofen 400mg',
    'Metformin 500mg',
    'Amlodipine 5mg',
    'Omeprazole 20mg',
    'Atorvastatin 10mg',
    'Ciprofloxacin 500mg',
    'Metronidazole 400mg',
    'Cetirizine 10mg',
    'Azithromycin 500mg',
    'Losartan 50mg',
    'Normal Saline 0.9% 500ml',
    'Pantoprazole 40mg',
    'Dexamethasone 4mg',
    'Tramadol 50mg',
  ];

  final List<String> _defaultConsumables = const [
    'Sterile Bandage',
    'Syringe 5ml',
    'Cotton Roll 100g',
    'Surgical Gloves (Pair)',
    'IV Cannula 20G',
    'Adhesive Tape',
    'Antiseptic Solution 100ml',
    'Gauge Swab 10x10cm',
    'Face Mask (N95)',
    'Alcohol Swab',
  ];

  // Photo Evidence Form
  final TextEditingController _photoUrlCtrl = TextEditingController();
  final TextEditingController _photoCaptionCtrl = TextEditingController();
  String _selectedPhotoCategory = 'Dressing Pre-Procedure';
  String? _selectedPhotoName;
  List<int>? _selectedPhotoBytes;
  String? _photoFormatError;
  bool _isUploadingPhoto = false;

  // Signature Form
  final TextEditingController _attenderNameCtrl = TextEditingController();
  final TextEditingController _attenderRelationCtrl = TextEditingController();
  final List<Offset?> _signaturePoints = [];

  bool _isSavingVitals = false;
  bool _isSavingCare = false;
  bool _isVerifying = false;
  Timer? _vitalsTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      // Periodically refresh visit details every 10 seconds to auto-unlock form when scheduled time is reached
      _vitalsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          final ctrl = Provider.of<HomeVisitController>(context, listen: false);
          if (ctrl.selectedVisit != null) {
            ctrl.fetchVisitDetails(ctrl.selectedVisit!.id);
          }
        }
      });
    });
  }

  void _clearVitalsForm() {
    _sysBpCtrl.clear();
    _diaBpCtrl.clear();
    _pulseCtrl.clear();
    _tempCtrl.clear();
    _spo2Ctrl.clear();
    _sugarCtrl.clear();
    _weightCtrl.clear();
    _heightCtrl.clear();
  }

  void _clearCareForm() {
    _notesCtrl.clear();
    _dressingCtrl.clear();
    _otherCareCtrl.clear();
    setState(() => _nailTrimmingDone = false);
  }

  void _clearMedForm() {
    _medNameCtrl.clear();
    _medDosageCtrl.clear();
    _medRouteCtrl.clear();
    _medQtyCtrl.text = '1';
    _medPriceCtrl.clear();
  }

  void _clearConsForm() {
    _consNameCtrl.clear();
    _consQtyCtrl.text = '1';
    _consPriceCtrl.clear();
  }

  bool _isAllowedImageFormat(String filename) {
    if (!filename.contains('.')) return false;
    final ext = filename.split('.').last.toLowerCase();
    const allowed = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
      'bmp',
      'gif',
      'tiff',
      'tif',
      'svg',
      'raw',
      'dng',
    };
    return allowed.contains(ext);
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'heif',
          'bmp',
          'gif',
          'tiff',
          'tif',
          'svg',
          'raw',
          'dng',
        ],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (!_isAllowedImageFormat(file.name)) {
          setState(() {
            _selectedPhotoName = null;
            _selectedPhotoBytes = null;
            _photoFormatError =
                'Invalid File Format! "${file.name}" is not a supported image format. Allowed: JPG, PNG, WEBP, HEIC, BMP, GIF, SVG, TIFF.';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invalid File Format! "${file.name}" is not a supported image file format.',
                ),
                backgroundColor: AppTheme.dangerColor,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedPhotoName = file.name;
          _selectedPhotoBytes = file.bytes;
          _photoFormatError = null;
        });
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
    }
  }

  void _clearPhotoForm() {
    _photoUrlCtrl.clear();
    _photoCaptionCtrl.clear();
    setState(() {
      _selectedPhotoName = null;
      _selectedPhotoBytes = null;
      _photoFormatError = null;
    });
  }

  void _clearSignatureForm() {
    _attenderNameCtrl.clear();
    _attenderRelationCtrl.clear();
    setState(() => _signaturePoints.clear());
  }

  void _extractAndFillDosage(String? name) {
    if (name == null || name.trim().isEmpty) return;
    final RegExp regExp = RegExp(
      r'(\d+(?:\.\d+)?\s*(?:mg|g|mcg|ml|iu|iu/ml|mg/ml|%))',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(name);
    if (match != null) {
      _medDosageCtrl.text = match.group(1)!;
    } else {
      final words = name.trim().split(' ');
      if (words.length > 1 && RegExp(r'\d').hasMatch(words.last)) {
        _medDosageCtrl.text = words.last;
      }
    }
  }

  void _updateMedicinePrice(String? name) {
    if (name == null || name.trim().isEmpty) return;
    _extractAndFillDosage(name);

    final key = name.trim().toLowerCase();
    double? price = _medicinePrices[key] ?? _defaultMedicinePrices[key];
    if (price == null) {
      for (var entry in _medicinePrices.entries) {
        if (entry.key.contains(key) || key.contains(entry.key)) {
          price = entry.value;
          break;
        }
      }
    }
    if (price == null) {
      for (var entry in _defaultMedicinePrices.entries) {
        if (entry.key.contains(key) || key.contains(entry.key)) {
          price = entry.value;
          break;
        }
      }
    }
    if (price != null && price > 0) {
      _medPriceCtrl.text = price.toStringAsFixed(2);
    }
  }

  void _updateConsumablePrice(String? name) {
    if (name == null || name.trim().isEmpty) return;
    final key = name.trim().toLowerCase();
    double? price = _consumablePrices[key] ?? _defaultConsumablePrices[key];
    if (price == null) {
      for (var entry in _consumablePrices.entries) {
        if (entry.key.contains(key) || key.contains(entry.key)) {
          price = entry.value;
          break;
        }
      }
    }
    if (price == null) {
      for (var entry in _defaultConsumablePrices.entries) {
        if (entry.key.contains(key) || key.contains(entry.key)) {
          price = entry.value;
          break;
        }
      }
    }
    if (price != null && price > 0) {
      _consPriceCtrl.text = price.toStringAsFixed(2);
    }
  }

  Future<void> _fetchInventoryCatalogs() async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3001/api';
    try {
      final medRes = await ApiService.get(
        '$baseUrl/inventory/medicine-catalog',
      );
      final medBody = ApiService.decodeJsonResponse(medRes);
      if (medBody['success'] == true && medBody['data'] != null) {
        final List list = medBody['data'];
        final List<String> medNames = [];
        final Map<String, double> medPrices = Map.from(_defaultMedicinePrices);

        for (var item in list) {
          final name = item['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            medNames.add(name);
            final p = double.tryParse(item['price']?.toString() ?? '');
            if (p != null && p > 0) {
              medPrices[name.toLowerCase().trim()] = p;
            }
          }
        }
        if (mounted) {
          setState(() {
            if (medNames.isNotEmpty) _dbMedicines = medNames;
            _medicinePrices = medPrices;
          });
        }
      }
    } catch (_) {}

    try {
      final consRes = await ApiService.get(
        '$baseUrl/inventory/consumables-catalog',
      );
      final consBody = ApiService.decodeJsonResponse(consRes);
      if (consBody['success'] == true && consBody['data'] != null) {
        final List list = consBody['data'];
        final List<String> consNames = [];
        final Map<String, double> consPrices = Map.from(
          _defaultConsumablePrices,
        );

        for (var item in list) {
          final name = item['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            consNames.add(name);
            final p = double.tryParse(item['price']?.toString() ?? '');
            if (p != null && p > 0) {
              consPrices[name.toLowerCase().trim()] = p;
            }
          }
        }
        if (mounted) {
          setState(() {
            if (consNames.isNotEmpty) _dbConsumables = consNames;
            _consumablePrices = consPrices;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final ctrl = Provider.of<HomeVisitController>(context, listen: false);
    await ctrl.fetchVisitDetails(widget.visitId);
    await ctrl.fetchVisits();
    _fetchInventoryCatalogs();
    if (ctrl.selectedVisit != null &&
        (ctrl.selectedVisit!.startTime == null ||
            ctrl.selectedVisit!.startTime!.trim().isEmpty) &&
        ctrl.selectedVisit!.status != 'Cancelled' &&
        ctrl.selectedVisit!.status != 'Completed' &&
        ctrl.selectedVisit!.status != 'Verified') {
      _promptStartVisitDialog(ctrl.selectedVisit!);
    }
  }

  void _promptStartVisitDialog(HomeVisitModel visit) {
    final formKey = GlobalKey<FormState>();
    final now = DateTime.now();
    final defaultTime = DateFormat('hh:mm a').format(now);

    final nurseCtrl = TextEditingController(
      text: visit.startNurseName ?? visit.nurseName ?? '',
    );
    final timeCtrl = TextEditingController(text: defaultTime);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.play_circle_fill_outlined,
                color: AppTheme.primaryColor,
                size: 26,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Start Home Visit Session',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record visit start time and executing nurse name to begin executing vitals & care activities.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: const Text(
                        'Executing Nurse Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: nurseCtrl,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(30),
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                      ],
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Enter Nurse Full Name',
                        prefixIcon: Icons.person_outline,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Nurse name is required';
                        if (val.trim().length < 3)
                          return 'Nurse name must be at least 3 characters';
                        if (val.trim().length > 30)
                          return 'Nurse name cannot exceed 30 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: const Text(
                        'Visit Start Time',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: timeCtrl,
                      readOnly: true,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          final dt = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            picked.hour,
                            picked.minute,
                          );
                          setDialogState(() {
                            timeCtrl.text = DateFormat('hh:mm a').format(dt);
                          });
                        }
                      },
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Select Start Time',
                        prefixIcon: Icons.access_time,
                        suffixIcon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Start time is required'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: AppTheme.primaryButton,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 16),
                label: Text(
                  isSubmitting ? 'Starting...' : 'Submit & Start Visit',
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() == true) {
                          setDialogState(() => isSubmitting = true);
                          try {
                            final baseUrl =
                                dotenv.env['BASE_URL'] ??
                                'http://localhost:3001/api';
                            final payload = {
                              'start_time': timeCtrl.text.trim(),
                              'nurse_name': nurseCtrl.text.trim(),
                            };
                            var res = await ApiService.put(
                              '$baseUrl/home-visits/${visit.id}/start',
                              payload,
                            );
                            var body = ApiService.decodeJsonResponse(res);
                            if (body['success'] != true) {
                              res = await ApiService.post(
                                '$baseUrl/home-visits/${visit.id}/start',
                                payload,
                              );
                              body = ApiService.decodeJsonResponse(res);
                            }
                            if (body['success'] != true) {
                              res = await ApiService.post(
                                '$baseUrl/home-visits/${visit.id}/vitals',
                                {
                                  'is_start_only': true,
                                  'start_time': timeCtrl.text.trim(),
                                  'nurse_name': nurseCtrl.text.trim(),
                                  'bypass_schedule': true,
                                },
                              );
                              body = ApiService.decodeJsonResponse(res);
                            }
                            if (body['success'] == true) {
                              if (mounted) {
                                Provider.of<HomeVisitController>(
                                  context,
                                  listen: false,
                                ).fetchVisitDetails(visit.id);
                                Navigator.of(dialogCtx).pop();
                              }
                            } else {
                              setDialogState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      body['message'] ??
                                          'Failed to record start time',
                                    ),
                                    backgroundColor: AppTheme.dangerColor,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error starting visit: $e'),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                            }
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vitalsTimer?.cancel();
    _tabController.dispose();
    _sysBpCtrl.dispose();
    _diaBpCtrl.dispose();
    _pulseCtrl.dispose();
    _tempCtrl.dispose();
    _spo2Ctrl.dispose();
    _sugarCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    _dressingCtrl.dispose();
    _otherCareCtrl.dispose();
    _medNameCtrl.dispose();
    _medDosageCtrl.dispose();
    _medRouteCtrl.dispose();
    _medQtyCtrl.dispose();
    _medPriceCtrl.dispose();
    _consNameCtrl.dispose();
    _consQtyCtrl.dispose();
    _consPriceCtrl.dispose();
    _photoUrlCtrl.dispose();
    _photoCaptionCtrl.dispose();
    _attenderNameCtrl.dispose();
    _attenderRelationCtrl.dispose();
    super.dispose();
  }

  Widget _buildLabel(String label) {
    if (!label.contains('*')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontFamily: 'Inter',
          ),
        ),
      );
    }

    final parts = label.split('*');
    final List<InlineSpan> spans = [];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              fontFamily: 'Inter',
            ),
          ),
        );
      }
      if (i < parts.length - 1) {
        spans.add(
          const TextSpan(
            text: '*',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.dangerColor,
              fontFamily: 'Inter',
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeVisitController>(
      builder: (context, controller, child) {
        final visit = controller.selectedVisit;

        if (controller.isLoading && visit == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        if (visit == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Home Visit Details')),
            body: const Center(
              child: Text('Visit not found or failed to load.'),
            ),
          );
        }

        final bool isCompletedOrVerified =
            widget.isReadOnlyView ||
            (visit.status == 'Completed' &&
                !_isPastVisit(visit.scheduledDate)) ||
            (visit.status == 'Verified' && !_isPastVisit(visit.scheduledDate));

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: AppTheme.backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 75,
            leading: widget.onBack != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: widget.onBack,
                    ),
                  )
                : null,
            title: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Home Visit Care - ${visit.visitNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Patient: ${visit.patientName ?? "N/A"} (${visit.patientDisplayId ?? ""})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (visit.status != 'Cancelled')
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, right: 16.0),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor,
                      side: const BorderSide(color: AppTheme.dangerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      Icons.do_not_disturb_on_outlined,
                      size: 16,
                    ),
                    label: const Text(
                      'Stop / Discontinue Care',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => _showDiscontinueDialog(context, visit),
                  ),
                ),
            ],
            bottom: isCompletedOrVerified
                ? null
                : TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.primaryColor,
                    indicatorWeight: 3,
                    isScrollable: true,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.medical_services_outlined),
                        text: 'Kit & Devices',
                      ),
                      Tab(
                        icon: Icon(Icons.monitor_heart_outlined),
                        text: 'Vitals',
                      ),
                      Tab(
                        icon: Icon(Icons.edit_note_outlined),
                        text: 'Nursing Care & Dressing',
                      ),
                      Tab(
                        icon: Icon(Icons.medication_liquid_outlined),
                        text: 'Meds & Consumables',
                      ),
                      Tab(
                        icon: Icon(Icons.insert_photo_outlined),
                        text: 'Photo Evidence',
                      ),
                      Tab(
                        icon: Icon(Icons.analytics_outlined),
                        text: 'View Live Summary',
                      ),
                    ],
                  ),
          ),
          body: isCompletedOrVerified
              ? (_selectedSummaryVisitId == null
                    ? _buildDailySessionsOverview(visit, controller)
                    : _buildCompletedVisitSummaryView(
                        (controller.selectedVisit != null &&
                                controller.selectedVisit!.id ==
                                    _selectedSummaryVisitId)
                            ? controller.selectedVisit!
                            : controller.visits.firstWhere(
                                (v) => v.id == _selectedSummaryVisitId,
                                orElse: () => visit,
                              ),
                        controller,
                      ))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildKitTab(visit, controller),
                    _buildVitalsTab(visit, controller),
                    _buildCareTab(visit, controller),
                    _buildMedsAndConsumablesTab(visit, controller),
                    _buildPhotosTab(visit, controller),
                    _buildLiveSessionSummaryTab(visit, controller),
                  ],
                ),
        );
      },
    );
  }

  // 1. Kit & Devices Tab with Interactive Form
  Widget _buildKitTab(HomeVisitModel visit, HomeVisitController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Select & Add Kit Items & Medical Devices Used',
            Icons.shopping_bag_outlined,
          ),
          const SizedBox(height: 16),

          // Interactive Form to Select & Add Used Kit/Devices
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Kit Device / Item Used During Visit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    // Shared add button logic
                    Future<void> addKitItem() async {
                      final name =
                          (_selectedKitDropdown != null &&
                              _selectedKitDropdown!.isNotEmpty)
                          ? _selectedKitDropdown!.trim()
                          : _kitItemNameCtrl.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select or enter a kit device name',
                            ),
                            backgroundColor: AppTheme.dangerColor,
                          ),
                        );
                        return;
                      }
                      final success = await controller.submitCarriedItem(visit.id, {
                        'item_type': _kitItemType,
                        'item_name': name,
                        'quantity_carried':
                            int.tryParse(_kitItemQtyCtrl.text) ?? 1,
                      });
                      if (success) {
                        _clearKitForm();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kit item / device added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.errorMessage ?? 'Failed to add kit item',
                            ),
                            backgroundColor: AppTheme.dangerColor,
                          ),
                        );
                      }
                    }

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomDropdownSearch(
                            label: '',
                            hint: 'Select or Type Kit Item / Device',
                            dropdownItems: _defaultKitDevices,
                            value: _selectedKitDropdown,
                            allowFreeText: true,
                            onChanged: (val) {
                              setState(() {
                                _selectedKitDropdown = val;
                                if (val != null) _kitItemNameCtrl.text = val;
                              });
                            },
                          ),
                          if (_selectedKitDropdown == 'Other (Type Custom Kit Item...)') ...[
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _customKitNameCtrl,
                              decoration: AppTheme.standardInputDecoration(
                                hintText: 'Enter Custom Kit Item / Device Name *',
                                prefixIcon: Icons.edit_note,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          CustomDropdownSearch(
                            label: '',
                            hint: 'Category',
                            dropdownMap: const {
                              'Device': 'Medical Device',
                              'Tool': 'Kit Tool',
                              'Consumable': 'Supply / Consumable',
                              'Medicine': 'Kit Medicine',
                            },
                            value: _kitItemType,
                            onChanged: (val) {
                              if (val != null) setState(() => _kitItemType = val);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _kitItemQtyCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: AppTheme.standardInputDecoration(hintText: 'Quantity'),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: AppTheme.primaryButton,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Kit Item'),
                              onPressed: addKitItem,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: CustomDropdownSearch(
                              label: '',
                              hint: 'Select or Type Kit Item / Device',
                              dropdownItems: _defaultKitDevices,
                              value: _selectedKitDropdown,
                              allowFreeText: true,
                              onChanged: (val) {
                                setState(() {
                                  _selectedKitDropdown = val;
                                  if (val != null) _kitItemNameCtrl.text = val;
                                });
                              },
                            ),
                          ),
                          if (_selectedKitDropdown == 'Other (Type Custom Kit Item...)') ...[
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _customKitNameCtrl,
                                decoration: AppTheme.standardInputDecoration(
                                  hintText: 'Enter Custom Kit Item / Device Name *',
                                  prefixIcon: Icons.edit_note,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: CustomDropdownSearch(
                              label: '',
                              hint: 'Category',
                              dropdownMap: const {
                                'Device': 'Medical Device',
                                'Tool': 'Kit Tool',
                                'Consumable': 'Supply / Consumable',
                                'Medicine': 'Kit Medicine',
                              },
                              value: _kitItemType,
                              onChanged: (val) {
                                if (val != null) setState(() => _kitItemType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _kitItemQtyCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: AppTheme.standardInputDecoration(hintText: 'Qty'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: AppTheme.primaryButton,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Kit Item'),
                            onPressed: addKitItem,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Added Kit Items List
          const Text(
            'Carried & Used Kit Devices List',

            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),

          if (visit.carriedItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'No kit items or medical devices added yet. Select and add devices using the form above.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 700;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 3 : 1,
                    childAspectRatio: 3.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: visit.carriedItems.length,
                  itemBuilder: (context, index) {
                    final item = visit.carriedItems[index];
                    IconData itemIcon = Icons.medical_services;
                    if (item.itemType == 'Device') itemIcon = Icons.devices;
                    if (item.itemType == 'Medicine')
                      itemIcon = Icons.medication;
                    if (item.itemType == 'Consumable')
                      itemIcon = Icons.clean_hands;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(
                              0.1,
                            ),
                            child: Icon(
                              itemIcon,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${item.itemType} • Qty Carried: ${item.quantityCarried}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.id != null)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.dangerColor,
                                size: 20,
                              ),
                              tooltip: 'Remove Device',
                              onPressed: () async {
                                final ok = await controller.removeCarriedItem(
                                  visit.id,
                                  item.id!,
                                );
                                if (ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Kit item removed'),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  // 2. Single Unified Vitals Entry Form Popup Modal
  void _showAddVitalsModalDialog(
    BuildContext context,
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKeyVitals,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.monitor_heart_outlined,
                                  color: AppTheme.primaryColor,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Record Patient Vital Signs',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Text(
                                    'Patient: ${visit.patientName ?? "Patient"} (${(visit.patientDisplayId != null && visit.patientDisplayId!.isNotEmpty) ? visit.patientDisplayId : "ID: ${visit.patientId}"})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Form Fields
                      // Row 1: BP Systolic, BP Diastolic
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Systolic BP (mmHg) *'),
                                TextFormField(
                                  controller: _sysBpCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 120',
                                    suffixIcon: const Icon(
                                      Icons.speed,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty)
                                      return 'Mandatory';
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 90 || n > 300)
                                      return '90-300 mmHg';
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
                                _buildLabel('Diastolic BP (mmHg) *'),
                                TextFormField(
                                  controller: _diaBpCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 80',
                                    suffixIcon: const Icon(
                                      Icons.speed,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty)
                                      return 'Mandatory';
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 50 || n > 180)
                                      return '50-180 mmHg';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Pulse Rate, Temperature
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Pulse Rate (bpm)'),
                                TextFormField(
                                  controller: _pulseCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 72',
                                    suffixIcon: const Icon(
                                      Icons.favorite_border,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Temperature (°F) *'),
                                TextFormField(
                                  controller: _tempCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'),
                                    ),
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 98.6',
                                    suffixIcon: const Icon(
                                      Icons.thermostat,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty)
                                      return 'Mandatory';
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 90 || n > 115)
                                      return '90-115 °F';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: SpO2, Sugar
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('SpO2 (%)'),
                                TextFormField(
                                  controller: _spo2Ctrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 98',
                                    suffixIcon: const Icon(
                                      Icons.air,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Blood Sugar (mg/dL)'),
                                TextFormField(
                                  controller: _sugarCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 110',
                                    suffixIcon: const Icon(
                                      Icons.water_drop,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val != null && val.trim().isNotEmpty) {
                                      final n = int.tryParse(val.trim());
                                      if (n == null || n < 30 || n > 600)
                                        return '30-600 mg/dL';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Weight, Height
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Weight (kg)'),
                                TextFormField(
                                  controller: _weightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'),
                                    ),
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 65.5',
                                    suffixIcon: const Icon(
                                      Icons.scale,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val != null && val.trim().isNotEmpty) {
                                      final n = double.tryParse(val.trim());
                                      if (n == null || n <= 0)
                                        return 'Must be > 0 kg';
                                    }
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
                                _buildLabel('Height (cm)'),
                                TextFormField(
                                  controller: _heightCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'),
                                    ),
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText: 'e.g. 170',
                                    suffixIcon: const Icon(
                                      Icons.height,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val != null && val.trim().isNotEmpty) {
                                      final n = double.tryParse(val.trim());
                                      if (n == null || n <= 0)
                                        return 'Must be > 0 cm';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: AppTheme.cancelButton,
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: AppTheme.primaryButton,
                            icon: _isSavingVitals
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                            label: Text(
                              _isSavingVitals
                                  ? 'Saving...'
                                  : 'Save Vitals Entry',
                            ),
                            onPressed: _isSavingVitals
                                ? null
                                : () async {
                                    if (!(_formKeyVitals.currentState
                                            ?.validate() ??
                                        false)) {
                                      return;
                                    }

                                    final sys = int.tryParse(_sysBpCtrl.text);
                                    final dia = int.tryParse(_diaBpCtrl.text);
                                    final pulse = int.tryParse(_pulseCtrl.text);
                                    final temp = double.tryParse(
                                      _tempCtrl.text,
                                    );
                                    final spo2 = int.tryParse(_spo2Ctrl.text);
                                    final sugar = int.tryParse(_sugarCtrl.text);
                                    final weight = double.tryParse(
                                      _weightCtrl.text,
                                    );
                                    final height = double.tryParse(
                                      _heightCtrl.text,
                                    );

                                    setDialogState(
                                      () => _isSavingVitals = true,
                                    );
                                    final success = await controller
                                        .submitVitals(visit.id, {
                                          'systolic_bp': sys,
                                          'diastolic_bp': dia,
                                          'pulse_rate': pulse,
                                          'temperature': temp,
                                          'spo2': spo2,
                                          'blood_sugar': sugar,
                                          'weight': weight,
                                          'height': height,
                                          'bypass_schedule': true,
                                        });
                                    setDialogState(
                                      () => _isSavingVitals = false,
                                    );

                                    if (success && mounted) {
                                      _clearVitalsForm();
                                      Navigator.of(dialogCtx).pop();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Patient vitals recorded successfully',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            controller.errorMessage ??
                                                'Failed to record vitals',
                                          ),
                                          backgroundColor: AppTheme.dangerColor,
                                        ),
                                      );
                                    }
                                  },
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
      ),
    );
  }

  Widget _buildVitalsTab(HomeVisitModel visit, HomeVisitController controller) {
    final vitalsFormCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Form(
        key: _formKeyVitals,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Patient Vital Signs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 14),

            // Row 1: BP Systolic, BP Diastolic
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Systolic BP (mmHg) *'),
                      TextFormField(
                        controller: _sysBpCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 120',
                          suffixIcon: const Icon(
                            Icons.speed,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Mandatory';
                          final n = int.tryParse(val.trim());
                          if (n == null || n < 90 || n > 300)
                            return '90-300 mmHg';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Diastolic BP (mmHg) *'),
                      TextFormField(
                        controller: _diaBpCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 80',
                          suffixIcon: const Icon(
                            Icons.speed,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Mandatory';
                          final n = int.tryParse(val.trim());
                          if (n == null || n < 50 || n > 180)
                            return '50-180 mmHg';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Pulse Rate, Temperature
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Pulse Rate (bpm)'),
                      TextFormField(
                        controller: _pulseCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 72',
                          suffixIcon: const Icon(
                            Icons.favorite_border,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = int.tryParse(val.trim());
                            if (n == null || n < 30 || n > 250)
                              return 'Invalid pulse';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Temperature (°F) *'),
                      TextFormField(
                        controller: _tempCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 98.6',
                          suffixIcon: const Icon(
                            Icons.thermostat,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Mandatory';
                          final n = double.tryParse(val.trim());
                          if (n == null || n < 90 || n > 115)
                            return '90-115 °F';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3: SpO2, Blood Sugar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('SpO2 (%)'),
                      TextFormField(
                        controller: _spo2Ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 98',
                          suffixIcon: const Icon(
                            Icons.air,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = int.tryParse(val.trim());
                            if (n == null || n < 50 || n > 100)
                              return '50-100%';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Blood Sugar (mg/dL)'),
                      TextFormField(
                        controller: _sugarCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 110',
                          suffixIcon: const Icon(
                            Icons.water_drop_outlined,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = int.tryParse(val.trim());
                            if (n == null || n < 30 || n > 600)
                              return '30-600 mg/dL';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 4: Weight, Height
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Weight (kg)'),
                      TextFormField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 65.5',
                          suffixIcon: const Icon(
                            Icons.scale,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = double.tryParse(val.trim());
                            if (n == null || n <= 0) return 'Must be > 0 kg';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Height (cm)'),
                      TextFormField(
                        controller: _heightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'e.g. 170',
                          suffixIcon: const Icon(
                            Icons.height,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = double.tryParse(val.trim());
                            if (n == null || n <= 0) return 'Must be > 0 cm';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: AppTheme.primaryButton,
                icon: _isSavingVitals
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.favorite, size: 18),
                label: Text(
                  _isSavingVitals ? 'Saving Vitals...' : 'Save Vitals Entry',
                ),
                onPressed: _isSavingVitals
                    ? null
                    : () async {
                        if (!(_formKeyVitals.currentState?.validate() ??
                            false)) {
                          return;
                        }

                        final sys = int.tryParse(_sysBpCtrl.text);
                        final dia = int.tryParse(_diaBpCtrl.text);
                        final pulse = int.tryParse(_pulseCtrl.text);
                        final temp = double.tryParse(_tempCtrl.text);
                        final spo2 = int.tryParse(_spo2Ctrl.text);
                        final sugar = int.tryParse(_sugarCtrl.text);
                        final weight = double.tryParse(_weightCtrl.text);
                        final height = double.tryParse(_heightCtrl.text);

                        setState(() => _isSavingVitals = true);
                        final success = await controller
                            .submitVitals(visit.id, {
                              'systolic_bp': sys,
                              'diastolic_bp': dia,
                              'pulse_rate': pulse,
                              'temperature': temp,
                              'spo2': spo2,
                              'blood_sugar': sugar,
                              'weight': weight,
                              'height': height,
                              'bypass_schedule': true,
                            });
                        setState(() => _isSavingVitals = false);

                        if (success) {
                          _clearVitalsForm();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Patient vitals recorded successfully',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.errorMessage ??
                                    'Failed to record vitals',
                              ),
                              backgroundColor: AppTheme.dangerColor,
                            ),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );

    final totalVitals = visit.vitalsHistory.length;
    final totalVitalsPages = (totalVitals == 0)
        ? 1
        : ((totalVitals - 1) ~/ _pageSize) + 1;
    final currentVitalsPage = _vitalsPage.clamp(1, totalVitalsPages);
    final vitalsStartIdx = (currentVitalsPage - 1) * _pageSize;
    final vitalsEndIdx = (vitalsStartIdx + _pageSize < totalVitals)
        ? vitalsStartIdx + _pageSize
        : totalVitals;
    final pageVitals = (vitalsStartIdx < totalVitals)
        ? visit.vitalsHistory.sublist(vitalsStartIdx, vitalsEndIdx)
        : <HomeVisitVitals>[];

    final vitalsTableCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Patient Vitals History Log',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalVitals Entry(ies)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visit.vitalsHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No vital signs recorded yet today.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 700),
                    child: Table(
                      defaultColumnWidth: const FlexColumnWidth(),
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFEDF2F7),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Center(
                                child: Text(
                                  'Date & Time Recorded',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'BP (mmHg)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Pulse (bpm)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Temp (°F)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'SpO₂ (%)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Sugar (mg/dL)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Weight (kg)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Height (cm)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        for (int idx = 0; idx < pageVitals.length; idx++) ...[
                          () {
                            final v = pageVitals[idx];
                            return TableRow(
                              decoration: BoxDecoration(
                                color: idx.isEven
                                    ? Colors.white
                                    : const Color(0xFFF8FAFC),
                                border: idx < pageVitals.length - 1
                                    ? const Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFEDF2F7),
                                        ),
                                      )
                                    : null,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  child: Center(
                                    child: _buildTimestampBadge(
                                      v.recordedAt,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    '${v.systolicBp ?? "--"} / ${v.diastolicBp ?? "--"}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    v.pulseRate != null
                                        ? '${v.pulseRate} bpm'
                                        : '--',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    v.temperature != null
                                        ? '${v.temperature} °F'
                                        : '--',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    v.spo2 != null ? '${v.spo2}%' : '--',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    v.bloodSugar != null
                                        ? '${v.bloodSugar} mg/dL'
                                        : '--',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    v.weight != null ? '${v.weight} kg' : '--',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    v.height != null ? '${v.height} cm' : '--',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Showing ${totalVitals == 0 ? 0 : vitalsStartIdx + 1}-$vitalsEndIdx of $totalVitals entries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentVitalsPage > 1
                          ? () => setState(() => _vitalsPage--)
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: const Text(
                        'Previous',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $currentVitalsPage of $totalVitalsPages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentVitalsPage < totalVitalsPages
                          ? () => setState(() => _vitalsPage++)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: const Text('Next', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),

          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSectionHeader(
                'Record Patient Vitals Entry',
                Icons.monitor_heart_outlined,
              ),
              ElevatedButton.icon(
                style: AppTheme.primaryButton,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Add Vitals Entry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () =>
                    _showAddVitalsModalDialog(context, visit, controller),
              ),
            ],
          ),
          const SizedBox(height: 20),
          vitalsTableCard,
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modal Dialog to Record or Update Vitals for a Specific Slot
  void _showRecordVitalsModal(
    BuildContext context,
    HomeVisitModel visit,
    HomeVisitController controller,
    String slotTime,
    HomeVisitVitals? existingVital,
  ) {
    final formKey = GlobalKey<FormState>();
    final sysCtrl = TextEditingController(
      text: existingVital?.systolicBp?.toString() ?? '',
    );
    final diaCtrl = TextEditingController(
      text: existingVital?.diastolicBp?.toString() ?? '',
    );
    final pulseCtrl = TextEditingController(
      text: existingVital?.pulseRate?.toString() ?? '',
    );
    final tempCtrl = TextEditingController(
      text: existingVital?.temperature?.toString() ?? '',
    );
    final spo2Ctrl = TextEditingController(
      text: existingVital?.spo2?.toString() ?? '',
    );
    final sugarCtrl = TextEditingController(
      text: existingVital?.bloodSugar?.toString() ?? '',
    );
    final weightCtrl = TextEditingController(
      text: existingVital?.weight?.toString() ?? '',
    );
    final heightCtrl = TextEditingController(
      text: existingVital?.height?.toString() ?? '',
    );

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.all(20),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.monitor_heart,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Vitals — $slotTime Slot',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          'Patient: ${visit.patientName ?? "Patient #${visit.patientId}"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dCtx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Systolic BP (mmHg) *'),
                                  TextFormField(
                                    controller: sysCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '90 - 300',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Systolic BP is required (90-300 mmHg)';
                                      }
                                      final num = int.tryParse(val);
                                      if (num == null || num < 90 || num > 300)
                                        return 'Must be 90-300 mmHg';
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
                                  _buildLabel('Diastolic BP (mmHg) *'),
                                  TextFormField(
                                    controller: diaCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '50 - 180',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Diastolic BP is required (50-180 mmHg)';
                                      }
                                      final num = int.tryParse(val);
                                      if (num == null || num < 50 || num > 180)
                                        return 'Must be 50-180 mmHg';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Pulse Rate (bpm)'),
                                  TextFormField(
                                    controller: pulseCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '40 - 200',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty)
                                        return null;
                                      final num = int.tryParse(val);
                                      if (num == null || num < 40 || num > 200)
                                        return 'Must be 40-200 bpm';
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
                                  _buildLabel('Body Temperature (°F) *'),
                                  TextFormField(
                                    controller: tempCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '90 - 115 °F',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Temperature is required (90-115 °F)';
                                      }
                                      final num = double.tryParse(val);
                                      if (num == null || num < 90 || num > 115)
                                        return 'Must be 90-115 °F';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('SpO₂ Level (%)'),
                                  TextFormField(
                                    controller: spo2Ctrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '70 - 100%',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty)
                                        return null;
                                      final num = int.tryParse(val);
                                      if (num == null || num < 70 || num > 100)
                                        return 'Must be 70-100%';
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
                                  _buildLabel('Blood Sugar (mg/dL)'),
                                  TextFormField(
                                    controller: sugarCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '30 - 600 mg/dL',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty)
                                        return null;
                                      final num = double.tryParse(val);
                                      if (num == null || num < 30 || num > 600)
                                        return 'Must be 30-600 mg/dL';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Weight (kg) *'),
                                  TextFormField(
                                    controller: weightCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '> 0 kg',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Weight is required (> 0 kg)';
                                      }
                                      final num = double.tryParse(val);
                                      if (num == null || num <= 0)
                                        return 'Must be > 0 kg';
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
                                  _buildLabel('Height (cm) *'),
                                  TextFormField(
                                    controller: heightCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: '> 0 cm',
                                        ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Height is required (> 0 cm)';
                                      }
                                      final num = double.tryParse(val);
                                      if (num == null || num <= 0)
                                        return 'Must be > 0 cm';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: AppTheme.primaryButton,
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDState(() => isSaving = true);
                            final success = await controller.submitVitals(
                              visit.id,
                              {
                                if (existingVital != null)
                                  'vitals_id': existingVital.id,
                                'bypass_schedule': true,
                                'systolic_bp': int.tryParse(sysCtrl.text),
                                'diastolic_bp': int.tryParse(diaCtrl.text),
                                'pulse_rate': int.tryParse(pulseCtrl.text),
                                'temperature': double.tryParse(tempCtrl.text),
                                'spo2': int.tryParse(spo2Ctrl.text),
                                'blood_sugar': double.tryParse(sugarCtrl.text),
                                'weight': double.tryParse(weightCtrl.text),
                                'height': double.tryParse(heightCtrl.text),
                              },
                            );
                            setDState(() => isSaving = false);
                            if (success && context.mounted) {
                              Navigator.pop(dCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    existingVital != null
                                        ? 'Vitals for $slotTime updated successfully!'
                                        : 'Vitals for $slotTime recorded successfully!',
                                  ),
                                  backgroundColor: AppTheme.secondaryColor,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          existingVital != null
                              ? 'Update $slotTime Vitals'
                              : 'Save $slotTime Vitals',
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVitalsScheduleStatusBanner(VitalsScheduleStatusModel? status) {
    return const SizedBox.shrink();
  }

  Widget _buildVitalsHistoryTable(List<HomeVisitVitals> history) {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No vital signs recorded yet today.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(
                label: Text(
                  'Date & Time Recorded',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'BP (mmHg)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Pulse (bpm)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Temp (°F)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'SpO₂ (%)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Sugar (mg/dL)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Weight / Height',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: history.map((v) {
              String timeStr = 'N/A';
              if (v.recordedAt != null) {
                try {
                  final dt = DateTime.parse(v.recordedAt!).toLocal();
                  int h = dt.hour % 12;
                  if (h == 0) h = 12;
                  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                  final m = dt.minute.toString().padLeft(2, '0');
                  final day = dt.day.toString().padLeft(2, '0');
                  final month = dt.month.toString().padLeft(2, '0');
                  final year = dt.year;
                  timeStr = '$day-$month-$year • $h:$m $ampm';
                } catch (_) {
                  timeStr = v.recordedAt!;
                }
              }

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  DataCell(
                    Text('${v.systolicBp ?? "--"} / ${v.diastolicBp ?? "--"}'),
                  ),
                  DataCell(
                    Text(v.pulseRate != null ? '${v.pulseRate} bpm' : '--'),
                  ),
                  DataCell(
                    Text(v.temperature != null ? '${v.temperature} °F' : '--'),
                  ),
                  DataCell(Text(v.spo2 != null ? '${v.spo2}%' : '--')),
                  DataCell(
                    Text(v.bloodSugar != null ? '${v.bloodSugar} mg/dL' : '--'),
                  ),
                  DataCell(
                    Text('${v.weight ?? "--"} kg / ${v.height ?? "--"} cm'),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showVitalsScheduleConfigDialog(
    BuildContext context,
    HomeVisitController controller,
    VitalsScheduleStatusModel? currentStatus,
  ) {
    final startCtrl = TextEditingController(
      text: currentStatus?.startTime ?? '09:00',
    );
    final endCtrl = TextEditingController(
      text: currentStatus?.endTime ?? '18:00',
    );
    final intervalCtrl = TextEditingController(
      text: (currentStatus?.intervalMinutes ?? 60).toString(),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(
          'Configure Vitals Schedule Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Define the monitoring window and minimum interval between vitals submissions:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildLabel('Monitoring Start Time (24h e.g. 09:00)'),
            TextField(
              controller: startCtrl,
              decoration: AppTheme.standardInputDecoration(hintText: '09:00'),
            ),
            const SizedBox(height: 12),
            _buildLabel('Monitoring End Time (24h e.g. 18:00)'),
            TextField(
              controller: endCtrl,
              decoration: AppTheme.standardInputDecoration(hintText: '18:00'),
            ),
            const SizedBox(height: 12),
            _buildLabel('Interval Duration (Minutes)'),
            TextField(
              controller: intervalCtrl,
              keyboardType: TextInputType.number,
              decoration: AppTheme.standardInputDecoration(hintText: '60'),
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
              final interval = int.tryParse(intervalCtrl.text) ?? 60;
              final success = await controller.updateVitalsConfig(
                startCtrl.text,
                endCtrl.text,
                interval,
              );
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Vitals schedule configuration updated successfully!',
                    ),
                    backgroundColor: AppTheme.secondaryColor,
                  ),
                );
              }
            },
            child: const Text('Save Schedule Config'),
          ),
        ],
      ),
    );
  }

  // 3. Care & Procedures Tab (Dressing, Nail Trimming, Care Activities, Nursing Notes)
  Widget _buildCareTab(HomeVisitModel visit, HomeVisitController controller) {
    final nursingCareFormCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Form(
        key: _formKeyCare,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record Nursing Care Entry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('Nursing Notes & Observations'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: AppTheme.standardInputDecoration(
                hintText:
                    'Enter clinical observations, general health condition, and comments...',
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('Dressing Procedures & Wound Care Details'),
            TextFormField(
              controller: _dressingCtrl,
              maxLines: 3,
              decoration: AppTheme.standardInputDecoration(
                hintText:
                    'Describe wound site, cleaning agent used, sterile dressing applied, etc.',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: CheckboxListTile(
                activeColor: AppTheme.primaryColor,
                title: const Text(
                  'Nail Trimming & Hygiene Care Activity Performed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text(
                  'Check if nail trimming or foot care was performed during visit.',
                ),
                value: _nailTrimmingDone,
                onChanged: (val) {
                  setState(() {
                    _nailTrimmingDone = val ?? false;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('Other Personal Care & Nursing Activities'),
            TextFormField(
              controller: _otherCareCtrl,
              maxLines: 2,
              decoration: AppTheme.standardInputDecoration(
                hintText:
                    'Catheter care, bed bath assistance, oral hygiene, position changes, etc.',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: _isSavingCare
                    ? null
                    : () async {
                        setState(() => _isSavingCare = true);
                        final success = await controller
                            .submitCareActivities(visit.id, {
                              'nursing_notes': _notesCtrl.text,
                              'dressing_procedures': _dressingCtrl.text,
                              'nail_trimming_done': _nailTrimmingDone,
                              'other_care_activities': _otherCareCtrl.text,
                            });
                        setState(() => _isSavingCare = false);
                        if (success && mounted) {
                          _clearCareForm();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nursing care details saved successfully! Form cleared for new entries.',
                              ),
                              backgroundColor: AppTheme.secondaryColor,
                            ),
                          );
                        }
                      },
                child: _isSavingCare
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Nursing Care Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    final careList = visit.careActivitiesHistory.isNotEmpty
        ? visit.careActivitiesHistory
        : (visit.careActivities != null
              ? [visit.careActivities!]
              : <HomeVisitCareActivities>[]);
    final totalCare = careList.length;
    final totalCarePages = (totalCare == 0)
        ? 1
        : ((totalCare - 1) ~/ _pageSize) + 1;
    final currentCarePage = _carePage.clamp(1, totalCarePages);
    final careStartIdx = (currentCarePage - 1) * _pageSize;
    final careEndIdx = (careStartIdx + _pageSize < totalCare)
        ? careStartIdx + _pageSize
        : totalCare;
    final pageCare = (careStartIdx < totalCare)
        ? careList.sublist(careStartIdx, careEndIdx)
        : <HomeVisitCareActivities>[];

    final nursingCareTableCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recorded Nursing Care History Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalCare Entry(ies)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (careList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No nursing care activities recorded yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(110),
                      1: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFEDF2F7),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Center(
                              child: Text(
                                'Date & Time Recorded',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(
                              'Care Activities & Observations Logged',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (int idx = 0; idx < pageCare.length; idx++) ...[
                        () {
                          final c = pageCare[idx];
                          return TableRow(
                            decoration: BoxDecoration(
                              color: idx.isEven
                                  ? Colors.white
                                  : const Color(0xFFF8FAFC),
                              border: idx < pageCare.length - 1
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFEDF2F7),
                                      ),
                                    )
                                  : null,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                                child: Center(
                                  child: _buildTimestampBadge(
                                    c.createdAt,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (c.nursingNotes != null &&
                                        c.nursingNotes!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Notes: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                              TextSpan(
                                                text: c.nursingNotes,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (c.dressingProcedures != null &&
                                        c.dressingProcedures!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Dressing: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.purple,
                                                ),
                                              ),
                                              TextSpan(
                                                text: c.dressingProcedures,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (c.nailTrimmingDone)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            '✓ Nail Trimming & Hygiene Done',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (c.otherCareActivities != null &&
                                        c.otherCareActivities!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Other Care: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                              TextSpan(
                                                text: c.otherCareActivities,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black87,
                                                ),
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
                        }(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalCare == 0 ? 0 : careStartIdx + 1}-$careEndIdx of $totalCare entries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentCarePage > 1
                          ? () => setState(() => _carePage--)
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: const Text(
                        'Previous',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $currentCarePage of $totalCarePages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentCarePage < totalCarePages
                          ? () => setState(() => _carePage++)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: const Text('Next', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Nursing Notes & Care Activities',
            Icons.edit_note_outlined,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT SIDE: Form Box (Increased width)
                    Expanded(flex: 6, child: nursingCareFormCard),
                    const SizedBox(width: 20),
                    // RIGHT SIDE: History Table Box (Reduced width)
                    Expanded(flex: 6, child: nursingCareTableCard),
                  ],
                );
              }

              return Column(
                children: [
                  nursingCareFormCard,
                  const SizedBox(height: 20),
                  nursingCareTableCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // 4. Medicines & Consumables Tab
  Widget _buildMedsAndConsumablesTab(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final activeMedicines = visit.medicines.where((m) {
      if (m.administeredAt == null || m.administeredAt!.isEmpty) return true;
      try {
        final formatted = m.administeredAt!.trim().replaceAll(' ', 'T');
        final dt = DateTime.parse(formatted);
        final recDate = dt.isUtc ? dt.toLocal() : dt;
        final medDateStr =
            "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
        return medDateStr == todayStr || medDateStr == visit.scheduledDate;
      } catch (_) {
        return true;
      }
    }).toList();

    final activeConsumables = visit.consumables.where((c) {
      if (c.createdAt == null || c.createdAt!.isEmpty) return true;
      try {
        final formatted = c.createdAt!.trim().replaceAll(' ', 'T');
        final dt = DateTime.parse(formatted);
        final recDate = dt.isUtc ? dt.toLocal() : dt;
        final consDateStr =
            "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
        return consDateStr == todayStr || consDateStr == visit.scheduledDate;
      } catch (_) {
        return true;
      }
    }).toList();

    final medicinesFormCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Medicines Administered',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          _buildLabel('Medicine Name'),
          CustomDropdownSearch(
            label: '',
            hint: 'Select or type medicine (e.g. Paracetamol)',
            dropdownItems: _dbMedicines.isNotEmpty
                ? _dbMedicines
                : _defaultMedicines,
            value: _medNameCtrl.text.isNotEmpty ? _medNameCtrl.text : null,
            allowFreeText: true,
            onChanged: (val) {
              setState(() {
                _medNameCtrl.text = val ?? '';
                _updateMedicinePrice(val);
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Dosage'),
                    TextFormField(
                      controller: _medDosageCtrl,
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Dosage (500mg)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Qty'),
                    TextFormField(
                      controller: _medQtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Qty',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Unit Price ₹'),
                    TextFormField(
                      controller: _medPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Price ₹',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: AppTheme.secondaryButton,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Medicine Item'),
              onPressed: () async {
                if (_medNameCtrl.text.trim().isEmpty) return;
                final success = await controller.submitMedicine(visit.id, {
                  'medicine_name': _medNameCtrl.text.trim(),
                  'dosage': _medDosageCtrl.text.trim(),
                  'route': 'Oral',
                  'quantity': int.tryParse(_medQtyCtrl.text) ?? 1,
                  'unit_price': double.tryParse(_medPriceCtrl.text) ?? 0.0,
                });
                if (success) {
                  _clearMedForm();
                }
              },
            ),
          ),
        ],
      ),
    );

    final consumablesFormCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Consumables Used',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          _buildLabel('Consumable Item'),
          CustomDropdownSearch(
            label: '',
            hint: 'Select or type consumable (e.g. Sterile Bandage)',
            dropdownItems: _dbConsumables.isNotEmpty
                ? _dbConsumables
                : _defaultConsumables,
            value: _consNameCtrl.text.isNotEmpty ? _consNameCtrl.text : null,
            allowFreeText: true,
            onChanged: (val) {
              setState(() {
                _consNameCtrl.text = val ?? '';
                _updateConsumablePrice(val);
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Qty Used'),
                    TextFormField(
                      controller: _consQtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Qty',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Unit Price ₹'),
                    TextFormField(
                      controller: _consPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: AppTheme.standardInputDecoration(
                        hintText: 'Price ₹',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: AppTheme.secondaryButton,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Consumable Item'),
              onPressed: () async {
                if (_consNameCtrl.text.trim().isEmpty) return;
                final success = await controller.submitConsumable(visit.id, {
                  'item_name': _consNameCtrl.text.trim(),
                  'quantity_used': int.tryParse(_consQtyCtrl.text) ?? 1,
                  'unit_price': double.tryParse(_consPriceCtrl.text) ?? 0.0,
                });
                if (success) {
                  _clearConsForm();
                }
              },
            ),
          ),
        ],
      ),
    );

    final totalMeds = activeMedicines.length;
    final totalMedsPages = (totalMeds == 0)
        ? 1
        : ((totalMeds - 1) ~/ _pageSize) + 1;
    final currentMedsPage = _medsPage.clamp(1, totalMedsPages);
    final medsStartIdx = (currentMedsPage - 1) * _pageSize;
    final medsEndIdx = (medsStartIdx + _pageSize < totalMeds)
        ? medsStartIdx + _pageSize
        : totalMeds;
    final pageMedicines = (medsStartIdx < totalMeds)
        ? activeMedicines.sublist(medsStartIdx, medsEndIdx)
        : <HomeVisitMedicine>[];

    final totalCons = activeConsumables.length;
    final totalConsPages = (totalCons == 0)
        ? 1
        : ((totalCons - 1) ~/ _pageSize) + 1;
    final currentConsPage = _consPage.clamp(1, totalConsPages);
    final consStartIdx = (currentConsPage - 1) * _pageSize;
    final consEndIdx = (consStartIdx + _pageSize < totalCons)
        ? consStartIdx + _pageSize
        : totalCons;
    final pageConsumables = (consStartIdx < totalCons)
        ? activeConsumables.sublist(consStartIdx, consEndIdx)
        : <HomeVisitConsumable>[];

    final medicinesTableCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recorded Medicines History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalMeds Item(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeMedicines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No medicines recorded yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3.5),
                      1: FlexColumnWidth(2.5),
                      2: FlexColumnWidth(3.5),
                      3: FlexColumnWidth(2.0),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFEDF2F7),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'Medicine & Dosage',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text(
                              'Qty & Price',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Center(
                              child: Text(
                                'Recorded Date & Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (int idx = 0; idx < pageMedicines.length; idx++) ...[
                        () {
                          final m = pageMedicines[idx];
                          final dosageStr =
                              (m.dosage != null && m.dosage!.isNotEmpty)
                              ? ' (${m.dosage})'
                              : '';
                          return TableRow(
                            decoration: BoxDecoration(
                              color: idx.isEven
                                  ? Colors.white
                                  : const Color(0xFFF8FAFC),
                              border: idx < pageMedicines.length - 1
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFEDF2F7),
                                      ),
                                    )
                                  : null,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.medication,
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${m.medicineName}$dosageStr',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Text(
                                  '${m.quantity} × ₹${m.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Center(
                                  child: _buildTimestampBadge(
                                    m.administeredAt,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '₹${(m.quantity * m.unitPrice).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalMeds == 0 ? 0 : medsStartIdx + 1}-$medsEndIdx of $totalMeds entries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentMedsPage > 1
                          ? () => setState(() => _medsPage--)
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: const Text(
                        'Previous',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $currentMedsPage of $totalMedsPages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentMedsPage < totalMedsPages
                          ? () => setState(() => _medsPage++)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: const Text('Next', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final consumablesTableCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recorded Consumables History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalCons Item(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeConsumables.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No consumable items recorded yet.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3.5),
                      1: FlexColumnWidth(2.5),
                      2: FlexColumnWidth(3.5),
                      3: FlexColumnWidth(2.0),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFEDF2F7),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'Consumable Item',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Text(
                              'Qty Used & Price',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Center(
                              child: Text(
                                'Recorded Date & Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (
                        int idx = 0;
                        idx < pageConsumables.length;
                        idx++
                      ) ...[
                        () {
                          final c = pageConsumables[idx];
                          return TableRow(
                            decoration: BoxDecoration(
                              color: idx.isEven
                                  ? Colors.white
                                  : const Color(0xFFF8FAFC),
                              border: idx < pageConsumables.length - 1
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFEDF2F7),
                                      ),
                                    )
                                  : null,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.clean_hands,
                                      size: 16,
                                      color: AppTheme.secondaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c.itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Text(
                                  '${c.quantityUsed} × ₹${c.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Center(
                                  child: _buildTimestampBadge(
                                    c.createdAt,
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '₹${(c.quantityUsed * c.unitPrice).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalCons == 0 ? 0 : consStartIdx + 1}-$consEndIdx of $totalCons entries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentConsPage > 1
                          ? () => setState(() => _consPage--)
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: const Text(
                        'Previous',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $currentConsPage of $totalConsPages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: currentConsPage < totalConsPages
                          ? () => setState(() => _consPage++)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: const Text('Next', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Log Administered Medicines & Used Consumables',
            Icons.medication_liquid_outlined,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT SIDE: Input Forms (Increased width)
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          medicinesFormCard,
                          const SizedBox(height: 20),
                          consumablesFormCard,
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // RIGHT SIDE: Entered History Tables (Reduced width)
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          medicinesTableCard,
                          const SizedBox(height: 20),
                          consumablesTableCard,
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Fallback for narrow screen widths
              return Column(
                children: [
                  medicinesFormCard,
                  const SizedBox(height: 16),
                  medicinesTableCard,
                  const SizedBox(height: 24),
                  consumablesFormCard,
                  const SizedBox(height: 16),
                  consumablesTableCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // 5. Time-based Photo Evidence Tab
  Widget _buildPhotosTab(HomeVisitModel visit, HomeVisitController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Timestamped Photo Evidence Upload & Gallery',
            Icons.insert_photo_outlined,
          ),
          const SizedBox(height: 20),

          // Photo Evidence Upload Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Timestamped Photo Evidence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, photoConstraints) {
                    final isMobilePhoto = photoConstraints.maxWidth < 600;
                    final categoryDropdown = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Photo Category *'),
                        CustomDropdownSearch(
                          label: '',
                          hint: 'Select Photo Category',
                          dropdownMap: const {
                            'Dressing Pre-Procedure': 'Pre-Dressing Wound Photo',
                            'Dressing Post-Procedure': 'Post-Dressing Photo',
                            'Care Activity': 'Care Activity Evidence',
                            'General Care': 'General Visit Photo',
                          },
                          value: _selectedPhotoCategory,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedPhotoCategory = val);
                            }
                          },
                        ),
                      ],
                    );
                    final filePicker = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Photo Evidence File *'),
                        InkWell(
                          onTap: _pickPhoto,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _photoFormatError != null
                                  ? const Color(0xFFFEF2F2)
                                  : (_selectedPhotoName != null
                                        ? const Color(0xFFF0FDF4)
                                        : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _photoFormatError != null
                                    ? AppTheme.dangerColor
                                    : (_selectedPhotoName != null
                                          ? AppTheme.secondaryColor
                                          : const Color(0xFFCBD5E0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _photoFormatError != null
                                      ? Icons.error
                                      : (_selectedPhotoName != null
                                            ? Icons.check_circle
                                            : Icons.cloud_upload_outlined),
                                  color: _photoFormatError != null
                                      ? AppTheme.dangerColor
                                      : (_selectedPhotoName != null
                                            ? AppTheme.secondaryColor
                                            : AppTheme.primaryColor),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedPhotoName != null
                                        ? 'Selected: $_selectedPhotoName'
                                        : 'Click to Browse & Upload Image (JPG, PNG, WEBP, HEIC)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedPhotoName != null
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: _photoFormatError != null
                                          ? AppTheme.dangerColor
                                          : (_selectedPhotoName != null
                                                ? Colors.green.shade800
                                                : Colors.black87),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _photoFormatError != null
                                        ? AppTheme.dangerColor
                                        : AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Browse File',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_photoFormatError != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppTheme.dangerColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _photoFormatError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.dangerColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                    return isMobilePhoto
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              categoryDropdown,
                              const SizedBox(height: 12),
                              filePicker,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: categoryDropdown),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: filePicker),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, captionConstraints) {
                    final isMobileCaption = captionConstraints.maxWidth < 500;
                    final captionField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Photo Notes / Caption (Optional)'),
                        TextFormField(
                          controller: _photoCaptionCtrl,
                          decoration: AppTheme.standardInputDecoration(
                            hintText:
                                'e.g. Wound cleaned, dressing applied intact...',
                          ),
                        ),
                      ],
                    );
                    final uploadBtn = SizedBox(
                      width: isMobileCaption ? double.infinity : null,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: AppTheme.secondaryButton,
                        icon: _isUploadingPhoto
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_a_photo),
                        label: Text(
                          _isUploadingPhoto ? 'Uploading...' : 'Upload Photo Evidence',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isUploadingPhoto
                            ? null
                            : () async {
                                if (_selectedPhotoName == null &&
                                    _selectedPhotoBytes == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select an image file to upload.',
                                      ),
                                      backgroundColor: AppTheme.dangerColor,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isUploadingPhoto = true);
                                String? cloudinaryUrl;
                                if (_selectedPhotoBytes != null) {
                                  try {
                                    cloudinaryUrl =
                                        await MediaService.uploadToCloudinary(
                                          fileBytes: _selectedPhotoBytes!,
                                          fileName:
                                              _selectedPhotoName ??
                                              'photo.jpg',
                                          folder: 'home_visits',
                                        );
                                  } catch (err) {
                                    debugPrint(
                                      'Cloudinary upload fallback: $err',
                                    );
                                  }
                                }

                                final photoPath =
                                    cloudinaryUrl ??
                                    'uploads/evidence_${DateTime.now().millisecondsSinceEpoch}_${_selectedPhotoName ?? "photo.jpg"}';

                                final success = await controller
                                    .submitPhotoEvidence(
                                      visit.id,
                                      photoPath,
                                      _selectedPhotoCategory,
                                      _photoCaptionCtrl.text,
                                    );
                                setState(() => _isUploadingPhoto = false);

                                if (success && mounted) {
                                  _clearPhotoForm();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Photo evidence uploaded to Cloudinary successfully!',
                                      ),
                                      backgroundColor:
                                          AppTheme.secondaryColor,
                                    ),
                                  );
                                }
                              },
                      ),
                    );
                    if (isMobileCaption) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          captionField,
                          const SizedBox(height: 12),
                          uploadBtn,
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: captionField),
                          const SizedBox(width: 16),
                          uploadBtn,
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),

                if (visit.photos.isNotEmpty) ...[
                  const Text(
                    'Captured Timestamped Photo Evidence Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final crossCount = gridConstraints.maxWidth < 400 ? 2
                          : gridConstraints.maxWidth < 600 ? 3
                          : 5;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.0,
                            ),
                        itemCount: visit.photos.length,
                        itemBuilder: (context, idx) {

                      final p = visit.photos[idx];
                      String timeStr = 'Just now';
                      if (p.capturedAt != null) {
                        try {
                          final dt = DateTime.parse(p.capturedAt!).toLocal();
                          int h = dt.hour % 12;
                          if (h == 0) h = 12;
                          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                          final m = dt.minute.toString().padLeft(2, '0');
                          final day = dt.day.toString().padLeft(2, '0');
                          final month = dt.month.toString().padLeft(2, '0');
                          final year = dt.year;
                          timeStr = '$day-$month-$year • $h:$m $ampm';
                        } catch (_) {
                          timeStr = p.capturedAt!;
                        }
                      }

                      final bool isNetworkImage =
                          p.photoUrl.startsWith('http://') ||
                          p.photoUrl.startsWith('https://');

                      return InkWell(
                        onTap: () => _showFullImagePreviewDialog(context, p),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Photo Thumbnail Image
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (isNetworkImage)
                                        Image.network(
                                          p.photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                                context,
                                                error,
                                                stackTrace,
                                              ) => Container(
                                                color: const Color(0xFFF1F5F9),
                                                child: const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: Colors.grey,
                                                      size: 36,
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      'Image unavailable',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  color: const Color(
                                                    0xFFF8FAFC,
                                                  ),
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: AppTheme
                                                                .primaryColor,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              },
                                        )
                                      else
                                        Container(
                                          color: const Color(0xFFF1F5F9),
                                          child: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.photo_library_outlined,
                                                color: AppTheme.primaryColor,
                                                size: 36,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Uploaded Evidence',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Zoom Icon Badge Overlay
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Card Details Footer
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.category ?? 'Photo Evidence',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppTheme.primaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (p.caption != null &&
                                        p.caption!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        p.caption!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

  // 6. Patient Attender Verification & Digital Signature Tab
  Widget _buildSignatureTab(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Patient Attender Verification & Digital Signature',
            Icons.draw_outlined,
          ),
          const SizedBox(height: 20),

          // Digital Attender Signature & Verification Form (Strict Style Guide rules)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient Attender Verification & Digital Signature',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Attender Full Name *'),
                          TextFormField(
                            controller: _attenderNameCtrl,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(30),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z\s]'),
                              ),
                            ],
                            decoration: AppTheme.standardInputDecoration(
                              hintText: 'Full Name (Min 3, Max 30 chars)',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length < 3) {
                                return 'Attender name must be at least 3 characters';
                              }
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
                          _buildLabel('Attender Relationship *'),
                          TextFormField(
                            controller: _attenderRelationCtrl,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(20),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z\s]'),
                              ),
                            ],
                            decoration: AppTheme.standardInputDecoration(
                              hintText: 'e.g. Son, Spouse, Daughter',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Attender relationship is required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLabel('Attender Digital Signature Pad *'),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _signaturePoints.isNotEmpty
                          ? AppTheme.primaryColor
                          : const Color(0xFFCBD5E0),
                      width: _signaturePoints.isNotEmpty ? 1.5 : 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        if (_signaturePoints.isEmpty)
                          const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.draw_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Draw attender signature here with mouse or touch...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            setState(() {
                              _signaturePoints.add(details.localPosition);
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _signaturePoints.add(details.localPosition);
                            });
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _signaturePoints.add(null);
                            });
                          },
                          child: CustomPaint(
                            painter: SignaturePainter(points: _signaturePoints),
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear Signature'),
                      onPressed: () => setState(() => _signaturePoints.clear()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: AppTheme.primaryButton,
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                          ),
                    label: Text(
                      _isVerifying
                          ? 'Generating Auto-Billing Invoice...'
                          : 'Verify Visit & Generate Billing Invoice',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isVerifying
                        ? null
                        : () async {
                            if (_attenderNameCtrl.text.trim().length < 3) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter valid attender name (min 3 chars).',
                                  ),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                              return;
                            }

                            setState(() => _isVerifying = true);
                            final result = await controller.verifyVisit(
                              visit.id,
                              _attenderNameCtrl.text.trim(),
                              _attenderRelationCtrl.text.trim(),
                              'signature_base64_data_valid',
                            );
                            setState(() => _isVerifying = false);

                            if (result != null && mounted) {
                              _clearSignatureForm();
                              showDialog(
                                context: context,
                                builder: (_) => HomeVisitInvoiceDialog(
                                  invoiceData: result,
                                  visit: visit,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEndVisitSignatureModal(
    BuildContext context,
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final nameCtrl = TextEditingController(text: _attenderNameCtrl.text);
    final relCtrl = TextEditingController(text: _attenderRelationCtrl.text);
    List<Offset?> sigPoints = List.from(_signaturePoints);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.draw_outlined,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'End Visit & Attender Verification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Patient Attender Verification & Digital Signature',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please record the attender details and obtain their signature to end the visit session and generate the billing invoice.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Attender Full Name *'),
                  TextFormField(
                    controller: nameCtrl,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(30),
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    decoration: AppTheme.standardInputDecoration(
                      hintText: 'Full Name (Min 3, Max 30 chars)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('Attender Relationship *'),
                  TextFormField(
                    controller: relCtrl,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    decoration: AppTheme.standardInputDecoration(
                      hintText: 'e.g. Son, Spouse, Daughter',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Attender Digital Signature Pad *'),
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sigPoints.isNotEmpty
                            ? AppTheme.primaryColor
                            : const Color(0xFFCBD5E0),
                        width: sigPoints.isNotEmpty ? 1.5 : 1.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          if (sigPoints.isEmpty)
                            const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.draw_outlined,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Draw attender signature here with mouse or touch...',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) {
                              setDialogState(
                                () => sigPoints.add(details.localPosition),
                              );
                            },
                            onPanUpdate: (details) {
                              setDialogState(
                                () => sigPoints.add(details.localPosition),
                              );
                            },
                            onPanEnd: (details) {
                              setDialogState(() => sigPoints.add(null));
                            },
                            child: CustomPaint(
                              painter: SignaturePainter(points: sigPoints),
                              size: Size.infinite,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text(
                          'Clear Signature',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () =>
                            setDialogState(() => sigPoints.clear()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: AppTheme.secondaryButton,
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                          label: Text(
                            isSubmitting
                                ? 'Processing...'
                                : 'Complete Visit & Create Invoice',
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (nameCtrl.text.trim().length < 3) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter valid attender name (min 3 chars).',
                                        ),
                                        backgroundColor: AppTheme.dangerColor,
                                      ),
                                    );
                                    return;
                                  }
                                  if (relCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter attender relationship.',
                                        ),
                                        backgroundColor: AppTheme.dangerColor,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSubmitting = true);
                                  _attenderNameCtrl.text = nameCtrl.text.trim();
                                  _attenderRelationCtrl.text = relCtrl.text
                                      .trim();

                                  final result = await controller.verifyVisit(
                                    visit.id,
                                    nameCtrl.text.trim(),
                                    relCtrl.text.trim(),
                                    'signature_base64_data_valid',
                                  );
                                  await controller.fetchVisits();

                                  if (result != null && mounted) {
                                    Navigator.of(dialogCtx).pop();
                                    showDialog(
                                      context: context,
                                      builder: (_) => HomeVisitInvoiceDialog(
                                        invoiceData: result,
                                        visit: visit,
                                        onCloseAndComplete: () {
                                          if (widget.onBack != null) {
                                            widget.onBack!();
                                          } else if (Navigator.of(
                                            context,
                                          ).canPop()) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Today's home visit marked as Completed & invoice generated!",
                                        ),
                                        backgroundColor:
                                            AppTheme.secondaryColor,
                                      ),
                                    );
                                  } else {
                                    setDialogState(() => isSubmitting = false);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 6. View Live Session Summary Tab (Live Real-Time Tracker for TODAY'S session entries ONLY)
  Widget _buildLiveSessionSummaryTab(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Filter vitals for TODAY / current scheduled session date ONLY
    final todayVitals = visit.vitalsHistory.where((v) {
      if (v.recordedAt == null || v.recordedAt!.isEmpty) return true;
      try {
        final formatted = v.recordedAt!.trim().replaceAll(' ', 'T');
        final dt = DateTime.parse(formatted);
        final recDate = dt.isUtc ? dt.toLocal() : dt;
        final dateStr =
            "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
        return dateStr == todayStr || dateStr == visit.scheduledDate;
      } catch (_) {
        return true;
      }
    }).toList();

    // Filter medicines for TODAY / current scheduled session date ONLY
    final todayMedicines = visit.medicines.where((m) {
      if (m.administeredAt == null || m.administeredAt!.isEmpty) return true;
      try {
        final formatted = m.administeredAt!.trim().replaceAll(' ', 'T');
        final dt = DateTime.parse(formatted);
        final recDate = dt.isUtc ? dt.toLocal() : dt;
        final dateStr =
            "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
        return dateStr == todayStr || dateStr == visit.scheduledDate;
      } catch (_) {
        return true;
      }
    }).toList();

    // Filter consumables for TODAY / current scheduled session date ONLY
    final todayConsumables = visit.consumables.where((c) {
      if (c.createdAt == null || c.createdAt!.isEmpty) return true;
      try {
        final formatted = c.createdAt!.trim().replaceAll(' ', 'T');
        final dt = DateTime.parse(formatted);
        final recDate = dt.isUtc ? dt.toLocal() : dt;
        final dateStr =
            "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
        return dateStr == todayStr || dateStr == visit.scheduledDate;
      } catch (_) {
        return true;
      }
    }).toList();

    // Filter photos for TODAY / current scheduled session date ONLY
    final todayPhotos = visit.photos.where((p) {
      if (p.capturedAt == null || p.capturedAt!.isEmpty) return true;
      try {
        final formatted = p.capturedAt!.trim().replaceAll(' ', 'T');
        final dt = DateTime.parse(formatted);
        final recDate = dt.isUtc ? dt.toLocal() : dt;
        final dateStr =
            "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
        return dateStr == todayStr || dateStr == visit.scheduledDate;
      } catch (_) {
        return true;
      }
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visit.status != 'Completed' && visit.status != 'Verified') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.secondaryColor.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.secondaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ready to Complete Today's Visit?",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Click below to capture attender signature, generate the itemized billing invoice, and mark today's home visit as Completed.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: AppTheme.secondaryButton.copyWith(
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.verified_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        "End Today's Visit",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => _showEndVisitSignatureModal(
                        context,
                        visit,
                        controller,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          _buildSectionHeader(
            'Today\'s Session Summary & Real-Time Tracker',
            Icons.analytics_outlined,
          ),
          const SizedBox(height: 16),

          // Real-time Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monitor_heart,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient: ${visit.patientName ?? "N/A"} (${visit.patientDisplayId ?? "N/A"})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Session: ${visit.scheduledDate} | Nurse: ${visit.nurseName ?? "N/A"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            visit.status == 'Verified' ||
                                visit.status == 'Completed'
                            ? Colors.green.shade50
                            : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              visit.status == 'Verified' ||
                                  visit.status == 'Completed'
                              ? Colors.green
                              : AppTheme.primaryColor,
                        ),
                      ),
                      child: Text(
                        visit.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              visit.status == 'Verified' ||
                                  visit.status == 'Completed'
                              ? Colors.green
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Live Summary Counters Row (Today's Entries Only)
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _liveSummaryChip(
                      Icons.devices,
                      'Kit Devices',
                      '${visit.carriedItems.length} Added',
                      AppTheme.primaryColor,
                    ),
                    _liveSummaryChip(
                      Icons.monitor_heart_outlined,
                      'Vitals Log',
                      '${todayVitals.length} Today Entries',
                      Colors.purple,
                    ),
                    _liveSummaryChip(
                      Icons.edit_note,
                      'Care Notes',
                      (visit.careActivitiesHistory.isNotEmpty ||
                              visit.careActivities != null)
                          ? '${visit.careActivitiesHistory.isNotEmpty ? visit.careActivitiesHistory.length : 1} Entry/Entries Recorded'
                          : 'Pending',
                      Colors.orange,
                    ),
                    _liveSummaryChip(
                      Icons.medication_liquid,
                      'Meds & Consumables',
                      '${todayMedicines.length} Meds / ${todayConsumables.length} Items Today',
                      AppTheme.secondaryColor,
                    ),
                    _liveSummaryChip(
                      Icons.camera_alt_outlined,
                      'Photos',
                      '${todayPhotos.length} Today Photos',
                      Colors.teal,
                    ),
                    _liveSummaryChip(
                      Icons.verified_user_outlined,
                      'Attender Verification',
                      visit.attenderName != null &&
                              visit.attenderName!.isNotEmpty
                          ? 'Verified (${visit.attenderName})'
                          : 'Pending',
                      visit.attenderName != null &&
                              visit.attenderName!.isNotEmpty
                          ? Colors.green
                          : AppTheme.dangerColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Kit Devices Added
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  '1. Carried & Used Kit Devices',
                  Icons.devices,
                ),
                const SizedBox(height: 12),
                if (visit.carriedItems.isEmpty)
                  const Text(
                    'No kit items or medical devices added yet in Kit & Devices tab.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      for (final item in visit.carriedItems)
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(
                              0.1,
                            ),
                            child: Icon(
                              item.itemType == 'Device'
                                  ? Icons.devices
                                  : Icons.medical_services,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          label: Text(
                            '${item.itemName} (${item.itemType} • Qty: ${item.quantityCarried})',
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Hourly Vitals Log (Today Only)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  '2. Today\'s Hourly Vitals Log',
                  Icons.monitor_heart_outlined,
                ),
                const SizedBox(height: 12),
                if (todayVitals.isEmpty)
                  const Text(
                    'No vitals logged today in Vitals tab.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Table(
                      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                          ),
                          children: [
                            _tableHeader('Recorded At'),
                            _tableHeader('BP (mmHg)'),
                            _tableHeader('Pulse (bpm)'),
                            _tableHeader('SpO2 (%)'),
                            _tableHeader('Temp (°F)'),
                            _tableHeader('Sugar (mg/dL)'),
                          ],
                        ),
                        for (final v in todayVitals)
                          TableRow(
                            children: [
                              _tableCell(
                                v.recordedAt != null
                                    ? () {
                                        try {
                                          final dt = DateTime.parse(
                                            v.recordedAt!,
                                          ).toLocal();
                                          int h = dt.hour % 12;
                                          if (h == 0) h = 12;
                                          final ampm = dt.hour >= 12
                                              ? 'PM'
                                              : 'AM';
                                          final m = dt.minute
                                              .toString()
                                              .padLeft(2, '0');
                                          return '$h:$m $ampm';
                                        } catch (_) {
                                          return v.recordedAt!;
                                        }
                                      }()
                                    : 'N/A',
                              ),
                              _tableCell(
                                '${v.systolicBp ?? "-"}/${v.diastolicBp ?? "-"}',
                              ),
                              _tableCell('${v.pulseRate ?? "-"}'),
                              _tableCell('${v.spo2 ?? "-"}'),
                              _tableCell('${v.temperature ?? "-"}'),
                              _tableCell('${v.bloodSugar ?? "-"}'),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Nursing Care & Dressing Notes (Today Only)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  '3. Today\'s Nursing Care & Dressing Records',
                  Icons.edit_note_outlined,
                ),
                const SizedBox(height: 12),
                if (visit.careActivitiesHistory.isEmpty &&
                    visit.careActivities == null)
                  const Text(
                    'No care activities recorded today in Nursing Care & Dressing tab.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else ...[
                  for (final care
                      in (visit.careActivitiesHistory.isNotEmpty
                          ? visit.careActivitiesHistory
                          : [visit.careActivities!])) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Recorded on: ${_formatRecordedAt(care.createdAt)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          if (care.nursingNotes != null &&
                              care.nursingNotes!.isNotEmpty)
                            _detailRow('Nursing Notes', care.nursingNotes!),
                          if (care.dressingProcedures != null &&
                              care.dressingProcedures!.isNotEmpty)
                            _detailRow(
                              'Dressing Procedure',
                              care.dressingProcedures!,
                            ),
                          if (care.nailTrimmingDone)
                            _detailRow(
                              'Nail Trimming / Hygiene Care',
                              'Completed',
                            ),
                          if (care.otherCareActivities != null &&
                              care.otherCareActivities!.isNotEmpty)
                            _detailRow(
                              'Other Care Activities',
                              care.otherCareActivities!,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Medicines & Consumables (Today Only)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  '4. Today\'s Medicines & Consumables',
                  Icons.medication_liquid_outlined,
                ),
                const SizedBox(height: 12),
                if (todayMedicines.isEmpty && todayConsumables.isEmpty)
                  const Text(
                    'No medicines or consumables logged today in Meds & Consumables tab.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else ...[
                  if (todayMedicines.isNotEmpty) ...[
                    const Text(
                      'Medicines Administered Today:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final m in todayMedicines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          '• ${m.medicineName} (${m.dosage}) - Qty: ${m.quantity} | ₹${(m.unitPrice * m.quantity).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  if (todayConsumables.isNotEmpty) ...[
                    const Text(
                      'Consumables Used Today:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final c in todayConsumables)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          '• ${c.itemName} - Qty: ${c.quantityUsed} | ₹${(c.unitPrice * c.quantityUsed).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 5: Today's Photo Evidence Gallery
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  '5. Today\'s Photo Evidence',
                  Icons.insert_photo_outlined,
                ),
                const SizedBox(height: 12),
                if (todayPhotos.isEmpty)
                  const Text(
                    'No photo evidence uploaded today in Photo Evidence tab.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: todayPhotos.length,
                    itemBuilder: (context, index) {
                      final p = todayPhotos[index];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.photo,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.category ?? 'Evidence',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _liveSummaryChip(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullImagePreviewDialog(
    BuildContext context,
    HomeVisitPhotoEvidence photo,
  ) {
    String timeStr = 'Just now';
    if (photo.capturedAt != null) {
      try {
        final dt = DateTime.parse(photo.capturedAt!).toLocal();
        int h = dt.hour % 12;
        if (h == 0) h = 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final m = dt.minute.toString().padLeft(2, '0');
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final year = dt.year;
        timeStr = '$day-$month-$year • $h:$m $ampm';
      } catch (_) {
        timeStr = photo.capturedAt!;
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.photo_outlined,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photo.category ?? 'Timestamped Photo Evidence',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              'Captured at $timeStr',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      tooltip: 'Close Preview',
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Full Image View with Zoom / Pan
              Expanded(
                child: Container(
                  color: const Color(0xFF0F172A),
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: photo.photoUrl.startsWith('http')
                          ? Image.network(
                              photo.photoUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          color: Colors.white54,
                                          size: 64,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Full-size image preview unavailable',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    color: Colors.white54,
                                    size: 64,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Uploaded Evidence File',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              // Caption Footer
              if (photo.caption != null && photo.caption!.isNotEmpty) ...[
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notes,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          photo.caption!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Daily Sessions Cards Overview (Step 1)
  Widget _buildDailySessionsOverview(
    HomeVisitModel currentVisit,
    HomeVisitController controller,
  ) {
    final patientVisits = controller.visits
        .where((v) => v.patientId == currentVisit.patientId)
        .toList();

    patientVisits.sort((a, b) => a.id.compareTo(b.id));

    if (patientVisits.isEmpty ||
        !patientVisits.any((v) => v.id == currentVisit.id)) {
      patientVisits.add(currentVisit);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_outlined,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Home Nursing Care History - ${currentVisit.patientName ?? "Patient"}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patient ID: ${currentVisit.patientDisplayId ?? "N/A"} | Select a Day Session Card below to view full details.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Recorded Care Sessions Timeline:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // List of Day Cards
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: patientVisits.length,
            itemBuilder: (context, index) {
              final v = patientVisits[index];
              final dayNumber = index + 1;
              final invoice = v.invoice ?? {};
              final double netAmount = (invoice['net_amount'] != null)
                  ? double.tryParse(invoice['net_amount'].toString()) ?? 0.0
                  : (invoice['total_amount'] != null
                        ? double.tryParse(invoice['total_amount'].toString()) ??
                              0.0
                        : 0.0);

              final bool isDone =
                  v.status == 'Verified' || v.status == 'Completed';
              final bool isCancelled = v.status == 'Cancelled';

              Color cardBorderColor = const Color(0xFFE2E8F0);
              Color badgeColor = Colors.orange;
              if (isDone) {
                cardBorderColor = const Color(0xFFBBF7D0);
                badgeColor = AppTheme.secondaryColor;
              } else if (isCancelled) {
                cardBorderColor = const Color(0xFFFECACA);
                badgeColor = AppTheme.dangerColor;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cardBorderColor,
                    width: isDone || isCancelled ? 1.5 : 1.0,
                  ),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    // Day Badge Box
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? AppTheme.dangerColor.withValues(alpha: 0.12)
                            : (isDone
                                  ? AppTheme.secondaryColor.withValues(
                                      alpha: 0.12,
                                    )
                                  : AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    )),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'DAY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCancelled
                                  ? AppTheme.dangerColor
                                  : (isDone
                                        ? AppTheme.secondaryColor
                                        : AppTheme.primaryColor),
                            ),
                          ),
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isCancelled
                                  ? AppTheme.dangerColor
                                  : (isDone
                                        ? AppTheme.secondaryColor
                                        : AppTheme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Session Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Day $dayNumber Care Session (${v.visitNumber})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  v.status == 'Verified'
                                      ? 'COMPLETED'
                                      : v.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Date: ${_formatDateDDMMYYYY(v.scheduledDate)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nurse: ${v.nurseName ?? "N/A"}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Attender: ${v.attenderName != null && v.attenderName!.isNotEmpty ? "${v.attenderName} (${v.attenderRelation ?? "Attender"})" : "N/A"}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Icon(
                                Icons.payments_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Total Bill: ₹${netAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // View Day Details Button
                    ElevatedButton.icon(
                      style: AppTheme.primaryButton,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text('View Day $dayNumber Summary Details'),
                      onPressed: () {
                        setState(() {
                          _selectedSummaryVisitId = v.id;
                        });
                        controller.fetchVisitDetails(v.id);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDateDDMMYYYY(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return 'N/A';
    final clean = dateStr.trim().split('T')[0].split(' ')[0];
    final parts = clean.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        return "${parts[2].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[0]}";
      } else {
        return "${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[2]}";
      }
    }
    return dateStr;
  }

  bool _isSameDay(String? d1, String? d2) {
    if (d1 == null || d2 == null || d1.trim().isEmpty || d2.trim().isEmpty) {
      return true;
    }
    final clean1 = d1.trim().split('T')[0].split(' ')[0];
    final clean2 = d2.trim().split('T')[0].split(' ')[0];

    final p1 = clean1.split('-');
    final p2 = clean2.split('-');

    if (p1.length == 3 && p2.length == 3) {
      String y1 = p1[0].length == 4 ? p1[0] : p1[2];
      String m1 = p1[1].padLeft(2, '0');
      String day1 = p1[0].length == 4
          ? p1[2].padLeft(2, '0')
          : p1[0].padLeft(2, '0');

      String y2 = p2[0].length == 4 ? p2[0] : p2[2];
      String m2 = p2[1].padLeft(2, '0');
      String day2 = p2[0].length == 4
          ? p2[2].padLeft(2, '0')
          : p2[0].padLeft(2, '0');

      return '$y1-$m1-$day1' == '$y2-$m2-$day2';
    }
    return clean1 == clean2;
  }

  // Overall Read-Only Summary View for Verified/Completed Home Visits (Step 2)
  Widget _buildCompletedVisitSummaryView(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final patientVisits = controller.visits
        .where((v) => v.patientId == visit.patientId)
        .toList();
    patientVisits.sort((a, b) => (a.scheduledDate).compareTo(b.scheduledDate));
    int dayNumber = patientVisits.indexWhere((v) => v.id == visit.id) + 1;
    if (dayNumber <= 0) dayNumber = 1;

    final sessionVitals = visit.vitalsHistory
        .where((v) => _isSameDay(v.recordedAt, visit.scheduledDate))
        .toList();
    final sessionCareHistory = visit.careActivitiesHistory
        .where((c) => _isSameDay(c.createdAt, visit.scheduledDate))
        .toList();
    final sessionMedicines = visit.medicines
        .where((m) => _isSameDay(m.administeredAt, visit.scheduledDate))
        .toList();
    final sessionConsumables = visit.consumables
        .where((c) => _isSameDay(c.createdAt, visit.scheduledDate))
        .toList();
    final sessionPhotos = visit.photos
        .where((p) => _isSameDay(p.capturedAt, visit.scheduledDate))
        .toList();

    final invoice = visit.invoice ?? {};
    final double netAmount = (invoice['net_amount'] != null)
        ? double.tryParse(invoice['net_amount'].toString()) ?? 0.0
        : (invoice['total_amount'] != null
              ? double.tryParse(invoice['total_amount'].toString()) ?? 0.0
              : 0.0);
    final String invoiceNum = invoice['invoice_number'] ?? 'INV-HV-VERIFIED';
    final String payStatus = invoice['payment_status'] ?? 'Unpaid';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to Daily Sessions List Button
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: OutlinedButton.icon(
              style: AppTheme.outlinedButton,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text(
                'Back to All Daily Care Sessions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                setState(() {
                  _selectedSummaryVisitId = null;
                });
              },
            ),
          ),

          // Status Banner (Verified / Cancelled / In-Progress)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: visit.status == 'Cancelled'
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: visit.status == 'Cancelled'
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: visit.status == 'Cancelled'
                        ? AppTheme.dangerColor.withValues(alpha: 0.15)
                        : AppTheme.secondaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    visit.status == 'Cancelled'
                        ? Icons.do_not_disturb_on_outlined
                        : Icons.verified,
                    color: visit.status == 'Cancelled'
                        ? AppTheme.dangerColor
                        : AppTheme.secondaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            visit.status == 'Cancelled'
                                ? 'Home Visit Care Discontinued / Stopped'
                                : 'Day $dayNumber Care Session Verified & Billed (${_formatDateDDMMYYYY(visit.scheduledDate)})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: visit.status == 'Cancelled'
                                  ? AppTheme.dangerColor
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: visit.status == 'Cancelled'
                                  ? AppTheme.dangerColor
                                  : AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              visit.status == 'Verified'
                                  ? 'COMPLETED'
                                  : visit.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visit.status == 'Cancelled'
                            ? (visit.notes != null && visit.notes!.isNotEmpty
                                  ? visit.notes!
                                  : 'Care plan stopped/discontinued for this patient.')
                            : 'All vitals, nursing procedures, medicines, evidence & attender signature are locked & billed for ${_formatDateDDMMYYYY(visit.scheduledDate)}. Execute Visit unlocks at 7:00 AM on the next scheduled date.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Billing & Invoice Card Banner
          if (visit.invoice != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: AppTheme.primaryColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice #: $invoiceNum',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Payment Status: $payStatus | Total Amount: ₹${netAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: AppTheme.primaryButton,
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'View Itemized Invoice',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => HomeVisitInvoiceDialog(
                          invoiceData: {'invoice': visit.invoice},
                          visit: visit,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Patient & Attender Overview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Patient & Attender Overview',
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _summaryTile(
                        'Patient Name',
                        visit.patientName ?? 'N/A',
                      ),
                    ),
                    Expanded(
                      child: _summaryTile(
                        'Patient ID',
                        visit.patientDisplayId ?? 'N/A',
                      ),
                    ),
                    Expanded(
                      child: _summaryTile(
                        'Scheduled Date',
                        _formatDateDDMMYYYY(visit.scheduledDate),
                      ),
                    ),
                    Expanded(
                      child: _summaryTile(
                        'Assigned Nurse',
                        visit.nurseName ?? 'Nurse',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _summaryTile(
                        'Verified Attender',
                        visit.attenderName ?? 'N/A',
                      ),
                    ),
                    Expanded(
                      child: _summaryTile(
                        'Attender Relation',
                        visit.attenderRelation ?? 'Attender',
                      ),
                    ),
                    Expanded(
                      child: _summaryTile(
                        'Signed At',
                        visit.signedAt ?? 'Completed',
                      ),
                    ),
                    Expanded(
                      child: _summaryTile(
                        'Visit Address',
                        visit.visitAddress ?? 'N/A',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Hourly Vitals History Log Table
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Day $dayNumber Recorded Hourly Vitals Log',
                  Icons.monitor_heart_outlined,
                ),
                const SizedBox(height: 16),
                if (sessionVitals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No vitals recorded for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Table(
                      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                          ),
                          children: [
                            _tableHeader('Date & Time'),
                            _tableHeader('BP (mmHg)'),
                            _tableHeader('Pulse (bpm)'),
                            _tableHeader('SpO2 (%)'),
                            _tableHeader('Temp (°F)'),
                            _tableHeader('Sugar (mg/dL)'),
                          ],
                        ),
                        for (final v in sessionVitals)
                          TableRow(
                            children: [
                              _tableCell(
                                v.recordedAt != null
                                    ? () {
                                        try {
                                          final dt = DateTime.parse(
                                            v.recordedAt!,
                                          ).toLocal();
                                          final day = dt.day.toString().padLeft(
                                            2,
                                            '0',
                                          );
                                          final month = dt.month
                                              .toString()
                                              .padLeft(2, '0');
                                          final year = dt.year;
                                          int h = dt.hour % 12;
                                          if (h == 0) h = 12;
                                          final ampm = dt.hour >= 12
                                              ? 'PM'
                                              : 'AM';
                                          final m = dt.minute
                                              .toString()
                                              .padLeft(2, '0');
                                          return '$day-$month-$year • $h:$m $ampm';
                                        } catch (_) {
                                          return v.recordedAt!;
                                        }
                                      }()
                                    : 'N/A',
                              ),
                              _tableCell(
                                '${v.systolicBp ?? "-"}/${v.diastolicBp ?? "-"}',
                              ),
                              _tableCell('${v.pulseRate ?? "-"}'),
                              _tableCell('${v.spo2 ?? "-"}'),
                              _tableCell('${v.temperature ?? "-"}'),
                              _tableCell('${v.bloodSugar ?? "-"}'),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Nursing Care Activities Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Day $dayNumber Nursing Care & Procedure Records',
                  Icons.edit_note_outlined,
                ),
                const SizedBox(height: 16),
                if (sessionCareHistory.isEmpty &&
                    (visit.careActivities == null ||
                        !_isSameDay(
                          visit.careActivities!.createdAt,
                          visit.scheduledDate,
                        )))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No nursing care notes or dressing procedures recorded for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  for (final care
                      in (sessionCareHistory.isNotEmpty
                          ? sessionCareHistory
                          : [visit.careActivities!])) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Recorded on: ${_formatRecordedAt(care.createdAt)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          if (care.nursingNotes != null &&
                              care.nursingNotes!.isNotEmpty)
                            _detailRow('Nursing Notes', care.nursingNotes!),
                          if (care.dressingProcedures != null &&
                              care.dressingProcedures!.isNotEmpty)
                            _detailRow(
                              'Dressing Procedure',
                              care.dressingProcedures!,
                            ),
                          if (care.nailTrimmingDone)
                            _detailRow(
                              'Nail Trimming / Hygiene Care',
                              'Completed',
                            ),
                          if (care.otherCareActivities != null &&
                              care.otherCareActivities!.isNotEmpty)
                            _detailRow(
                              'Other Care Activities',
                              care.otherCareActivities!,
                            ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Administered Medicines & Consumables Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Day $dayNumber Administered Medicines & Consumables',
                  Icons.medication_liquid_outlined,
                ),
                const SizedBox(height: 16),
                if (sessionMedicines.isEmpty && sessionConsumables.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No medicines or consumables administered for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else ...[
                  if (sessionMedicines.isNotEmpty) ...[
                    const Text(
                      'Medicines Administered:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final m in sessionMedicines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          '• ${m.medicineName} (${m.dosage}) - Qty: ${m.quantity} | ₹${(m.unitPrice * m.quantity).toStringAsFixed(2)}${(m.administeredAt != null && m.administeredAt!.isNotEmpty) ? " (${m.administeredAt!.split("T")[0]})" : ""}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (sessionConsumables.isNotEmpty) ...[
                    const Text(
                      'Consumables Used:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final c in sessionConsumables)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          '• ${c.itemName} - Qty: ${c.quantityUsed} | ₹${(c.unitPrice * c.quantityUsed).toStringAsFixed(2)}${(c.createdAt != null && c.createdAt!.isNotEmpty) ? " (${c.createdAt!.split("T")[0]})" : ""}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Timestamped Photo Evidence Gallery
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Day $dayNumber Timestamped Photo Evidence Gallery',
                  Icons.insert_photo_outlined,
                ),
                const SizedBox(height: 16),
                if (sessionPhotos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No timestamped photo evidence uploaded for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: sessionPhotos.length,
                    itemBuilder: (context, idx) {
                      final p = sessionPhotos[idx];
                      return InkWell(
                        onTap: () => _showFullImagePreviewDialog(context, p),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: p.photoUrl.startsWith('http')
                                      ? Image.network(
                                          p.photoUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: const Color(0xFFF1F5F9),
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  p.category ?? 'Evidence',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPastVisit(String scheduledDateStr) {
    if (scheduledDateStr.isEmpty) return false;
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final dateParts = scheduledDateStr.split('-');
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
        return vDate.isBefore(todayDate);
      }
    } catch (_) {}
    return false;
  }

  void _showDiscontinueDialog(BuildContext context, HomeVisitModel visit) {
    String selectedReason = 'Patient Cured / Fully Recovered';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.do_not_disturb_on_outlined,
                color: AppTheme.dangerColor,
                size: 26,
              ),
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
              const Text(
                'Select Discontinuation Reason:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              CustomDropdownSearch(
                label: '',
                hint: 'Select Reason',
                dropdownMap: const {
                  'Patient Cured / Fully Recovered':
                      'Patient Cured / Fully Recovered',
                  'Patient / Attender Requested Discontinuation':
                      'Patient / Attender Requested Discontinuation',
                  'Admitted to Hospital / IPD Care':
                      'Admitted to Hospital / IPD Care',
                  'Doctor Advice / Care Plan Ended':
                      'Doctor Advice / Care Plan Ended',
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
              const Text(
                'Additional Notes / Remarks (Optional):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: AppTheme.standardInputDecoration(
                  hintText: 'Enter reason notes (e.g. Cured and recovered)...',
                ),
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
                final homeVisitCtrl = Provider.of<HomeVisitController>(
                  context,
                  listen: false,
                );
                final success = await homeVisitCtrl.cancelVisit(
                  visit.id,
                  selectedReason,
                  notesCtrl.text,
                );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Home visit care for ${visit.patientName ?? "Patient"} stopped/discontinued successfully.',
                      ),
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                  );
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatRecordedAt(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty)
      return 'Recorded (Time not specified)';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  Widget _buildTimestampBadge(
    String? rawDate, {
    Color color = AppTheme.primaryColor,
  }) {
    if (rawDate == null || rawDate.isEmpty) {
      return const Text(
        '--',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }
    String dateStr = rawDate;
    String timeStr = '';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      dateStr = DateFormat('dd MMM yyyy').format(dt);
      timeStr = DateFormat('hh:mm a').format(dt);
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 10, color: color),
                const SizedBox(width: 3),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(PointMode.points, [points[i]!], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
