import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
  final TextEditingController _medPriceCtrl = TextEditingController(
    text: '50.00',
  );

  // Consumable Form Controllers
  final TextEditingController _consNameCtrl = TextEditingController();
  final TextEditingController _consQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _consPriceCtrl = TextEditingController(
    text: '20.00',
  );

  List<String> _dbMedicines = [];
  List<String> _dbConsumables = [];

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
    _medPriceCtrl.text = '50.00';
  }

  void _clearConsForm() {
    _consNameCtrl.clear();
    _consQtyCtrl.text = '1';
    _consPriceCtrl.text = '20.00';
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedPhotoName = file.name;
          _selectedPhotoBytes = file.bytes;
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
    });
  }

  void _clearSignatureForm() {
    _attenderNameCtrl.clear();
    _attenderRelationCtrl.clear();
    setState(() => _signaturePoints.clear());
  }

  Future<void> _fetchInventoryCatalogs() async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3001/api';
    try {
      final medRes = await ApiService.get('$baseUrl/inventory/medicine-catalog');
      final medBody = ApiService.decodeJsonResponse(medRes);
      if (medBody['success'] == true && medBody['data'] != null) {
        final List list = medBody['data'];
        final medNames = list.map((e) => e['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        if (medNames.isNotEmpty && mounted) {
          setState(() {
            _dbMedicines = medNames.cast<String>();
          });
        }
      }
    } catch (_) {}

    try {
      final consRes = await ApiService.get('$baseUrl/inventory/consumables-catalog');
      final consBody = ApiService.decodeJsonResponse(consRes);
      if (consBody['success'] == true && consBody['data'] != null) {
        final List list = consBody['data'];
        final consNames = list.map((e) => e['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
        if (consNames.isNotEmpty && mounted) {
          setState(() {
            _dbConsumables = consNames.cast<String>();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final ctrl = Provider.of<HomeVisitController>(context, listen: false);
    await ctrl.fetchVisitDetails(widget.visitId);
    _fetchInventoryCatalogs();
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
    final bool hasStar = label.endsWith(' *');
    final String baseText = hasStar
        ? label.substring(0, label.length - 2)
        : label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: RichText(
        text: TextSpan(
          text: baseText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontFamily: 'Inter',
          ),
          children: [
            if (hasStar)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppTheme.dangerColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home Visit Care - ${visit.visitNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        'Patient: ${visit.patientName ?? "N/A"} (${visit.patientDisplayId ?? ""})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
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
                        icon: Icon(Icons.draw_outlined),
                        text: 'Attender Signature',
                      ),
                    ],
                  ),
          ),
          body: isCompletedOrVerified
              ? (_selectedSummaryVisitId == null
                    ? _buildDailySessionsOverview(visit, controller)
                    : _buildCompletedVisitSummaryView(
                        controller.visits.firstWhere(
                          (v) => v.id == _selectedSummaryVisitId,
                          orElse: () => visit,
                        ),
                        controller,
                      ))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildKitTab(visit),
                    _buildVitalsTab(visit, controller),
                    _buildCareTab(visit, controller),
                    _buildMedsAndConsumablesTab(visit, controller),
                    _buildPhotosTab(visit, controller),
                    _buildSignatureTab(visit, controller),
                  ],
                ),
        );
      },
    );
  }

  // 1. Kit Overview Tab
  Widget _buildKitTab(HomeVisitModel visit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Medical Devices, Medicines & Supplies Carried in Kit',
            Icons.shopping_bag_outlined,
          ),
          const SizedBox(height: 16),
          if (visit.carriedItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Default kit loaded: BP Apparatus, Stethoscope, Glucometer, Thermometer, Pulse Oximeter, Dressing Kit, Bandages & Antiseptics.',
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

  // 2. Vitals Tab with 9 AM - 6 PM Hourly Slot Cards (Starting 9:30 AM)
  Widget _buildVitalsTab(HomeVisitModel visit, HomeVisitController controller) {
    final status = visit.vitalsScheduleStatus;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                'Hourly Vitals Monitoring Cards (9:00 AM - 6:00 PM)',
                Icons.monitor_heart_outlined,
              ),
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.primaryColor,
                ),
                tooltip: 'Configure Vitals Schedule',
                onPressed: () => _showVitalsScheduleConfigDialog(
                  context,
                  controller,
                  status,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Schedule Status Banner
          _buildVitalsScheduleStatusBanner(status),
          const SizedBox(height: 20),

          // 9 to 6 Hourly Vitals Entry Slot Cards
          _buildHourlyVitalsCardsList(visit, controller),
          const SizedBox(height: 32),

          // Hourly Vitals History Log Table
          _buildSectionHeader('Hourly Vitals History Log', Icons.history),
          const SizedBox(height: 16),
          _buildVitalsHistoryTable(visit.vitalsHistory),
        ],
      ),
    );
  }

  // 9:00 AM to 6:00 PM Hourly Slots Cards List (Starting 9:30 AM)
  Widget _buildHourlyVitalsCardsList(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final now = DateTime.now();

    final List<Map<String, dynamic>> hourlySlots = [
      {'label': '9:30 AM', 'hour': 9, 'minute': 30},
      {'label': '10:30 AM', 'hour': 10, 'minute': 30},
      {'label': '11:30 AM', 'hour': 11, 'minute': 30},
      {'label': '12:30 PM', 'hour': 12, 'minute': 30},
      {'label': '1:30 PM', 'hour': 13, 'minute': 30},
      {'label': '2:30 PM', 'hour': 14, 'minute': 30},
      {'label': '3:30 PM', 'hour': 15, 'minute': 30},
      {'label': '4:30 PM', 'hour': 16, 'minute': 30},
      {'label': '5:30 PM', 'hour': 17, 'minute': 30},
    ];

    return Column(
      children: List.generate(hourlySlots.length, (index) {
        final slot = hourlySlots[index];
        final String slotTime = slot['label'];
        final int slotHour = slot['hour'];
        final int slotMinute = slot['minute'];

        final slotDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          slotHour,
          slotMinute,
        );
        final slotWindowStart = slotDateTime.subtract(
          const Duration(minutes: 15),
        );
        final slotWindowEnd = slotDateTime.add(const Duration(minutes: 45));

        // Match recorded vitals entry to this specific time window
        HomeVisitVitals? recordedVital;
        for (final v in visit.vitalsHistory) {
          if (v.recordedAt != null && v.recordedAt!.isNotEmpty) {
            try {
              final formatted = v.recordedAt!.trim().replaceAll(' ', 'T');
              final dt = DateTime.parse(formatted);
              final recDate = dt.isUtc ? dt.toLocal() : dt;
              final diffMins = recDate.difference(slotDateTime).inMinutes.abs();
              if (diffMins <= 45 || (recDate.isAfter(slotWindowStart) && recDate.isBefore(slotWindowEnd))) {
                recordedVital = v;
                break;
              }
            } catch (_) {}
          }
        }

        final bool isRecorded = recordedVital != null;
        final bool isOpenNow =
            now.isAfter(slotWindowStart) && now.isBefore(slotWindowEnd);
        final bool isPastNotFilled = !isRecorded && now.isAfter(slotWindowEnd);

        Color cardBorder = const Color(0xFFE2E8F0);
        Color headerBg = const Color(0xFFF8FAFC);
        Color badgeBg = Colors.grey.shade200;
        Color badgeText = Colors.grey.shade700;
        String badgeStatus = 'LOCKED';
        IconData statusIcon = Icons.lock_clock;

        if (isRecorded) {
          cardBorder = const Color(0xFFBBF7D0);
          headerBg = const Color(0xFFF0FDF4);
          badgeBg = AppTheme.secondaryColor;
          badgeText = Colors.white;
          badgeStatus = 'RECORDED';
          statusIcon = Icons.check_circle;
        } else if (isOpenNow) {
          cardBorder = AppTheme.primaryColor;
          headerBg = AppTheme.primaryColor.withValues(alpha: 0.06);
          badgeBg = Colors.orange;
          badgeText = Colors.white;
          badgeStatus = 'OPEN FOR ENTRY';
          statusIcon = Icons.alarm_on;
        } else if (isPastNotFilled) {
          cardBorder = const Color(0xFFFED7AA);
          headerBg = const Color(0xFFFFF7ED);
          badgeBg = const Color(0xFFEA580C);
          badgeText = Colors.white;
          badgeStatus = 'NOT FILLED';
          statusIcon = Icons.remove_circle_outline;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cardBorder,
              width: isRecorded || isOpenNow ? 1.5 : 1.0,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      color: isRecorded
                          ? AppTheme.secondaryColor
                          : (isOpenNow
                                ? AppTheme.primaryColor
                                : (isPastNotFilled
                                      ? const Color(0xFFEA580C)
                                      : Colors.grey)),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Hourly Vitals — $slotTime Slot',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeStatus,
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Card Content Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: isRecorded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _buildVitalChip(
                                'Blood Pressure',
                                '${recordedVital.systolicBp ?? "--"}/${recordedVital.diastolicBp ?? "--"} mmHg',
                                Icons.speed,
                              ),
                              _buildVitalChip(
                                'Pulse Rate',
                                recordedVital.pulseRate != null
                                    ? '${recordedVital.pulseRate} bpm'
                                    : '--',
                                Icons.favorite,
                              ),
                              _buildVitalChip(
                                'Body Temp',
                                recordedVital.temperature != null
                                    ? '${recordedVital.temperature} °F'
                                    : '--',
                                Icons.thermostat,
                              ),
                              _buildVitalChip(
                                'SpO₂ Level',
                                recordedVital.spo2 != null
                                    ? '${recordedVital.spo2}%'
                                    : '--',
                                Icons.air,
                              ),
                              _buildVitalChip(
                                'Blood Sugar',
                                recordedVital.bloodSugar != null
                                    ? '${recordedVital.bloodSugar} mg/dL'
                                    : '--',
                                Icons.water_drop,
                              ),
                              if (recordedVital.weight != null ||
                                  recordedVital.height != null)
                                _buildVitalChip(
                                  'Weight/Height',
                                  '${recordedVital.weight ?? "--"} kg / ${recordedVital.height ?? "--"} cm',
                                  Icons.monitor_weight,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              style: AppTheme.outlinedButton,
                              icon: const Icon(Icons.edit, size: 14),
                              label: Text('Update $slotTime Entry'),
                              onPressed: () => _showRecordVitalsModal(
                                context,
                                visit,
                                controller,
                                slotTime,
                                recordedVital,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              isOpenNow
                                  ? 'Active monitoring window open now. Click to record $slotTime vital signs.'
                                  : (isPastNotFilled
                                        ? 'Vitals entry window closed for $slotTime slot (Not recorded).'
                                        : 'Locked. Scheduled for $slotTime slot.'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isOpenNow
                                    ? AppTheme.primaryColor
                                    : (isPastNotFilled
                                          ? const Color(0xFFC2410C)
                                          : Colors.grey.shade600),
                                fontWeight: isOpenNow || isPastNotFilled
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isOpenNow)
                            ElevatedButton.icon(
                              style: AppTheme.primaryButton,
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Record $slotTime Vitals'),
                              onPressed: () => _showRecordVitalsModal(
                                context,
                                visit,
                                controller,
                                slotTime,
                                null,
                              ),
                            )
                          else if (isPastNotFilled)
                            OutlinedButton.icon(
                              style: AppTheme.outlinedButton,
                              icon: const Icon(Icons.schedule, size: 16),
                              label: const Text('+ Record Missed Vitals'),
                              onPressed: () => _showRecordVitalsModal(
                                context,
                                visit,
                                controller,
                                slotTime,
                                null,
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.grey.shade600,
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.lock_clock, size: 16),
                              label: Text('Locked Until $slotTime'),
                              onPressed: null,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      }),
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
                                if (existingVital != null) 'vitals_id': existingVital.id,
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
                      : Text(existingVital != null ? 'Update $slotTime Vitals' : 'Save $slotTime Vitals'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyCare,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Nursing Notes & Care Activities',
              Icons.edit_note_outlined,
            ),
            const SizedBox(height: 20),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
                                    'other_care_activities':
                                        _otherCareCtrl.text,
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
            const SizedBox(height: 24),

            // Saved Nursing Care History Log
            if (visit.careActivities != null) ...[
              _buildSectionHeader(
                'Logged Nursing Care & Procedures',
                Icons.history,
              ),
              const SizedBox(height: 16),
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
                    if (visit.careActivities!.nursingNotes != null &&
                        visit.careActivities!.nursingNotes!.isNotEmpty) ...[
                      const Text(
                        'Nursing Notes:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        visit.careActivities!.nursingNotes!,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (visit.careActivities!.dressingProcedures != null &&
                        visit
                            .careActivities!
                            .dressingProcedures!
                            .isNotEmpty) ...[
                      const Text(
                        'Dressing Procedures:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        visit.careActivities!.dressingProcedures!,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        const Text(
                          'Nail Trimming: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Chip(
                          label: Text(
                            visit.careActivities!.nailTrimmingDone
                                ? 'Completed'
                                : 'Not Performed',
                            style: TextStyle(
                              color: visit.careActivities!.nailTrimmingDone
                                  ? Colors.green.shade800
                                  : Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor:
                              visit.careActivities!.nailTrimmingDone
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                        ),
                      ],
                    ),
                    if (visit.careActivities!.otherCareActivities != null &&
                        visit
                            .careActivities!
                            .otherCareActivities!
                            .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Other Activities:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        visit.careActivities!.otherCareActivities!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 4. Medicines & Consumables Tab
  Widget _buildMedsAndConsumablesTab(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final activeMedicines = visit.medicines.where((m) {
      if (m.administeredAt == null || m.administeredAt!.isEmpty) return true;
      try {
        final formatted = m.administeredAt!.trim().replaceAll(' ', 'T');
        final dt = DateTime.parse(formatted);
        final recDate = dt.isUtc ? dt.toLocal() : dt;
        final medDateStr = "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
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
        final consDateStr = "${recDate.year}-${recDate.month.toString().padLeft(2, '0')}-${recDate.day.toString().padLeft(2, '0')}";
        return consDateStr == todayStr || consDateStr == visit.scheduledDate;
      } catch (_) {
        return true;
      }
    }).toList();

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

          // Administered Medicines Section
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
                  'Medicines Administered During Visit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomDropdownSearch(
                        label: '',
                        hint: 'Medicine Name (e.g. Paracetamol)',
                        dropdownItems: _dbMedicines.isNotEmpty ? _dbMedicines : _defaultMedicines,
                        value: _medNameCtrl.text.isNotEmpty ? _medNameCtrl.text : null,
                        onChanged: (val) {
                          setState(() {
                            _medNameCtrl.text = val ?? '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _medDosageCtrl,
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'Dosage (500mg)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _medQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'Qty',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _medPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'Unit Price ₹',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: AppTheme.secondaryButton,
                      onPressed: () async {
                        if (_medNameCtrl.text.trim().isEmpty) return;
                        final success = await controller
                            .submitMedicine(visit.id, {
                              'medicine_name': _medNameCtrl.text.trim(),
                              'dosage': _medDosageCtrl.text.trim(),
                              'route': 'Oral',
                              'quantity': int.tryParse(_medQtyCtrl.text) ?? 1,
                              'unit_price':
                                  double.tryParse(_medPriceCtrl.text) ?? 0.0,
                            });
                        if (success) {
                          _clearMedForm();
                        }
                      },
                      child: const Text('Add Med'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (activeMedicines.isEmpty)
                  const Text(
                    'No medicines logged yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeMedicines.length,
                    itemBuilder: (context, idx) {
                      final m = activeMedicines[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.medication,
                          color: AppTheme.primaryColor,
                        ),
                        title: Text(
                          '${m.medicineName} (${m.dosage})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Qty: ${m.quantity} • Unit Price: ₹${m.unitPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          'Subtotal: ₹${(m.quantity * m.unitPrice).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Consumables Section
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
                  'Consumables Used During Visit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Autocomplete<String>(
                        initialValue: TextEditingValue(text: _consNameCtrl.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = textEditingValue.text.toLowerCase();
                          final items = _dbConsumables.isNotEmpty ? _dbConsumables : _defaultConsumables;
                          if (query.isEmpty) return items;
                          return items.where((item) => item.toLowerCase().contains(query));
                        },
                        onSelected: (String selection) {
                          setState(() {
                            _consNameCtrl.text = selection;
                          });
                        },
                        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                          textController.addListener(() {
                            _consNameCtrl.text = textController.text;
                          });
                          return TextFormField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: AppTheme.standardInputDecoration(
                              hintText: 'Consumable Item (e.g. Sterile Bandage, Syringe)',
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      title: Text(option, style: const TextStyle(fontSize: 13)),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _consQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'Qty',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _consPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: AppTheme.standardInputDecoration(
                          hintText: 'Unit Price ₹',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: AppTheme.secondaryButton,
                      onPressed: () async {
                        if (_consNameCtrl.text.trim().isEmpty) return;
                        final success = await controller
                            .submitConsumable(visit.id, {
                              'item_name': _consNameCtrl.text.trim(),
                              'quantity_used':
                                  int.tryParse(_consQtyCtrl.text) ?? 1,
                              'unit_price':
                                  double.tryParse(_consPriceCtrl.text) ?? 0.0,
                            });
                        if (success) {
                          _clearConsForm();
                        }
                      },
                      child: const Text('Add Consumable'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (activeConsumables.isEmpty)
                  const Text(
                    'No consumable items logged yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeConsumables.length,
                    itemBuilder: (context, idx) {
                      final c = activeConsumables[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.clean_hands,
                          color: AppTheme.secondaryColor,
                        ),
                        title: Text(
                          c.itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Qty Used: ${c.quantityUsed} • Unit Price: ₹${c.unitPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          'Subtotal: ₹${(c.quantityUsed * c.unitPrice).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Photo Category *'),
                          CustomDropdownSearch(
                            label: '',
                            hint: 'Select Photo Category',
                            dropdownMap: const {
                              'Dressing Pre-Procedure':
                                  'Pre-Dressing Wound Photo',
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
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Column(
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
                                color: _selectedPhotoName != null
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedPhotoName != null
                                      ? AppTheme.secondaryColor
                                      : const Color(0xFFCBD5E0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedPhotoName != null
                                        ? Icons.check_circle
                                        : Icons.cloud_upload_outlined,
                                    color: _selectedPhotoName != null
                                        ? AppTheme.secondaryColor
                                        : AppTheme.primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedPhotoName != null
                                          ? 'Selected: $_selectedPhotoName'
                                          : 'Click to Browse & Upload Image (JPG, PNG)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _selectedPhotoName != null
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: _selectedPhotoName != null
                                            ? Colors.green.shade800
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
                                      color: AppTheme.primaryColor,
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
                          _buildLabel('Photo Notes / Caption (Optional)'),
                          TextFormField(
                            controller: _photoCaptionCtrl,
                            decoration: AppTheme.standardInputDecoration(
                              hintText:
                                  'e.g. Wound cleaned, dressing applied intact...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: SizedBox(
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
                            _isUploadingPhoto
                                ? 'Uploading...'
                                : 'Upload Photo Evidence',
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
                      ),
                    ),
                  ],
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
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.95,
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

                                      // Category Badge Overlay
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            p.category ?? 'Evidence',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
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
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.category ?? 'Photo Evidence',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.primaryColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (p.caption != null &&
                                        p.caption!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        p.caption!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                          fontStyle: FontStyle.italic,
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
                                  v.status.toUpperCase(),
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
                                'Date: ${v.scheduledDate}',
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

  // Overall Read-Only Summary View for Verified/Completed Home Visits (Step 2)
  Widget _buildCompletedVisitSummaryView(
    HomeVisitModel visit,
    HomeVisitController controller,
  ) {
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
                                : 'Home Visit Verified & Completed Today',
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
                              visit.status.toUpperCase(),
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
                            : 'All vitals, nursing procedures, medicines, evidence & attender signature are locked & billed for ${visit.scheduledDate}. Execute Visit unlocks at 8:50 AM (10 minutes before 9:00 AM duty time) on the next scheduled date.',
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
                        visit.scheduledDate,
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
          if (visit.vitalsHistory.isNotEmpty) ...[
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
                    'Recorded Hourly Vitals Log',
                    Icons.monitor_heart_outlined,
                  ),
                  const SizedBox(height: 16),
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
                        for (final v in visit.vitalsHistory)
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
          ],

          // Nursing Care Activities Summary
          if (visit.careActivities != null) ...[
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
                    'Nursing Care & Procedure Records',
                    Icons.edit_note_outlined,
                  ),
                  const SizedBox(height: 16),
                  if (visit.careActivities!.nursingNotes != null &&
                      visit.careActivities!.nursingNotes!.isNotEmpty)
                    _detailRow(
                      'Nursing Notes',
                      visit.careActivities!.nursingNotes!,
                    ),
                  if (visit.careActivities!.dressingProcedures != null &&
                      visit.careActivities!.dressingProcedures!.isNotEmpty)
                    _detailRow(
                      'Dressing Procedure',
                      visit.careActivities!.dressingProcedures!,
                    ),
                  _detailRow(
                    'Nail Trimming / Hygiene Care',
                    visit.careActivities!.nailTrimmingDone
                        ? 'Completed'
                        : 'Not Performed',
                  ),
                  if (visit.careActivities!.otherCareActivities != null &&
                      visit.careActivities!.otherCareActivities!.isNotEmpty)
                    _detailRow(
                      'Other Care Activities',
                      visit.careActivities!.otherCareActivities!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Administered Medicines & Consumables Summary
          if (visit.medicines.isNotEmpty || visit.consumables.isNotEmpty) ...[
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
                    'Administered Medicines & Consumables',
                    Icons.medication_liquid_outlined,
                  ),
                  const SizedBox(height: 16),
                  if (visit.medicines.isNotEmpty) ...[
                    const Text(
                      'Medicines Administered:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final m in visit.medicines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          '• ${m.medicineName} (${m.dosage}) - Qty: ${m.quantity} | ₹${m.unitPrice * m.quantity}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (visit.consumables.isNotEmpty) ...[
                    const Text(
                      'Consumables Used:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final c in visit.consumables)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(
                          '• ${c.itemName} - Qty: ${c.quantityUsed} | ₹${c.unitPrice * c.quantityUsed}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Timestamped Photo Evidence Gallery
          if (visit.photos.isNotEmpty) ...[
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
                    'Timestamped Photo Evidence Gallery',
                    Icons.insert_photo_outlined,
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.95,
                        ),
                    itemCount: visit.photos.length,
                    itemBuilder: (context, idx) {
                      final p = visit.photos[idx];
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
            fontFamily: 'Inter',
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
