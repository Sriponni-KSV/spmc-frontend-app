import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/home_visit_model.dart';
import '../controllers/home_visit_controller.dart';
import 'home_visit_invoice_dialog.dart';

class HomeVisitExecutionScreen extends StatefulWidget {
  final int visitId;
  final VoidCallback? onBack;

  const HomeVisitExecutionScreen({super.key, required this.visitId, this.onBack});

  @override
  State<HomeVisitExecutionScreen> createState() => _HomeVisitExecutionScreenState();
}

class _HomeVisitExecutionScreenState extends State<HomeVisitExecutionScreen> with SingleTickerProviderStateMixin {
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

  // Medicine Form Controllers
  final TextEditingController _medNameCtrl = TextEditingController();
  final TextEditingController _medDosageCtrl = TextEditingController();
  final TextEditingController _medRouteCtrl = TextEditingController();
  final TextEditingController _medQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _medPriceCtrl = TextEditingController(text: '50.00');

  // Consumable Form Controllers
  final TextEditingController _consNameCtrl = TextEditingController();
  final TextEditingController _consQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _consPriceCtrl = TextEditingController(text: '20.00');

  // Photo Evidence Form
  final TextEditingController _photoUrlCtrl = TextEditingController();
  final TextEditingController _photoCaptionCtrl = TextEditingController();
  String _selectedPhotoCategory = 'Dressing Pre-Procedure';

  // Signature Form
  final TextEditingController _attenderNameCtrl = TextEditingController();
  final TextEditingController _attenderRelationCtrl = TextEditingController();
  final List<Offset?> _signaturePoints = [];

  bool _isSavingVitals = false;
  bool _isSavingCare = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final ctrl = Provider.of<HomeVisitController>(context, listen: false);
    await ctrl.fetchVisitDetails(widget.visitId);
    final visit = ctrl.selectedVisit;

