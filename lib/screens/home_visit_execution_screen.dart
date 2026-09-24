import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../core/routes/route_constants.dart';
import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/home_visit_model.dart';
import '../controllers/home_visit_controller.dart';
import '../services/api_service.dart';
import '../services/home_visit_service.dart';
import '../services/media_service.dart';
import '../widgets/custom_dropdown_search.dart';
import '../widgets/app_top_bar_actions.dart';
import 'home_visit_invoice_dialog.dart';
import '../utils/unsaved_changes_helper.dart';
import '../utils/modal_history_helper.dart';
import '../utils/app_notification.dart';
import '../utils/capitalize_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/live_speech_service.dart';
import '../utils/app_localizations.dart';
import '../utils/tamil_transliteration_helper.dart';
import '../providers/language_provider.dart';

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
  bool _isLeaving = false;

  void _handleLeave() {
    if (!mounted) return;
    setState(() {
      _isLeaving = true;
    });
    UnsavedChangesHelper.setUnsavedChanges(false);
    UnsavedChangesHelper.clear();
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      final loc = GoRouterState.of(context).matchedLocation;
      if (loc.startsWith('/nurse')) {
        context.go(AppRoutes.nurseHomeVisits);
      } else if (loc.startsWith('/admin')) {
        context.go(AppRoutes.adminHomeVisits);
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(AppRoutes.nurseDashboard);
      }
    }
  }

  Future<bool?> _showUnsavedChangesDialog(
    BuildContext context, {
    HomeVisitModel? visit,
  }) {
    final bool isCompleted = widget.isReadOnlyView ||
        _isLeaving ||
        (visit != null &&
            (visit.status == 'Completed' ||
                visit.status == 'Verified' ||
                visit.status == 'Cancelled'));

    if (isCompleted) {
      _handleLeave();
      return Future.value(true);
    }
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 500;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          child: Container(
            width: isMobile ? double.infinity : 440,
            constraints: const BoxConstraints(maxWidth: 440),
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.dangerColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ctx.tr('unsaved_form_data', fallback: 'Unsaved Form Data'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textPrimaryColor,
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  ctx.tr('unsaved_form_leave_confirm', fallback: 'Do you want to leave this page? Any unsaved form data or entries will be lost.'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: AppTheme.dangerButton,
                        onPressed: () {
                          ModalHistoryHelper.skipNextHistoryBack();
                          Navigator.of(ctx).pop(true);
                          UnsavedChangesHelper.setUnsavedChanges(false);
                          UnsavedChangesHelper.clear();
                          _handleLeave();
                        },
                        child: Text(ctx.tr('leave_page', fallback: 'Leave Page')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: AppTheme.cancelButton,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(ctx.tr('stay_on_page', fallback: 'Stay on Page')),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: AppTheme.cancelButton,
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(ctx.tr('stay_on_page', fallback: 'Stay on Page')),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: AppTheme.dangerButton,
                        onPressed: () {
                          ModalHistoryHelper.skipNextHistoryBack();
                          Navigator.of(ctx).pop(true);
                          UnsavedChangesHelper.setUnsavedChanges(false);
                          UnsavedChangesHelper.clear();
                          _handleLeave();
                        },
                        child: Text(ctx.tr('leave_page', fallback: 'Leave Page')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

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
  String _medType = 'Regular';
  final TextEditingController _medFrequencyCtrl = TextEditingController(
    text: '1-0-1',
  );
  final TextEditingController _medDurationCtrl = TextEditingController(
    text: '5 days',
  );
  final TextEditingController _medGivenTimeCtrl = TextEditingController();

  // Consumable Form Controllers
  final TextEditingController _consNameCtrl = TextEditingController();
  final TextEditingController _consQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _consPriceCtrl = TextEditingController();

  // Kit & Devices Form Controllers
  bool _isAddingKitItem = false;
  String? _selectedKitDropdown;
  final TextEditingController _customKitNameCtrl = TextEditingController();
  final TextEditingController _kitItemNameCtrl = TextEditingController();
  final TextEditingController _kitItemQtyCtrl = TextEditingController(
    text: '1',
  );
  String _kitItemType = 'Device';
  List<Map<String, dynamic>> _dbKitMasterItems = [];
  List<String> _dbKitDevices = [];

  List<String> get _effectiveKitDevices {
    final List<String> items = [];
    if (_dbKitDevices.isNotEmpty) {
      for (final name in _dbKitDevices) {
        if (name.trim().isNotEmpty && !items.contains(name.trim())) {
          items.add(name.trim());
        }
      }
    } else {
      for (final defaultItem in _defaultKitDevices) {
        if (defaultItem != 'Other (Type Custom Kit Item...)' &&
            !items.contains(defaultItem)) {
          items.add(defaultItem);
        }
      }
    }
    if (!items.contains('Other (Type Custom Kit Item...)')) {
      items.add('Other (Type Custom Kit Item...)');
    }
    return items;
  }

  final List<String> _defaultKitDevices = const [
    'BP Apparatus',
    'Stethoscope',
    'Thermometer',
    'Glucometer Kit',
    'Pulse Oximeter',
    'Nebulizer Machine',
    'ECG Machine (Portable)',
    'Oxygen Concentrator / Cylinder',
    'Suction Machine',
    'Dressing & Minor Procedure Kit',
    'Other (Type Custom Kit Item...)',
  ];

  static const List<String> _kitItemTypes = [
    'Device',
    'Equipment',
    'Kit',
    'Monitoring Tool',
    'Accessories',
  ];

  String _getTranslatedKitDevice(String name) {
    switch (name.trim()) {
      case 'BP Apparatus':
        return context.tr('kit_bp_apparatus', fallback: 'BP Apparatus');
      case 'Stethoscope':
        return context.tr('kit_stethoscope', fallback: 'Stethoscope');
      case 'Thermometer':
      case 'Thermometer (Digital)':
        return context.tr('kit_thermometer', fallback: 'Thermometer');
      case 'Glucometer Kit':
        return context.tr('kit_glucometer', fallback: 'Glucometer Kit');
      case 'Pulse Oximeter':
        return context.tr('kit_pulse_oximeter', fallback: 'Pulse Oximeter');
      case 'Nebulizer Machine':
        return context.tr('kit_nebulizer', fallback: 'Nebulizer Machine');
      case 'ECG Machine (Portable)':
        return context.tr('kit_ecg_machine', fallback: 'ECG Machine (Portable)');
      case 'Oxygen Concentrator / Cylinder':
        return context.tr(
          'kit_oxygen',
          fallback: 'Oxygen Concentrator / Cylinder',
        );
      case 'Suction Machine':
        return context.tr('kit_suction', fallback: 'Suction Machine');
      case 'Dressing & Minor Procedure Kit':
        return context.tr(
          'kit_dressing',
          fallback: 'Dressing & Minor Procedure Kit',
        );
      case 'Other (Type Custom Kit Item...)':
        return context.tr(
          'kit_item_other',
          fallback: 'Other (Type Custom Kit Item...)',
        );
      default:
        return name;
    }
  }

  Map<String, String> _getKitDeviceMap() {
    final map = <String, String>{};
    for (final item in _effectiveKitDevices) {
      map[item] = _getTranslatedKitDevice(item);
    }
    return map;
  }

  String _getTranslatedKitType(String type) {
    switch (type.trim()) {
      case 'Device':
        return context.tr('cat_device', fallback: 'Device');
      case 'Equipment':
        return context.tr('cat_equipment', fallback: 'Equipment');
      case 'Kit':
        return context.tr('cat_kit', fallback: 'Kit');
      case 'Monitoring Tool':
        return context.tr('cat_monitoring_tool', fallback: 'Monitoring Tool');
      case 'Accessories':
        return context.tr('cat_accessories', fallback: 'Accessories');
      default:
        return type;
    }
  }

  Map<String, String> _getKitTypeMap() {
    final map = <String, String>{};
    for (final type in _kitItemTypes) {
      map[type] = _getTranslatedKitType(type);
    }
    return map;
  }

  String _getTranslatedHomeVisitStatus(String status) {
    final s = status.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_').trim();
    switch (s) {
      case 'in_progress':
        return context.tr('in_progress', fallback: 'In-Progress');
      case 'scheduled':
        return context.tr('scheduled', fallback: 'Scheduled');
      case 'completed':
        return context.tr('completed_status', fallback: 'Completed');
      case 'verified':
        return context.tr('verified', fallback: 'Verified');
      case 'cancelled':
        return context.tr('cancelled', fallback: 'Cancelled');
      case 'stopped':
        return context.tr('stopped', fallback: 'Stopped');
      default:
        return status;
    }
  }

  String _getTranslatedAttenderRelation(String? relation) {
    if (relation == null || relation.trim().isEmpty) return context.tr('attender_label', fallback: 'Attender');
    final r = relation.toLowerCase().trim();
    switch (r) {
      case 'father':
        return context.tr('rel_father', fallback: 'Father');
      case 'mother':
        return context.tr('rel_mother', fallback: 'Mother');
      case 'son':
        return context.tr('rel_son', fallback: 'Son');
      case 'daughter':
        return context.tr('rel_daughter', fallback: 'Daughter');
      case 'spouse':
      case 'husband':
      case 'wife':
        return context.tr('rel_spouse', fallback: relation);
      case 'brother':
        return context.tr('rel_brother', fallback: 'Brother');
      case 'sister':
        return context.tr('rel_sister', fallback: 'Sister');
      case 'guardian':
        return context.tr('rel_guardian', fallback: 'Guardian');
      case 'attender':
        return context.tr('attender_label', fallback: 'Attender');
      default:
        return relation;
    }
  }

  String _getTranslatedPaymentStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'paid') return context.tr('paid', fallback: 'Paid');
    if (s == 'unpaid') return context.tr('unpaid', fallback: 'Unpaid');
    if (s == 'pending') return context.tr('pending', fallback: 'Pending');
    return status;
  }

  String _getTranslatedPhotoCategory(String? category) {
    if (category == null || category.trim().isEmpty) {
      return context.tr('evidence_label', fallback: 'Evidence');
    }
    switch (category) {
      case 'Dressing Pre-Procedure':
        return context.tr('photo_cat_dressing_pre', fallback: 'Pre-Dressing Wound Photo');
      case 'Dressing Post-Procedure':
        return context.tr('photo_cat_dressing_post', fallback: 'Post-Dressing Photo');
      case 'Care Activity':
        return context.tr('photo_cat_care_activity', fallback: 'Care Activity Evidence');
      case 'General Care':
        return context.tr('photo_cat_general_care', fallback: 'General Visit Photo');
      case 'Photo Evidence':
      case 'Timestamped Photo Evidence':
      case 'Evidence':
        return context.tr('evidence_label', fallback: 'Evidence');
      default:
        return category;
    }
  }

  void _clearKitForm() {
    setState(() {
      _selectedKitDropdown = null;
      _customKitNameCtrl.clear();
      _kitItemNameCtrl.clear();
      _kitItemQtyCtrl.text = '1';
      _kitItemType = 'Device';
    });
  }

  Widget _buildQtyStepperField({
    required TextEditingController controller,
    int min = 1,
    int max = 999,
    ValueChanged<String>? onChanged,
    StateSetter? setModalState,
    String? suffix,
  }) {
    void updateQty(int delta) {
      int current = int.tryParse(controller.text) ?? min;
      int updated = (current + delta).clamp(min, max);
      final newText = updated.toString();
      controller.text = newText;
      if (setModalState != null) {
        setModalState(() {});
      } else if (mounted) {
        setState(() {});
      }
      if (onChanged != null) {
        onChanged(newText);
      }
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => updateQty(-1),
              child: const SizedBox(
                width: 32,
                height: 38,
                child: Icon(Icons.remove, size: 16, color: Color(0xFF0284C7)),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (val) {
                if (val.isNotEmpty) {
                  int? parsed = int.tryParse(val);
                  if (parsed != null) {
                    if (parsed < min) controller.text = min.toString();
                    if (parsed > max) controller.text = max.toString();
                  }
                }
                if (onChanged != null) {
                  onChanged(controller.text);
                }
                if (setModalState != null) {
                  setModalState(() {});
                }
              },
              decoration: InputDecoration(
                hintText: '1',
                suffixText: suffix,
                suffixStyle: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          Material(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => updateQty(1),
              child: const SizedBox(
                width: 32,
                height: 38,
                child: Icon(Icons.add, size: 16, color: Color(0xFF0284C7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _vitalsPage = 1;
  int _vitalsPageSize = 25;
  int _medsPage = 1;
  int _consPage = 1;
  int _carePage = 1;
  int _procPage = 1;
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

  final List<ProcedureMasterModel> _defaultProcedures = [
    ProcedureMasterModel(
      id: 1,
      name: 'Diaper Change',
      procedureCharge: 100.0,
      status: 'Active',
      mappedConsumables: [
        ProcedureConsumableMappingModel(
          consumableId: 1,
          consumableName: 'Diaper',
          unit: 'Pc',
          unitPrice: 40.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 2,
          consumableName: 'Gloves',
          unit: 'Pair',
          unitPrice: 15.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 3,
          consumableName: 'Disposable Sheet',
          unit: 'Pc',
          unitPrice: 35.0,
          qtyPerProcedure: 1,
        ),
      ],
    ),
    ProcedureMasterModel(
      id: 2,
      name: 'Wound Dressing',
      procedureCharge: 250.0,
      status: 'Active',
      mappedConsumables: [
        ProcedureConsumableMappingModel(
          consumableId: 2,
          consumableName: 'Gloves',
          unit: 'Pair',
          unitPrice: 15.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 4,
          consumableName: 'Gauze',
          unit: 'Pc',
          unitPrice: 10.0,
          qtyPerProcedure: 2,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 5,
          consumableName: 'Dressing Pad',
          unit: 'Pc',
          unitPrice: 25.0,
          qtyPerProcedure: 1,
        ),
      ],
    ),
    ProcedureMasterModel(
      id: 3,
      name: 'Injection',
      procedureCharge: 80.0,
      status: 'Active',
      mappedConsumables: [
        ProcedureConsumableMappingModel(
          consumableId: 6,
          consumableName: 'Syringe 5ml',
          unit: 'Pc',
          unitPrice: 15.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 7,
          consumableName: 'Alcohol Swab',
          unit: 'Pc',
          unitPrice: 5.0,
          qtyPerProcedure: 1,
        ),
      ],
    ),
    ProcedureMasterModel(
      id: 4,
      name: 'Catheter Care',
      procedureCharge: 150.0,
      status: 'Active',
      mappedConsumables: [
        ProcedureConsumableMappingModel(
          consumableId: 2,
          consumableName: 'Gloves',
          unit: 'Pair',
          unitPrice: 15.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 8,
          consumableName: 'Antiseptic Solution 100ml',
          unit: 'Pc',
          unitPrice: 50.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 9,
          consumableName: 'Sterile Bandage',
          unit: 'Pc',
          unitPrice: 20.0,
          qtyPerProcedure: 1,
        ),
      ],
    ),
    ProcedureMasterModel(
      id: 5,
      name: 'IV Fluid Administration',
      procedureCharge: 200.0,
      status: 'Active',
      mappedConsumables: [
        ProcedureConsumableMappingModel(
          consumableId: 10,
          consumableName: 'IV Cannula 20G',
          unit: 'Pc',
          unitPrice: 65.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 11,
          consumableName: 'Adhesive Tape',
          unit: 'Pc',
          unitPrice: 15.0,
          qtyPerProcedure: 1,
        ),
        ProcedureConsumableMappingModel(
          consumableId: 7,
          consumableName: 'Alcohol Swab',
          unit: 'Pc',
          unitPrice: 5.0,
          qtyPerProcedure: 1,
        ),
      ],
    ),
  ];

  // Photo Evidence Form
  final TextEditingController _photoUrlCtrl = TextEditingController();
  final TextEditingController _photoCaptionCtrl = TextEditingController();
  String? _selectedPhotoCategory;
  String? _selectedPhotoName;
  List<int>? _selectedPhotoBytes;
  int? _selectedPhotoSize;
  String? _photoFormatError;
  bool _photoSubmitAttempted = false;
  bool _isUploadingPhoto = false;

  // Signature & Feedback Form
  final TextEditingController _attenderNameCtrl = TextEditingController();
  final TextEditingController _attenderRelationCtrl = TextEditingController();
  final TextEditingController _feedbackCtrl = TextEditingController();
  final List<Offset?> _signaturePoints = [];
  bool _isSigningSignature = false;

  // Voice to Text (Speech Recognition) State
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String? _activeDictationField;
  bool get _isListeningFeedback => _activeDictationField != null;
  String _speechTranscription = '';
  String _dictationLanguage = 'ta-IN';

  static const List<String> _quickNursingNoteTemplates = [
    'Patient is stable and comfortable / நோயாளி சீராக உள்ளார்',
    'Vitals checked & within normal limits / உயிரளவுகள் இயல்பானவை',
    'Sterile dressing changed cleanly / டிரஸ்ஸிங் மாற்றப்பட்டது',
    'Wound healing well, no discharge / காயம் சீராக ஆறி வருகிறது',
    'Patient advised on diet & hydration / உணவு, நீர்ச்சத்து ஆலோசனை வழங்கப்பட்டது',
    'Hygiene & position care provided / சுகாதாரம், நிலை மாற்றம் செய்யப்பட்டது',
  ];

  static const List<String> _quickDressingTemplates = [
    'Cleaned with Normal Saline & Betadine / நார்மல் சலைன் மூலம் சுத்தம் செய்யப்பட்டது',
    'Sterile gauze & adhesive tape applied / சுத்தமான பேண்டேஜ் போடப்பட்டது',
    'Surgical wound clean, sutures intact / அறுவைசிகிச்சை காயம் சுத்தமாக உள்ளது',
    'Minimal serous discharge, no signs of infection / தொற்று அறிகுறிகள் இல்லை',
  ];

  bool _isSavingVitals = false;
  bool _isSavingCare = false;
  bool _isVerifying = false;
  String _vitalsFilter = 'All';
  Timer? _vitalsTimer;

  static const List<String> _quickFeedbackTemplates = [
    'Patient is stable and comfortable',
    'Medication administered on time',
    'Vitals checked and normal',
    'Wound dressing changed cleanly',
    'Attender satisfied with home care',
    'Patient advised on diet & hydration',
    'Catheter & hygiene care provided',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    if (!widget.isReadOnlyView) {
      UnsavedChangesHelper.setUnsavedChanges(true);
    }
    _initSpeech();
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

  Future<void> _initSpeech() async {
    final enabled = await LiveSpeechService().initialize();
    if (mounted) {
      setState(() => _speechEnabled = enabled);
    }
  }

  Future<void> _toggleSpeechDictation({
    required TextEditingController targetController,
    required String fieldId,
    StateSetter? setModalState,
  }) async {
    if (_activeDictationField == fieldId) {
      await LiveSpeechService().stopListening();
      if (mounted) {
        setState(() => _activeDictationField = null);
      }
      if (setModalState != null) {
        setModalState(() => _activeDictationField = null);
      }
      return;
    }

    if (_activeDictationField != null) {
      await LiveSpeechService().stopListening();
    }

    final initialText = targetController.text.trim();
    if (mounted) {
      setState(() {
        _activeDictationField = fieldId;
        _speechTranscription = '';
      });
    }
    if (setModalState != null) {
      setModalState(() {
        _activeDictationField = fieldId;
        _speechTranscription = '';
      });
    }

    final lang = _dictationLanguage;
    final success = await LiveSpeechService().startListening(
      lang: lang,
      onResult: (liveWords) {
        final words = liveWords.trim();
        if (words.isNotEmpty) {
          final newText = initialText.isEmpty ? words : '$initialText $words';
          targetController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
          if (setModalState != null) {
            setModalState(() {
              _speechTranscription = words;
            });
          } else if (mounted) {
            setState(() {
              _speechTranscription = words;
            });
          }
        }
      },
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted) {
            setState(() => _activeDictationField = null);
          }
          if (setModalState != null) {
            setModalState(() => _activeDictationField = null);
          }
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _activeDictationField = null);
          AppNotification.showError(
            context,
            'Speech recognition error: $err',
          );
        }
        if (setModalState != null) {
          setModalState(() => _activeDictationField = null);
        }
      },
    );

    if (!success) {
      if (mounted) {
        setState(() => _activeDictationField = null);
      }
      if (setModalState != null) {
        setModalState(() => _activeDictationField = null);
      }
    }
  }

  Widget _buildDictationLanguagePill({StateSetter? setModalState}) {
    final isTamil = _dictationLanguage.startsWith('ta');
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              if (_dictationLanguage != 'ta-IN') {
                if (setModalState != null) {
                  setModalState(() => _dictationLanguage = 'ta-IN');
                } else if (mounted) {
                  setState(() => _dictationLanguage = 'ta-IN');
                }
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isTamil ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'தமிழ் (ta)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isTamil ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () {
              if (_dictationLanguage != 'en-IN') {
                if (setModalState != null) {
                  setModalState(() => _dictationLanguage = 'en-IN');
                } else if (mounted) {
                  setState(() => _dictationLanguage = 'en-IN');
                }
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: !isTamil ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'English (en)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: !isTamil ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSupportedNotesField({
    required String fieldId,
    required String label,
    required TextEditingController controller,
    String? hintText,
    int maxLines = 3,
    int maxLength = 500,
    List<String>? quickTemplates,
    String? Function(String?)? validator,
    StateSetter? setModalState,
    bool isModal = false,
  }) {
    final isListening = _activeDictationField == fieldId;
    final isTamil = _dictationLanguage.startsWith('ta');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildLabel(label)),
            const SizedBox(width: 8),
            _buildDictationLanguagePill(setModalState: setModalState),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _toggleSpeechDictation(
                targetController: controller,
                fieldId: fieldId,
                setModalState: setModalState,
              ),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isListening
                      ? AppTheme.dangerColor.withOpacity(0.12)
                      : AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isListening
                        ? AppTheme.dangerColor
                        : AppTheme.primaryColor.withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isListening ? Icons.stop_circle : Icons.mic,
                      size: 15,
                      color: isListening
                          ? AppTheme.dangerColor
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isListening
                          ? context.tr('stop_voice_input')
                          : context.tr('voice_to_text'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isListening
                            ? AppTheme.dangerColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (isListening) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.dangerColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTamil
                        ? 'நேரடி குரல் பதிவு செயலில் உள்ளது (தமிழ் ta-IN)... மைக்ரோஃபோனில் பேசவும்'
                        : 'Live dictation active (English en-IN)... Speak clearly into microphone',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _toggleSpeechDictation(
                    targetController: controller,
                    fieldId: fieldId,
                    setModalState: setModalState,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'STOP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: isModal ? 3 : maxLines,
          maxLength: maxLength,
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxLength),
            FilteringTextInputFormatter.allow(
              RegExp(r'[a-zA-Z0-9\u0B80-\u0BFF\s.,/#\-\(\):;?!]'),
            ),
          ],
          decoration: AppTheme.standardInputDecoration(
            hintText: hintText ?? (isTamil
                ? 'நேரடி குரல் மூலம் பேசவும் அல்லது தட்டச்சு செய்யவும்...'
                : 'Speak with voice to text or type here...'),
            suffixIcon: IconButton(
              icon: Icon(
                isListening ? Icons.mic_off : Icons.mic,
                color: isListening
                    ? AppTheme.dangerColor
                    : AppTheme.primaryColor,
                size: 20,
              ),
              tooltip: isListening
                  ? context.tr('stop_voice_input')
                  : '${context.tr('voice_to_text')} (${isTamil ? "தமிழ்" : "English"})',
              onPressed: () => _toggleSpeechDictation(
                targetController: controller,
                fieldId: fieldId,
                setModalState: setModalState,
              ),
            ),
          ),
          validator: validator,
          onChanged: (val) {
            if (setModalState != null) {
              setModalState(() {});
            } else if (mounted) {
              setState(() {});
            }
          },
        ),
        if (quickTemplates != null && quickTemplates.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: quickTemplates.map((template) {
              return InkWell(
                onTap: () {
                  final cur = controller.text.trim();
                  if (cur.isEmpty) {
                    controller.text = template;
                  } else if (!cur.contains(template)) {
                    controller.text = '$cur. $template';
                  }
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: controller.text.length),
                  );
                  if (setModalState != null) {
                    setModalState(() {});
                  } else if (mounted) {
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 12, color: Color(0xFF475569)),
                      const SizedBox(width: 3),
                      Text(
                        template,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackVoiceField({
    required TextEditingController controller,
    StateSetter? setModalState,
    bool isModal = false,
  }) {
    return _buildVoiceSupportedNotesField(
      fieldId: 'feedback',
      label: 'Visit & Care Feedback / Remarks',
      controller: controller,
      hintText: 'Speak or type attender feedback, patient condition, care remarks...',
      maxLines: isModal ? 3 : 4,
      maxLength: 500,
      quickTemplates: _quickFeedbackTemplates,
      setModalState: setModalState,
      isModal: isModal,
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
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
    _formKeyVitals.currentState?.reset();
  }

  void _clearCareForm() {
    _notesCtrl.clear();
    _dressingCtrl.clear();
    _otherCareCtrl.clear();
    setState(() => _nailTrimmingDone = false);
  }

  int? _parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final str = timeStr.trim().toUpperCase();
    try {
      final isPm = str.contains('PM');
      final isAm = str.contains('AM');
      final clean = str.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0].trim());
        int min = int.parse(parts[1].trim().split(' ')[0]);
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return hour * 60 + min;
      }
    } catch (_) {}
    return null;
  }

  String _getCurrentFormattedTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  Future<void> _selectGivenTime(BuildContext context) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (_medGivenTimeCtrl.text.isNotEmpty) {
      try {
        final parts = _medGivenTimeCtrl.text.trim().split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
          hour += 12;
        } else if (parts.length > 1 &&
            parts[1].toUpperCase() == 'AM' &&
            hour == 12) {
          hour = 0;
        }
        initialTime = TimeOfDay(hour: hour, minute: minute);
      } catch (_) {}
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() {
        _medGivenTimeCtrl.text =
            '${hour.toString().padLeft(2, '0')}:$minute $period';
      });
    }
  }

  Widget _buildQuickPill(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _clearMedForm() {
    _medNameCtrl.clear();
    _medDosageCtrl.clear();
    _medRouteCtrl.clear();
    _medQtyCtrl.text = '1';
    _medPriceCtrl.clear();
    setState(() {
      _medType = 'Regular';
      _medFrequencyCtrl.text = '1-0-1';
      _medDurationCtrl.text = '5 days';
      _medGivenTimeCtrl.text = _getCurrentFormattedTime();
    });
  }

  void _clearConsForm() {
    _consNameCtrl.clear();
    _consQtyCtrl.text = '1';
    _consPriceCtrl.clear();
  }

  int _parseDurationDays(String? durationStr) {
    if (durationStr == null || durationStr.trim().isEmpty) return 5;
    final lower = durationStr.toLowerCase().trim();
    final match = RegExp(r'(\d+)').firstMatch(lower);
    if (match != null) {
      final num = int.tryParse(match.group(1)!);
      if (num != null && num > 0) {
        if (lower.contains('month')) return num * 30;
        if (lower.contains('week')) return num * 7;
        return num;
      }
    }
    if (lower.contains('month')) return 30;
    if (lower.contains('week')) return 7;
    return 5;
  }

  Widget _buildDailyDoseChecklist({
    required HomeVisitMedicine medicine,
    required HomeVisitModel visit,
    required HomeVisitController controller,
    int? currentDayNumber,
  }) {
    if (medicine.medicineType == 'STAT') {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEEBC8),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFBD38D)),
        ),
        child: Text(
          context.tr('stat_given_immediately', fallback: 'STAT - Given Immediately (Single Dose)'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC05621),
          ),
        ),
      );
    }

    final totalDays = _parseDurationDays(medicine.duration);

    // Calculate medication start date (Day 1) from medicine.administeredAt
    DateTime startDt = DateTime.now();
    if (medicine.administeredAt != null &&
        medicine.administeredAt!.isNotEmpty) {
      try {
        final formatted = medicine.administeredAt!.trim().replaceAll(' ', 'T');
        final parsed = DateTime.parse(formatted);
        startDt = parsed.isUtc ? parsed.toLocal() : parsed;
      } catch (_) {}
    } else if (visit.scheduledDate.isNotEmpty) {
      try {
        startDt = DateTime.parse(visit.scheduledDate);
      } catch (_) {}
    }
    final medStartDate = DateTime(startDt.year, startDt.month, startDt.day);

    // Calculate current visit date
    DateTime currentVisitDt = DateTime.now();
    if (visit.scheduledDate.isNotEmpty) {
      try {
        currentVisitDt = DateTime.parse(visit.scheduledDate);
      } catch (_) {}
    }
    final currentVisitDate = DateTime(
      currentVisitDt.year,
      currentVisitDt.month,
      currentVisitDt.day,
    );

    final dayDiff = currentVisitDate.difference(medStartDate).inDays;
    final activeDayNumber =
        currentDayNumber ?? (dayDiff >= 0 ? dayDiff + 1 : 1);
    final startDateStr =
        "${medStartDate.day.toString().padLeft(2, '0')}/${medStartDate.month.toString().padLeft(2, '0')}/${medStartDate.year}";

    return StatefulBuilder(
      builder: (context, setLocalChecklistState) {
        final daysMap = Map<String, bool>.from(medicine.administeredDays);

        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  const Icon(
                    Icons.playlist_add_check,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  Text(
                    context.tr('daily_tablet_checklist', fallback: 'Daily Tablet Administration Checklist:'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    '($totalDays ${context.tr('days_plan', fallback: 'Days Plan')} | ${context.tr('prescribed_added', fallback: 'Prescribed/Added')}: $startDateStr | ${context.tr('current_visit', fallback: 'Current Visit')}: ${context.tr('day', fallback: 'Day')} $activeDayNumber)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int dayIdx = 1; dayIdx <= totalDays; dayIdx++) ...[
                    () {
                      final dayKey = '$dayIdx';
                      final isChecked = daysMap[dayKey] == true;
                      final isToday = dayIdx == activeDayNumber;
                      final isPast = dayIdx < activeDayNumber;
                      final isFuture = dayIdx > activeDayNumber;

                      // Compute date for this day
                      final dayDate = medStartDate.add(
                        Duration(days: dayIdx - 1),
                      );
                      final dayDateStr =
                          "${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}";

                      return MouseRegion(
                        cursor: isToday && !isChecked
                            ? SystemMouseCursors.click
                            : (isFuture
                                  ? SystemMouseCursors.forbidden
                                  : SystemMouseCursors.basic),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            if (isFuture) {
                              AppNotification.showWarning(
                                context,
                                'Day $dayIdx ($dayDateStr) is scheduled for a future visit and cannot be executed today.',
                              );
                              return;
                            }
                            if (isPast && !isChecked) {
                              AppNotification.showInfo(
                                context,
                                'Day $dayIdx ($dayDateStr) was scheduled for a past visit.',
                              );
                              return;
                            }
                            if (isChecked) {
                              AppNotification.showInfo(
                                context,
                                'Dose for this day is already recorded and cannot be unticked.',
                              );
                              return;
                            }
                            setLocalChecklistState(() {
                              daysMap[dayKey] = true;
                              medicine.administeredDays[dayKey] = true;
                            });
                            if (medicine.id != null) {
                              await controller.toggleMedicineDay(
                                visit.id,
                                medicine.id!,
                                daysMap,
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? AppTheme.secondaryColor.withOpacity(0.15)
                                  : (isToday
                                        ? AppTheme.primaryColor.withOpacity(0.1)
                                        : (isFuture
                                              ? const Color(0xFFF1F5F9)
                                              : const Color(0xFFF8FAFC))),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChecked
                                    ? AppTheme.secondaryColor
                                    : (isToday
                                          ? AppTheme.primaryColor
                                          : (isFuture
                                                ? const Color(0xFFE2E8F0)
                                                : const Color(0xFFCBD5E1))),
                                width: isToday ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isChecked
                                      ? Icons.check_box
                                      : (isFuture
                                            ? Icons.lock_clock_outlined
                                            : Icons.check_box_outline_blank),
                                  size: 17,
                                  color: isChecked
                                      ? AppTheme.secondaryColor
                                      : (isToday
                                            ? AppTheme.primaryColor
                                            : (isFuture
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B))),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "${context.tr('day', fallback: 'Day')} $dayIdx ($dayDateStr)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isToday || isChecked
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isChecked
                                        ? AppTheme.secondaryColor
                                        : (isToday
                                              ? AppTheme.primaryColor
                                              : (isFuture
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF334155))),
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                       context.tr('today_badge', fallback: 'TODAY'),
                                       style: const TextStyle(
                                         fontSize: 8,
                                         fontWeight: FontWeight.bold,
                                         color: Colors.white,
                                       ),
                                     ),
                                  ),
                                ] else if (isFuture) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCBD5E1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                       context.tr('locked_badge', fallback: 'LOCKED'),
                                       style: const TextStyle(
                                         fontSize: 7,
                                         fontWeight: FontWeight.bold,
                                         color: Colors.white,
                                       ),
                                     ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }(),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDigitInputSlot(
    TextEditingController ctrl,
    FocusNode currentFn,
    FocusNode? nextFn,
    String label,
    VoidCallback onChanged,
    StateSetter setModalState,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 36,
          height: 38,
          child: TextFormField(
            controller: ctrl,
            focusNode: currentFn,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[01]')),
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (val) {
              setModalState(() {
                onChanged();
              });
              if (val.length == 1 && nextFn != null) {
                nextFn.requestFocus();
              }
            },
          ),
        ),
      ],
    );
  }

  Future<bool> _showConfirmDeleteDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.dangerColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dangerColor,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
            ),
            actions: [
              OutlinedButton(
                style: AppTheme.cancelButton,
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: AppTheme.dangerButton,
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showRecordMedicineModal(
    BuildContext context,
    HomeVisitModel visit,
    HomeVisitController controller, {
    HomeVisitMedicine? existingMedicine,
  }) {
    String localType = existingMedicine?.medicineType ?? _medType;
    String selectedFoodTiming =
        existingMedicine?.foodTiming ??
        (existingMedicine?.route ?? 'After Food');
    final nameCtrl = TextEditingController(
      text: existingMedicine?.medicineName ?? _medNameCtrl.text,
    );
    final qtyCtrl = TextEditingController(
      text: existingMedicine != null
          ? existingMedicine.quantity.toString()
          : (_medQtyCtrl.text.isNotEmpty ? _medQtyCtrl.text : '1'),
    );

    // 4-Parameter Frequency Controllers (M - A - E - N)
    final f1Ctrl = TextEditingController(text: '1');
    final f2Ctrl = TextEditingController(text: '0');
    final f3Ctrl = TextEditingController(text: '1');
    final f4Ctrl = TextEditingController(text: '0');
    final fn1 = FocusNode();
    final fn2 = FocusNode();
    final fn3 = FocusNode();
    final fn4 = FocusNode();

    final freqSource = existingMedicine?.frequency ?? _medFrequencyCtrl.text;
    if (freqSource.isNotEmpty && freqSource != 'STAT') {
      final digits = freqSource.replaceAll(RegExp(r'[^01]'), '');
      if (digits.length >= 1) f1Ctrl.text = digits[0];
      if (digits.length >= 2) f2Ctrl.text = digits[1];
      if (digits.length >= 3) f3Ctrl.text = digits[2];
      if (digits.length >= 4) f4Ctrl.text = digits[3];
    }

    final freqCtrl = TextEditingController(
      text: localType == 'STAT'
          ? 'STAT'
          : '${f1Ctrl.text} - ${f2Ctrl.text} - ${f3Ctrl.text} - ${f4Ctrl.text}',
    );

    // Duration Stepper Controller (Max 365 Days)
    int initialDays = 5;
    final durSource = existingMedicine?.duration ?? _medDurationCtrl.text;
    if (durSource.isNotEmpty) {
      final match = RegExp(r'(\d+)').firstMatch(durSource);
      if (match != null) {
        initialDays = int.tryParse(match.group(1)!) ?? 5;
      }
    }
    final durDaysCtrl = TextEditingController(
      text: initialDays.clamp(1, 365).toString(),
    );
    final durCtrl = TextEditingController(
      text: localType == 'STAT'
          ? 'STAT - Single Dose'
          : '${durDaysCtrl.text} Days',
    );

    final givenTimeCtrl = TextEditingController(
      text:
          existingMedicine?.givenTime ??
          (_medGivenTimeCtrl.text.isNotEmpty
              ? _medGivenTimeCtrl.text
              : _getCurrentFormattedTime()),
    );

    bool isSubmitting = false;
    bool submitAttempted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            void updateFreqText() {
              if (localType == 'STAT') {
                freqCtrl.text = 'STAT';
              } else {
                freqCtrl.text =
                    '${f1Ctrl.text.isEmpty ? "0" : f1Ctrl.text} - ${f2Ctrl.text.isEmpty ? "0" : f2Ctrl.text} - ${f3Ctrl.text.isEmpty ? "0" : f3Ctrl.text} - ${f4Ctrl.text.isEmpty ? "0" : f4Ctrl.text}';
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.medication_liquid,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        existingMedicine != null
                            ? context.tr('edit_medicine_item')
                            : context.tr('record_medicine_item'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dCtx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(context.tr('medicine_type_req')),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(context.tr('regular')),
                            selected: localType == 'Regular',
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: localType == 'Regular'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  localType = 'Regular';
                                  updateFreqText();
                                  durCtrl.text = '${durDaysCtrl.text} Days';
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(context.tr('stat')),
                            selected: localType == 'STAT',
                            selectedColor: const Color(0xFFDD6B20),
                            labelStyle: TextStyle(
                              color: localType == 'STAT'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  localType = 'STAT';
                                  freqCtrl.text = 'STAT';
                                  durCtrl.text = 'STAT - Single Dose';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildLabel(context.tr('medicine_name_req')),
                      CustomDropdownSearch(
                        label: '',
                        hint: context.tr('select_medicine_hint'),
                        dropdownMap: {
                          for (final m in (_dbMedicines.isNotEmpty
                              ? _dbMedicines
                              : _defaultMedicines))
                            m: context.translateMedicine(m),
                        },
                        value: nameCtrl.text.isNotEmpty ? nameCtrl.text : null,
                        allowFreeText: true,
                        onChanged: (val) {
                          setModalState(() {
                            nameCtrl.text = val ?? '';
                            submitAttempted = false;
                          });
                        },
                      ),
                      if (submitAttempted && nameCtrl.text.trim().isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            'Please select or enter medicine name',
                            style: TextStyle(
                              color: AppTheme.dangerColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (MediaQuery.of(context).size.width < 600) ...[
                        _buildLabel(context.tr('qty_req', fallback: 'Qty *')),
                        _buildQtyStepperField(
                          controller: qtyCtrl,
                          min: 1,
                          max: 999,
                          setModalState: setModalState,
                        ),
                        const SizedBox(height: 14),
                        _buildLabel(context.tr('food_label', fallback: 'Food Relation')),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedFoodTiming,
                          decoration: AppTheme.standardInputDecoration(
                            hintText: 'Select Food Relation',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'After Food',
                              child: Text(
                                context.tr('food_after', fallback: 'After Food'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Before Food',
                              child: Text(
                                context.tr('food_before', fallback: 'Before Food'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'With Food',
                              child: Text(
                                context.tr('food_with', fallback: 'With Food'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedFoodTiming = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildLabel(
                          localType == 'STAT'
                              ? context.tr('frequency', fallback: 'Frequency')
                              : context.tr('frequency_req', fallback: 'Frequency (1 - 0 - 1 - 0) *'),
                        ),
                        if (localType == 'STAT')
                          Container(
                            height: 48,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEEBC8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFBD38D),
                              ),
                            ),
                            child: Text(
                              context.tr('stat_single_dose', fallback: 'STAT (Immediate Single Dose)'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC05621),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildDigitInputSlot(
                                  f1Ctrl,
                                  fn1,
                                  fn2,
                                  context.tr('morning_abbr', fallback: 'M'),
                                  updateFreqText,
                                  setModalState,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                _buildDigitInputSlot(
                                  f2Ctrl,
                                  fn2,
                                  fn3,
                                  context.tr('afternoon_abbr', fallback: 'A'),
                                  updateFreqText,
                                  setModalState,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                _buildDigitInputSlot(
                                  f3Ctrl,
                                  fn3,
                                  fn4,
                                  context.tr('evening_abbr', fallback: 'E'),
                                  updateFreqText,
                                  setModalState,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                _buildDigitInputSlot(
                                  f4Ctrl,
                                  fn4,
                                  null,
                                  context.tr('night_abbr', fallback: 'N'),
                                  updateFreqText,
                                  setModalState,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),
                        _buildLabel(
                          localType == 'STAT'
                              ? context.tr('duration', fallback: 'Duration')
                              : '${context.tr("duration", fallback: "Duration")} *',
                        ),
                        if (localType == 'STAT')
                          Container(
                            height: 48,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              context.tr('stat_single_dose_display', fallback: 'STAT - Single Dose'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          _buildQtyStepperField(
                            controller: durDaysCtrl,
                            min: 1,
                            max: 365,
                            suffix: 'Days',
                            setModalState: setModalState,
                            onChanged: (val) {
                              durCtrl.text = '$val Days';
                            },
                          ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel(context.tr('qty_req', fallback: 'Qty *')),
                                  _buildQtyStepperField(
                                    controller: qtyCtrl,
                                    min: 1,
                                    max: 999,
                                    setModalState: setModalState,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel(context.tr('food_label', fallback: 'Food Relation')),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: selectedFoodTiming,
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText: 'Select Food Relation',
                                        ),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'After Food',
                                        child: Text(
                                          context.tr('food_after', fallback: 'After Food'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Before Food',
                                        child: Text(
                                          context.tr('food_before', fallback: 'Before Food'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'With Food',
                                        child: Text(
                                          context.tr('food_with', fallback: 'With Food'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(
                                          () => selectedFoodTiming = val,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel(
                                    localType == 'STAT'
                                        ? context.tr('frequency', fallback: 'Frequency')
                                        : context.tr('frequency_req', fallback: 'Frequency (1 - 0 - 1 - 0) *'),
                                  ),
                                  if (localType == 'STAT')
                                    Container(
                                      height: 48,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEEBC8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFFBD38D),
                                        ),
                                      ),
                                      child: Text(
                                        context.tr('stat_single_dose', fallback: 'STAT (Immediate Single Dose)'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFC05621),
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _buildDigitInputSlot(
                                            f1Ctrl,
                                            fn1,
                                            fn2,
                                            context.tr('morning_abbr', fallback: 'M'),
                                            updateFreqText,
                                            setModalState,
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              '-',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          _buildDigitInputSlot(
                                            f2Ctrl,
                                            fn2,
                                            fn3,
                                            context.tr('afternoon_abbr', fallback: 'A'),
                                            updateFreqText,
                                            setModalState,
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              '-',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          _buildDigitInputSlot(
                                            f3Ctrl,
                                            fn3,
                                            fn4,
                                            context.tr('evening_abbr', fallback: 'E'),
                                            updateFreqText,
                                            setModalState,
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Text(
                                              '-',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          _buildDigitInputSlot(
                                            f4Ctrl,
                                            fn4,
                                            null,
                                            context.tr('night_abbr', fallback: 'N'),
                                            updateFreqText,
                                            setModalState,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel(
                                    localType == 'STAT'
                                        ? context.tr('duration', fallback: 'Duration')
                                        : '${context.tr("duration", fallback: "Duration")} *',
                                  ),
                                  if (localType == 'STAT')
                                    Container(
                                      height: 48,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Text(
                                        context.tr('stat_single_dose_display', fallback: 'STAT - Single Dose'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  else
                                    _buildQtyStepperField(
                                      controller: durDaysCtrl,
                                      min: 1,
                                      max: 365,
                                     suffix: context.tr('days', fallback: 'Days'),
                                      setModalState: setModalState,
                                      onChanged: (val) {
                                        durCtrl.text = '$val Days';
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (localType == 'STAT') ...[
                        const SizedBox(height: 14),
                        _buildLabel(context.tr('given_time_req', fallback: 'Given Time *')),
                        TextFormField(
                          controller: givenTimeCtrl,
                          readOnly: true,
                          decoration:
                              AppTheme.standardInputDecoration(
                                hintText: 'e.g. 09:30 AM',
                                prefixIcon: Icons.access_time,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.access_time,
                                    color: AppTheme.primaryColor,
                                  ),
                                  onPressed: () async {
                                    TimeOfDay initTime = TimeOfDay.now();
                                    if (givenTimeCtrl.text.isNotEmpty) {
                                      final curMins = _parseTimeToMinutes(
                                        givenTimeCtrl.text,
                                      );
                                      if (curMins != null) {
                                        initTime = TimeOfDay(
                                          hour: curMins ~/ 60,
                                          minute: curMins % 60,
                                        );
                                      }
                                    }

                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: initTime,
                                    );
                                    if (picked != null) {
                                      final hour = picked.hourOfPeriod == 0
                                          ? 12
                                          : picked.hourOfPeriod;
                                      final minute = picked.minute
                                          .toString()
                                          .padLeft(2, '0');
                                      final period =
                                          picked.period == DayPeriod.am
                                          ? 'AM'
                                          : 'PM';
                                      setModalState(() {
                                        givenTimeCtrl.text =
                                            '${hour.toString().padLeft(2, '0')}:$minute $period';
                                      });
                                    }
                                  },
                                ),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: AppTheme.cancelButton,
                  onPressed: isSubmitting ? null : () => Navigator.pop(dCtx),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton.icon(
                  style: AppTheme.dangerButton,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    isSubmitting
                        ? (existingMedicine != null
                              ? context.tr('updating')
                              : context.tr('saving'))
                        : (existingMedicine != null
                              ? context.tr('update_medicine_item')
                              : context.tr('save_medicine_item')),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            setModalState(() => submitAttempted = true);
                            return;
                          }

                          if (localType == 'STAT') {
                            final givenTimeText = givenTimeCtrl.text.trim();
                            if (givenTimeText.isEmpty) {
                              AppNotification.showError(
                                dCtx,
                                'Please select Given Time for STAT medicine',
                              );
                              return;
                            }
                          }

                          updateFreqText();
                          if (localType != 'STAT') {
                            durCtrl.text = '${durDaysCtrl.text} Days';
                          }

                          setModalState(() => isSubmitting = true);
                          final payload = {
                            'medicine_name': nameCtrl.text.trim(),
                            'dosage': existingMedicine?.dosage ?? '',
                            'route': selectedFoodTiming,
                            'food_timing': selectedFoodTiming,
                            'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                            'unit_price': existingMedicine?.unitPrice ?? 0.0,
                            'medicine_type': localType,
                            'frequency': freqCtrl.text.trim(),
                            'duration': durCtrl.text.trim(),
                            'given_time': givenTimeCtrl.text.trim(),
                            'administered_days':
                                (existingMedicine != null &&
                                    existingMedicine
                                        .administeredDays
                                        .isNotEmpty)
                                ? existingMedicine.administeredDays
                                : {"1": true},
                          };

                          final bool success;
                          if (existingMedicine != null &&
                              existingMedicine.id != null) {
                            success = await controller.updateMedicineItem(
                              visit.id,
                              existingMedicine.id!,
                              payload,
                            );
                          } else {
                            success = await controller.submitMedicine(
                              visit.id,
                              payload,
                            );
                          }

                          if (context.mounted && dCtx.mounted) {
                            Navigator.pop(dCtx);
                            if (success) {
                              AppNotification.showSuccess(
                                context,
                                existingMedicine != null
                                    ? 'Medicine updated successfully'
                                    : 'Medicine logged successfully',
                              );
                            } else {
                              AppNotification.showError(
                                context,
                                controller.errorMessage ??
                                    'Failed to save medicine',
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordConsumableModal(
    BuildContext context,
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final nameCtrl = TextEditingController(text: _consNameCtrl.text);
    final qtyCtrl = TextEditingController(
      text: _consQtyCtrl.text.isNotEmpty ? _consQtyCtrl.text : '1',
    );
    bool isSubmitting = false;
    bool submitAttempted = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Record Consumable Item',
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
                    onPressed: () => Navigator.pop(dCtx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Consumable Item Name *'),
                    CustomDropdownSearch(
                      label: '',
                      hint: 'Select consumable item (e.g. Sterile Bandage)',
                      dropdownItems: _dbConsumables.isNotEmpty
                          ? _dbConsumables
                          : _defaultConsumables,
                      value: nameCtrl.text.isNotEmpty ? nameCtrl.text : null,
                      allowFreeText: true,
                      maxLength: 60,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(60),
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9\u0B80-\u0BFF\s]'),
                        ),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          nameCtrl.text = val ?? '';
                          submitAttempted = false;
                        });
                      },
                    ),
                    if (submitAttempted && nameCtrl.text.trim().isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Please select or enter consumable name',
                          style: TextStyle(
                            color: AppTheme.dangerColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _buildLabel('Quantity Used *'),
                    _buildQtyStepperField(
                      controller: qtyCtrl,
                      min: 1,
                      max: 999,
                      setModalState: setModalState,
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: AppTheme.cancelButton,
                  onPressed: isSubmitting ? null : () => Navigator.pop(dCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: AppTheme.dangerButton,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    isSubmitting ? 'Saving...' : 'Save Consumable Item',
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final cName = nameCtrl.text.trim();
                          if (cName.length < 3 || cName.length > 60) {
                            setModalState(() => submitAttempted = true);
                            AppNotification.showError(
                              dialogCtx,
                              'Consumable name must be between 3 and 60 characters',
                            );
                            return;
                          }
                          if (!RegExp(r'[a-zA-Z\u0B80-\u0BFF]').hasMatch(cName)) {
                            AppNotification.showError(
                              dialogCtx,
                              'Consumable name must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols',
                            );
                            return;
                          }
                          if (!RegExp(r'^[a-zA-Z0-9\u0B80-\u0BFF\s]+$').hasMatch(cName)) {
                            AppNotification.showError(
                              dialogCtx,
                              'Special characters are not allowed in consumable item name',
                            );
                            return;
                          }
                          final parsedQty = (int.tryParse(qtyCtrl.text) ?? 1)
                              .clamp(1, 999);

                          setModalState(() => isSubmitting = true);
                          final success = await controller
                              .submitConsumable(visit.id, {
                                'item_name': cName,
                                'quantity_used': parsedQty,
                                'unit_price': 0.0,
                              });
                          if (context.mounted && dCtx.mounted) {
                            Navigator.pop(dCtx);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  void _showAddManualConsumableDialog(
    BuildContext context,
    Function(ProcedureConsumableMappingModel) onAdd,
  ) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '20');
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'Pc');
    bool submitAttempted = false;
    bool isPriceLocked = false;

    final availableConsumables = _dbConsumables.isNotEmpty
        ? _dbConsumables
        : _defaultConsumables;

    const defaultPriceMap = {
      'Diaper': 40.0,
      'Gloves': 15.0,
      'Disposable Sheet': 35.0,
      'Gauze': 10.0,
      'Dressing Pad': 25.0,
      'Syringe 5ml': 15.0,
      'Alcohol Swab': 5.0,
      'Antiseptic Solution 100ml': 50.0,
      'Sterile Bandage': 20.0,
      'IV Cannula 20G': 65.0,
      'Adhesive Tape': 15.0,
    };

    double? getKnownConsumablePrice(String cName) {
      final key = cName.toLowerCase().trim();
      if (key.isEmpty) return null;
      if (_consumablePrices.containsKey(key)) {
        return _consumablePrices[key];
      }
      if (_defaultConsumablePrices.containsKey(key)) {
        return _defaultConsumablePrices[key];
      }
      for (final entry in defaultPriceMap.entries) {
        if (entry.key.toLowerCase().trim() == key) {
          return entry.value;
        }
      }
      return null;
    }

    bool isKnownItem(String cName) {
      final key = cName.toLowerCase().trim();
      if (key.isEmpty) return false;
      return availableConsumables.any((c) => c.toLowerCase().trim() == key) ||
          _consumablePrices.containsKey(key) ||
          _defaultConsumablePrices.containsKey(key) ||
          defaultPriceMap.keys.any((k) => k.toLowerCase().trim() == key);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add Consumable Item',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Consumable Name *'),
                    CustomDropdownSearch(
                      label: '',
                      hint: 'Select or type consumable name',
                      dropdownItems: availableConsumables,
                      allowFreeText: true,
                      maxLength: 60,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(60),
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9\s]'),
                        ),
                      ],
                      onChanged: (val) {
                        setDlgState(() {
                          nameCtrl.text = val ?? '';
                          submitAttempted = false;
                          final knownPrice = getKnownConsumablePrice(
                            nameCtrl.text,
                          );
                          if (knownPrice != null) {
                            priceCtrl.text = knownPrice
                                .toStringAsFixed(2)
                                .replaceAll(RegExp(r'\.00$'), '');
                            isPriceLocked = true;
                          } else if (isKnownItem(nameCtrl.text)) {
                            priceCtrl.text = '20';
                            isPriceLocked = true;
                          } else {
                            isPriceLocked = false;
                          }
                        });
                      },
                    ),
                    if (submitAttempted && nameCtrl.text.trim().isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Please select or enter consumable name',
                          style: TextStyle(
                            color: AppTheme.dangerColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildLabel('Unit Price (₹)'),
                                  if (isPriceLocked) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.lock,
                                      size: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ],
                              ),
                              TextFormField(
                                controller: priceCtrl,
                                readOnly: isPriceLocked,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                  LengthLimitingTextInputFormatter(7),
                                ],
                                decoration: AppTheme.standardInputDecoration(
                                  hintText: isPriceLocked
                                      ? 'Locked by catalog'
                                      : 'Price (Max ₹50,000)',
                                  suffixIcon: isPriceLocked
                                      ? const Tooltip(
                                          message:
                                              'Price is locked for existing catalog items',
                                          child: Icon(
                                            Icons.lock_outline,
                                            size: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                        )
                                      : null,
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
                              _buildLabel('Quantity *'),
                              _buildQtyStepperField(
                                controller: qtyCtrl,
                                min: 1,
                                max: 999,
                                setModalState: setDlgState,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  style: AppTheme.cancelButton,
                  onPressed: () {
                    ModalHistoryHelper.skipNextHistoryBack();
                    Navigator.pop(dCtx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: AppTheme.dangerButton,
                  onPressed: () {
                    final cName = nameCtrl.text.trim();
                    if (cName.isEmpty || cName.length < 3) {
                      setDlgState(() => submitAttempted = true);
                      AppNotification.showError(
                        ctx,
                        'Consumable name must be at least 3 characters',
                      );
                      return;
                    }
                    if (!RegExp(r'[a-zA-Z\u0B80-\u0BFF]').hasMatch(cName)) {
                      AppNotification.showError(
                        ctx,
                        'Consumable name must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols',
                      );
                      return;
                    }
                    if (!RegExp(r'^[a-zA-Z0-9\u0B80-\u0BFF\s]+$').hasMatch(cName)) {
                      AppNotification.showError(
                        ctx,
                        'Special characters are not allowed in consumable item name',
                      );
                      return;
                    }
                    final rawPrice = double.tryParse(priceCtrl.text.trim());
                    if (rawPrice == null || rawPrice < 0 || rawPrice > 50000) {
                      AppNotification.showError(
                        ctx,
                        'Unit price must be between ₹0 and ₹50,000',
                      );
                      return;
                    }
                    final price = rawPrice;
                    final qty = (int.tryParse(qtyCtrl.text.trim()) ?? 1).clamp(
                      1,
                      999,
                    );
                    final unit = unitCtrl.text.trim().isNotEmpty
                        ? unitCtrl.text.trim()
                        : 'Pc';

                    final item = ProcedureConsumableMappingModel(
                      consumableId: 0,
                      consumableName: cName,
                      unit: unit,
                      unitPrice: price,
                      qtyPerProcedure: qty,
                    );
                    onAdd(item);
                    ModalHistoryHelper.skipNextHistoryBack();
                    Navigator.pop(dCtx);
                  },
                  child: const Text('Add Consumable'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordProcedureModal(
    BuildContext context,
    HomeVisitModel visit,
    HomeVisitController controller, {
    HomeVisitProcedureModel? existingProcedure,
  }) {
    if (controller.proceduresMaster.isEmpty) {
      controller.fetchProceduresMaster();
    }

    String selectedProcName = existingProcedure?.procedureName ?? '';
    ProcedureMasterModel? selectedProc;
    final chargeCtrl = TextEditingController(
      text: existingProcedure != null
          ? existingProcedure.chargePerProcedure.toStringAsFixed(0)
          : '0',
    );
    String selectedFreq = existingProcedure?.frequency ?? 'Once Daily';
    int freqMultiplier = existingProcedure?.frequencyMultiplier ?? 1;
    bool isSubmitting = false;
    final List<ProcedureConsumableMappingModel> manualConsumables = [];

    final Map<String, TextEditingController> itemQtyCtrls = {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final procs = controller.proceduresMaster.isNotEmpty
                ? controller.proceduresMaster
                : _defaultProcedures;
            final procNames = procs.map((p) => p.name).toList();

            if (selectedProcName.isNotEmpty && selectedProc == null) {
              selectedProc = procs.firstWhere(
                (p) =>
                    p.name.toLowerCase() ==
                    selectedProcName.trim().toLowerCase(),
                orElse: () => ProcedureMasterModel(
                  id: existingProcedure?.procedureId ?? 0,
                  name: selectedProcName.trim(),
                  procedureCharge: existingProcedure?.chargePerProcedure ?? 0.0,
                  status: 'Active',
                  mappedConsumables: [],
                ),
              );
            }

            void updateCalculatedItems() {
              if (selectedProc == null) return;
              for (var m in selectedProc!.mappedConsumables) {
                final calculatedTotal = m.qtyPerProcedure * freqMultiplier;
                if (!itemQtyCtrls.containsKey(m.consumableName)) {
                  itemQtyCtrls[m.consumableName] = TextEditingController(
                    text: calculatedTotal.toString(),
                  );
                } else {
                  itemQtyCtrls[m.consumableName]!.text = calculatedTotal
                      .toString();
                }
              }
            }

            final chargePerProc =
                double.tryParse(chargeCtrl.text.trim()) ??
                (selectedProc?.procedureCharge ?? 0.0);
            final totalProcCharge = chargePerProc * freqMultiplier;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.medical_services_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        existingProcedure != null
                            ? context.tr('edit_procedure_item')
                            : context.tr('record_procedure_item'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dCtx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 650,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(context.tr('procedure_name_req')),
                      CustomDropdownSearch(
                        label: '',
                        hint: context.tr('select_procedure_hint'),
                        dropdownMap: {
                          for (final p in procs) p.name: context.translateProcedure(p.name),
                        },
                        value: selectedProcName.isNotEmpty
                            ? selectedProcName
                            : null,
                        allowFreeText: true,
                        maxLength: 60,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(60),
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;]'),
                          ),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedProcName = val ?? '';
                            if (selectedProcName.trim().isNotEmpty) {
                              final match = procs.firstWhere(
                                (p) =>
                                    p.name.toLowerCase() ==
                                    selectedProcName.trim().toLowerCase(),
                                orElse: () => ProcedureMasterModel(
                                  id: 0,
                                  name: selectedProcName.trim(),
                                  procedureCharge: 0.0,
                                  status: 'Active',
                                  mappedConsumables: [],
                                ),
                              );
                              selectedProc = match;
                              if (match.id != 0) {
                                chargeCtrl.text = match.procedureCharge
                                    .toStringAsFixed(0);
                              } else {
                                chargeCtrl.text = '0';
                              }
                            } else {
                              selectedProc = null;
                              chargeCtrl.text = '0';
                            }
                            itemQtyCtrls.clear();
                            updateCalculatedItems();
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('procedure_charge')),
                                TextFormField(
                                  controller: chargeCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                    LengthLimitingTextInputFormatter(8),
                                  ],
                                  decoration: AppTheme.standardInputDecoration(
                                    hintText:
                                        'Charge per procedure (Max ₹100,000)',
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {});
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
                                _buildLabel(context.tr('frequency')),
                                CustomDropdownSearch(
                                  label: '',
                                  hint:
                                      'Select or enter frequency (e.g. 1-999)',
                                  dropdownMap: {
                                    'Once Daily (1x/day)': context.tr(
                                      'freq_once_daily',
                                      fallback: 'Once Daily (1x/day)',
                                    ),
                                    '2 Times/Day (2x/day)': context.tr(
                                      'freq_twice_daily',
                                      fallback: '2 Times/Day (2x/day)',
                                    ),
                                    '3 Times/Day (3x/day)': context.tr(
                                      'freq_thrice_daily',
                                      fallback: '3 Times/Day (3x/day)',
                                    ),
                                    'Every 4 Hours (6x/day)': context.tr(
                                      'freq_every_4_hours',
                                      fallback: 'Every 4 Hours (6x/day)',
                                    ),
                                  },
                                  value: selectedFreq.isNotEmpty
                                      ? selectedFreq
                                      : null,
                                  allowFreeText: true,
                                  maxLength: 3,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  onChanged: (val) {
                                    if (val != null && val.trim().isNotEmpty) {
                                      setModalState(() {
                                        final trimmed = val.trim();
                                        if (trimmed.contains('Once Daily') ||
                                            trimmed.contains('1x')) {
                                          selectedFreq = 'Once Daily (1x/day)';
                                          freqMultiplier = 1;
                                        } else if (trimmed.contains(
                                              '2 Times',
                                            ) ||
                                            trimmed.contains('2x')) {
                                          selectedFreq = '2 Times/Day (2x/day)';
                                          freqMultiplier = 2;
                                        } else if (trimmed.contains(
                                              '3 Times',
                                            ) ||
                                            trimmed.contains('3x')) {
                                          selectedFreq = '3 Times/Day (3x/day)';
                                          freqMultiplier = 3;
                                        } else if (trimmed.contains(
                                              'Every 4 Hours',
                                            ) ||
                                            trimmed.contains('6x')) {
                                          selectedFreq =
                                              'Every 4 Hours (6x/day)';
                                          freqMultiplier = 6;
                                        } else {
                                          final numMatch = RegExp(
                                            r'(\d+)',
                                          ).firstMatch(trimmed);
                                          if (numMatch != null) {
                                            final parsedNum =
                                                int.tryParse(
                                                  numMatch.group(1)!,
                                                ) ??
                                                1;
                                            freqMultiplier = parsedNum.clamp(
                                              1,
                                              999,
                                            );
                                            selectedFreq =
                                                '$freqMultiplier Times/Day (${freqMultiplier}x/day)';
                                          } else {
                                            freqMultiplier = 1;
                                            selectedFreq =
                                                'Once Daily (1x/day)';
                                          }
                                        }
                                        updateCalculatedItems();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (selectedProcName.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Procedure Charge Breakdown:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${chargePerProc.toStringAsFixed(0)} per procedure × $selectedFreq',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Total Procedure Charge',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    '₹${totalProcCharge.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildLabel('Procedure Consumables'),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 15,
                              ),
                              label: const Text(
                                'Add Manually',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                _showAddManualConsumableDialog(context, (
                                  newConsumable,
                                ) {
                                  setModalState(() {
                                    final existingManualIdx = manualConsumables
                                        .indexWhere(
                                          (c) =>
                                              c.consumableName
                                                  .trim()
                                                  .toLowerCase() ==
                                              newConsumable.consumableName
                                                  .trim()
                                                  .toLowerCase(),
                                        );
                                    if (existingManualIdx != -1) {
                                      final existing =
                                          manualConsumables[existingManualIdx];
                                      final updatedQty =
                                          existing.qtyPerProcedure +
                                          newConsumable.qtyPerProcedure;
                                      manualConsumables[existingManualIdx] =
                                          ProcedureConsumableMappingModel(
                                            consumableId: existing.consumableId,
                                            consumableName:
                                                existing.consumableName,
                                            unit: existing.unit,
                                            unitPrice: existing.unitPrice,
                                            qtyPerProcedure: updatedQty,
                                          );
                                      if (itemQtyCtrls.containsKey(
                                        existing.consumableName,
                                      )) {
                                        final curVal =
                                            int.tryParse(
                                              itemQtyCtrls[existing
                                                      .consumableName]!
                                                  .text
                                                  .trim(),
                                            ) ??
                                            (existing.qtyPerProcedure *
                                                freqMultiplier);
                                        itemQtyCtrls[existing.consumableName]!
                                                .text =
                                            (curVal +
                                                    (newConsumable
                                                            .qtyPerProcedure *
                                                        freqMultiplier))
                                                .toString();
                                      }
                                    } else if (selectedProc != null &&
                                        selectedProc!.mappedConsumables.any(
                                          (c) =>
                                              c.consumableName
                                                  .trim()
                                                  .toLowerCase() ==
                                              newConsumable.consumableName
                                                  .trim()
                                                  .toLowerCase(),
                                        )) {
                                      final mappedItem = selectedProc!
                                          .mappedConsumables
                                          .firstWhere(
                                            (c) =>
                                                c.consumableName
                                                    .trim()
                                                    .toLowerCase() ==
                                                newConsumable.consumableName
                                                    .trim()
                                                    .toLowerCase(),
                                          );
                                      if (itemQtyCtrls.containsKey(
                                        mappedItem.consumableName,
                                      )) {
                                        final curVal =
                                            int.tryParse(
                                              itemQtyCtrls[mappedItem
                                                      .consumableName]!
                                                  .text
                                                  .trim(),
                                            ) ??
                                            (mappedItem.qtyPerProcedure *
                                                freqMultiplier);
                                        itemQtyCtrls[mappedItem.consumableName]!
                                                .text =
                                            (curVal +
                                                    (newConsumable
                                                            .qtyPerProcedure *
                                                        freqMultiplier))
                                                .toString();
                                      }
                                    } else {
                                      manualConsumables.add(newConsumable);
                                    }
                                  });
                                });
                              },
                            ),
                          ],
                        ),
                        () {
                          final allConsumables = [
                            if (selectedProc != null)
                              ...selectedProc!.mappedConsumables,
                            ...manualConsumables,
                          ];

                          if (allConsumables.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No pre-mapped consumables for this procedure. Click "+ Add Consumable Manually" above to add items.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.2),
                                1: FlexColumnWidth(1.2),
                                2: FlexColumnWidth(1.4),
                                3: FlexColumnWidth(1.5),
                                4: FlexColumnWidth(1.5),
                                5: FlexColumnWidth(0.6),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                  ),
                                  children: [
                                    _buildTableHeader('Consumable Item'),
                                    _buildTableHeader('Qty / Proc'),
                                    _buildTableHeader('Unit Price'),
                                    _buildTableHeader('Required Qty'),
                                    _buildTableHeader('Total (₹)'),
                                    _buildTableHeader(''),
                                  ],
                                ),
                                for (var m in allConsumables) ...[
                                  () {
                                    final totalQty =
                                        m.qtyPerProcedure * freqMultiplier;
                                    if (!itemQtyCtrls.containsKey(
                                      m.consumableName,
                                    )) {
                                      itemQtyCtrls[m.consumableName] =
                                          TextEditingController(
                                            text: totalQty.toString(),
                                          );
                                    }

                                    final currentQtyStr =
                                        itemQtyCtrls[m.consumableName]?.text
                                            .trim() ??
                                        '';
                                    final currentQtyRaw = int.tryParse(
                                      currentQtyStr,
                                    );
                                    final currentQty =
                                        (currentQtyRaw == null ||
                                            currentQtyRaw < 1)
                                        ? 1
                                        : currentQtyRaw.clamp(1, 999);

                                    double unitPrice = m.unitPrice;
                                    if (unitPrice <= 0) {
                                      const defaultPriceMap = {
                                        'Diaper': 40.0,
                                        'Gloves': 15.0,
                                        'Disposable Sheet': 35.0,
                                        'Gauze': 10.0,
                                        'Dressing Pad': 25.0,
                                        'Syringe 5ml': 15.0,
                                        'Alcohol Swab': 5.0,
                                        'Antiseptic Solution 100ml': 50.0,
                                        'Sterile Bandage': 20.0,
                                        'IV Cannula 20G': 65.0,
                                        'Adhesive Tape': 15.0,
                                      };
                                      unitPrice =
                                          defaultPriceMap[m.consumableName] ??
                                          20.0;
                                    }
                                    final lineTotal = currentQty * unitPrice;

                                    return TableRow(
                                      children: [
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              m.consumableName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              '${m.qtyPerProcedure} ${m.unit}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              '₹${unitPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: SizedBox(
                                              height: 34,
                                              child: TextFormField(
                                                controller:
                                                    itemQtyCtrls[m
                                                        .consumableName],
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.center,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                    3,
                                                  ),
                                                ],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                decoration:
                                                    AppTheme.standardInputDecoration(
                                                      hintText: 'Qty',
                                                    ).copyWith(
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 4,
                                                          ),
                                                    ),
                                                onChanged: (val) {
                                                  setModalState(() {});
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              '₹${lineTotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        TableCell(
                                          verticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: AppTheme.dangerColor,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              setModalState(() {
                                                manualConsumables.remove(m);
                                                if (selectedProc != null) {
                                                  selectedProc!
                                                      .mappedConsumables
                                                      .remove(m);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }(),
                                ],
                              ],
                            ),
                          );
                        }(),
                        const SizedBox(height: 12),
                        () {
                          final allConsumables = [
                            if (selectedProc != null)
                              ...selectedProc!.mappedConsumables,
                            ...manualConsumables,
                          ];
                          double totalConsumablesCost = 0.0;
                          for (var m in allConsumables) {
                            final qtyStr =
                                itemQtyCtrls[m.consumableName]?.text.trim() ??
                                '';
                            final qtyRaw = int.tryParse(qtyStr);
                            final qty = (qtyRaw == null || qtyRaw < 1)
                                ? (m.qtyPerProcedure * freqMultiplier).clamp(
                                    1,
                                    999,
                                  )
                                : qtyRaw.clamp(1, 999);

                            double uPrice = m.unitPrice;
                            if (uPrice <= 0) {
                              const defaultPriceMap = {
                                'Diaper': 40.0,
                                'Gloves': 15.0,
                                'Disposable Sheet': 35.0,
                                'Gauze': 10.0,
                                'Dressing Pad': 25.0,
                                'Syringe 5ml': 15.0,
                                'Alcohol Swab': 5.0,
                                'Antiseptic Solution 100ml': 50.0,
                                'Sterile Bandage': 20.0,
                                'IV Cannula 20G': 65.0,
                                'Adhesive Tape': 15.0,
                              };
                              uPrice =
                                  defaultPriceMap[m.consumableName] ?? 20.0;
                            }
                            totalConsumablesCost += (qty * uPrice);
                          }
                          final grandTotal =
                              totalProcCharge + totalConsumablesCost;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Procedure Base Charge:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      '₹${totalProcCharge.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Consumables Cost:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      '₹${totalConsumablesCost.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Divider(
                                    height: 1,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Grand Total Price:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    Text(
                                      '₹${grandTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.secondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: AppTheme.cancelButton,
                  onPressed: isSubmitting ? null : () => Navigator.pop(dCtx),
                  child: Text(context.tr('cancel')),
                ),
                ElevatedButton.icon(
                  style: AppTheme.dangerButton,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    isSubmitting
                        ? (existingProcedure != null
                              ? context.tr('updating')
                              : context.tr('saving'))
                        : (existingProcedure != null
                              ? context.tr('update_procedure_item')
                              : context.tr('save_procedure_item')),
                  ),
                  onPressed: (isSubmitting || selectedProcName.trim().isEmpty)
                      ? null
                      : () async {
                          final procName = selectedProcName.trim();
                          if (procName.length < 3 || procName.length > 60) {
                            AppNotification.showError(
                              dialogCtx,
                              'Procedure name must be between 3 and 60 characters',
                            );
                            return;
                          }
                          if (!RegExp(r'[a-zA-Z\u0B80-\u0BFF]').hasMatch(procName)) {
                            AppNotification.showError(
                              dialogCtx,
                              'Procedure name must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols',
                            );
                            return;
                          }
                          if (!RegExp(
                            r'^[a-zA-Z0-9\u0B80-\u0BFF\s.,/#\-\(\):;]+$',
                          ).hasMatch(procName)) {
                            AppNotification.showError(
                              dialogCtx,
                              'Procedure name contains invalid special characters',
                            );
                            return;
                          }

                          final parsedCharge = double.tryParse(
                            chargeCtrl.text.trim(),
                          );
                          if (parsedCharge == null ||
                              parsedCharge < 0 ||
                              parsedCharge > 100000) {
                            AppNotification.showError(
                              dialogCtx,
                              'Procedure charge must be a valid amount between ₹0 and ₹1,00,000',
                            );
                            return;
                          }

                          final allConsumables = [
                            if (selectedProc != null)
                              ...selectedProc!.mappedConsumables,
                            ...manualConsumables,
                          ];

                          for (var m in allConsumables) {
                            final qStr =
                                itemQtyCtrls[m.consumableName]?.text.trim() ??
                                '';
                            final qVal = int.tryParse(qStr);
                            if (qVal == null || qVal < 1 || qVal > 999) {
                              AppNotification.showError(
                                dialogCtx,
                                'Required quantity for "${m.consumableName}" must be between 1 and 999',
                              );
                              return;
                            }
                          }

                          setModalState(() => isSubmitting = true);

                          final itemsPayload = allConsumables.map((m) {
                            final customTotal =
                                (int.tryParse(
                                          itemQtyCtrls[m.consumableName]
                                                  ?.text ??
                                              '',
                                        ) ??
                                        (m.qtyPerProcedure * freqMultiplier))
                                    .clamp(1, 999);
                            double uPrice = m.unitPrice;
                            if (uPrice <= 0) {
                              const defaultPriceMap = {
                                'Diaper': 40.0,
                                'Gloves': 15.0,
                                'Disposable Sheet': 35.0,
                                'Gauze': 10.0,
                                'Dressing Pad': 25.0,
                                'Syringe 5ml': 15.0,
                                'Alcohol Swab': 5.0,
                                'Antiseptic Solution 100ml': 50.0,
                                'Sterile Bandage': 20.0,
                                'IV Cannula 20G': 65.0,
                                'Adhesive Tape': 15.0,
                              };
                              uPrice =
                                  defaultPriceMap[m.consumableName] ?? 20.0;
                            }

                            return {
                              'consumable_name': m.consumableName,
                              'qty_per_procedure': m.qtyPerProcedure,
                              'unit': m.unit,
                              'unit_price': uPrice,
                              'frequency_multiplier': freqMultiplier,
                              'duration_days':
                                  existingProcedure?.durationDays ?? 1,
                              'total_qty': customTotal,
                            };
                          }).toList();

                          final payload = {
                            'procedure_id':
                                (selectedProc != null && selectedProc!.id != 0)
                                ? selectedProc!.id
                                : existingProcedure?.procedureId,
                            'procedure_name': procName,
                            'charge_per_procedure': parsedCharge,
                            'frequency': selectedFreq,
                            'frequency_multiplier': freqMultiplier,
                            'duration_days':
                                existingProcedure?.durationDays ?? 1,
                            'items': itemsPayload,
                          };

                          final bool success;
                          if (existingProcedure != null &&
                              existingProcedure.id != null) {
                            success = await controller.updateProcedureItem(
                              visit.id,
                              existingProcedure.id!,
                              payload,
                            );
                          } else {
                            success = await controller.recordProcedure(
                              visit.id,
                              payload,
                            );
                          }

                          if (context.mounted && dCtx.mounted) {
                            Navigator.pop(dCtx);
                            if (success) {
                              AppNotification.showSuccess(
                                context,
                                existingProcedure != null
                                    ? 'Procedure updated successfully'
                                    : 'Procedure recorded successfully',
                              );
                            } else {
                              AppNotification.showError(
                                context,
                                controller.errorMessage ??
                                    'Failed to save procedure',
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  bool _isAllowedImageFormat(String filename) {
    if (!filename.contains('.')) return false;
    final ext = filename.split('.').last.toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png'};
    return allowed.contains(ext);
  }

  void _showSelectedPhotoPreviewModal(BuildContext context) {
    if (_selectedPhotoBytes == null) return;
    showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Selected Photo Preview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (_selectedPhotoSize != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatFileSize(_selectedPhotoSize!),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(dCtx),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 380),
                    color: const Color(0xFF0F172A),
                    child: Image.memory(
                      Uint8List.fromList(_selectedPhotoBytes!),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                            height: 200,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedPhotoName ?? 'Selected Image',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedPhotoCategory != null &&
                          _selectedPhotoCategory!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _selectedPhotoCategory!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              style: AppTheme.dangerButton,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remove Image'),
              onPressed: () {
                Navigator.pop(dCtx);
                setState(() {
                  _selectedPhotoName = null;
                  _selectedPhotoBytes = null;
                  _selectedPhotoSize = null;
                  _photoFormatError = null;
                });
              },
            ),
            ElevatedButton.icon(
              style: AppTheme.primaryButton,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Done'),
              onPressed: () => Navigator.pop(dCtx),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPhotoInNewTab(String photoUrl) async {
    if (photoUrl.isEmpty) return;
    String fullUrl = photoUrl.trim();
    if (!fullUrl.startsWith('http://') && !fullUrl.startsWith('https://')) {
      final baseUrl = ApiEndpoints.baseUrl;
      final serverHost = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      final cleanPath = fullUrl.startsWith('/')
          ? fullUrl.substring(1)
          : fullUrl;
      fullUrl = '$serverHost/$cleanPath';
    }
    final uri = Uri.tryParse(fullUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (err) {
        debugPrint('Error launching photo URL: $err');
      }
    }
  }

  void _showDeletePhotoConfirmationDialog(
    BuildContext context,
    int visitId,
    HomeVisitPhotoEvidence photo,
  ) {
    if (photo.id == null) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppTheme.dangerColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Delete Photo Evidence?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this captured photo evidence? This action cannot be undone.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category: ${photo.category ?? "General Care"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (photo.caption != null && photo.caption!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Caption: "${photo.caption}"',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: AppTheme.cancelButton,
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: AppTheme.dangerButton,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete Photo'),
            onPressed: () async {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(dialogCtx).pop();
              final ctrl = Provider.of<HomeVisitController>(
                context,
                listen: false,
              );
              final success = await ctrl.deletePhotoEvidenceItem(
                visitId,
                photo.id!,
              );
              if (context.mounted) {
                if (success) {
                  AppNotification.showSuccess(
                    context,
                    'Photo evidence deleted successfully',
                  );
                } else {
                  AppNotification.showError(
                    context,
                    ctrl.errorMessage ?? 'Failed to delete photo evidence',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileSize = file.size > 0 ? file.size : (file.bytes?.length ?? 0);
        const maxSizeBytes = 15 * 1024 * 1024; // 15 MB

        if (!_isAllowedImageFormat(file.name)) {
          setState(() {
            _selectedPhotoName = null;
            _selectedPhotoBytes = null;
            _selectedPhotoSize = null;
            _photoFormatError =
                'Invalid File Format! "${file.name}" is not a supported image format. Allowed formats: JPG, JPEG, PNG.';
          });
          if (mounted) {
            AppNotification.showError(
              context,
              'Invalid File Format! "${file.name}" is not supported. Allowed formats: JPG, JPEG, PNG.',
            );
          }
          return;
        }

        if (fileSize > maxSizeBytes) {
          final sizeStr = _formatFileSize(fileSize);
          setState(() {
            _selectedPhotoName = null;
            _selectedPhotoBytes = null;
            _selectedPhotoSize = null;
            _photoFormatError =
                'File size exceeds the 15 MB limit ($sizeStr). Please select an image under 15 MB.';
          });
          if (mounted) {
            AppNotification.showError(
              context,
              'File size exceeds the 15 MB limit ($sizeStr). Please select an image under 15 MB.',
            );
          }
          return;
        }

        setState(() {
          _selectedPhotoName = file.name;
          _selectedPhotoBytes = file.bytes;
          _selectedPhotoSize = fileSize;
          _photoFormatError = null;
        });

        if (mounted) {
          _showSelectedPhotoPreviewModal(context);
        }
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
    }
  }

  void _clearPhotoForm() {
    _photoUrlCtrl.clear();
    _photoCaptionCtrl.clear();
    setState(() {
      _selectedPhotoCategory = null;
      _selectedPhotoName = null;
      _selectedPhotoBytes = null;
      _selectedPhotoSize = null;
      _photoFormatError = null;
      _photoSubmitAttempted = false;
    });
  }

  void _clearSignatureForm() {
    _attenderNameCtrl.clear();
    _attenderRelationCtrl.clear();
    _feedbackCtrl.clear();
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
    final baseUrl = ApiEndpoints.baseUrl;
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
          final category = item['category']?.toString().toLowerCase() ?? '';
          final isMedicine =
              RegExp(
                r'\b(\d+mg|\d+mcg|tablet|capsule|syrup|paracetamol|amoxicillin|ibuprofen|metformin|amlodipine)\b',
                caseSensitive: false,
              ).hasMatch(name) ||
              category.contains('pharmacy');

          if (name.isNotEmpty && !isMedicine) {
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

    try {
      final kitItemsData = await HomeVisitService().fetchKitItemsMaster();
      final List<String> kitNames = [];
      for (var item in kitItemsData) {
        final name = item['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          kitNames.add(name);
        }
      }
      if (mounted) {
        setState(() {
          _dbKitMasterItems = kitItemsData;
          if (kitNames.isNotEmpty) {
            _dbKitDevices = kitNames;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final ctrl = Provider.of<HomeVisitController>(context, listen: false);
    final authUser = Provider.of<AuthProvider>(context, listen: false).user;
    await ctrl.fetchVisitDetails(widget.visitId);
    await ctrl.fetchVisits();
    _fetchInventoryCatalogs();
    if (!mounted || widget.isReadOnlyView) return;
    if (ctrl.selectedVisit != null &&
        (ctrl.selectedVisit!.startTime == null ||
            ctrl.selectedVisit!.startTime!.trim().isEmpty) &&
        ctrl.selectedVisit!.status != 'Cancelled' &&
        ctrl.selectedVisit!.status != 'Completed' &&
        ctrl.selectedVisit!.status != 'Verified') {
      // Check if nurse has another active in-progress visit
      HomeVisitModel? activeVisit;
      for (final v in ctrl.visits) {
        if (v.id != widget.visitId && v.status.toLowerCase() == 'in-progress') {
          final bool isNurseMatch =
              (authUser != null &&
                  v.nurseId != null &&
                  v.nurseId == authUser.id) ||
              (v.nurseName != null &&
                  v.nurseName!.trim().isNotEmpty &&
                  authUser != null &&
                  authUser.fullname.trim().isNotEmpty &&
                  v.nurseName!.trim().toLowerCase() ==
                      authUser.fullname.trim().toLowerCase()) ||
              (v.startNurseName != null &&
                  v.startNurseName!.trim().isNotEmpty &&
                  authUser != null &&
                  authUser.fullname.trim().isNotEmpty &&
                  v.startNurseName!.trim().toLowerCase() ==
                      authUser.fullname.trim().toLowerCase());

          final bool isVisitNurseMatch =
              (ctrl.selectedVisit?.nurseId != null &&
                  v.nurseId != null &&
                  ctrl.selectedVisit!.nurseId == v.nurseId) ||
              (ctrl.selectedVisit?.nurseName != null &&
                  ctrl.selectedVisit!.nurseName!.trim().isNotEmpty &&
                  v.nurseName != null &&
                  v.nurseName!.trim().isNotEmpty &&
                  ctrl.selectedVisit!.nurseName!.trim().toLowerCase() ==
                      v.nurseName!.trim().toLowerCase());

          final bool isSameNurse =
              isNurseMatch ||
              (authUser?.role != 'Nurse' &&
                  authUser?.role != 'Head Nurse' &&
                  isVisitNurseMatch);

          if (isSameNurse) {
            activeVisit = v;
            break;
          }
        }
      }

      if (activeVisit != null) {
        _showActiveVisitRestrictionDialog(activeVisit);
        return;
      }

      _promptStartVisitDialog(ctrl.selectedVisit!);
    }
  }

  void _showActiveVisitRestrictionDialog(HomeVisitModel activeVisit) {
    final rawPatientName = activeVisit.patientName ?? 'Patient';
    final patientDisplayId =
        (activeVisit.patientDisplayId != null &&
            activeVisit.patientDisplayId!.trim().isNotEmpty)
        ? activeVisit.patientDisplayId!
        : 'ID: ${activeVisit.patientId}';
    final visitNumber = activeVisit.visitNumber ?? 'HV-${activeVisit.id}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.block_flipped,
                color: AppTheme.dangerColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Active Visit In-Progress',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You currently have an active home visit in progress. Nurses cannot execute multiple active visits simultaneously.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 15,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Patient: $rawPatientName ($patientDisplayId)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        size: 15,
                        color: AppTheme.secondaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Visit Number: $visitNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  if (activeVisit.startTime != null &&
                      activeVisit.startTime!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 15,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Started At: ${activeVisit.startTime}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please complete or resume your ongoing visit before starting another session.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: AppTheme.cancelButton,
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(ctx).pop();
              _handleLeave();
            },
            child: const Text('Exit to Visits List'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: AppTheme.primaryButton,
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(ctx).pop();
              context.go('/nurse/home-visits/execute/${activeVisit.id}');
            },
            child: const Text('Resume Active Visit'),
          ),
        ],
      ),
    );
  }

  void _promptStartVisitDialog(HomeVisitModel visit) {
    if (!mounted || widget.isReadOnlyView) return;
    final formKey = GlobalKey<FormState>();
    final executionClickTime = DateTime.now();
    final defaultTime = DateFormat('hh:mm a').format(executionClickTime);
    final minAllowedTime = executionClickTime.subtract(
      const Duration(hours: 1),
    );
    final maxAllowedTime = executionClickTime.add(const Duration(hours: 1));

    final String rawNurseName = visit.startNurseName ?? visit.nurseName ?? '';
    final String rawPatientName = visit.patientName ?? 'Patient';
    final String patientDisplayId =
        (visit.patientDisplayId != null &&
            visit.patientDisplayId!.trim().isNotEmpty)
        ? visit.patientDisplayId!
        : 'ID: ${visit.patientId}';
    final String patientDisplayWithId = '$rawPatientName ($patientDisplayId)';

    final nurseCtrl = TextEditingController(text: rawNurseName);
    final timeCtrl = TextEditingController(text: defaultTime);
    bool isSubmitting = false;

    final bool isInProgress = visit.status.toLowerCase() == 'in-progress';
    final String dialogTitle = isInProgress
        ? 'Resume Home Visit Session'
        : 'Start Home Visit Session';

    Future<bool> confirmCloseVisitSession() async {
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (confirmCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.dangerColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Close Visit Session?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to close this visit session and return to the visits list? Any unsubmitted start time will not be recorded.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          actions: [
            OutlinedButton(
              style: AppTheme.cancelButton,
              onPressed: () => Navigator.of(confirmCtx).pop(false),
              child: const Text('Stay in Session'),
            ),
            ElevatedButton(
              style: AppTheme.dangerButton,
              onPressed: () => Navigator.of(confirmCtx).pop(true),
              child: const Text('Close Session'),
            ),
          ],
        ),
      );
      return result == true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldClose = await confirmCloseVisitSession();
            if (shouldClose && mounted) {
              Navigator.of(dialogCtx).pop();
              _handleLeave();
            }
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.play_circle_fill_outlined,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dialogTitle,
                    style: const TextStyle(
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
                      Text(
                        isInProgress
                            ? 'Confirm visit resume time before managing patient vitals & care.'
                            : 'Record visit start time before accessing patient vitals.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 15,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Patient: $patientDisplayWithId',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    size: 15,
                                    color: AppTheme.nurseColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Executing Nurse: ',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          TextSpan(
                                            text: rawNurseName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme
                                                  .nurseColor, // Purple for nurse name
                                            ),
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.lock_outline,
                                    size: 13,
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          isInProgress
                              ? 'Visit Resume Time'
                              : 'Visit Start Time',
                          style: const TextStyle(
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
                          TimeOfDay initialPickerTime = TimeOfDay.now();
                          try {
                            if (timeCtrl.text.trim().isNotEmpty) {
                              final parsed = DateFormat('hh:mm a').parse(timeCtrl.text.trim());
                              initialPickerTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
                            }
                          } catch (_) {}
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: initialPickerTime,
                            helpText: 'Select Visit Start Time',
                          );
                          if (picked != null) {
                            final now = DateTime.now();
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
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Start time is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 13,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Tap to adjust session start time if needed.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: AppTheme.cancelButton,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final shouldClose = await confirmCloseVisitSession();
                          if (shouldClose && mounted) {
                            ModalHistoryHelper.skipNextHistoryBack();
                            Navigator.of(dialogCtx).pop();
                            _handleLeave();
                          }
                        },
                  child: const Text('Exit Session'),
                ),
              ),
              const SizedBox(width: 8),
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
                    isSubmitting
                        ? 'Starting...'
                        : (isInProgress
                              ? 'Submit & Resume Visit'
                              : 'Submit & Start Visit'),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() == true) {
                            setDialogState(() => isSubmitting = true);
                            try {
                              final baseUrl = ApiEndpoints.baseUrl;
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
                                  ModalHistoryHelper.skipNextHistoryBack();
                                  Navigator.of(dialogCtx).pop();
                                }
                              } else {
                                setDialogState(() => isSubmitting = false);
                                if (dialogCtx.mounted) {
                                  AppNotification.showError(
                                    dialogCtx,
                                    body['message'] ??
                                        'Failed to record start time',
                                  );
                                }
                              }
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                              if (dialogCtx.mounted) {
                                AppNotification.showError(
                                  dialogCtx,
                                  'Error starting visit: $e',
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
      ),
    );
  }

  @override
  void dispose() {
    UnsavedChangesHelper.setUnsavedChanges(false);
    _vitalsTimer?.cancel();
    LiveSpeechService().stopListening();
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
    _medFrequencyCtrl.dispose();
    _medDurationCtrl.dispose();
    _medGivenTimeCtrl.dispose();
    _consNameCtrl.dispose();
    _consQtyCtrl.dispose();
    _consPriceCtrl.dispose();
    _customKitNameCtrl.dispose();
    _kitItemNameCtrl.dispose();
    _kitItemQtyCtrl.dispose();
    _photoUrlCtrl.dispose();
    _photoCaptionCtrl.dispose();
    _attenderNameCtrl.dispose();
    _attenderRelationCtrl.dispose();
    _feedbackCtrl.dispose();
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

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop || _isLeaving) return;
            if (_selectedSummaryVisitId != null) {
              setState(() {
                _selectedSummaryVisitId = null;
              });
              return;
            }
          },
          child: Scaffold(
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
                        onPressed: () {
                          if (_selectedSummaryVisitId != null) {
                            setState(() {
                              _selectedSummaryVisitId = null;
                            });
                            return;
                          }
                          final bool isCompleted = widget.isReadOnlyView ||
                              visit.status == 'Completed' ||
                              visit.status == 'Verified' ||
                              visit.status == 'Cancelled' ||
                              isCompletedOrVerified;

                          if (isCompleted) {
                            _handleLeave();
                            return;
                          }
                          _showUnsavedChangesDialog(context, visit: visit);
                        },
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
                      //             elevation: 0,
                      //             scrolledUnderElevation: 0,
                      //             toolbarHeight: 75,
                      //             leading: (widget.onBack != null || _selectedSummaryVisitId != null)
                      //                 ? Padding(
                      //                     padding: const EdgeInsets.only(top: 16.0),
                      //                     child: IconButton(
                      //                       icon: const Icon(
                      //                         Icons.arrow_back,
                      //                         color: AppTheme.primaryColor,
                      //                       ),
                      //                       onPressed: () {
                      //                         if (_selectedSummaryVisitId != null) {
                      //                           setState(() {
                      //                             _selectedSummaryVisitId = null;
                      //                           });
                      //                         } else {
                      //                           widget.onBack?.call();
                      //                         }
                      //                       },
                      //                     ),
                      //                   )
                      //                 : null,
                      //             title: Padding(
                      //               padding: const EdgeInsets.only(top: 16.0),
                      //               child: Row(
                      //                 children: [
                      //                   Container(
                      //                     padding: const EdgeInsets.all(8),
                      //                     decoration: BoxDecoration(
                      //                       color: AppTheme.primaryColor.withOpacity(0.1),
                      //                       borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (ctx) {
                          final isTamil = Provider.of<LanguageProvider>(ctx).isTamil;
                          final rawPatientName = visit.patientName ?? (isTamil ? 'நோயாளி' : 'Patient');
                          final formattedPatientName = TamilTransliterationHelper.formatName(
                            rawPatientName,
                            isTamil: isTamil,
                            showBoth: true,
                          );
                          final pId = (visit.patientDisplayId != null && visit.patientDisplayId!.isNotEmpty)
                              ? ' (${visit.patientDisplayId})'
                              : '';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ctx.tr('home_visit_care', fallback: 'Home Visit Care')} - ${visit.visitNumber}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                  fontFamily: 'Inter',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${ctx.tr('patient_label', fallback: 'Patient:')} $formattedPatientName$pId',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontFamily: 'Inter',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                const Padding(
                  padding: EdgeInsets.only(top: 16.0, right: 12.0),
                  child: AppTopBarActions(showClock: false),
                ),
                if (visit.status != 'Cancelled' &&
                    visit.status != 'Completed' &&
                    visit.status != 'Verified')
                  Builder(
                    builder: (ctx) {
                      final isMobile = MediaQuery.of(ctx).size.width < 700;

                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0, right: 16.0),
                        child: isMobile
                            ? IconButton(
                                tooltip: ctx.tr('stop_care_plan', fallback: 'Stop Care Plan'),
                                style: IconButton.styleFrom(
                                  foregroundColor: AppTheme.dangerColor,
                                  backgroundColor: AppTheme.dangerColor
                                      .withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(
                                      color: AppTheme.dangerColor,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.do_not_disturb_on_outlined,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _showDiscontinueDialog(context, visit),
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.dangerColor,
                                  side: const BorderSide(
                                    color: AppTheme.dangerColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.do_not_disturb_on_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  ctx.tr('stop_care_plan', fallback: 'Stop Care Plan'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: () =>
                                    _showDiscontinueDialog(context, visit),
                              ),
                      );
                    },
                  ),
              ],
              bottom: isCompletedOrVerified
                  ? null
                  : TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      isScrollable: true,
                      tabs: [
                        Tab(
                          icon: const Icon(
                            Icons.medical_services_outlined,
                            color: Color(0xFF0284C7),
                          ),
                          text: context.tr('tab_kit_devices', fallback: 'Kit & Devices'),
                        ),
                        Tab(
                          icon: const Icon(
                            Icons.monitor_heart_outlined,
                            color: Color(0xFF16A34A),
                          ),
                          text: context.tr('tab_vitals', fallback: 'Vitals'),
                        ),
                        Tab(
                          icon: const Icon(
                            Icons.health_and_safety_outlined,
                            color: Color(0xFFE11D48),
                          ),
                          text: context.tr('tab_nursing_care', fallback: 'Nursing Care & Dressing'),
                        ),
                        Tab(
                          icon: const Icon(
                            Icons.medication_liquid_outlined,
                            color: Color(0xFFEA580C),
                          ),
                          text: context.tr('tab_meds_consumables', fallback: 'Meds & Consumables'),
                        ),
                        Tab(
                          icon: const Icon(
                            Icons.insert_photo_outlined,
                            color: Color(0xFF9333EA),
                          ),
                          text: context.tr('tab_photo_evidence', fallback: 'Photo Evidence'),
                        ),
                        Tab(
                          icon: const Icon(
                            Icons.analytics_outlined,
                            color: Color(0xFF0D9488),
                          ),
                          text: context.tr('tab_live_summary', fallback: 'View Live Summary'),
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
          ),
        );
      },
    );
  }

  // 1. Kit & Devices Tab with Interactive Form
  Widget _buildKitTab(HomeVisitModel visit, HomeVisitController controller) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1 Header
          _buildSectionHeader(
            context.tr('select_add_kit_header', fallback: 'Select & Add Kit Items & Medical Devices Used'),
            Icons.fact_check_outlined,
            subtitle: context.tr('select_add_kit_sub', fallback: 'Add the kit items or medical devices used during this visit.'),
          ),
          const SizedBox(height: 16),

          // Interactive Form Card
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
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.secondaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('add_kit_box_header', fallback: 'Add Kit Device / Item Used During Visit'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                          fontFamily: 'Inter',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 650;
                    Future<void> addKitItem() async {
                      if (_isAddingKitItem) return;

                      String? name;
                      if (_selectedKitDropdown ==
                          'Other (Type Custom Kit Item...)') {
                        final customName = _customKitNameCtrl.text.trim();
                        if (customName.isEmpty) {
                          AppNotification.showError(
                            context,
                            'Please enter a custom kit item name',
                          );
                          return;
                        }
                        if (customName.length < 3 || customName.length > 60) {
                          AppNotification.showError(
                            context,
                            'Custom kit item name must be between 3 and 60 characters',
                          );
                          return;
                        }
                        if (!RegExp(r'[a-zA-Z]').hasMatch(customName)) {
                          AppNotification.showError(
                            context,
                            'Custom kit item name must contain at least one letter',
                          );
                          return;
                        }
                        name = customName;
                      } else if (_selectedKitDropdown != null &&
                          _selectedKitDropdown!.trim().isNotEmpty) {
                        if (!_effectiveKitDevices.contains(
                          _selectedKitDropdown!.trim(),
                        )) {
                          AppNotification.showError(
                            context,
                            'Please select a valid kit device/item from the list',
                          );
                          return;
                        }
                        name = _selectedKitDropdown!.trim();
                      } else {
                        AppNotification.showError(
                          context,
                          'Please select a valid kit device/item from the dropdown',
                        );
                        return;
                      }

                      if (!_kitItemTypes.contains(_kitItemType)) {
                        AppNotification.showError(
                          context,
                          'Please select a valid category',
                        );
                        return;
                      }

                      final int qty =
                          int.tryParse(_kitItemQtyCtrl.text.trim()) ?? 1;
                      if (qty <= 0 || qty > 999) {
                        AppNotification.showError(
                          context,
                          'Quantity must be between 1 and 999',
                        );
                        return;
                      }

                      final isDuplicate = visit.carriedItems.any(
                        (item) =>
                            item.itemName.trim().toLowerCase() ==
                            name!.trim().toLowerCase(),
                      );
                      if (isDuplicate) {
                        AppNotification.showWarning(
                          context,
                          '"$name" is already added to this visit. Edit or remove the existing item below.',
                        );
                        return;
                      }

                      setState(() => _isAddingKitItem = true);
                      try {
                        final success = await controller
                            .submitCarriedItem(visit.id, {
                              'item_type': _kitItemType,
                              'item_name': name,
                              'quantity_carried': qty,
                            });
                        if (success) {
                          _clearKitForm();
                          if (context.mounted) {
                            AppNotification.showSuccess(
                              context,
                              'Kit item / device added successfully',
                            );
                          }
                        } else {
                          if (context.mounted) {
                            AppNotification.showError(
                              context,
                              controller.errorMessage ??
                                  'Failed to add kit item',
                            );
                          }
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isAddingKitItem = false);
                        }
                      }
                    }

                    void handleKitDropdownChange(String? val) {
                      setState(() {
                        _selectedKitDropdown = val;
                        if (val != null) {
                          _kitItemNameCtrl.text = val;
                          final matched = _dbKitMasterItems.firstWhere(
                            (element) =>
                                element['name']
                                    ?.toString()
                                    .toLowerCase()
                                    .trim() ==
                                val.toLowerCase().trim(),
                            orElse: () => {},
                          );
                          if (matched.isNotEmpty &&
                              matched['item_type'] != null) {
                            final t = matched['item_type'].toString();
                            if (_kitItemTypes.contains(t)) {
                              _kitItemType = t;
                            }
                          }
                        }
                      });
                    }

                    final addButton = ElevatedButton.icon(
                      style: AppTheme.dangerButton.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      icon: _isAddingKitItem
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: Text(
                        _isAddingKitItem
                            ? context.tr('adding', fallback: 'Adding...')
                            : context.tr('add_kit_item', fallback: '+ Add Kit Item'),
                      ),
                      onPressed: _isAddingKitItem ? null : addKitItem,
                    );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLabel(context.tr('kit_device_item', fallback: 'Kit / Device Item')),
                          CustomDropdownSearch(
                            label: '',
                            hint: context.tr('select_kit_item_hint', fallback: 'Select Kit Item / Device'),
                            dropdownMap: _getKitDeviceMap(),
                            value: _selectedKitDropdown,
                            allowFreeText: false,
                            maxLength: 60,
                            onChanged: handleKitDropdownChange,
                          ),
                          if (_selectedKitDropdown ==
                              'Other (Type Custom Kit Item...)') ...[
                            const SizedBox(height: 12),
                            _buildLabel('Custom Kit Item Name'),
                            TextFormField(
                              controller: _customKitNameCtrl,
                              maxLength: 60,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(60),
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):]'),
                                ),
                              ],
                              decoration: AppTheme.standardInputDecoration(
                                hintText:
                                    'Enter Custom Kit Item / Device Name *',
                                prefixIcon: Icons.edit_note,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildLabel(context.tr('category', fallback: 'Category')),
                          CustomDropdownSearch(
                            label: '',
                            hint: context.tr('category', fallback: 'Category'),
                            dropdownMap: _getKitTypeMap(),
                            value: _kitItemType,
                            allowFreeText: false,
                            maxLength: 30,
                            onChanged: (val) {
                              if (val != null && _kitItemTypes.contains(val)) {
                                setState(() => _kitItemType = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildLabel(context.tr('quantity', fallback: 'Quantity')),
                          _buildQtyStepperField(
                            controller: _kitItemQtyCtrl,
                            min: 1,
                            max: 999,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, child: addButton),
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('kit_device_item', fallback: 'Kit / Device Item')),
                                CustomDropdownSearch(
                                  label: '',
                                  hint: context.tr('select_kit_item_hint', fallback: 'Select Kit Item / Device'),
                                  dropdownMap: _getKitDeviceMap(),
                                  value: _selectedKitDropdown,
                                  allowFreeText: false,
                                  maxLength: 60,
                                  onChanged: handleKitDropdownChange,
                                ),
                              ],
                            ),
                          ),
                          if (_selectedKitDropdown ==
                              'Other (Type Custom Kit Item...)') ...[
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Custom Kit Item Name'),
                                  TextFormField(
                                    controller: _customKitNameCtrl,
                                    maxLength: 60,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(60),
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):]'),
                                      ),
                                    ],
                                    decoration:
                                        AppTheme.standardInputDecoration(
                                          hintText:
                                              'Enter Custom Kit Item Name *',
                                          prefixIcon: Icons.edit_note,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('category', fallback: 'Category')),
                                CustomDropdownSearch(
                                  label: '',
                                  hint: context.tr('category', fallback: 'Category'),
                                  dropdownMap: _getKitTypeMap(),
                                  value: _kitItemType,
                                  allowFreeText: false,
                                  maxLength: 30,
                                  onChanged: (val) {
                                    if (val != null &&
                                        _kitItemTypes.contains(val)) {
                                      setState(() => _kitItemType = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('quantity', fallback: 'Quantity')),
                                _buildQtyStepperField(
                                  controller: _kitItemQtyCtrl,
                                  min: 1,
                                  max: 999,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          addButton,
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2 Header with Items Count Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSectionHeader(
                  context.tr('carried_used_kit_list', fallback: 'Carried & Used Kit Devices List'),
                  Icons.assignment_turned_in_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${visit.carriedItems.length} ${context.tr('items', fallback: 'Items')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Empty State Box or Carried Items Grid
          if (visit.carriedItems.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF93C5FD),
                  width: 1.2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Color(0xFF0284C7),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No kit items or medical devices added yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select and add devices using the form above.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              itemIcon,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getTranslatedKitDevice(item.itemName),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${context.tr('category', fallback: 'Category')}: ${_getTranslatedKitType(item.itemType)} • ${context.tr('qty', fallback: 'Qty')}: ${item.quantityCarried}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.dangerColor,
                              size: 20,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  title: const Text(
                                    'Remove Kit Item',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: SizedBox(
                                    width: 440,
                                    child: Text(
                                      'Are you sure you want to remove "${item.itemName}"?',
                                      softWrap: true,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      style: AppTheme.cancelButton,
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: AppTheme.dangerButton,
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && item.id != null) {
                                await controller.removeCarriedItem(
                                  visit.id,
                                  item.id!,
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
    HomeVisitController controller, {
    HomeVisitVitals? existingVital,
  }) {
    _clearVitalsForm();
    if (existingVital != null) {
      _sysBpCtrl.text = existingVital.systolicBp?.toString() ?? '';
      _diaBpCtrl.text = existingVital.diastolicBp?.toString() ?? '';
      _pulseCtrl.text = existingVital.pulseRate?.toString() ?? '';
      _tempCtrl.text = existingVital.temperature?.toString() ?? '';
      _spo2Ctrl.text = existingVital.spo2?.toString() ?? '';
      _sugarCtrl.text = existingVital.bloodSugar?.toString() ?? '';
      _weightCtrl.text = existingVital.weight?.toString() ?? '';
      _heightCtrl.text = existingVital.height?.toString() ?? '';
    }
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            _clearVitalsForm();
          },
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 650,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.monitor_heart_outlined,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  existingVital != null
                                      ? context.tr('update_patient_vital_signs')
                                      : context.tr('record_patient_vital_signs'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryColor,
                                    fontFamily: 'Inter',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Patient: ${visit.patientName ?? "Patient"} (${(visit.patientDisplayId != null && visit.patientDisplayId!.isNotEmpty) ? visit.patientDisplayId : "ID: ${visit.patientId}"})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              ModalHistoryHelper.skipNextHistoryBack();
                              _clearVitalsForm();
                              Navigator.of(dialogCtx).pop();
                            },
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
                                _buildLabel(context.tr('systolic_bp_req')),
                                TextFormField(
                                  controller: _sysBpCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
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
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter Systolic BP';
                                    }
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 70 || n > 250) {
                                      return 'Please enter Systolic BP between 70-250 mmHg';
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
                                _buildLabel(context.tr('diastolic_bp_req')),
                                TextFormField(
                                  controller: _diaBpCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
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
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter Diastolic BP';
                                    }
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 40 || n > 150) {
                                      return 'Please enter Diastolic BP between 40-150 mmHg';
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

                      // Row 2: Pulse Rate, Temperature
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('pulse_rate_req')),
                                TextFormField(
                                  controller: _pulseCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
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
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter Pulse Rate';
                                    }
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 30 || n > 250) {
                                      return 'Please enter Pulse Rate between 30-250 bpm';
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
                                _buildLabel(context.tr('temperature_req')),
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
                                    LengthLimitingTextInputFormatter(5),
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
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter Temperature';
                                    }
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 90.0 || n > 115.0) {
                                      return 'Please enter Temperature between 90-115 °F';
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

                      // Row 3: SpO2, Sugar
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('spo2_req')),
                                TextFormField(
                                  controller: _spo2Ctrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
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
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter SpO2';
                                    }
                                    final n = int.tryParse(val.trim());
                                    if (n == null || n < 50 || n > 100) {
                                      return 'Please enter SpO2 between 50-100%';
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
                                _buildLabel(context.tr('blood_sugar_label')),
                                TextFormField(
                                  controller: _sugarCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
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
                                      if (n == null || n < 30 || n > 600) {
                                        return 'Please enter Blood Sugar between 30-600 mg/dL';
                                      }
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
                                _buildLabel(context.tr('weight_label')),
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
                                    LengthLimitingTextInputFormatter(5),
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
                                      if (n == null || n < 1.0 || n > 300.0) {
                                        return 'Please enter Weight between 1 to 300 kg';
                                      }
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
                                _buildLabel(context.tr('height_label')),
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
                                    LengthLimitingTextInputFormatter(5),
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
                                      if (n == null || n < 30.0 || n > 250.0) {
                                        return 'Please enter Height between 30 to 250 cm';
                                      }
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
                            onPressed: () {
                              ModalHistoryHelper.skipNextHistoryBack();
                              _clearVitalsForm();
                              Navigator.of(dialogCtx).pop();
                            },
                            child: Text(context.tr('cancel')),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: AppTheme.dangerButton,
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
                                  ? context.tr('saving')
                                  : existingVital != null
                                  ? context.tr('update_vitals_entry')
                                  : context.tr('save_vitals_entry'),
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
                                    final payload = <String, dynamic>{
                                      if (existingVital != null &&
                                          existingVital.id != null)
                                        'vitals_id': existingVital.id,
                                      'systolic_bp': sys,
                                      'diastolic_bp': dia,
                                      'pulse_rate': pulse,
                                      'temperature': temp,
                                      'spo2': spo2,
                                      'blood_sugar': sugar,
                                      'weight': weight,
                                      'height': height,
                                      'bypass_schedule': true,
                                    };
                                    final success = await controller
                                        .submitVitals(visit.id, payload);
                                    setDialogState(
                                      () => _isSavingVitals = false,
                                    );

                                    if (success && mounted) {
                                      ModalHistoryHelper.skipNextHistoryBack();
                                      _clearVitalsForm();
                                      Navigator.of(dialogCtx).pop();
                                      AppNotification.showSuccess(
                                        context,
                                        existingVital != null
                                            ? 'Patient vitals updated successfully'
                                            : 'Patient vitals recorded successfully',
                                      );
                                    } else if (dialogCtx.mounted) {
                                      AppNotification.showError(
                                        dialogCtx,
                                        controller.errorMessage ??
                                            'Failed to save vitals',
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
          ),
        ),
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
                style: AppTheme.dangerButton,
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
                          AppNotification.showSuccess(
                            context,
                            'Patient vitals recorded successfully',
                          );
                        } else {
                          AppNotification.showError(
                            context,
                            controller.errorMessage ??
                                'Failed to record vitals',
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );

    final todaysVitals = visit.vitalsHistory
        .where((v) => _isRecordedToday(v.recordedAt))
        .toList();
    final sortedVitals = List<HomeVisitVitals>.from(todaysVitals);
    sortedVitals.sort((a, b) {
      if (a.recordedAt == null) return 1;
      if (b.recordedAt == null) return -1;
      return b.recordedAt!.compareTo(a.recordedAt!);
    });

    final filteredVitals = sortedVitals.where((v) {
      if (_vitalsFilter == 'Abnormal') {
        final sys = v.systolicBp ?? 120;
        final dia = v.diastolicBp ?? 80;
        final pulse = v.pulseRate ?? 72;
        final temp = v.temperature ?? 98.6;
        final spo2 = v.spo2 ?? 98;
        final sugar = v.bloodSugar ?? 100;
        final isAbnormalBp = sys > 140 || sys < 90 || dia > 90 || dia < 60;
        final isAbnormalPulse = pulse > 100 || pulse < 60;
        final isAbnormalTemp = temp > 99.5 || temp < 95.0;
        final isAbnormalSpo2 = spo2 < 95;
        final isAbnormalSugar = sugar > 180 || sugar < 70;
        return isAbnormalBp ||
            isAbnormalPulse ||
            isAbnormalTemp ||
            isAbnormalSpo2 ||
            isAbnormalSugar;
      }
      return true;
    }).toList();

    final totalVitals = filteredVitals.length;
    final totalVitalsPages = (totalVitals == 0)
        ? 1
        : ((totalVitals - 1) ~/ _vitalsPageSize) + 1;
    final currentVitalsPage = _vitalsPage.clamp(1, totalVitalsPages);
    final vitalsStartIdx = (currentVitalsPage - 1) * _vitalsPageSize;
    final vitalsEndIdx = (vitalsStartIdx + _vitalsPageSize < totalVitals)
        ? vitalsStartIdx + _vitalsPageSize
        : totalVitals;
    final pageVitals = (vitalsStartIdx < totalVitals)
        ? filteredVitals.sublist(vitalsStartIdx, vitalsEndIdx)
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      context.tr('patient_vitals_history_log'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontFamily: 'Inter',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$totalVitals Entry(ies)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                initialValue: _vitalsFilter,
                tooltip: context.tr('filter'),
                onSelected: (val) {
                  setState(() {
                    _vitalsFilter = val;
                    _vitalsPage = 1;
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'All',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.list_alt,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(context.tr('all_entries', fallback: 'All Entries')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Today',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.today,
                          size: 18,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(context.tr('todays_entries', fallback: "Today's Entries")),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Abnormal',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppTheme.dangerColor,
                        ),
                        const SizedBox(width: 8),
                        Text(context.tr('abnormal_vitals', fallback: 'Abnormal Vitals')),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _vitalsFilter != 'All'
                        ? AppTheme.primaryColor.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _vitalsFilter != 'All'
                          ? AppTheme.primaryColor
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 16,
                        color: _vitalsFilter != 'All'
                            ? AppTheme.primaryColor
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _vitalsFilter == 'All'
                            ? context.tr('filter')
                            : '${context.tr('filter')}: $_vitalsFilter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _vitalsFilter != 'All'
                              ? AppTheme.primaryColor
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: _vitalsFilter != 'All'
                            ? AppTheme.primaryColor
                            : const Color(0xFF475569),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredVitals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monitor_heart_outlined,
                      size: 44,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('no_records_found'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('no_vitals_recorded_yet'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
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
                    constraints: const BoxConstraints(minWidth: 1050),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(170),
                        1: FixedColumnWidth(140),
                        2: FixedColumnWidth(110),
                        3: FixedColumnWidth(100),
                        4: FixedColumnWidth(100),
                        5: FixedColumnWidth(90),
                        6: FixedColumnWidth(110),
                        7: FixedColumnWidth(100),
                        8: FixedColumnWidth(100),
                        9: FixedColumnWidth(90),
                      },
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_date_time', fallback: 'Date & Time Recorded'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_time_gap', fallback: 'Time Gap / Duration'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_bp', fallback: 'BP (mmHg)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_pulse', fallback: 'Pulse (bpm)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_temp', fallback: 'Temp (°F)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_spo2', fallback: 'SpO₂ (%)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_sugar', fallback: 'Sugar (mg/dL)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_weight', fallback: 'Weight (kg)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                context.tr('vitals_height', fallback: 'Height (cm)'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                'Actions',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
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
                                color: Colors.white,
                                border: idx < pageVitals.length - 1
                                    ? const Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      )
                                    : null,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: _buildTimestampBadge(
                                    v.recordedAt,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                () {
                                  final gapStr = _formatTimeGap(
                                    v,
                                    sortedVitals,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        gapStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                  );
                                }(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    '${v.systolicBp ?? "--"} / ${v.diastolicBp ?? "--"}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    v.pulseRate != null
                                        ? '${v.pulseRate} bpm'
                                        : '--',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    v.temperature != null
                                        ? '${v.temperature} °F'
                                        : '--',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    v.spo2 != null ? '${v.spo2}%' : '--',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    v.bloodSugar != null
                                        ? '${v.bloodSugar} mg/dL'
                                        : '--',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    v.weight != null ? '${v.weight} kg' : '--',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    v.height != null ? '${v.height} cm' : '--',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: PopupMenuButton<String>(
                                    icon: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.more_vert,
                                        color: Color(0xFF475569),
                                        size: 18,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Actions',
                                    onSelected: (val) async {
                                      if (val == 'edit') {
                                        _showAddVitalsModalDialog(
                                          context,
                                          visit,
                                          controller,
                                          existingVital: v,
                                        );
                                      } else if (val == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: Colors.white,
                                            surfaceTintColor:
                                                Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            title: const Text(
                                              'Delete Vitals Entry',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: const SizedBox(
                                              width: 440,
                                              child: Text(
                                                'Are you sure you want to delete this recorded vitals entry?',
                                                softWrap: true,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                style: AppTheme.cancelButton,
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: AppTheme.dangerButton,
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true && v.id != null) {
                                          final success = await controller
                                              .deleteVitalsItem(
                                                visit.id,
                                                v.id!,
                                              );
                                          if (success && mounted) {
                                            AppNotification.showSuccess(
                                              context,
                                              'Vitals entry deleted successfully',
                                            );
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      if (!widget.isReadOnlyView) ...[
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: AppTheme.primaryColor,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Edit Entry'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: AppTheme.dangerColor,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Delete Entry'),
                                            ],
                                          ),
                                        ),
                                      ],
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
            ),
            const SizedBox(height: 16),

            // Footer / Pagination Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).locale.languageCode == 'ta'
                            ? 'மொத்தம் $totalVitals பதிவுகளில் ${totalVitals == 0 ? 0 : vitalsStartIdx + 1} முதல் $vitalsEndIdx வரை காட்டப்படுகிறது'
                            : 'Showing ${totalVitals == 0 ? 0 : vitalsStartIdx + 1} to $vitalsEndIdx of $totalVitals entries',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
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
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: currentVitalsPage > 1
                            ? () => setState(() => _vitalsPage--)
                            : null,
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        label: Text(
                          context.tr('previous', fallback: 'Previous'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppLocalizations.of(context).locale.languageCode == 'ta' ? '$currentVitalsPage / $totalVitalsPages' : '$currentVitalsPage of $totalVitalsPages',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: currentVitalsPage < totalVitalsPages
                            ? () => setState(() => _vitalsPage++)
                            : null,
                        icon: const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        label: Text(
                          context.tr('next', fallback: 'Next'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final header = _buildSectionHeader(
                context.tr('record_patient_vitals_entry'),
                Icons.monitor_heart_outlined,
                subtitle: context.tr('track_manage_vitals'),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    if (!widget.isReadOnlyView) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: AppTheme.dangerButton.copyWith(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(context.tr('add_vitals_entry_btn')),
                        onPressed: () => _showAddVitalsModalDialog(
                          context,
                          visit,
                          controller,
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: header),
                  if (!widget.isReadOnlyView) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: AppTheme.dangerButton.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        minimumSize: WidgetStateProperty.all(const Size(0, 48)),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.tr('add_vitals_entry_btn')),
                      onPressed: () =>
                          _showAddVitalsModalDialog(context, visit, controller),
                    ),
                  ],
                ],
              );
            },
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
                  style: AppTheme.dangerButton,
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
                              AppNotification.showSuccess(
                                context,
                                existingVital != null
                                    ? 'Vitals for $slotTime updated successfully!'
                                    : 'Vitals for $slotTime recorded successfully!',
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
                  'Time Gap / Duration',
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

              final gapStr = _formatTimeGap(v, history);
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: gapStr == 'Initial Entry'
                            ? AppTheme.primaryColor.withOpacity(0.08)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: gapStr == 'Initial Entry'
                              ? AppTheme.primaryColor.withOpacity(0.3)
                              : const Color(0xFFFDBA74),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        gapStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: gapStr == 'Initial Entry'
                              ? AppTheme.primaryColor
                              : const Color(0xFFC2410C),
                        ),
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
            onPressed: () {
              ModalHistoryHelper.skipNextHistoryBack();
              Navigator.of(dialogCtx).pop();
            },
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
              if (dialogCtx.mounted) {
                ModalHistoryHelper.skipNextHistoryBack();
                Navigator.of(dialogCtx).pop();
              }
              if (success && context.mounted) {
                AppNotification.showSuccess(
                  context,
                  'Vitals schedule configuration updated successfully!',
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
            Text(
              context.tr('record_nursing_care_entry'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildVoiceSupportedNotesField(
              fieldId: 'nursing_notes',
              label: context.tr('nursing_notes_observations'),
              controller: _notesCtrl,
              hintText: context.tr('enter_clinical_observations'),
              maxLines: 3,
              maxLength: 500,
              quickTemplates: _quickNursingNoteTemplates,
              validator: (val) {
                if (val != null && val.trim().isNotEmpty) {
                  if (val.trim().length > 500) {
                    return 'Nursing notes cannot exceed 500 characters';
                  }
                  if (!RegExp(r'[a-zA-Z\u0B80-\u0BFF]').hasMatch(val)) {
                    return 'Notes must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildVoiceSupportedNotesField(
              fieldId: 'dressing_procedures',
              label: context.tr('dressing_procedures_details'),
              controller: _dressingCtrl,
              hintText: context.tr('describe_wound_site'),
              maxLines: 3,
              maxLength: 500,
              quickTemplates: _quickDressingTemplates,
              validator: (val) {
                if (val != null && val.trim().isNotEmpty) {
                  if (val.trim().length > 500) {
                    return 'Dressing details cannot exceed 500 characters';
                  }
                  if (!RegExp(r'[a-zA-Z\u0B80-\u0BFF]').hasMatch(val)) {
                    return 'Dressing details must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols';
                  }
                }
                return null;
              },
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
                title: Text(
                  context.tr('nail_trimming_hygiene'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  context.tr('check_nail_trimming'),
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
            _buildVoiceSupportedNotesField(
              fieldId: 'other_care',
              label: context.tr('other_personal_care_activities', fallback: 'Other Personal Care & Nursing Activities'),
              controller: _otherCareCtrl,
              hintText: context.tr('other_personal_care_hint', fallback: 'Catheter care, bed bath assistance, oral hygiene, position changes, etc.'),
              maxLines: 2,
              maxLength: 500,
              validator: (val) {
                if (val != null && val.trim().isNotEmpty) {
                  if (val.trim().length > 500) {
                    return 'Personal care details cannot exceed 500 characters';
                  }
                  if (!RegExp(r'[a-zA-Z\u0B80-\u0BFF]').hasMatch(val)) {
                    return 'Personal care details must contain alphabetical or Tamil characters and cannot consist solely of numbers or symbols';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              child: ElevatedButton(
                style: AppTheme.dangerButton,
                onPressed: _isSavingCare
                    ? null
                    : () async {
                        if (!(_formKeyCare.currentState?.validate() ?? false)) {
                          return;
                        }

                        final notes = _notesCtrl.text.trim();
                        final dressing = _dressingCtrl.text.trim();
                        final otherCare = _otherCareCtrl.text.trim();

                        if (notes.isEmpty &&
                            dressing.isEmpty &&
                            otherCare.isEmpty &&
                            !_nailTrimmingDone) {
                          AppNotification.showError(
                            context,
                            'Please enter at least one nursing note, dressing procedure, or personal care activity',
                          );
                          return;
                        }

                        setState(() => _isSavingCare = true);
                        final success = await controller
                            .submitCareActivities(visit.id, {
                              'nursing_notes': notes,
                              'dressing_procedures': dressing,
                              'nail_trimming_done': _nailTrimmingDone,
                              'other_care_activities': otherCare,
                            });
                        setState(() => _isSavingCare = false);
                        if (success && mounted) {
                          _clearCareForm();
                          AppNotification.showSuccess(
                            context,
                            'Nursing care details saved successfully! Form cleared for new entries.',
                          );
                        } else if (mounted) {
                          AppNotification.showError(
                            context,
                            controller.errorMessage ??
                                'Failed to save nursing care details',
                          );
                        }
                      },
                child: _isSavingCare
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        context.tr('save_care_entry', fallback: 'Save Nursing Care'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    final allCare = visit.careActivitiesHistory.isNotEmpty
        ? visit.careActivitiesHistory
        : (visit.careActivities != null
              ? [visit.careActivities!]
              : <HomeVisitCareActivities>[]);
    final careList = allCare
        .where((c) => _isRecordedToday(c.createdAt))
        .toList();
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
            children: [
              Expanded(
                child: Text(
                  context.tr('nursing_care_history'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 44,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('no_records_found'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('no_nursing_care_recorded'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
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
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Center(
                              child: Text(
                                context.tr('vitals_date_time', fallback: 'Date & Time Recorded'),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
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
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context.tr('nursing_notes_care_activities'),
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

    final currentDayNumber = _calculateVisitDayNumber(visit, controller);

    final activeMedicines =
        visit.medicines
            .where((m) => _isRecordedToday(m.administeredAt))
            .toList()
          ..sort((a, b) {
            if (a.id != null && b.id != null && a.id != b.id) {
              return b.id!.compareTo(a.id!);
            }
            return 0;
          });

    final activeConsumables =
        visit.consumables.where((c) => _isRecordedToday(c.createdAt)).toList()
          ..sort((a, b) {
            if (a.id != null && b.id != null && a.id != b.id) {
              return b.id!.compareTo(a.id!);
            }
            return 0;
          });

    if (_medGivenTimeCtrl.text.isEmpty) {
      _medGivenTimeCtrl.text = _getCurrentFormattedTime();
    }

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
      padding: const EdgeInsets.all(14),
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
            children: [
              const Icon(
                Icons.medication_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('medicines_history'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 44,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('no_records_found'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('no_medicines_recorded_yet'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (int idx = 0; idx < pageMedicines.length; idx++) ...[
              () {
                final m = pageMedicines[idx];
                final isStat = m.medicineType == 'STAT';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (MediaQuery.of(context).size.width < 600) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              isStat ? Icons.flash_on : Icons.medication,
                              size: 20,
                              color: isStat
                                  ? const Color(0xFFDD6B20)
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                         context.translateMedicine(m.medicineName),
                                         style: const TextStyle(
                                           fontWeight: FontWeight.bold,
                                           fontSize: 14,
                                         ),
                                         softWrap: true,
                                       ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isStat
                                          ? const Color(0xFFFEEBC8)
                                          : const Color(0xFFEBF8FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isStat
                                            ? const Color(0xFFFBD38D)
                                            : const Color(0xFFBEE3F8),
                                      ),
                                    ),
                                    child: Text(
                                      m.medicineType == 'Regular' ? context.tr('regular_badge', fallback: 'Regular') : (m.medicineType == 'STAT' ? context.tr('stat_badge', fallback: 'STAT') : m.medicineType),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isStat
                                            ? const Color(0xFFC05621)
                                            : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                  tooltip: 'Edit Medicine',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _showRecordMedicineModal(
                                      context,
                                      visit,
                                      controller,
                                      existingMedicine: m,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.dangerColor,
                                  ),
                                  tooltip: 'Delete Medicine',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final confirmed =
                                        await _showConfirmDeleteDialog(
                                          context,
                                          title: 'Delete Medicine Record',
                                          message:
                                              'Are you sure you want to delete "${m.medicineName}" from this session? This action cannot be undone.',
                                        );
                                    if (confirmed && m.id != null) {
                                      final success = await controller
                                          .deleteMedicineItem(visit.id, m.id!);
                                      if (success && mounted) {
                                        AppNotification.showSuccess(
                                          context,
                                          'Medicine record deleted successfully',
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${context.tr('qty_label', fallback: 'Qty')}: ${m.quantity} | ${context.tr('food_label', fallback: 'Food')}: ${(m.foodTiming == 'After Food' ? context.tr('food_after', fallback: 'After Food') : (m.foodTiming == 'Before Food' ? context.tr('food_before', fallback: 'Before Food') : (m.foodTiming == 'With Food' ? context.tr('food_with', fallback: 'With Food') : (m.foodTiming ?? (m.route ?? context.tr('food_after', fallback: 'After Food'))))))} | ${context.tr('freq_label', fallback: 'Freq')}: ${m.frequency != null && m.frequency!.isNotEmpty ? m.frequency! : "N/A"} | ${context.tr('duration_label', fallback: 'Duration')}: ${m.duration != null && m.duration!.isNotEmpty ? (AppLocalizations.of(context).locale.languageCode == 'ta' ? m.duration!.replaceAll('Days', 'நாட்கள்').replaceAll('days', 'நாட்கள்') : m.duration!) : "N/A"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (m.givenTime != null && m.givenTime!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 13,
                                    color: AppTheme.secondaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    m.givenTime!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryColor,
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox.shrink(),
                            _buildTimestampBadge(
                              m.administeredAt,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isStat ? Icons.flash_on : Icons.medication,
                              size: 20,
                              color: isStat
                                  ? const Color(0xFFDD6B20)
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                         context.translateMedicine(m.medicineName),
                                         style: const TextStyle(
                                           fontWeight: FontWeight.bold,
                                           fontSize: 14,
                                         ),
                                         softWrap: true,
                                       ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isStat
                                              ? const Color(0xFFFEEBC8)
                                              : const Color(0xFFEBF8FF),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isStat
                                                ? const Color(0xFFFBD38D)
                                                : const Color(0xFFBEE3F8),
                                          ),
                                        ),
                                        child: Text(
                                      m.medicineType == 'Regular' ? context.tr('regular_badge', fallback: 'Regular') : (m.medicineType == 'STAT' ? context.tr('stat_badge', fallback: 'STAT') : m.medicineType),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isStat
                                                ? const Color(0xFFC05621)
                                                : AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${context.tr('qty_label', fallback: 'Qty')}: ${m.quantity} | ${context.tr('food_label', fallback: 'Food')}: ${(m.foodTiming == 'After Food' ? context.tr('food_after', fallback: 'After Food') : (m.foodTiming == 'Before Food' ? context.tr('food_before', fallback: 'Before Food') : (m.foodTiming == 'With Food' ? context.tr('food_with', fallback: 'With Food') : (m.foodTiming ?? (m.route ?? context.tr('food_after', fallback: 'After Food'))))))} | ${context.tr('freq_label', fallback: 'Freq')}: ${m.frequency != null && m.frequency!.isNotEmpty ? m.frequency! : "N/A"} | ${context.tr('duration_label', fallback: 'Duration')}: ${m.duration != null && m.duration!.isNotEmpty ? (AppLocalizations.of(context).locale.languageCode == 'ta' ? m.duration!.replaceAll('Days', 'நாட்கள்').replaceAll('days', 'நாட்கள்') : m.duration!) : "N/A"}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (m.givenTime != null &&
                                        m.givenTime!.isNotEmpty) ...[
                                      const Icon(
                                        Icons.access_time,
                                        size: 13,
                                        color: AppTheme.secondaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        m.givenTime!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.secondaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      tooltip: 'Edit Medicine',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _showRecordMedicineModal(
                                          context,
                                          visit,
                                          controller,
                                          existingMedicine: m,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppTheme.dangerColor,
                                      ),
                                      tooltip: 'Delete Medicine',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final confirmed =
                                            await _showConfirmDeleteDialog(
                                              context,
                                              title: 'Delete Medicine Record',
                                              message:
                                                  'Are you sure you want to delete "${m.medicineName}" from this session? This action cannot be undone.',
                                            );
                                        if (confirmed && m.id != null) {
                                          final success = await controller
                                              .deleteMedicineItem(
                                                visit.id,
                                                m.id!,
                                              );
                                          if (success && mounted) {
                                            AppNotification.showSuccess(
                                              context,
                                              'Medicine record deleted successfully',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildTimestampBadge(
                                  m.administeredAt,
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildDailyDoseChecklist(
                        medicine: m,
                        visit: visit,
                        controller: controller,
                      ),
                    ],
                  ),
                );
              }(),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              Text(
                AppLocalizations.of(context).locale.languageCode == 'ta' ? 'மொத்தம் $totalMeds பதிவுகளில் ${totalMeds == 0 ? 0 : medsStartIdx + 1}-$medsEndIdx காட்டப்படுகிறது' : 'Showing ${totalMeds == 0 ? 0 : medsStartIdx + 1}-$medsEndIdx of $totalMeds entries',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: currentMedsPage > 1
                        ? () => setState(() => _medsPage--)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 14),
                    label: const Text('Prev', style: TextStyle(fontSize: 11)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$currentMedsPage / $totalMedsPages',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: currentMedsPage < totalMedsPages
                        ? () => setState(() => _medsPage++)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 14),
                    label: const Text('Next', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final displayProcedures =
        visit.procedures.where((p) => _isRecordedToday(p.createdAt)).toList()
          ..sort((a, b) {
            if (a.id != null && b.id != null && a.id != b.id) {
              return b.id!.compareTo(a.id!);
            }
            if (a.createdAt != null && b.createdAt != null) {
              return b.createdAt!.compareTo(a.createdAt!);
            }
            return 0;
          });

    final totalProcedures = displayProcedures.length;
    final totalProcPages = (totalProcedures == 0)
        ? 1
        : ((totalProcedures - 1) ~/ _pageSize) + 1;
    final currentProcPage = _procPage.clamp(1, totalProcPages);
    final procStartIdx = (currentProcPage - 1) * _pageSize;
    final procEndIdx = (procStartIdx + _pageSize < totalProcedures)
        ? procStartIdx + _pageSize
        : totalProcedures;
    final pageProcedures = (procStartIdx < totalProcedures)
        ? displayProcedures.sublist(procStartIdx, procEndIdx)
        : <HomeVisitProcedureModel>[];

    final proceduresTableCard = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_edu_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('procedures_history'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${displayProcedures.length} Procedure(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (displayProcedures.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      size: 44,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('no_records_found'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('no_procedures_recorded_yet'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (int idx = 0; idx < pageProcedures.length; idx++) ...[
              () {
                final p = pageProcedures[idx];
                final procConsumables = visit.consumables.where((c) {
                  final nameLower = c.itemName.toLowerCase();
                  final procLower = p.procedureName.toLowerCase();
                  return nameLower.contains('($procLower)') ||
                      nameLower.contains(procLower);
                }).toList();

                final double consumableCharge = procConsumables.fold(
                  0.0,
                  (sum, c) => sum + (c.quantityUsed * c.unitPrice),
                );
                final double grandTotalProc =
                    p.totalProcedureCharge + consumableCharge;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (MediaQuery.of(context).size.width < 600) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                         context.translateProcedure(p.procedureName),
                                         style: const TextStyle(
                                           fontWeight: FontWeight.bold,
                                           fontSize: 14,
                                         ),
                                         softWrap: true,
                                       ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEBF8FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFBEE3F8),
                                      ),
                                    ),
                                    child: Text(
                                      p.frequency == 'Once Daily' ? context.tr('freq_once_daily', fallback: 'Once Daily') : (p.frequency == '2 Times/Day' ? context.tr('freq_2x_day', fallback: '2 Times/Day') : (p.frequency == '3 Times/Day' ? context.tr('freq_3x_day', fallback: '3 Times/Day') : (p.frequency == 'Every 4 Hours' ? context.tr('freq_every_4h', fallback: 'Every 4 Hours') : p.frequency))),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                  tooltip: 'Edit Procedure',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _showRecordProcedureModal(
                                      context,
                                      visit,
                                      controller,
                                      existingProcedure: p,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.dangerColor,
                                  ),
                                  tooltip: 'Delete Procedure',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final confirmed =
                                        await _showConfirmDeleteDialog(
                                          context,
                                          title: 'Delete Procedure Record',
                                          message:
                                              'Are you sure you want to delete "${p.procedureName}" from this session? This action cannot be undone.',
                                        );
                                    if (confirmed && p.id != null) {
                                      final success = await controller
                                          .deleteProcedureItem(visit.id, p.id!);
                                      if (success && mounted) {
                                        AppNotification.showSuccess(
                                          context,
                                          'Procedure record deleted successfully',
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          consumableCharge > 0
                              ? '${context.tr('procedure_label', fallback: 'Procedure')}: ₹${p.totalProcedureCharge.toStringAsFixed(2)} | ${context.tr('consumables_label', fallback: 'Consumables')}: ₹${consumableCharge.toStringAsFixed(2)}'
                              : '${context.tr('charge_per_proc', fallback: 'Charge/Proc')}: ₹${p.chargePerProcedure.toStringAsFixed(2)} | ${context.tr('total_charge', fallback: 'Total Charge')}: ₹${p.totalProcedureCharge.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                        if (procConsumables.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: procConsumables.map((c) {
                              final cleanName = c.itemName
                                  .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
                                  .trim();
                              final totalCost = c.quantityUsed * c.unitPrice;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  '${context.translateConsumable(cleanName)} (${c.quantityUsed}x) • ₹${totalCost.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${context.tr('total', fallback: 'Total')}: ₹${grandTotalProc.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            _buildTimestampBadge(
                              p.createdAt,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                         context.translateProcedure(p.procedureName),
                                         style: const TextStyle(
                                           fontWeight: FontWeight.bold,
                                           fontSize: 14,
                                         ),
                                         softWrap: true,
                                       ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEBF8FF),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFBEE3F8),
                                          ),
                                        ),
                                        child: Text(
                                      p.frequency == 'Once Daily' ? context.tr('freq_once_daily', fallback: 'Once Daily') : (p.frequency == '2 Times/Day' ? context.tr('freq_2x_day', fallback: '2 Times/Day') : (p.frequency == '3 Times/Day' ? context.tr('freq_3x_day', fallback: '3 Times/Day') : (p.frequency == 'Every 4 Hours' ? context.tr('freq_every_4h', fallback: 'Every 4 Hours') : p.frequency))),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    consumableCharge > 0
                              ? '${context.tr('procedure_label', fallback: 'Procedure')}: ₹${p.totalProcedureCharge.toStringAsFixed(2)} | ${context.tr('consumables_label', fallback: 'Consumables')}: ₹${consumableCharge.toStringAsFixed(2)}'
                              : '${context.tr('charge_per_proc', fallback: 'Charge/Proc')}: ₹${p.chargePerProcedure.toStringAsFixed(2)} | ${context.tr('total_charge', fallback: 'Total Charge')}: ₹${p.totalProcedureCharge.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  if (procConsumables.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 5,
                                      children: procConsumables.map((c) {
                                        final cleanName = c.itemName
                                            .replaceAll(
                                              RegExp(r'\s*\([^)]*\)'),
                                              '',
                                            )
                                            .trim();
                                        final totalCost =
                                            c.quantityUsed * c.unitPrice;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Text(
                                            '$cleanName (${c.quantityUsed}x) • ₹${totalCost.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF475569),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '₹${grandTotalProc.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      tooltip: 'Edit Procedure',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _showRecordProcedureModal(
                                          context,
                                          visit,
                                          controller,
                                          existingProcedure: p,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppTheme.dangerColor,
                                      ),
                                      tooltip: 'Delete Procedure',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final confirmed =
                                            await _showConfirmDeleteDialog(
                                              context,
                                              title: 'Delete Procedure Record',
                                              message:
                                                  'Are you sure you want to delete "${p.procedureName}" from this session? This action cannot be undone.',
                                            );
                                        if (confirmed && p.id != null) {
                                          final success = await controller
                                              .deleteProcedureItem(
                                                visit.id,
                                                p.id!,
                                              );
                                          if (success && mounted) {
                                            AppNotification.showSuccess(
                                              context,
                                              'Procedure record deleted successfully',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildTimestampBadge(
                                  p.createdAt,
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }(),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              Text(
                'Showing ${totalProcedures == 0 ? 0 : procStartIdx + 1}-$procEndIdx of $totalProcedures entries',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: currentProcPage > 1
                        ? () => setState(() => _procPage--)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 14),
                    label: const Text('Prev', style: TextStyle(fontSize: 11)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$currentProcPage / $totalProcPages',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: currentProcPage < totalProcPages
                        ? () => setState(() => _procPage++)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 14),
                    label: const Text('Next', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 800;
              final headerWidget = _buildSectionHeader(
                context.tr('log_administered_meds_proc'),
                Icons.medication_liquid_outlined,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerWidget,
                    if (!widget.isReadOnlyView) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            style: AppTheme.dangerButton,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              context.tr('add_medicine_btn'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _showRecordMedicineModal(
                              context,
                              visit,
                              controller,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: AppTheme.dangerButton,
                            icon: const Icon(
                              Icons.medical_services_outlined,
                              size: 18,
                            ),
                            label: Text(
                              context.tr('add_procedure_item_btn'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => _showRecordProcedureModal(
                              context,
                              visit,
                              controller,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: headerWidget),
                  if (!widget.isReadOnlyView) ...[
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: AppTheme.dangerButton,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            context.tr('add_medicine_btn'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _showRecordMedicineModal(
                            context,
                            visit,
                            controller,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: AppTheme.dangerButton,
                          icon: const Icon(
                            Icons.medical_services_outlined,
                            size: 18,
                          ),
                          label: Text(
                            context.tr('add_procedure_item_btn'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _showRecordProcedureModal(
                            context,
                            visit,
                            controller,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: medicinesTableCard),
                    const SizedBox(width: 20),
                    Expanded(child: proceduresTableCard),
                  ],
                );
              }

              return Column(
                children: [
                  medicinesTableCard,
                  const SizedBox(height: 20),
                  proceduresTableCard,
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
    final activePhotos = visit.photos
        .where((p) => _isRecordedToday(p.capturedAt))
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context.tr('photo_evidence_upload_gallery', fallback: 'Timestamped Photo Evidence Upload & Gallery'),
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
                Text(
                  context.tr('upload_photo_evidence', fallback: 'Upload Timestamped Photo Evidence'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, photoConstraints) {
                    final isMobilePhoto = photoConstraints.maxWidth < 600;
                    final categoryHasError =
                        _photoSubmitAttempted &&
                        (_selectedPhotoCategory == null ||
                            _selectedPhotoCategory!.trim().isEmpty);
                    final fileHasError =
                        _photoSubmitAttempted &&
                        (_selectedPhotoName == null &&
                            _selectedPhotoBytes == null);

                    final categoryDropdown = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('${context.tr('photo_category', fallback: 'Photo Category')} *'),
                        CustomDropdownSearch(
                          label: '',
                          hint: context.tr('select_photo_category', fallback: 'Select Photo Category'),
                          dropdownMap: {
                            'Dressing Pre-Procedure': context.tr(
                              'photo_cat_dressing_pre',
                              fallback: 'Pre-Dressing Wound Photo',
                            ),
                            'Dressing Post-Procedure': context.tr(
                              'photo_cat_dressing_post',
                              fallback: 'Post-Dressing Photo',
                            ),
                            'Care Activity': context.tr(
                              'photo_cat_care_activity',
                              fallback: 'Care Activity Evidence',
                            ),
                            'General Care': context.tr(
                              'photo_cat_general_care',
                              fallback: 'General Visit Photo',
                            ),
                          },
                          value: _selectedPhotoCategory,
                          borderColor: categoryHasError
                              ? AppTheme.dangerColor
                              : null,
                          focusedBorderColor: categoryHasError
                              ? AppTheme.dangerColor
                              : null,
                          borderWidth: categoryHasError ? 1.5 : null,
                          onChanged: (val) {
                            setState(() {
                              _selectedPhotoCategory = val;
                            });
                          },
                        ),
                        if (categoryHasError) ...[
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppTheme.dangerColor,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Photo category is mandatory. Please select a category.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.dangerColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                    final filePicker = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('${context.tr('photo_evidence_file', fallback: 'Photo Evidence File')} *'),
                        if (_selectedPhotoBytes != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.secondaryColor,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.secondaryColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedPhotoName ?? 'Selected Image',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF166534),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_selectedPhotoSize != null)
                                        Text(
                                          'Size: ${_formatFileSize(_selectedPhotoSize!)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 34),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Preview',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _showSelectedPhotoPreviewModal(context),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 34),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _pickPhoto,
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppTheme.dangerColor,
                                  ),
                                  tooltip: 'Remove',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedPhotoName = null;
                                      _selectedPhotoBytes = null;
                                      _selectedPhotoSize = null;
                                      _photoFormatError = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          )
                        else
                          InkWell(
                            onTap: _pickPhoto,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_photoFormatError != null || fileHasError)
                                    ? const Color(0xFFFEF2F2)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      (_photoFormatError != null ||
                                          fileHasError)
                                      ? AppTheme.dangerColor
                                      : const Color(0xFFCBD5E0),
                                  width:
                                      (_photoFormatError != null ||
                                          fileHasError)
                                      ? 1.5
                                      : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    (_photoFormatError != null || fileHasError)
                                        ? Icons.error
                                        : Icons.cloud_upload_outlined,
                                    color:
                                        (_photoFormatError != null ||
                                            fileHasError)
                                        ? AppTheme.dangerColor
                                        : AppTheme.primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      context.tr('click_to_browse_upload'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            (_photoFormatError != null ||
                                                fileHasError)
                                            ? AppTheme.dangerColor
                                            : Colors.black87,
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
                                      color:
                                          (_photoFormatError != null ||
                                              fileHasError)
                                          ? AppTheme.dangerColor
                                          : AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      context.tr('browse_file'),
                                      style: const TextStyle(
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
                        ] else if (fileHasError) ...[
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppTheme.dangerColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Photo evidence image file is mandatory. Please choose a file.',
                                  style: TextStyle(
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
                        _buildLabel(context.tr('photo_notes_caption')),
                        TextFormField(
                          controller: _photoCaptionCtrl,
                          maxLength: 100,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(100),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\u0B80-\u0BFF\s]'),
                            ),
                          ],
                          validator: (val) {
                            final text = val?.trim() ?? '';
                            if (text.isEmpty) return null;
                            if (text.length < 3) {
                              return 'Caption must be at least 3 characters if provided';
                            }
                            if (text.length > 100) {
                              return 'Caption cannot exceed 100 characters';
                            }
                            if (!RegExp(r'[a-zA-Z\u0B80-\u0BFF]').hasMatch(text)) {
                              return 'Caption must contain letters or Tamil characters and cannot consist solely of numbers';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9\u0B80-\u0BFF\s]+$').hasMatch(text)) {
                              return 'Special characters are not allowed in caption';
                            }
                            return null;
                          },
                          decoration: AppTheme.standardInputDecoration(
                            hintText: context.tr('photo_notes_hint'),
                          ),
                        ),
                      ],
                    );
                    final uploadBtn = SizedBox(
                      width: isMobileCaption ? double.infinity : null,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: AppTheme.dangerButton,
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
                          _isUploadingPhoto
                              ? context.tr('uploading')
                              : context.tr('upload_photo_evidence_btn'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isUploadingPhoto
                            ? null
                            : () async {
                                setState(() => _photoSubmitAttempted = true);

                                if (_selectedPhotoCategory == null ||
                                    _selectedPhotoCategory!.trim().isEmpty) {
                                  AppNotification.showError(
                                    context,
                                    'Please select a Photo Category.',
                                  );
                                  return;
                                }

                                if (_selectedPhotoName == null &&
                                    _selectedPhotoBytes == null) {
                                  AppNotification.showError(
                                    context,
                                    'Please select an image file to upload (JPG, JPEG, PNG).',
                                  );
                                  return;
                                }

                                if (_photoFormatError != null ||
                                    (_selectedPhotoName != null &&
                                        !_isAllowedImageFormat(
                                          _selectedPhotoName!,
                                        ))) {
                                  AppNotification.showError(
                                    context,
                                    'Invalid image format! Only JPG, JPEG, and PNG files are supported.',
                                  );
                                  return;
                                }

                                if (_selectedPhotoSize != null &&
                                    _selectedPhotoSize! > 15 * 1024 * 1024) {
                                  AppNotification.showError(
                                    context,
                                    'File size exceeds the 15 MB limit. Please select an image under 15 MB.',
                                  );
                                  return;
                                }

                                final captionText = _photoCaptionCtrl.text
                                    .trim();
                                if (captionText.isNotEmpty) {
                                  if (captionText.length < 3) {
                                    AppNotification.showError(
                                      context,
                                      'Caption must be at least 3 characters if provided',
                                    );
                                    return;
                                  }
                                  if (captionText.length > 100) {
                                    AppNotification.showError(
                                      context,
                                      'Caption cannot exceed 100 characters',
                                    );
                                    return;
                                  }
                                  if (!RegExp(
                                    r'[a-zA-Z\u0B80-\u0BFF]',
                                  ).hasMatch(captionText)) {
                                    AppNotification.showError(
                                      context,
                                      'Caption must contain letters or Tamil characters and cannot consist solely of numbers',
                                    );
                                    return;
                                  }
                                  if (!RegExp(
                                    r'^[a-zA-Z0-9\u0B80-\u0BFF\s]+$',
                                  ).hasMatch(captionText)) {
                                    AppNotification.showError(
                                      context,
                                      'Special characters are not allowed in caption',
                                    );
                                    return;
                                  }
                                }

                                setState(() => _isUploadingPhoto = true);
                                String? cloudinaryUrl;
                                if (_selectedPhotoBytes != null) {
                                  try {
                                    cloudinaryUrl =
                                        await MediaService.uploadToCloudinary(
                                          fileBytes: _selectedPhotoBytes!,
                                          fileName:
                                              _selectedPhotoName ?? 'photo.jpg',
                                          folder: 'Home Visit',
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
                                      _selectedPhotoCategory!,
                                      _photoCaptionCtrl.text.trim(),
                                    );
                                setState(() => _isUploadingPhoto = false);

                                if (success && mounted) {
                                  _clearPhotoForm();
                                  AppNotification.showSuccess(
                                    context,
                                    'Photo evidence uploaded successfully!',
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

                if (activePhotos.isNotEmpty) ...[
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
                      final crossCount = gridConstraints.maxWidth < 400
                          ? 2
                          : gridConstraints.maxWidth < 600
                          ? 3
                          : 5;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: activePhotos.length,
                        itemBuilder: (context, idx) {
                          final p = activePhotos[idx];
                          String timeStr = 'Just now';
                          if (p.capturedAt != null) {
                            try {
                              final dt = DateTime.parse(
                                p.capturedAt!,
                              ).toLocal();
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
                            onTap: () => _showFullImagePreviewDialog(
                              context,
                              p,
                              visitId: visit.id,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
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
                                                    color: const Color(
                                                      0xFFF1F5F9,
                                                    ),
                                                    child: const Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
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
                                                    Icons
                                                        .photo_library_outlined,
                                                    color:
                                                        AppTheme.primaryColor,
                                                    size: 36,
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Uploaded Evidence',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          // Open in New Tab Button Overlay (Top-Left)
                                          if (p.photoUrl.isNotEmpty)
                                            Positioned(
                                              top: 6,
                                              left: 6,
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () =>
                                                      _openPhotoInNewTab(
                                                        p.photoUrl,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.95,
                                                          ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.2,
                                                              ),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                            0,
                                                            1,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Icons.open_in_new,
                                                      color:
                                                          AppTheme.primaryColor,
                                                      size: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Delete Button Overlay (Top-Right)
                                          if (!widget.isReadOnlyView &&
                                              p.id != null)
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () =>
                                                      _showDeletePhotoConfirmationDialog(
                                                        context,
                                                        visit.id,
                                                        p,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.95,
                                                          ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.2,
                                                              ),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                            0,
                                                            1,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Icons.delete_outline,
                                                      color:
                                                          AppTheme.dangerColor,
                                                      size: 15,
                                                    ),
                                                  ),
                                                ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          Tooltip(
                                            message: p.caption!,
                                            child: Text(
                                              p.caption!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
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
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 44,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.tr('no_records_found'),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('no_photo_evidence_yet'),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
    final isCompleted = visit.status == 'Completed' || visit.status == 'Verified';

    return SingleChildScrollView(
      physics: _isSigningSignature
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context.tr('patient_attender_verification_title', fallback: 'Patient Attender Verification & Digital Signature'),
            Icons.draw_outlined,
          ),
          const SizedBox(height: 20),

          if (isCompleted) ...[
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppTheme.secondaryColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('home_visit_completed_verified', fallback: 'Home Visit Completed & Verified'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Attender verification completed on ${visit.signedAt ?? visit.scheduledDate}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          context.tr('completed_status', fallback: 'COMPLETED'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailField(
                          context.tr('verified_attender_name', fallback: 'Verified Attender Name'),
                          visit.attenderName ?? 'Attender',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailField(
                          context.tr('relationship_label', fallback: 'Relationship'),
                          visit.attenderRelation ?? 'Attender',
                        ),
                      ),
                    ],
                  ),
                  if (visit.feedback != null &&
                      visit.feedback!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildLabel('Recorded Visit & Care Feedback'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.record_voice_over_outlined,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              visit.feedback!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF1E293B),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildLabel('Attender Digital Signature'),
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.draw_outlined,
                            color: AppTheme.secondaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Digital Signature Verified & Stored',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
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
                  Text(
                    context.tr('patient_attender_verification_title', fallback: 'Patient Attender Verification & Digital Signature'),
                    style: const TextStyle(
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
                            _buildLabel(context.tr('attender_full_name_req')),
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
                            _buildLabel(context.tr('attender_relationship_req')),
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
                  const SizedBox(height: 18),
                  _buildFeedbackVoiceField(
                    controller: _feedbackCtrl,
                    isModal: false,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel(context.tr('attender_signature_pad_req')),
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
                        fit: StackFit.expand,
                        children: [
                          if (_signaturePoints.isEmpty)
                            IgnorePointer(
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.draw_outlined,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.tr('draw_signature_hint', fallback: 'Draw attender signature here with mouse or touch...'),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _isSigningSignature = true;
                                  _signaturePoints.add(event.localPosition);
                                });
                              },
                              onPointerMove: (event) {
                                setState(() {
                                  _signaturePoints.add(event.localPosition);
                                });
                              },
                              onPointerUp: (event) {
                                setState(() {
                                  _isSigningSignature = false;
                                  _signaturePoints.add(null);
                                });
                              },
                              onPointerCancel: (event) {
                                setState(() {
                                  _isSigningSignature = false;
                                  _signaturePoints.add(null);
                                });
                              },
                              child: CustomPaint(
                                painter: SignaturePainter(
                                  points: _signaturePoints,
                                ),
                                size: Size.infinite,
                              ),
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
                        label: Text(context.tr('clear_signature', fallback: 'Clear Signature')),
                        onPressed: () =>
                            setState(() => _signaturePoints.clear()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: AppTheme.dangerButton,
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
                              size: 18,
                            ),
                      label: Text(
                        _isVerifying
                            ? context.tr('generating_invoice', fallback: 'Generating Auto-Billing Invoice...')
                            : context.tr('verify_visit_generate_invoice', fallback: 'Verify Visit & Generate Billing Invoice'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isVerifying
                          ? null
                          : () async {
                              if (_attenderNameCtrl.text.trim().length < 3) {
                                AppNotification.showError(
                                  context,
                                  'Please enter valid attender name (min 3 chars).',
                                );
                                return;
                              }

                              setState(() => _isVerifying = true);
                              final result = await controller.verifyVisit(
                                visit.id,
                                _attenderNameCtrl.text.trim(),
                                _attenderRelationCtrl.text.trim(),
                                'signature_base64_data_valid',
                                feedback: _feedbackCtrl.text.trim(),
                              );
                              setState(() => _isVerifying = false);

                              if (result != null && mounted) {
                                _clearSignatureForm();
                                showDialog(
                                  context: context,
                                  builder: (_) => HomeVisitInvoiceDialog(
                                    invoiceData: result,
                                    visit: visit,
                                    onCloseAndComplete: () {
                                      _handleLeave();
                                    },
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
    final feedbackCtrl = TextEditingController(text: _feedbackCtrl.text);
    List<Offset?> sigPoints = List.from(_signaturePoints);
    bool isSubmitting = false;
    bool isDialogSigning = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              physics: isDialogSigning
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.draw_outlined,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('end_visit_attender_verification'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                                maxLines: 2,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    context.tr('patient_attender_verification_title', fallback: 'Patient Attender Verification & Digital Signature'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('attender_verification_sub', fallback: 'Please record the attender details, care feedback, and obtain their signature to end the visit session and generate the billing invoice.'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel(context.tr('attender_full_name_req')),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(30),
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s.]')),
                      const CapitalizeWordsInputFormatter(),
                    ],
                    decoration: AppTheme.standardInputDecoration(
                      hintText: 'Full Name (Min 3, Max 30 chars)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel(context.tr('attender_relationship_req')),
                  TextFormField(
                    controller: relCtrl,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                      const CapitalizeWordsInputFormatter(),
                    ],
                    decoration: AppTheme.standardInputDecoration(
                      hintText: 'e.g. Son, Spouse, Daughter',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeedbackVoiceField(
                    controller: feedbackCtrl,
                    setModalState: setDialogState,
                    isModal: true,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel(context.tr('attender_signature_pad_req')),
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
                        fit: StackFit.expand,
                        children: [
                          if (sigPoints.isEmpty)
                            const IgnorePointer(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.draw_outlined,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Draw attender signature here',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) {
                                FocusScope.of(context).unfocus();
                                setDialogState(() {
                                  isDialogSigning = true;
                                  sigPoints.add(event.localPosition);
                                });
                              },
                              onPointerMove: (event) {
                                setDialogState(() {
                                  sigPoints.add(event.localPosition);
                                });
                              },
                              onPointerUp: (event) {
                                setDialogState(() {
                                  isDialogSigning = false;
                                  sigPoints.add(null);
                                });
                              },
                              onPointerCancel: (event) {
                                setDialogState(() {
                                  isDialogSigning = false;
                                  sigPoints.add(null);
                                });
                              },
                              child: CustomPaint(
                                painter: SignaturePainter(points: sigPoints),
                                size: Size.infinite,
                              ),
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
                        flex: 1,
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: AppTheme.cancelButton,
                            child: Text(context.tr('cancel')),
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    ModalHistoryHelper.skipNextHistoryBack();
                                    Navigator.of(dialogCtx).pop();
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            style: AppTheme.dangerButton,
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
                                  ? context.tr('processing', fallback: 'Processing...')
                                  : context.tr('complete_visit_create_invoice', fallback: 'Complete Visit & Create Invoice'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (nameCtrl.text.trim().length < 3) {
                                      AppNotification.showError(
                                        dialogCtx,
                                        'Please enter attender full name (min 3 chars).',
                                      );
                                      return;
                                    }
                                    if (relCtrl.text.trim().isEmpty) {
                                      AppNotification.showError(
                                        dialogCtx,
                                        'Please specify attender relationship.',
                                      );
                                      return;
                                    }
                                    if (sigPoints.isEmpty) {
                                      AppNotification.showError(
                                        dialogCtx,
                                        'Attender signature is required to complete the home visit.',
                                      );
                                      return;
                                    }
                                    setDialogState(() => isSubmitting = true);
                                    _attenderNameCtrl.text = nameCtrl.text
                                        .trim();
                                    _attenderRelationCtrl.text = relCtrl.text
                                        .trim();
                                    _feedbackCtrl.text = feedbackCtrl.text
                                        .trim();

                                    final result = await controller.verifyVisit(
                                      visit.id,
                                      nameCtrl.text.trim(),
                                      relCtrl.text.trim(),
                                      'signature_base64_data_valid',
                                      feedback: feedbackCtrl.text.trim(),
                                    );
                                    await controller.fetchVisits();

                                    if (result != null && context.mounted) {
                                      ModalHistoryHelper.skipNextHistoryBack();
                                      Navigator.of(dialogCtx).pop();
                                      showDialog(
                                        context: context,
                                        builder: (_) => HomeVisitInvoiceDialog(
                                          invoiceData: result,
                                          visit: visit,
                                          onCloseAndComplete: () {
                                            _handleLeave();
                                          },
                                        ),
                                      );
                                      AppNotification.showSuccess(
                                        context,
                                        "Today's home visit marked as Completed & invoice generated!",
                                      );
                                    } else if (context.mounted) {
                                      setDialogState(
                                        () => isSubmitting = false,
                                      );
                                      AppNotification.showError(
                                        dialogCtx,
                                        controller.errorMessage ??
                                            'Failed to complete visit and generate invoice. Please try again.',
                                      );
                                    }
                                  },
                          ),
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

    final currentDayNumber = _calculateVisitDayNumber(visit, controller);

    // Filter vitals for TODAY ONLY
    final todayVitals = visit.vitalsHistory
        .where((v) => _isRecordedToday(v.recordedAt))
        .toList();

    // Filter medicines for TODAY ONLY
    final todayMedicines = visit.medicines
        .where((m) => _isRecordedToday(m.administeredAt))
        .toList();

    // Filter consumables for TODAY ONLY
    final todayConsumables = visit.consumables
        .where((c) => _isRecordedToday(c.createdAt))
        .toList();

    // Filter procedures for TODAY ONLY
    final todayProcedures = visit.procedures
        .where((p) => _isRecordedToday(p.createdAt))
        .toList();

    // Filter photos for TODAY ONLY
    final todayPhotos = visit.photos
        .where((p) => _isRecordedToday(p.capturedAt))
        .toList();

    // Filter care activities for TODAY ONLY
    final allCare = visit.careActivitiesHistory.isNotEmpty
        ? visit.careActivitiesHistory
        : (visit.careActivities != null
              ? [visit.careActivities!]
              : <HomeVisitCareActivities>[]);
    final todayCare = allCare
        .where((c) => _isRecordedToday(c.createdAt))
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
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
              child: LayoutBuilder(
                builder: (context, bannerConstraints) {
                  final isNarrow = bannerConstraints.maxWidth < 650;
                  final buttonWidget = SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: AppTheme.dangerButton.copyWith(
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.verified_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        context.tr('end_todays_visit', fallback: "End Today's Visit"),
                        style: const TextStyle(
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
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withOpacity(
                                  0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.secondaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('ready_to_complete_visit', fallback: "Ready to Complete Today's Visit?"),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF14532D),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.tr('ready_to_complete_sub', fallback: "Click below to capture attender signature, generate the itemized billing invoice, and mark today's home visit as Completed."),
                                    style: const TextStyle(
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
                        SizedBox(width: double.infinity, child: buttonWidget),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('ready_to_complete_visit', fallback: "Ready to Complete Today's Visit?"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14532D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('ready_to_complete_sub', fallback: "Click to capture attender signature, generate the itemized billing invoice, and mark today's home visit as Completed."),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      buttonWidget,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          _buildSectionHeader(
            context.tr('session_summary_tracker', fallback: "Today's Session Summary & Real-Time Tracker"),
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
                            '${context.tr('patient_label', fallback: 'Patient:')} ${TamilTransliterationHelper.translate(context, visit.patientName ?? "N/A")} (${visit.patientDisplayId ?? "N/A"})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${context.tr('session', fallback: 'Session')}: ${visit.scheduledDate} | ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                TextSpan(
                                  text: '${context.tr('nurse_label', fallback: 'Nurse:')} ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.nurseColor,
                                  ),
                                ),
                                TextSpan(
                                  text: visit.nurseName ?? "N/A",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.nurseColor,
                                  ),
                                ),
                              ],
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
                        _getTranslatedHomeVisitStatus(visit.status).toUpperCase(),
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
                      context.tr('kit_devices_stat', fallback: 'Kit Devices'),
                      '${visit.carriedItems.length} ${context.tr('added_suffix', fallback: 'Added')}',
                      AppTheme.primaryColor,
                    ),
                    _liveSummaryChip(
                      Icons.monitor_heart_outlined,
                      context.tr('vitals_log_stat', fallback: 'Vitals Log'),
                      '${todayVitals.length} ${context.tr('today_entries_suffix', fallback: 'Today Entries')}',
                      Colors.purple,
                    ),
                    _liveSummaryChip(
                      Icons.edit_note,
                      context.tr('care_notes_stat', fallback: 'Care Notes'),
                      todayCare.isNotEmpty
                          ? '${todayCare.length} ${context.tr('today_entries_suffix', fallback: 'Today Entries')}'
                          : context.tr('pending_status', fallback: 'Pending'),
                      Colors.orange,
                    ),
                    _liveSummaryChip(
                      Icons.medication_liquid,
                      context.tr('meds_procedures_stat', fallback: 'Meds & Procedures'),
                      '${todayMedicines.length} ${context.tr('meds_short', fallback: 'Meds')} / ${todayProcedures.length} ${context.tr('procedures_short', fallback: 'Procedures')}',
                      AppTheme.secondaryColor,
                    ),
                    _liveSummaryChip(
                      Icons.camera_alt_outlined,
                      context.tr('photos_stat', fallback: 'Photos'),
                      '${todayPhotos.length} ${context.tr('today_photos_suffix', fallback: 'Today Photos')}',
                      Colors.teal,
                    ),
                    _liveSummaryChip(
                      Icons.verified_user_outlined,
                      context.tr('attender_verification_stat', fallback: 'Attender Verification'),
                      visit.attenderName != null &&
                              visit.attenderName!.isNotEmpty
                          ? '${context.tr('verified', fallback: 'Verified')} (${visit.attenderName})'
                          : context.tr('pending_status', fallback: 'Pending'),
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
                  context.tr('carried_used_kit_devices_title', fallback: '1. Carried & Used Kit Devices'),
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
                            '${_getTranslatedKitDevice(item.itemName)} (${_getTranslatedKitType(item.itemType)} • ${context.tr('qty', fallback: 'Qty')}: ${item.quantityCarried})',
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
                  context.tr('todays_hourly_vitals_title'),
                  Icons.monitor_heart_outlined,
                ),
                const SizedBox(height: 12),
                if (todayVitals.isEmpty)
                  Text(
                    context.tr('no_vitals_logged_today'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                            _tableHeader(context.tr('recorded_at')),
                            _tableHeader(context.tr('blood_pressure')),
                            _tableHeader(context.tr('pulse_rate_req')),
                            _tableHeader(context.tr('spo2_req')),
                            _tableHeader(context.tr('temperature_req')),
                            _tableHeader(context.tr('blood_sugar_label')),
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
                  context.tr('todays_nursing_care_title'),
                  Icons.edit_note_outlined,
                ),
                const SizedBox(height: 12),
                if (todayCare.isEmpty)
                  Text(
                    context.tr('no_care_recorded_today'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else ...[
                  for (final care in todayCare) ...[
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
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${context.tr('recorded_on', fallback: 'Recorded on')}: ${_formatRecordedAt(care.createdAt)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          if (care.nursingNotes != null &&
                              care.nursingNotes!.isNotEmpty)
                            _detailRow(context.tr('nurse_notes', fallback: 'Nursing Notes'), care.nursingNotes!),
                          if (care.dressingProcedures != null &&
                              care.dressingProcedures!.isNotEmpty)
                            _detailRow(
                              context.tr('dressing_procedure', fallback: 'Dressing Procedure'),
                              care.dressingProcedures!,
                            ),
                          if (care.nailTrimmingDone)
                            _detailRow(
                              context.tr('nail_trimming_hygiene', fallback: 'Nail Trimming / Hygiene Care'),
                              context.tr('status_completed', fallback: 'Completed'),
                            ),
                          if (care.otherCareActivities != null &&
                              care.otherCareActivities!.isNotEmpty)
                            _detailRow(
                              context.tr('other_care_activities', fallback: 'Other Care Activities'),
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
                  context.tr('todays_meds_procedures_title'),
                  Icons.medication_liquid_outlined,
                ),
                const SizedBox(height: 12),
                if (todayMedicines.isEmpty &&
                    todayProcedures.isEmpty &&
                    todayConsumables.isEmpty)
                  Text(
                    context.tr('no_meds_logged_today'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else ...[
                  if (todayMedicines.isNotEmpty) ...[
                    Text(
                      context.tr('meds_administered_today_no_fee', fallback: 'Medicines Administered Today (No Billing Fee):'),
                      style: const TextStyle(
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
                          '• ${context.translateMedicine(m.medicineName)} (${m.dosage}) - ${context.tr('qty', fallback: 'Qty')}: ${m.quantity}',
                          style: const TextStyle(fontSize: 13),
                          softWrap: true,
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (todayProcedures.isNotEmpty) ...[
                    Text(
                      context.tr('recorded_procedures_consumables', fallback: 'Recorded Procedures & Consumables:'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final p in todayProcedures)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          '• ${context.translateProcedure(p.procedureName)} (${p.frequency}) - ${context.tr('charge', fallback: 'Charge')}: ₹${p.totalProcedureCharge.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ] else if (todayConsumables.isNotEmpty) ...[
                    Text(
                      context.tr('consumables_recorded_today', fallback: 'Consumables Recorded Today:'),
                      style: const TextStyle(
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
                          '• ${context.translateConsumable(c.itemName)} - ${context.tr('qty', fallback: 'Qty')}: ${c.quantityUsed} | ₹${(c.unitPrice * c.quantityUsed).toStringAsFixed(2)}',
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
                  context.tr('todays_photo_evidence_title'),
                  Icons.insert_photo_outlined,
                ),
                const SizedBox(height: 12),
                if (todayPhotos.isEmpty)
                  Text(
                    context.tr('no_photos_uploaded_today'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  LayoutBuilder(
                    builder: (context, photoGridConstraints) {
                      final crossCount = photoGridConstraints.maxWidth < 450
                          ? 2
                          : photoGridConstraints.maxWidth < 700
                          ? 3
                          : 4;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          childAspectRatio: 0.95,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: todayPhotos.length,
                        itemBuilder: (context, index) {
                          final p = todayPhotos[index];
                          final isNetwork =
                              p.photoUrl.startsWith('http://') ||
                              p.photoUrl.startsWith('https://');

                          String timeStr = '';
                          if (p.capturedAt != null) {
                            try {
                              final dt = DateTime.parse(
                                p.capturedAt!,
                              ).toLocal();
                              int h = dt.hour % 12;
                              if (h == 0) h = 12;
                              final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                              final m = dt.minute.toString().padLeft(2, '0');
                              final day = dt.day.toString().padLeft(2, '0');
                              final month = dt.month.toString().padLeft(2, '0');
                              timeStr = '$day-$month • $h:$m $ampm';
                            } catch (_) {
                              timeStr = p.capturedAt!;
                            }
                          }

                          return InkWell(
                            onTap: () => _showFullImagePreviewDialog(
                              context,
                              p,
                              visitId: visit.id,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(9),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (isNetwork)
                                            Image.network(
                                              p.photoUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                    if (progress == null) {
                                                      return child;
                                                    }
                                                    return Container(
                                                      color: const Color(
                                                        0xFFF1F5F9,
                                                      ),
                                                      child: const Center(
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
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
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    color: const Color(
                                                      0xFFF1F5F9,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        color: Colors.grey,
                                                        size: 28,
                                                      ),
                                                    ),
                                                  ),
                                            )
                                          else
                                            Container(
                                              color: const Color(0xFFF1F5F9),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.photo_library_outlined,
                                                  color: AppTheme.primaryColor,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.5,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.fullscreen,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          p.category ?? 'Photo Evidence',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: AppTheme.primaryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (timeStr.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500,
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
    HomeVisitPhotoEvidence photo, {
    int? visitId,
  }) {
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

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
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
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
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
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTranslatedPhotoCategory(photo.category),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${context.tr('captured_at_label', fallback: 'Captured at')} $timeStr',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (photo.photoUrl.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.open_in_new,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            tooltip: context.tr('open_image_new_tab', fallback: 'Open Image in New Tab'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _openPhotoInNewTab(photo.photoUrl),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (!widget.isReadOnlyView &&
                            photo.id != null &&
                            visitId != null) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.dangerColor,
                              size: 20,
                            ),
                            tooltip: context.tr('delete_photo_evidence', fallback: 'Delete Photo Evidence'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              ModalHistoryHelper.skipNextHistoryBack();
                              Navigator.of(dialogCtx).pop();
                              _showDeletePhotoConfirmationDialog(
                                context,
                                visitId,
                                photo,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                        ],
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 20,
                          ),
                          tooltip: context.tr('close_preview', fallback: 'Close Preview'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            ModalHistoryHelper.skipNextHistoryBack();
                            Navigator.of(dialogCtx).pop();
                          },
                        ),
                      ],
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
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.broken_image,
                                          color: Colors.white54,
                                          size: 64,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          context.tr('full_image_preview_unavailable', fallback: 'Full-size image preview unavailable'),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.photo_library,
                                    color: Colors.white54,
                                    size: 64,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('uploaded_evidence_file', fallback: 'Uploaded Evidence File'),
                                    style: const TextStyle(color: Colors.white70),
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
                        color: AppTheme.secondaryColor,
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

    if (patientVisits.isEmpty ||
        !patientVisits.any((v) => v.id == currentVisit.id)) {
      patientVisits.add(currentVisit);
    }

    patientVisits.sort((a, b) {
      final dateCmp = _toNormalizedDateKey(
        a.scheduledDate,
      ).compareTo(_toNormalizedDateKey(b.scheduledDate));
      if (dateCmp != 0) return dateCmp;
      return a.id.compareTo(b.id);
    });

    final distinctDates = <String>[];
    for (final v in patientVisits) {
      final dKey = _toNormalizedDateKey(v.scheduledDate);
      if (dKey.isNotEmpty && !distinctDates.contains(dKey)) {
        distinctDates.add(dKey);
      }
    }
    distinctDates.sort();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12.0 : 24.0,
        vertical: 16.0,
      ),
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
            child: LayoutBuilder(
              builder: (context, bannerConstraints) {
                final isNarrowBanner = bannerConstraints.maxWidth < 650;
                final bool hasActivePlan = patientVisits.any(
                  (pv) =>
                      pv.status != 'Cancelled' &&
                      pv.status != 'Completed' &&
                      pv.status != 'Verified',
                );

                return Row(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (ctx) {
                              final isTamil = Provider.of<LanguageProvider>(ctx).isTamil;
                              final rawPatientName = currentVisit.patientName ?? (isTamil ? 'நோயாளி' : 'Patient');
                              final formattedPatientName = TamilTransliterationHelper.formatName(
                                rawPatientName,
                                isTamil: isTamil,
                                showBoth: true,
                              );
                              return Text(
                                '${ctx.tr('daily_home_nursing_care_history', fallback: 'Daily Home Nursing Care History')} - $formattedPatientName',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${context.tr('patient_id_label', fallback: 'Patient ID')}: ${currentVisit.patientDisplayId ?? "N/A"} | ${context.tr('select_day_session_card_desc', fallback: 'Select a Day Session Card below to view full details.')}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasActivePlan) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.dangerColor,
                          side: const BorderSide(color: AppTheme.dangerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isNarrowBanner ? 10 : 14,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(
                          Icons.do_not_disturb_on_outlined,
                          size: 16,
                        ),
                        label: Text(
                          context.tr('stop_care_plan', fallback: 'Stop Care Plan'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isNarrowBanner ? 11.5 : 12.5,
                          ),
                        ),
                        onPressed: () =>
                            _showDiscontinueDialog(context, currentVisit),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          Text(
            context.tr('recorded_care_sessions_timeline', fallback: 'Recorded Care Sessions Timeline:'),
            style: const TextStyle(
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
              final dKey = _toNormalizedDateKey(v.scheduledDate);
              final dateIdx = distinctDates.indexOf(dKey);
              final dayNumber = dateIdx >= 0 ? dateIdx + 1 : (index + 1);
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cardBorderColor,
                    width: isDone || isCancelled ? 1.5 : 1.0,
                  ),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final isMobileCard = cardConstraints.maxWidth < 680;

                    final dayBadge = Container(
                      width: 58,
                      height: 58,
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
                            context.tr('day_caps', fallback: 'DAY'),
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
                              fontSize: 20,
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
                    );

                    final sessionHeader = Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${context.tr('day_label', fallback: 'Day')} $dayNumber ${context.tr('care_session', fallback: 'Care Session')} (${v.visitNumber})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            v.status == 'Verified'
                                ? context.tr('completed_status', fallback: 'COMPLETED')
                                : (v.status == 'Completed'
                                      ? context.tr('completed_status', fallback: 'COMPLETED')
                                      : (v.status == 'Cancelled'
                                            ? context.tr('stopped', fallback: 'STOPPED')
                                            : v.status.toUpperCase())),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );

                    final sessionDetails = Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${context.tr('scheduled_date_label', fallback: 'Date')}: ${_formatDateDDMMYYYY(v.scheduledDate)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (ctx) {
                                final isTamil = Provider.of<LanguageProvider>(ctx).isTamil;
                                final nurseFormatted = TamilTransliterationHelper.formatName(
                                  v.nurseName ?? (isTamil ? 'நர்ஸ்' : 'Nurse'),
                                  isTamil: isTamil,
                                  showBoth: true,
                                );
                                return Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${ctx.tr('assigned_nurse_label', fallback: 'Nurse')}: ',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.nurseColor,
                                        ),
                                      ),
                                      TextSpan(
                                        text: nurseFormatted,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.nurseColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (ctx) {
                                final isTamil = Provider.of<LanguageProvider>(ctx).isTamil;
                                final attenderFormatted = v.attenderName != null && v.attenderName!.isNotEmpty
                                    ? TamilTransliterationHelper.formatName(v.attenderName!, isTamil: isTamil, showBoth: true)
                                    : 'N/A';
                                final relation = v.attenderRelation ?? ctx.tr('attender_relation_label', fallback: 'Attender');
                                return Text(
                                  '${ctx.tr('verified_attender_label', fallback: 'Attender')}: $attenderFormatted ${v.attenderName != null && v.attenderName!.isNotEmpty ? "($relation)" : ""}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.black87,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 13,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${context.tr('total_bill', fallback: 'Total Bill:')} ₹${netAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    final actionButtons = ElevatedButton.icon(
                      style: AppTheme.primaryButton,
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: Text(
                        context.tr('view_day_details', params: {'day': '$dayNumber'}, fallback: 'View Day $dayNumber Details'),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedSummaryVisitId = v.id;
                        });
                        controller.fetchVisitDetails(v.id);
                      },
                    );

                    if (isMobileCard) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              dayBadge,
                              const SizedBox(width: 12),
                              Expanded(child: sessionHeader),
                            ],
                          ),
                          const SizedBox(height: 12),
                          sessionDetails,
                          const SizedBox(height: 14),
                          actionButtons,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        dayBadge,
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              sessionHeader,
                              const SizedBox(height: 8),
                              sessionDetails,
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        actionButtons,
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _toNormalizedDateKey(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    final clean = dateStr
        .trim()
        .split('T')[0]
        .split(' ')[0]
        .replaceAll('/', '-');
    final parts = clean.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        return "${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}";
      } else if (parts[2].length == 4) {
        return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
      }
    }
    return clean;
  }

  int _calculateVisitDayNumber(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final patientVisits = controller.visits
        .where((v) => v.patientId == visit.patientId)
        .toList();
    if (!patientVisits.any((v) => v.id == visit.id)) {
      patientVisits.add(visit);
    }
    final distinctDates = <String>[];
    for (final v in patientVisits) {
      final dKey = _toNormalizedDateKey(v.scheduledDate);
      if (dKey.isNotEmpty && !distinctDates.contains(dKey)) {
        distinctDates.add(dKey);
      }
    }
    distinctDates.sort();
    final currentKey = _toNormalizedDateKey(visit.scheduledDate);
    final dateIdx = distinctDates.indexOf(currentKey);
    return dateIdx >= 0 ? dateIdx + 1 : 1;
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
      return false;
    }
    try {
      final clean1 = d1.trim().split('T')[0].split(' ')[0].replaceAll('/', '-');
      final clean2 = d2.trim().split('T')[0].split(' ')[0].replaceAll('/', '-');

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
    } catch (_) {
      return false;
    }
  }

  // Overall Read-Only Summary View for Verified/Completed Home Visits (Step 2)
  Widget _buildCompletedVisitSummaryView(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final dayNumber = _calculateVisitDayNumber(visit, controller);

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
    final String rawPayStatus = invoice['payment_status'] ?? 'Unpaid';
    final isTamil = Provider.of<LanguageProvider>(context).isTamil;
    final String payStatus = rawPayStatus.toLowerCase() == 'paid'
        ? context.tr('paid', fallback: 'Paid')
        : (rawPayStatus.toLowerCase() == 'pending'
            ? context.tr('pending', fallback: 'Pending')
            : context.tr('unpaid', fallback: 'Unpaid'));

    final patientNameFormatted = TamilTransliterationHelper.formatName(
      visit.patientName ?? (isTamil ? 'நோயாளி' : 'Patient'),
      isTamil: isTamil,
      showBoth: true,
    );
    final nurseNameFormatted = TamilTransliterationHelper.formatName(
      visit.nurseName ?? (isTamil ? 'நர்ஸ்' : 'Nurse'),
      isTamil: isTamil,
      showBoth: true,
    );
    final attenderNameFormatted = visit.attenderName != null && visit.attenderName!.isNotEmpty
        ? TamilTransliterationHelper.formatName(visit.attenderName!, isTamil: isTamil, showBoth: true)
        : 'N/A';
    final attenderRelation = visit.attenderRelation ?? context.tr('attender_relation_label', fallback: 'Attender');
    final signedAt = visit.signedAt ?? context.tr('completed_status', fallback: 'Completed');
    final visitAddress = visit.visitAddress ?? 'N/A';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedSummaryVisitId != null) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSummaryVisitId = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('back_to_all_sessions_overview', fallback: 'Back to All Sessions Overview'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Status Banner (Verified / Cancelled / In-Progress)
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        size: isMobile ? 22 : 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                visit.status == 'Cancelled'
                                    ? context.tr('home_visit_care_discontinued_stopped', fallback: 'Home Visit Care Discontinued / Stopped')
                                    : '${context.tr('day_label', fallback: 'Day')} $dayNumber ${context.tr('care_session_verified_billed', fallback: 'Care Session Verified & Billed')} (${_formatDateDDMMYYYY(visit.scheduledDate)})',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: visit.status == 'Cancelled'
                                      ? AppTheme.dangerColor
                                      : Colors.green,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: visit.status == 'Cancelled'
                                      ? AppTheme.dangerColor
                                      : AppTheme.secondaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  visit.status == 'Verified'
                                      ? context.tr('completed_status', fallback: 'COMPLETED')
                                      : (visit.status == 'Cancelled'
                                          ? context.tr('stopped', fallback: 'STOPPED')
                                          : (visit.status == 'Completed'
                                              ? context.tr('completed_status', fallback: 'COMPLETED')
                                              : visit.status.toUpperCase())),
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
                          Text(
                            visit.status == 'Cancelled'
                                ? (visit.notes != null &&
                                          visit.notes!.isNotEmpty
                                      ? visit.notes!
                                      : context.tr('care_plan_stopped_desc', fallback: 'Care plan stopped/discontinued for this patient.'))
                                : context.tr(
                                    'session_locked_billed_msg',
                                    params: {'date': _formatDateDDMMYYYY(visit.scheduledDate)},
                                    fallback: 'All vitals, nursing procedures, medicines, evidence & attender signature are locked & billed for ${_formatDateDDMMYYYY(visit.scheduledDate)}. Execute Visit unlocks at 7:00 AM on the next scheduled date.',
                                  ),
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
              const SizedBox(height: 20),

              // Billing & Invoice Card Banner
              if (visit.invoice != null) ...[
                Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: AppTheme.primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${context.tr('invoice_num_label', fallback: 'Invoice #:')} $invoiceNum',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      Text(
                                        '${context.tr('payment_status_label', fallback: 'Status:')} $payStatus | ${context.tr('total_amount_label', fallback: 'Total:')} ₹${netAmount.toStringAsFixed(2)}',
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
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: AppTheme.dangerButton,
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  context.tr('view_itemized_invoice', fallback: 'View Itemized Invoice'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => HomeVisitInvoiceDialog(
                                      invoiceData: {'invoice': visit.invoice},
                                      visit: visit,
                                      onCloseAndComplete: () {
                                        _handleLeave();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
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
                                      '${context.tr('invoice_num_label', fallback: 'Invoice #:')} $invoiceNum',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${context.tr('payment_status_label', fallback: 'Payment Status:')} $payStatus | ${context.tr('total_amount_label', fallback: 'Total Amount:')} ₹${netAmount.toStringAsFixed(2)}',
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
                              style: AppTheme.dangerButton,
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: Text(
                                context.tr('view_itemized_invoice', fallback: 'View Itemized Invoice'),
                                style: const TextStyle(
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
                                    onCloseAndComplete: () {
                                      _handleLeave();
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
              ],

              // Patient & Attender Overview Card
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                      context.tr('patient_attender_overview', fallback: 'Patient & Attender Overview'),
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    if (isMobile) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _summaryTile(
                              context.tr('patient_name_label', fallback: 'Patient Name'),
                              patientNameFormatted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryTile(
                              context.tr('patient_id_label', fallback: 'Patient ID'),
                              visit.patientDisplayId ?? 'N/A',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _summaryTile(
                              context.tr('scheduled_date_label', fallback: 'Scheduled Date'),
                              _formatDateDDMMYYYY(visit.scheduledDate),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryTile(
                              context.tr('assigned_nurse_label', fallback: 'Assigned Nurse'),
                              nurseNameFormatted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _summaryTile(
                              context.tr('verified_attender_label', fallback: 'Verified Attender'),
                              attenderNameFormatted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryTile(
                              context.tr('attender_relation_label', fallback: 'Attender Relation'),
                              attenderRelation,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _summaryTile(
                              context.tr('signed_at_label', fallback: 'Signed At'),
                              signedAt,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryTile(
                              context.tr('visit_address_label', fallback: 'Visit Address'),
                              visitAddress,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _summaryTile(
                              context.tr('patient_name_label', fallback: 'Patient Name'),
                              patientNameFormatted,
                            ),
                          ),
                          Expanded(
                            child: _summaryTile(
                              context.tr('patient_id_label', fallback: 'Patient ID'),
                              visit.patientDisplayId ?? 'N/A',
                            ),
                          ),
                          Expanded(
                            child: _summaryTile(
                              context.tr('scheduled_date_label', fallback: 'Scheduled Date'),
                              _formatDateDDMMYYYY(visit.scheduledDate),
                            ),
                          ),
                          Expanded(
                            child: _summaryTile(
                              context.tr('assigned_nurse_label', fallback: 'Assigned Nurse'),
                              nurseNameFormatted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryTile(
                              context.tr('verified_attender_label', fallback: 'Verified Attender'),
                              attenderNameFormatted,
                            ),
                          ),
                          Expanded(
                            child: _summaryTile(
                              context.tr('attender_relation_label', fallback: 'Attender Relation'),
                              attenderRelation,
                            ),
                          ),
                          Expanded(
                            child: _summaryTile(
                              context.tr('signed_at_label', fallback: 'Signed At'),
                              signedAt,
                            ),
                          ),
                          Expanded(
                            child: _summaryTile(
                              context.tr('visit_address_label', fallback: 'Visit Address'),
                              visitAddress,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hourly Vitals History Log Table
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                      '${context.tr('day_label', fallback: 'Day')} $dayNumber ${context.tr('recorded_hourly_vitals_log', fallback: 'Recorded Hourly Vitals Log')}',
                      Icons.monitor_heart_outlined,
                    ),
                    const SizedBox(height: 16),
                    if (sessionVitals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          context.tr('no_vitals_recorded_day', params: {'day': '$dayNumber', 'date': _formatDateDDMMYYYY(visit.scheduledDate)}, fallback: 'No vitals recorded for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).'),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 580),
                            child: Table(
                              border: TableBorder.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  children: [
                                    _tableHeader(context.tr('date_time', fallback: 'Date & Time')),
                                    _tableHeader(context.tr('bp_unit', fallback: 'BP (mmHg)')),
                                    _tableHeader(context.tr('pulse_unit', fallback: 'Pulse (bpm)')),
                                    _tableHeader(context.tr('spo2_unit', fallback: 'SpO2 (%)')),
                                    _tableHeader(context.tr('temp_unit', fallback: 'Temp (°F)')),
                                    _tableHeader(context.tr('sugar_unit', fallback: 'Sugar (mg/dL)')),
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
                                                  final day = dt.day
                                                      .toString()
                                                      .padLeft(2, '0');
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
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nursing Care Activities Summary
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                      '${context.tr('day_label', fallback: 'Day')} $dayNumber ${context.tr('nursing_care_procedure_records', fallback: 'Nursing Care & Procedure Records')}',
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
                          context.tr('no_nursing_care_recorded_day', params: {'day': '$dayNumber', 'date': _formatDateDDMMYYYY(visit.scheduledDate)}, fallback: 'No nursing care notes or dressing procedures recorded for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).'),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
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
                                    '${context.tr('recorded_on_label', fallback: 'Recorded on:')} ${_formatRecordedAt(care.createdAt)}',
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
                                _detailRow(context.tr('nursing_notes_label', fallback: 'Nursing Notes'), care.nursingNotes!),
                              if (care.dressingProcedures != null &&
                                  care.dressingProcedures!.isNotEmpty)
                                _detailRow(
                                  context.tr('dressing_procedure_label', fallback: 'Dressing Procedure'),
                                  context.translateProcedure(care.dressingProcedures!),
                                ),
                              if (care.nailTrimmingDone)
                                _detailRow(
                                  context.tr('nail_trimming_hygiene_label', fallback: 'Nail Trimming / Hygiene Care'),
                                  context.tr('completed_status', fallback: 'Completed'),
                                ),
                              if (care.otherCareActivities != null &&
                                  care.otherCareActivities!.isNotEmpty)
                                _detailRow(
                                  context.tr('other_care_activities_label', fallback: 'Other Care Activities'),
                                  care.otherCareActivities!,
                                ),
                            ],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Administered Medicines & Consumables Summary
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                      '${context.tr('day_label', fallback: 'Day')} $dayNumber ${context.tr('administered_medicines_consumables', fallback: 'Administered Medicines & Consumables')}',
                      Icons.medication_liquid_outlined,
                    ),
                    const SizedBox(height: 16),
                    if (sessionMedicines.isEmpty && sessionConsumables.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          context.tr('no_meds_consumables_recorded_day', params: {'day': '$dayNumber', 'date': _formatDateDDMMYYYY(visit.scheduledDate)}, fallback: 'No medicines or consumables administered for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).'),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else ...[
                      if (sessionMedicines.isNotEmpty) ...[
                        Text(
                          context.tr('medicines_administered_label', fallback: 'Medicines Administered:'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final m in sessionMedicines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: m.medicineType == 'STAT'
                                          ? const Color(0xFFFEEBC8)
                                          : const Color(0xFFEBF8FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      m.medicineType == 'Regular' ? context.tr('regular_badge', fallback: 'Regular') : (m.medicineType == 'STAT' ? context.tr('stat_badge', fallback: 'STAT') : m.medicineType),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: m.medicineType == 'STAT'
                                            ? const Color(0xFFC05621)
                                            : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${context.translateMedicine(m.medicineName)}${m.dosage != null && m.dosage!.isNotEmpty ? " (${m.dosage})" : ""} - ${context.tr('qty_prefix', fallback: 'Qty:')} ${m.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          softWrap: true,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${context.tr('freq_prefix', fallback: 'Freq:')} ${m.frequency ?? "N/A"} | ${context.tr('duration_prefix', fallback: 'Duration:')} ${m.duration ?? "N/A"}${m.givenTime != null && m.givenTime!.isNotEmpty ? " | ${context.tr('given_time_prefix', fallback: 'Given Time:')} ${m.givenTime}" : ""}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildDailyDoseChecklist(
                                          medicine: m,
                                          currentDayNumber: dayNumber,
                                          visit: visit,
                                          controller: controller,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      if (sessionConsumables.isNotEmpty) ...[
                        Text(
                          context.tr('consumables_used_label', fallback: 'Consumables Used:'),
                          style: const TextStyle(
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
                              '• ${context.translateConsumable(c.itemName)} - ${context.tr('qty_prefix', fallback: 'Qty:')} ${c.quantityUsed} | ₹${(c.unitPrice * c.quantityUsed).toStringAsFixed(2)}${(c.createdAt != null && c.createdAt!.isNotEmpty) ? " (${c.createdAt!.split("T")[0]})" : ""}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Timestamped Photo Evidence Gallery
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                      '${context.tr('day_label', fallback: 'Day')} $dayNumber ${context.tr('timestamped_photo_evidence_gallery', fallback: 'Timestamped Photo Evidence Gallery')}',
                      Icons.insert_photo_outlined,
                    ),
                    const SizedBox(height: 16),
                    if (sessionPhotos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          context.tr('no_photos_uploaded_day', params: {'day': '$dayNumber', 'date': _formatDateDDMMYYYY(visit.scheduledDate)}, fallback: 'No timestamped photo evidence uploaded for Day $dayNumber (${_formatDateDDMMYYYY(visit.scheduledDate)}).'),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile
                              ? 2
                              : (constraints.maxWidth < 1100 ? 3 : 5),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: sessionPhotos.length,
                        itemBuilder: (context, idx) {
                          final p = sessionPhotos[idx];
                          return InkWell(
                            onTap: () =>
                                _showFullImagePreviewDialog(context, p),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
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
                                      p.category != null ? context.tr('evidence_label', fallback: p.category!) : context.tr('evidence_label', fallback: 'Evidence'),
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
      },
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
          color: AppTheme.secondaryColor,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
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
          );
        },
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
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isTamil = Localizations.localeOf(context).languageCode == 'ta';
          final patientDisplayName = TamilTransliterationHelper.formatName(
            visit.patientName ?? '',
            isTamil: isTamil,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.do_not_disturb_on_outlined,
                    color: AppTheme.dangerColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('stop_home_visit_care_title', fallback: 'Stop Home Visit Care'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      Text(
                        context.tr('terminate_cancel_care_plan', fallback: 'Terminate & Cancel Care Plan'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.dangerColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr(
                                  'stop_care_plan_warning',
                                  fallback: 'Filling this form will stop all further home visit care for {patient} and cancel the active care plan.',
                                  params: {'patient': patientDisplayName.isNotEmpty ? patientDisplayName : "Patient #${visit.patientId}"},
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9F1239),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('select_reason_to_stop', fallback: 'Select Reason to Stop Care *'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CustomDropdownSearch(
                        label: '',
                        hint: context.tr('select_reason_hint', fallback: 'Select Reason'),
                        dropdownMap: {
                          'Patient Cured / Fully Recovered':
                              context.tr('reason_cured', fallback: 'Patient Cured / Fully Recovered'),
                          'Patient / Attender Requested Discontinuation':
                              context.tr('reason_patient_requested', fallback: 'Patient / Attender Requested Discontinuation'),
                          'Admitted to Hospital / IPD Care':
                              context.tr('reason_admitted_hospital', fallback: 'Admitted to Hospital / IPD Care'),
                          'Doctor Advice / Care Plan Completed':
                              context.tr('reason_doctor_advice', fallback: 'Doctor Advice / Care Plan Completed'),
                          'Patient Relocated / Not Reachable':
                              context.tr('reason_relocated', fallback: 'Patient Relocated / Not Reachable'),
                          'Financial / Billing Constraints':
                              context.tr('reason_financial', fallback: 'Financial / Billing Constraints'),
                          'Other Reason':
                              context.tr('reason_other', fallback: 'Other Reason'),
                        },
                        value: selectedReason,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr('remarks_nurse_handover_notes', fallback: 'Remarks / Nurse Handover Notes (Optional):'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 3,
                        maxLength: 250,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,/#\-\(\):;%+]'),
                          ),
                          LengthLimitingTextInputFormatter(250),
                        ],
                        decoration: AppTheme.standardInputDecoration(
                          hintText: context.tr('stop_notes_hint', fallback: 'Enter details (e.g., patient recovered after 5 days of care and attender requested stop)...'),
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final clean = val.trim();
                            if (clean.length > 250) {
                              return 'Notes cannot exceed 250 characters';
                            }
                            if (!RegExp(r'[a-zA-Z]').hasMatch(clean)) {
                              return 'Notes must contain alphabetical characters if provided';
                            }
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
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  context.tr('go_back', fallback: 'Go Back'),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton.icon(
                style: AppTheme.dangerButton,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  isSubmitting
                      ? context.tr('stopping_care', fallback: 'Stopping Care...')
                      : context.tr('confirm_stop_care', fallback: 'Confirm Stop Care'),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (formKey.currentState != null &&
                            !formKey.currentState!.validate()) {
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        final homeVisitCtrl = Provider.of<HomeVisitController>(
                          context,
                          listen: false,
                        );
                        final success = await homeVisitCtrl.cancelVisit(
                          visit.id,
                          selectedReason,
                          notesCtrl.text.trim(),
                        );
                        setDialogState(() => isSubmitting = false);
                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                        if (success && context.mounted) {
                          AppNotification.showSuccess(
                            context,
                            'Home visit care plan (${visit.visitNumber}) for ${patientDisplayName.isNotEmpty ? patientDisplayName : "Patient"} stopped and cancelled successfully.',
                          );
                          _handleLeave();
                        }
                      },
              ),
            ],
          );
        },
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

  bool _isRecordedToday(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return false;
    try {
      final formatted = dateStr.trim().replaceAll(' ', 'T');
      final dt = DateTime.parse(formatted);
      final local = dt.isUtc ? dt.toLocal() : dt;
      final now = DateTime.now();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    } catch (_) {
      return false;
    }
  }

  String _formatTimeGap(
    HomeVisitVitals current,
    List<HomeVisitVitals> allVitals,
  ) {
    if (current.recordedAt == null || current.recordedAt!.isEmpty) return '--';
    try {
      final rawFormatted = current.recordedAt!.trim().replaceAll(' ', 'T');
      final dtCurrent = DateTime.parse(rawFormatted).toLocal();

      DateTime? dtPrevious;
      for (var v in allVitals) {
        if (v.recordedAt != null && v.recordedAt!.isNotEmpty) {
          try {
            final vRaw = v.recordedAt!.trim().replaceAll(' ', 'T');
            final dt = DateTime.parse(vRaw).toLocal();
            // Only consider vitals recorded on the same day as current
            if (dt.year == dtCurrent.year &&
                dt.month == dtCurrent.month &&
                dt.day == dtCurrent.day) {
              if (dt.isBefore(dtCurrent)) {
                if (dtPrevious == null || dt.isAfter(dtPrevious)) {
                  dtPrevious = dt;
                }
              }
            }
          } catch (_) {}
        }
      }

      if (dtPrevious == null) {
        return context.tr('initial_entry', fallback: 'Initial Entry');
      }

      final diff = dtCurrent.difference(dtPrevious);
      if (diff.isNegative) return '--';

      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      final isTamil = AppLocalizations.of(context).locale.languageCode == 'ta';

      if (hours > 0 && minutes > 0) {
        return isTamil ? '+$hours மணி ${minutes} நிமி' : '+$hours hr ${minutes} mins';
      } else if (hours > 0) {
        return isTamil ? '+$hours மணி' : '+$hours hr${hours > 1 ? "s" : ""}';
      } else if (minutes > 0) {
        return isTamil ? '+$minutes நிமி' : '+$minutes min${minutes > 1 ? "s" : ""}';
      } else {
        return isTamil ? '< 1 நிமிடம்' : '< 1 min';
      }
    } catch (_) {
      return '--';
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (timeStr.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, size: 11, color: Colors.grey.shade600),
              const SizedBox(width: 3),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {String? subtitle}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1E293B), size: 22),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Inter',
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ],
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
    if (points.isEmpty) return;

    final Paint paint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      } else if (current != null && next == null) {
        canvas.drawCircle(current, 1.5, paint);
      }
    }

    if (points.length == 1 && points[0] != null) {
      canvas.drawCircle(points[0]!, 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