    if (visit != null) {
      if (visit.vitals != null) {
        _sysBpCtrl.text = visit.vitals!.systolicBp?.toString() ?? '';
        _diaBpCtrl.text = visit.vitals!.diastolicBp?.toString() ?? '';
        _pulseCtrl.text = visit.vitals!.pulseRate?.toString() ?? '';
        _tempCtrl.text = visit.vitals!.temperature?.toString() ?? '';
        _spo2Ctrl.text = visit.vitals!.spo2?.toString() ?? '';
        _sugarCtrl.text = visit.vitals!.bloodSugar?.toString() ?? '';
        _weightCtrl.text = visit.vitals!.weight?.toString() ?? '';
        _heightCtrl.text = visit.vitals!.height?.toString() ?? '';
      }

      if (visit.careActivities != null) {
        _notesCtrl.text = visit.careActivities!.nursingNotes ?? '';
        _dressingCtrl.text = visit.careActivities!.dressingProcedures ?? '';
        _nailTrimmingDone = visit.careActivities!.nailTrimmingDone;
        _otherCareCtrl.text = visit.careActivities!.otherCareActivities ?? '';
      }

      if (visit.attenderName != null) _attenderNameCtrl.text = visit.attenderName!;
      if (visit.attenderRelation != null) _attenderRelationCtrl.text = visit.attenderRelation!;
    }
  }

  @override
  void dispose() {
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
    final String baseText = hasStar ? label.substring(0, label.length - 2) : label;

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
                style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold),
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
            body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          );
        }

        if (visit == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Home Visit Details')),
            body: const Center(child: Text('Visit not found or failed to load.')),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: widget.onBack != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                    onPressed: widget.onBack,
                  )
                : null,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: AppTheme.primaryColor),
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
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.medical_services_outlined), text: 'Kit & Devices'),
                Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'Vitals'),
                Tab(icon: Icon(Icons.edit_note_outlined), text: 'Nursing Care & Dressing'),
                Tab(icon: Icon(Icons.medication_liquid_outlined), text: 'Meds & Consumables'),
                Tab(icon: Icon(Icons.verified_user_outlined), text: 'Photos & Attender Signature'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildKitTab(visit),
              _buildVitalsTab(visit, controller),
              _buildCareTab(visit, controller),
              _buildMedsAndConsumablesTab(visit, controller),
              _buildSignatureAndVerificationTab(visit, controller),
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
          _buildSectionHeader('Medical Devices, Medicines & Supplies Carried in Kit', Icons.shopping_bag_outlined),
          const SizedBox(height: 16),
          if (visit.carriedItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text('Default kit loaded: BP Apparatus, Stethoscope, Glucometer, Thermometer, Pulse Oximeter, Dressing Kit, Bandages & Antiseptics.'),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
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
                  if (item.itemType == 'Medicine') itemIcon = Icons.medication;

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
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          child: Icon(itemIcon, color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${item.itemType} • Qty Carried: ${item.quantityCarried}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }

  // 2. Vitals Tab with Strict Boundary Check (Style Guide Rules)
  Widget _buildVitalsTab(HomeVisitModel visit, HomeVisitController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyVitals,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Record Patient Vital Signs', Icons.monitor_heart_outlined),
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
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Systolic BP (mmHg)'),
                            TextFormField(
                              controller: _sysBpCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: AppTheme.standardInputDecoration(hintText: '90 - 300'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final num = int.tryParse(val);
                                if (num == null || num < 90 || num > 300) {
                                  return 'Must be between 90 and 300 mmHg';
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
                            _buildLabel('Diastolic BP (mmHg)'),
                            TextFormField(
                              controller: _diaBpCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: AppTheme.standardInputDecoration(hintText: '50 - 180'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final num = int.tryParse(val);
                                if (num == null || num < 50 || num > 180) {
                                  return 'Must be between 50 and 180 mmHg';
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
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: AppTheme.standardInputDecoration(hintText: '40 - 200'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Body Temperature (°F)'),
                            TextFormField(
                              controller: _tempCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: AppTheme.standardInputDecoration(hintText: '90 - 115 °F'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final num = double.tryParse(val);
                                if (num == null || num < 90.0 || num > 115.0) {
                                  return 'Must be between 90 and 115 °F';
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('SpO₂ (%)'),
                            TextFormField(
                              controller: _spo2Ctrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: AppTheme.standardInputDecoration(hintText: '70 - 100%'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Blood Sugar Level (mg/dL)'),
                            TextFormField(
                              controller: _sugarCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: AppTheme.standardInputDecoration(hintText: '30 - 600 mg/dL'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final num = double.tryParse(val);
                                if (num == null || num < 30.0 || num > 600.0) {
                                  return 'Must be between 30 and 600 mg/dL';
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Weight (kg)'),
                            TextFormField(
                              controller: _weightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: AppTheme.standardInputDecoration(hintText: '> 0 kg'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final num = double.tryParse(val);
                                if (num == null || num <= 0) {
                                  return 'Weight must be positive and non-zero';
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
                            _buildLabel('Height (cm)'),
                            TextFormField(
                              controller: _heightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: AppTheme.standardInputDecoration(hintText: '> 0 cm'),
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final num = double.tryParse(val);
                                if (num == null || num <= 0) {
                                  return 'Height must be positive and non-zero';
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
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: AppTheme.primaryButton,
                      onPressed: _isSavingVitals
                          ? null
                          : () async {
                              if (_formKeyVitals.currentState!.validate()) {
                                setState(() => _isSavingVitals = true);
                                final success = await controller.submitVitals(visit.id, {
                                  'systolic_bp': int.tryParse(_sysBpCtrl.text),
                                  'diastolic_bp': int.tryParse(_diaBpCtrl.text),
                                  'pulse_rate': int.tryParse(_pulseCtrl.text),
                                  'temperature': double.tryParse(_tempCtrl.text),
                                  'spo2': int.tryParse(_spo2Ctrl.text),
                                  'blood_sugar': double.tryParse(_sugarCtrl.text),
                                  'weight': double.tryParse(_weightCtrl.text),
                                  'height': double.tryParse(_heightCtrl.text),
                                });
                                setState(() => _isSavingVitals = false);
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vitals saved successfully!'), backgroundColor: AppTheme.secondaryColor),
                                  );
                                }
                              }
                            },
                      child: _isSavingVitals
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Vitals Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            _buildSectionHeader('Nursing Notes & Care Activities', Icons.edit_note_outlined),
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
                      hintText: 'Enter clinical observations, general health condition, and comments...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Dressing Procedures & Wound Care Details'),
                  TextFormField(
                    controller: _dressingCtrl,
                    maxLines: 3,
                    decoration: AppTheme.standardInputDecoration(
                      hintText: 'Describe wound site, cleaning agent used, sterile dressing applied, etc.',
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
                      subtitle: const Text('Check if nail trimming or foot care was performed during visit.'),
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
                      hintText: 'Catheter care, bed bath assistance, oral hygiene, position changes, etc.',
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
                              final success = await controller.submitCareActivities(visit.id, {
                                'nursing_notes': _notesCtrl.text,
                                'dressing_procedures': _dressingCtrl.text,
                                'nail_trimming_done': _nailTrimmingDone,
                                'other_care_activities': _otherCareCtrl.text,
                              });
                              setState(() => _isSavingCare = false);
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Care activities saved successfully!'), backgroundColor: AppTheme.secondaryColor),
                                );
                              }
                            },
                      child: _isSavingCare
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Nursing Care Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Medicines & Consumables Tab
  Widget _buildMedsAndConsumablesTab(HomeVisitModel visit, HomeVisitController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Log Administered Medicines & Used Consumables', Icons.medication_liquid_outlined),
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
                const Text('Medicines Administered During Visit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _medNameCtrl,
                        decoration: AppTheme.standardInputDecoration(hintText: 'Medicine Name (e.g. Paracetamol)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _medDosageCtrl,
                        decoration: AppTheme.standardInputDecoration(hintText: 'Dosage (500mg)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _medQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: AppTheme.standardInputDecoration(hintText: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _medPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: AppTheme.standardInputDecoration(hintText: 'Unit Price ₹'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: AppTheme.secondaryButton,
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
                          _medNameCtrl.clear();
                          _medDosageCtrl.clear();
                        }
                      },
                      child: const Text('Add Med'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visit.medicines.isEmpty)
                  const Text('No medicines logged yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visit.medicines.length,
                    itemBuilder: (context, idx) {
                      final m = visit.medicines[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.medication, color: AppTheme.primaryColor),
                        title: Text('${m.medicineName} (${m.dosage})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Qty: ${m.quantity} • Unit Price: ₹${m.unitPrice.toStringAsFixed(2)}'),
                        trailing: Text('Subtotal: ₹${(m.quantity * m.unitPrice).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
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
                const Text('Consumables Used During Visit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _consNameCtrl,
                        decoration: AppTheme.standardInputDecoration(hintText: 'Consumable Item (e.g. Sterile Bandage, Syringe)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _consQtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: AppTheme.standardInputDecoration(hintText: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _consPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: AppTheme.standardInputDecoration(hintText: 'Unit Price ₹'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: AppTheme.secondaryButton,
                      onPressed: () async {
                        if (_consNameCtrl.text.trim().isEmpty) return;
                        final success = await controller.submitConsumable(visit.id, {
                          'item_name': _consNameCtrl.text.trim(),
                          'quantity_used': int.tryParse(_consQtyCtrl.text) ?? 1,
                          'unit_price': double.tryParse(_consPriceCtrl.text) ?? 0.0,
                        });
                        if (success) {
                          _consNameCtrl.clear();
                        }
                      },
                      child: const Text('Add Consumable'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visit.consumables.isEmpty)
                  const Text('No consumable items logged yet.', style: TextStyle(color: Colors.grey, fontSize: 13))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visit.consumables.length,
                    itemBuilder: (context, idx) {
                      final c = visit.consumables[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.clean_hands, color: AppTheme.secondaryColor),
                        title: Text(c.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Qty Used: ${c.quantityUsed} • Unit Price: ₹${c.unitPrice.toStringAsFixed(2)}'),
                        trailing: Text('Subtotal: ₹${(c.quantityUsed * c.unitPrice).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
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

  // 5. Photos & Digital Attender Signature Tab
  Widget _buildSignatureAndVerificationTab(HomeVisitModel visit, HomeVisitController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Time-based Photo Evidence & Attender Signature Verification', Icons.verified_user_outlined),
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
                const Text('Upload Timestamped Photo Evidence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPhotoCategory,
                        decoration: AppTheme.standardInputDecoration(),
                        items: const [
                          DropdownMenuItem(value: 'Dressing Pre-Procedure', child: Text('Pre-Dressing Wound Photo')),
                          DropdownMenuItem(value: 'Dressing Post-Procedure', child: Text('Post-Dressing Photo')),
                          DropdownMenuItem(value: 'Care Activity', child: Text('Care Activity Evidence')),
                          DropdownMenuItem(value: 'General Care', child: Text('General Visit Photo')),
                        ],
                        onChanged: (val) => setState(() => _selectedPhotoCategory = val!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _photoUrlCtrl,
                        decoration: AppTheme.standardInputDecoration(hintText: 'Photo URL / Image Path'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: AppTheme.secondaryButton,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Add Photo'),
                      onPressed: () async {
                        final url = _photoUrlCtrl.text.trim().isNotEmpty
                            ? _photoUrlCtrl.text.trim()
                            : 'https://placehold.co/600x400/png?text=Home+Visit+Evidence';
                        final success = await controller.submitPhotoEvidence(
                          visit.id,
                          url,
                          _selectedPhotoCategory,
                          _photoCaptionCtrl.text,
                        );
                        if (success) {
                          _photoUrlCtrl.clear();
                          _photoCaptionCtrl.clear();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visit.photos.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: visit.photos.length,
                    itemBuilder: (context, idx) {
                      final p = visit.photos[idx];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.category ?? 'Evidence', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryColor)),
                            Text('Time: ${p.capturedAt ?? "Just now"}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            const Spacer(),
                            const Icon(Icons.image_outlined, size: 24, color: Colors.grey),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

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
                const Text('Patient Attender Verification & Digital Signature', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
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
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                            ],
                            decoration: AppTheme.standardInputDecoration(hintText: 'Full Name (Min 3, Max 30 chars)'),
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
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                            ],
                            decoration: AppTheme.standardInputDecoration(hintText: 'e.g. Son, Spouse, Daughter'),
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
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E0)),
                  ),
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        RenderBox renderBox = context.findRenderObject() as RenderBox;
                        _signaturePoints.add(renderBox.globalToLocal(details.globalPosition));
                      });
                    },
                    onPanEnd: (details) => _signaturePoints.add(null),
                    child: CustomPaint(
                      painter: SignaturePainter(points: _signaturePoints),
                      size: Size.infinite,
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: Text(
                      _isVerifying ? 'Generating Auto-Billing Invoice...' : 'Verify Visit & Generate Billing Invoice',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isVerifying
                        ? null
                        : () async {
                            if (_attenderNameCtrl.text.trim().length < 3) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter valid attender name (min 3 chars).'), backgroundColor: AppTheme.dangerColor),
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
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => oldDelegate.points != points;
}
