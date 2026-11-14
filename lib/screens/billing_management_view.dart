import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../controllers/billing_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/ipd_controller.dart';
import '../models/patient_model.dart';
import '../widgets/custom_dropdown_search.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'dart:convert';
import '../config/api_config.dart';
import '../models/home_visit_model.dart';
import '../services/home_visit_service.dart';
import 'home_visit_invoice_dialog.dart';
import '../widgets/billing_receipt_dialog.dart';
import '../utils/receipt_printer.dart';
import '../utils/app_notification.dart';

class BillingManagementView extends StatefulWidget {
  const BillingManagementView({Key? key}) : super(key: key);

  @override
  State<BillingManagementView> createState() => _BillingManagementViewState();
}

class _BillingManagementViewState extends State<BillingManagementView> with TickerProviderStateMixin {
  TabController? _tabController;
  final BillingController _billingCtrl = BillingController();
  final PatientController _patientCtrl = PatientController();
  final IpdController _ipdCtrl = IpdController();
  final HomeVisitService _homeVisitService = HomeVisitService();

  List<Map<String, dynamic>> _catalogServices = [];
  List<PatientModel> _patients = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _ipAdmissions = [];
  List<HomeVisitModel> _pendingUnbilledHomeVisits = [];
  List<Map<String, dynamic>> _unbilledOtCases = [];
  List<Map<String, dynamic>> _otBillingCases = [];
  bool _isLoadingOtBillingCases = false;
  String _otBillingFilter = 'All'; // 'All', 'Unbilled', 'Billed'
  String _otBillingSearch = '';
  bool _isLoadingCatalog = false;
  bool _isLoadingInvoices = false;
  bool _isLoadingAdmissions = false;
  bool _isLoadingUnbilledVisits = false;
  bool _isLoadingUnbilledOtCases = false;
  int? _qbSelectedOtCaseId;

  // Search queries
  String _catalogSearch = '';
  String _invoiceSearch = '';
  String _ipSearch = '';
  String _homeCareStatusFilter = 'All';
  String _homeCareSubTab = 'Invoiced'; // 'Invoiced' or 'Pending Unbilled'
  String _homeCareUnbilledSearch = '';
  /// Toggle to show/hide Home Visit in the Quick Bill section
  String _qbVisitType = 'OP'; // 'OP' or 'HomeVisit'

  // For Pharmacy Prescriptions Queue & Dispensing (MocDoc)
  List<Map<String, dynamic>> _pharmacyPrescriptions = [];
  bool _isLoadingPrescriptions = false;
  String _pharmacySearch = '';
  String _pharmacyStatusFilter = 'Pending'; // 'Pending', 'Dispensed', 'All'

  // For Lab Investigation Orders Queue & Billing (MocDoc)
  List<Map<String, dynamic>> _labRequests = [];
  bool _isLoadingLabRequests = false;
  String _labSearch = '';
  String _labStatusFilter = 'Pending'; // 'Pending', 'Billed', 'All'

  // Quick Bill State
  String? _qbDoctorName;
  int? _qbConsultationId;
  List<int>? _qbLabRequestIds;

  final TextEditingController _labTestPriceCtrl = TextEditingController();

  // For Pharmacy Billing
  final TextEditingController _pharmacyPriceCtrl = TextEditingController();
  final TextEditingController _pharmacyQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _customPharmacyItemCtrl = TextEditingController();
  List<Map<String, dynamic>> _medicineInventory = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String? _currentRole;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).user;
    final role = user?.role;
    if (role != _currentRole) {
      _currentRole = role;
      int tabLength = 7;
      if (role == 'Pharmacy') {
        tabLength = 2;
      } else if (role == 'Lab') {
        tabLength = 2;
      }
      
      _tabController?.dispose();
      _tabController = TabController(length: tabLength, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          _refreshDataForTab(_tabController!.index);
        }
      });
      _refreshDataForTab(0);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _pharmacyPriceCtrl.dispose();
    _pharmacyQtyCtrl.dispose();
    _customPharmacyItemCtrl.dispose();
    _labTestPriceCtrl.dispose();
    super.dispose();
  }

  void _loadAllData() {
    _loadCatalog();
    _loadPatients();
    _loadInvoices();
    _loadIpAdmissions();
    _loadPendingUnbilledHomeVisits();
    _loadUnbilledOtCases();
    _loadOtBillingCases();
    _loadMedicineInventory();
    _loadPrescriptions();
    _loadLabRequests();
  }

  Future<void> _loadPrescriptions() async {
    if (!mounted) return;
    try {
      final list = await _billingCtrl.fetchPharmacyPrescriptions();
      if (mounted) setState(() => _pharmacyPrescriptions = list);
    } catch (e) {
      debugPrint('Error loading pharmacy prescriptions: $e');
    } finally {
    }
  }

  Future<void> _loadLabRequests() async {
    if (!mounted) return;
    try {
      final list = await _billingCtrl.fetchLabRequests();
      if (mounted) setState(() => _labRequests = list);
    } catch (e) {
      debugPrint('Error loading lab requests: $e');
    } finally {
    }
  }

  void _refreshDataForTab(int tabIndex) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final role = user?.role;

    if (role == 'Pharmacy') {
      if (tabIndex == 0) {
        _loadPrescriptions();
        _loadMedicineInventory();
        _loadInvoices();
      } else if (tabIndex == 1) {
        _loadCatalog();
      }
    } else if (role == 'Lab') {
      if (tabIndex == 0) {
        _loadLabRequests();
        _loadCatalog();
        _loadInvoices();
      } else if (tabIndex == 1) {
        _loadCatalog();
      }
    } else {
      if (tabIndex == 0) {
        _loadCatalog();
        _loadPatients();
      } else if (tabIndex == 1) {
        _loadPrescriptions();
        _loadMedicineInventory();
        _loadInvoices();
      } else if (tabIndex == 2) {
        _loadLabRequests();
        _loadCatalog();
        _loadInvoices();
      } else if (tabIndex == 3) {
        _loadIpAdmissions();
      } else if (tabIndex == 4) {
        _loadOtBillingCases();
      } else if (tabIndex == 5) {
        _loadPendingUnbilledHomeVisits();
      } else if (tabIndex == 6) {
        _loadCatalog();
      }
    }
  }

  Future<void> _loadOtBillingCases() async {
    if (!mounted) return;
    setState(() => _isLoadingOtBillingCases = true);
    try {
      final list = await _billingCtrl.fetchOtBillingCases();
      if (mounted) setState(() => _otBillingCases = list);
    } catch (e) {
      debugPrint('Error loading OT billing cases: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOtBillingCases = false);
    }
  }

  Future<void> _loadUnbilledOtCases() async {
    if (!mounted) return;
    setState(() => _isLoadingUnbilledOtCases = true);
    try {
      final list = await _billingCtrl.fetchUnbilledOtCases();
      if (mounted) setState(() => _unbilledOtCases = list);
    } catch (e) {
      debugPrint('Error loading unbilled OT cases: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUnbilledOtCases = false);
    }
  }

  Future<void> _loadMedicineInventory() async {
    try {
      final response = await ApiService.get('${ApiEndpoints.baseUrl}/inventory/items');
      final body = jsonDecode(response.body);
      if (body['success'] == true && mounted) {
        setState(() {
          _medicineInventory = List<Map<String, dynamic>>.from(body['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading medicine inventory: $e');
    }
  }

  Future<void> _loadCatalog() async {
    if (!mounted) return;
    setState(() => _isLoadingCatalog = true);
    try {
      final list = await _billingCtrl.fetchBillingServices();
      if (mounted) {
        final user = Provider.of<AuthProvider>(context, listen: false).user;
        final role = user?.role;
        List<Map<String, dynamic>> filteredList = list;
        if (role == 'Lab') {
          filteredList = list.where((s) => s['category'] == 'Lab').toList();
        } else if (role == 'Pharmacy') {
          filteredList = list.where((s) => s['category'] == 'Pharmacy').toList();
        }
        setState(() => _catalogServices = filteredList);
      }
    } catch (e) {
      debugPrint('Error loading billing catalog: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;
    try {
      final list = await _patientCtrl.fetchPatients();
      if (mounted) setState(() => _patients = list);
    } catch (e) {
      debugPrint('Error loading patients: $e');
    }
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() => _isLoadingInvoices = true);
    try {
      final list = await _billingCtrl.fetchInvoices();
      if (mounted) setState(() => _invoices = list);
    } catch (e) {
      debugPrint('Error loading invoices: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  Future<void> _loadIpAdmissions() async {
    if (!mounted) return;
    setState(() => _isLoadingAdmissions = true);
    try {
      final list = await _ipdCtrl.fetchAdmissions();
      if (mounted) setState(() => _ipAdmissions = list);
    } catch (e) {
      debugPrint('Error loading IP admissions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAdmissions = false);
    }
  }

  Future<void> _loadPendingUnbilledHomeVisits() async {
    if (!mounted) return;
    setState(() => _isLoadingUnbilledVisits = true);
    try {
      final visits = await _homeVisitService.getHomeVisits();
      final unbilled = visits.where((v) {
        final isDone = v.status.toLowerCase() == 'completed' || v.status.toLowerCase() == 'verified';
        final hasNoInvoice = v.invoice == null || v.invoice!['id'] == null;
        return isDone && hasNoInvoice;
      }).toList();
      if (mounted) {
        setState(() => _pendingUnbilledHomeVisits = unbilled);
      }
    } catch (e) {
      debugPrint('Error loading pending unbilled home visits: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUnbilledVisits = false);
    }
  }

  Future<void> _generateAndOpenHomeVisitInvoice(HomeVisitModel visit) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await _homeVisitService.generateInvoice(visit.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dlgCtx) => Localizations.override(
            context: dlgCtx,
            locale: const Locale('en'),
            child: HomeVisitInvoiceDialog(
              invoiceData: res,
              visit: visit,
              onCloseAndComplete: () {
                _loadInvoices();
                _loadPendingUnbilledHomeVisits();
              },
            ),
          ),
        );
        if (mounted) {
          _loadInvoices();
          _loadPendingUnbilledHomeVisits();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppNotification.showError(context, 'Error generating invoice: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final user = Provider.of<AuthProvider>(context).user;
    final role = user?.role;

    List<Tab> tabs = [];
    List<Widget> tabViews = [];
    String subtitle = 'Manage quick bills, OP invoices, IP billing worksheets, and service catalog';

    if (role == 'Pharmacy') {
      subtitle = 'Manage doctor prescriptions queue, medication dispensing, and pharmacy billing';
      tabs = const [
        Tab(icon: Icon(Icons.medication_outlined), text: 'Pharmacy Billing'),
        Tab(icon: Icon(Icons.menu_book_outlined), text: 'Medication Prices'),
      ];
      tabViews = [
        _buildPharmacyBillingTab(isMobile),
        _buildCatalogTab(isMobile),
      ];
    } else if (role == 'Lab') {
      subtitle = 'Manage doctor lab investigation orders, diagnostic test billing, and prices';
      tabs = const [
        Tab(icon: Icon(Icons.biotech_outlined), text: 'Lab Billing'),
        Tab(icon: Icon(Icons.menu_book_outlined), text: 'Lab Tests Catalog'),
      ];
      tabViews = [
        _buildLabBillingTab(isMobile),
        _buildCatalogTab(isMobile),
      ];
    } else {
      subtitle = 'Manage OP quick billing, pharmacy dispensing, lab diagnostics, IPD, and OT surgery';
      tabs = const [
        Tab(icon: Icon(Icons.receipt_outlined), text: 'Quick Bill'),
        Tab(icon: Icon(Icons.medication_outlined), text: 'Pharmacy Billing'),
        Tab(icon: Icon(Icons.biotech_outlined), text: 'Lab Billing'),
        Tab(icon: Icon(Icons.hotel_outlined), text: 'IP Billing'),
        Tab(icon: Icon(Icons.medical_services_outlined), text: 'OT Billing'),
        Tab(icon: Icon(Icons.home_work_outlined), text: 'Home Care'),
        Tab(icon: Icon(Icons.settings_outlined), text: 'Services Catalog'),
      ];
      tabViews = [
        _buildQuickBillTab(isMobile),
        _buildPharmacyBillingTab(isMobile),
        _buildLabBillingTab(isMobile),
        _buildIpBillingTab(isMobile),
        _buildOtBillingTab(isMobile),
        _buildHomeCareBillingTab(isMobile),
        _buildCatalogTab(isMobile),
      ];
    }

    return Localizations.override(
      context: context,
      locale: const Locale('en'),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom transparent header
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 20 : 24, isMobile ? 16 : 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Billing & Invoices',
                    style: Theme.of(context).textTheme.displayLarge ??
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // TabBar Container
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderColor, width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController!,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textSecondaryColor,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 20.0 : 36.0, vertical: 8.0),
                tabs: tabs,
              ),
            ),
            
            // TabBarView Content
            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TABS ──────────────────────────────────────────────────────────────────

  // 1. Quick Bill (OP) Tab
  PatientModel? _qbSelectedPatient;
  List<Map<String, dynamic>> _qbSelectedItems = [];
  double _qbDiscount = 0.0;
  String _qbPaymentMode = 'Cash';
  final TextEditingController _qbDiscountController = TextEditingController(text: '0');
  final TextEditingController _qbPaidController = TextEditingController(text: '0');
  final TextEditingController _qbRefController = TextEditingController();

  Widget _buildQuickBillTab(bool isMobile) {
    final user = Provider.of<AuthProvider>(context).user;
    final role = user?.role;
    double subtotal = 0;
    for (var item in _qbSelectedItems) {
      subtotal += (item['unit_price'] as double) * (item['quantity'] as int);
    }
    double netAmount = subtotal - _qbDiscount;
    if (netAmount < 0) netAmount = 0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text('Quick Bill Form (OP Services)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
                      if (role != 'Pharmacy' && role != 'Lab')
                        OutlinedButton.icon(
                          icon: const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF0284C7)),
                          label: Text(
                            'OT Billing (${_otBillingCases.where((c) => c['is_billed'] != true).length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _tabController?.animateTo(4),
                        ),
                    ],
                  ),
                  
                  // Patient Selector
                  _buildLabel('Patient *'),
                  CustomDropdownSearch(
                    label: '',
                    hint: 'Select Patient',
                    value: _qbSelectedPatient?.id?.toString(),
                    dropdownMap: {
                      for (var p in _patients)
                        p.id.toString(): '${p.name} (${p.patientId}) - ${p.phone}'
                    },
                    onChanged: (val) {
                      if (val != null) {
                        final p = _patients.firstWhere((pt) => pt.id.toString() == val);
                        setState(() {
                          _qbSelectedPatient = p;
                          _qbSelectedOtCaseId = null;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                  _buildLabel('Add OP Service / Consultation Fee *'),
                  Row(
                    children: [
                      Expanded(
                        child: CustomDropdownSearch(
                          label: '',
                          hint: 'Select OP Service / Fee',
                          clearOnSelect: true,
                          dropdownMap: {
                            for (var s in _catalogServices.where((x) => x['category'] != 'IP' && x['category'] != 'Pharmacy' && x['category'] != 'Lab'))
                              s['id'].toString(): '${s['name']} (₹${s['price']})'
                          },
                          onChanged: (val) {
                            if (val != null) {
                              final svc = _catalogServices.firstWhere((s) => s['id'].toString() == val);
                              _addQbItem(svc);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_qbSelectedItems.isNotEmpty) ...[
                    const Divider(height: 32, thickness: 1.2),
                    _buildSummaryRow('Subtotal', subtotal),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Discount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          height: 40,
                          child: TextFormField(
                            controller: _qbDiscountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (val) {
                              setState(() {
                                _qbDiscount = double.tryParse(val) ?? 0.0;
                                _qbPaidController.text = (subtotal - _qbDiscount).toStringAsFixed(0);
                              });
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              fillColor: const Color(0xFFF1F5F9),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Net Amount', netAmount, isBold: true, color: AppTheme.primaryColor),
                    const Divider(height: 32),

                    // Payment mode Selector
                    const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    _buildPaymentModeWrap(_qbPaymentMode, (mode) => setState(() => _qbPaymentMode = mode)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Collected Amount (₹)'),
                              TextFormField(
                                controller: _qbPaidController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: '0'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Reference / Txn Id'),
                              TextFormField(
                                controller: _qbRefController,
                                decoration: const InputDecoration(hintText: 'Optional'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _submitQuickBill,
                      style: AppTheme.primaryButton.copyWith(
                        minimumSize: MaterialStateProperty.all(const Size(double.infinity, 54)),
                      ),
                      child: const Text('Generate Invoice & Receipt'),
                    )
                  ]
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _addQbItem(Map<String, dynamic> service) {
    final idx = _qbSelectedItems.indexWhere((x) => x['service_id'] == service['id'] && x['item_name'] == service['name']);
    if (idx >= 0) {
      setState(() {
        _qbSelectedItems[idx]['quantity'] = (_qbSelectedItems[idx]['quantity'] as int) + 1;
      });
    } else {
      setState(() {
        _qbSelectedItems.add({
          'service_id': service['id'],
          'category': service['category'] ?? 'OP',
          'item_name': service['name'],
          'quantity': 1,
          'unit_price': double.parse(service['price'].toString())
        });
      });
    }
  }

  Future<void> _submitQuickBill() async {
    if (_qbSelectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a patient'), backgroundColor: Colors.red));
      return;
    }
    if (_qbSelectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item'), backgroundColor: Colors.red));
      return;
    }

    final double collected = double.tryParse(_qbPaidController.text) ?? 0.0;
    final type = _qbVisitType;

    try {
      final res = await _billingCtrl.createInvoice(
        patientId: _qbSelectedPatient!.id!,
        admissionType: type,
        otCaseId: _qbSelectedOtCaseId,
        doctorName: _qbDoctorName,
        consultationId: _qbConsultationId,
        labRequestIds: _qbLabRequestIds,
        items: _qbSelectedItems,
        discount: _qbDiscount,
        initialPayment: collected > 0 ? {
          'amount': collected,
          'payment_mode': _qbPaymentMode,
          'transaction_reference': _qbRefController.text
        } : null
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice created successfully!'), backgroundColor: Colors.green));
        // Reset Qb Fields
        setState(() {
          _qbSelectedPatient = null;
          _qbSelectedOtCaseId = null;
          _qbConsultationId = null;
          _qbLabRequestIds = null;
          _qbDoctorName = null;
          _qbSelectedItems = [];
          _qbDiscount = 0.0;
          _qbDiscountController.text = '0';
          _qbPaidController.text = '0';
          _qbRefController.text = '';
          _qbVisitType = 'OP';
        });
        _loadInvoices();
        _loadPrescriptions();
        _loadLabRequests();
        _loadUnbilledOtCases();
        _showInvoiceReceiptDialog(res['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showEditOtCaseFeesDialog(Map<String, dynamic> otc, {VoidCallback? onUpdated}) {
    final caseId = otc['id'] ?? otc['ot_case_id'];
    if (caseId == null) return;

    double initTheatre = double.tryParse((otc['theatre_fee'] ?? 0).toString()) ?? 0.0;
    if (initTheatre <= 0) {
      initTheatre = double.tryParse((otc['theatre_charge'] ?? 5000).toString()) ?? 5000.0;
    }

    double initSurgeon = double.tryParse((otc['surgeon_fee'] ?? 0).toString()) ?? 0.0;
    if (initSurgeon <= 0) initSurgeon = 6000.0;

    double initAsst = double.tryParse((otc['assistant_surgeon_fee'] ?? 0).toString()) ?? 0.0;
    if (initAsst <= 0) initAsst = 2000.0;

    double initAnaesth = double.tryParse((otc['anaesthesia_fee'] ?? 0).toString()) ?? 0.0;
    if (initAnaesth <= 0) initAnaesth = 3000.0;

    if (otc['items'] is List) {
      for (var it in (otc['items'] as List)) {
        final name = (it['item_name'] ?? '').toString().toLowerCase();
        final price = double.tryParse((it['unit_price'] ?? 0).toString()) ?? 0.0;
        if (price > 0) {
          if (name.contains('theatre') && (otc['theatre_fee'] == null || otc['theatre_fee'] == 0)) initTheatre = price;
          if ((name.contains('lead surgeon') || (name.contains('surgeon') && !name.contains('assistant'))) && (otc['surgeon_fee'] == null || otc['surgeon_fee'] == 0)) initSurgeon = price;
          if (name.contains('assistant') && (otc['assistant_surgeon_fee'] == null || otc['assistant_surgeon_fee'] == 0)) initAsst = price;
          if (name.contains('anaesth') && (otc['anaesthesia_fee'] == null || otc['anaesthesia_fee'] == 0)) initAnaesth = price;
        }
      }
    }

    final hasAsst = otc['assistant_surgeon'] != null && otc['assistant_surgeon'].toString().trim().isNotEmpty;
    final hasAnaesth = otc['anaesthetist'] != null && otc['anaesthetist'].toString().trim().isNotEmpty;

    final TextEditingController theatreCtrl = TextEditingController(text: initTheatre.toStringAsFixed(0));
    final TextEditingController surgeonCtrl = TextEditingController(text: initSurgeon.toStringAsFixed(0));
    final TextEditingController asstCtrl = TextEditingController(text: initAsst.toStringAsFixed(0));
    final TextEditingController anaesthCtrl = TextEditingController(text: initAnaesth.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (dCtx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogContext, setDlgState) {
            final bool isMobileDialog = MediaQuery.of(dialogContext).size.width < 620;

            double calcTotal() {
              double t = double.tryParse(theatreCtrl.text.trim()) ?? 0;
              t += double.tryParse(surgeonCtrl.text.trim()) ?? 0;
              if (hasAsst) t += double.tryParse(asstCtrl.text.trim()) ?? 0;
              if (hasAnaesth) t += double.tryParse(anaesthCtrl.text.trim()) ?? 0;
              return t;
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobileDialog ? 12.0 : 40.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.edit_calendar_outlined, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Case Bill Amount: ${otc['case_number'] ?? 'OT Case'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${otc['surgery_type'] ?? 'Surgery'} • ${otc['patient_name'] ?? 'Patient'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? double.maxFinite : 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text('Estimated Surgical Bill Total:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                            ),
                            const SizedBox(width: 8),
                            Text('₹${calcTotal().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor)),
                          ],
                        ),
                      ),
                      _buildLabel('Operation Theatre Charge (₹)'),
                      TextFormField(
                        controller: theatreCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDlgState(() {}),
                        decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Enter Theatre Fee'),
                      ),
                      const SizedBox(height: 12),
                      _buildLabel('Lead Surgeon Fee (Dr. ${otc['lead_surgeon'] ?? 'Surgeon'}) (₹)'),
                      TextFormField(
                        controller: surgeonCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDlgState(() {}),
                        decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Enter Surgeon Fee'),
                      ),
                      if (hasAsst) ...[
                        const SizedBox(height: 12),
                        _buildLabel('Assistant Surgeon Fee (Dr. ${otc['assistant_surgeon']}) (₹)'),
                        TextFormField(
                          controller: asstCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDlgState(() {}),
                          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Enter Assistant Surgeon Fee'),
                        ),
                      ],
                      if (hasAnaesth) ...[
                        const SizedBox(height: 12),
                        _buildLabel('Anaesthetist Fee (Dr. ${otc['anaesthetist']}) (₹)'),
                        TextFormField(
                          controller: anaesthCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDlgState(() {}),
                          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Enter Anaesthesia Fee'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: isMobileDialog
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Save & Bill in Quick Bill'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSaving ? null : () async {
                            final tf = double.tryParse(theatreCtrl.text.trim()) ?? 0;
                            final sf = double.tryParse(surgeonCtrl.text.trim()) ?? 0;
                            final asf = hasAsst ? (double.tryParse(asstCtrl.text.trim()) ?? 0) : 0.0;
                            final anf = hasAnaesth ? (double.tryParse(anaesthCtrl.text.trim()) ?? 0) : 0.0;

                            setDlgState(() => isSaving = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(dCtx);

                            try {
                              final res = await _billingCtrl.updateOtCaseFees(
                                caseId: int.parse(caseId.toString()),
                                theatreFee: tf,
                                surgeonFee: sf,
                                assistantSurgeonFee: asf,
                                anaesthesiaFee: anf,
                              );
                              if (dCtx.mounted) navigator.pop();
                              if (mounted) {
                                _loadUnbilledOtCases();
                                final updatedCharges = Map<String, dynamic>.from(res['charges'] ?? {});
                                updatedCharges['patient_id'] = otc['patient_id'];
                                _loadOtCaseIntoQuickBill(updatedCharges);
                              }
                            } catch (e) {
                              if (dialogContext.mounted) setDlgState(() => isSaving = false);
                              messenger.showSnackBar(SnackBar(content: Text('Error updating fees: $e'), backgroundColor: Colors.red));
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving ? null : () => Navigator.pop(dCtx),
                              style: AppTheme.cancelButton,
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 16),
                              label: const Text('Save Fees'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(color: AppTheme.primaryColor),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: isSaving ? null : () async {
                                final tf = double.tryParse(theatreCtrl.text.trim()) ?? 0;
                                final sf = double.tryParse(surgeonCtrl.text.trim()) ?? 0;
                                final asf = hasAsst ? (double.tryParse(asstCtrl.text.trim()) ?? 0) : 0.0;
                                final anf = hasAnaesth ? (double.tryParse(anaesthCtrl.text.trim()) ?? 0) : 0.0;

                                setDlgState(() => isSaving = true);
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(dCtx);

                                try {
                                  final res = await _billingCtrl.updateOtCaseFees(
                                    caseId: int.parse(caseId.toString()),
                                    theatreFee: tf,
                                    surgeonFee: sf,
                                    assistantSurgeonFee: asf,
                                    anaesthesiaFee: anf,
                                  );
                                  if (dCtx.mounted) navigator.pop();
                                  if (mounted) {
                                    _loadUnbilledOtCases();
                                    onUpdated?.call();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('OT Case ${otc['case_number'] ?? ''} fees updated successfully! Total: ₹${res['charges']?['subtotal'] ?? calcTotal()}'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (dialogContext.mounted) setDlgState(() => isSaving = false);
                                  messenger.showSnackBar(SnackBar(content: Text('Error updating fees: $e'), backgroundColor: Colors.red));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ]
                  : [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(dCtx),
                            style: AppTheme.cancelButton,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 16),
                            label: const Text('Save Fees'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.primaryColor),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isSaving ? null : () async {
                              final tf = double.tryParse(theatreCtrl.text.trim()) ?? 0;
                              final sf = double.tryParse(surgeonCtrl.text.trim()) ?? 0;
                              final asf = hasAsst ? (double.tryParse(asstCtrl.text.trim()) ?? 0) : 0.0;
                              final anf = hasAnaesth ? (double.tryParse(anaesthCtrl.text.trim()) ?? 0) : 0.0;

                              setDlgState(() => isSaving = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(dCtx);

                              try {
                                final res = await _billingCtrl.updateOtCaseFees(
                                  caseId: int.parse(caseId.toString()),
                                  theatreFee: tf,
                                  surgeonFee: sf,
                                  assistantSurgeonFee: asf,
                                  anaesthesiaFee: anf,
                                );
                                if (dCtx.mounted) navigator.pop();
                                if (mounted) {
                                  _loadUnbilledOtCases();
                                  onUpdated?.call();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('OT Case ${otc['case_number'] ?? ''} fees updated successfully! Total: ₹${res['charges']?['subtotal'] ?? calcTotal()}'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (dialogContext.mounted) setDlgState(() => isSaving = false);
                                messenger.showSnackBar(SnackBar(content: Text('Error updating fees: $e'), backgroundColor: Colors.red));
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.receipt_long, size: 16),
                            label: const Text('Save & Bill in Quick Bill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isSaving ? null : () async {
                              final tf = double.tryParse(theatreCtrl.text.trim()) ?? 0;
                              final sf = double.tryParse(surgeonCtrl.text.trim()) ?? 0;
                              final asf = hasAsst ? (double.tryParse(asstCtrl.text.trim()) ?? 0) : 0.0;
                              final anf = hasAnaesth ? (double.tryParse(anaesthCtrl.text.trim()) ?? 0) : 0.0;

                              setDlgState(() => isSaving = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(dCtx);

                              try {
                                final res = await _billingCtrl.updateOtCaseFees(
                                  caseId: int.parse(caseId.toString()),
                                  theatreFee: tf,
                                  surgeonFee: sf,
                                  assistantSurgeonFee: asf,
                                  anaesthesiaFee: anf,
                                );
                                if (dCtx.mounted) navigator.pop();
                                if (mounted) {
                                  _loadUnbilledOtCases();
                                  final updatedCharges = Map<String, dynamic>.from(res['charges'] ?? {});
                                  updatedCharges['patient_id'] = otc['patient_id'];
                                  _loadOtCaseIntoQuickBill(updatedCharges);
                                }
                              } catch (e) {
                                if (dialogContext.mounted) setDlgState(() => isSaving = false);
                                messenger.showSnackBar(SnackBar(content: Text('Error updating fees: $e'), backgroundColor: Colors.red));
                              }
                            },
                          ),
                        ],
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _loadOtCaseIntoQuickBill(Map<String, dynamic> otc) {
    final patientId = otc['patient_id'];
    PatientModel? matchedPatient;
    try {
      matchedPatient = _patients.firstWhere((p) => p.id == patientId);
    } catch (_) {}

    final items = List<Map<String, dynamic>>.from(otc['items'] ?? []);

    setState(() {
      if (matchedPatient != null) {
        _qbSelectedPatient = matchedPatient;
      }
      _qbSelectedOtCaseId = otc['id'];
      _qbSelectedItems = items.map((it) => {
        'service_id': it['service_id'],
        'item_name': it['item_name'],
        'unit_price': double.tryParse((it['unit_price'] ?? 0).toString()) ?? 0.0,
        'quantity': it['quantity'] ?? 1,
        'subtotal': double.tryParse((it['subtotal'] ?? 0).toString()) ?? 0.0,
        'category': it['category'] ?? 'OT',
      }).toList();
      _qbVisitType = 'OP';
    });

    if (_tabController != null && _tabController!.index != 0) {
      _tabController!.animateTo(0);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${items.length} surgical charges for OT Case ${otc['case_number'] ?? ''}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showUnbilledOtCasesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final bool isMobileDialog = MediaQuery.of(ctx).size.width < 620;

        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobileDialog ? 12.0 : 40.0,
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medical_services_outlined, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Unbilled Operation Theatre Cases',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Container(
            width: isMobileDialog ? double.maxFinite : 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            child: _unbilledOtCases.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('No pending unbilled OT cases found.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _unbilledOtCases.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (c, i) {
                      final otc = _unbilledOtCases[i];
                      final items = List<Map<String, dynamic>>.from(otc['items'] ?? []);
                      final double subtotal = double.tryParse((otc['subtotal'] ?? 0).toString()) ?? 0.0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Case Number, Patient Name & Amount
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${otc['case_number'] ?? 'OT Case'} • ${otc['patient_name'] ?? 'Patient'} (${otc['patient_display_id'] ?? ''})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.secondaryColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Procedure: ${otc['surgery_type'] ?? '-'} • Theatre: ${otc['theatre_name'] ?? otc['ot_room'] ?? 'OT'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lead Surgeon: Dr. ${otc['lead_surgeon'] ?? '-'} • Anaesthetist: Dr. ${otc['anaesthetist'] ?? '-'}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor),
                            ),
                            if (items.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: items.map((it) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      '${it['item_name'] ?? 'Item'}: ₹${it['unit_price'] ?? 0}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_note, size: 15),
                                    label: const Text('Edit Fees'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      side: const BorderSide(color: AppTheme.primaryColor),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _showEditOtCaseFeesDialog(otc, onUpdated: () {
                                        _loadUnbilledOtCases();
                                        _showUnbilledOtCasesDialog();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.receipt_long, size: 16),
                                    label: const Text('Bill OT Case'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                      if (mounted) {
                                        _loadOtCaseIntoQuickBill(otc);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: AppTheme.cancelButton,
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  
  int _calcDrugQuantity(String freq, String dur) {
    int daily = 1;
    final f = freq.toLowerCase().trim();
    if (f.contains('1-0-1') || f.contains('twice') || f.contains('bd') || f.contains('bid')) {
      daily = 2;
    } else if (f.contains('1-1-1') || f.contains('thrice') || f.contains('tds') || f.contains('tid')) {
      daily = 3;
    } else if (f.contains('1-1-1-1') || f.contains('four') || f.contains('qid')) {
      daily = 4;
    } else if (f.contains('1-0-0') || f.contains('0-0-1') || f.contains('once') || f.contains('od')) {
      daily = 1;
    } else {
      final m = RegExp(r'(\d+)\s*time').firstMatch(f);
      if (m != null) daily = int.tryParse(m.group(1) ?? '1') ?? 1;
    }

    int days = 1;
    final d = dur.toLowerCase().trim();
    final mDur = RegExp(r'(\d+)').firstMatch(d);
    if (mDur != null) {
      final num = int.tryParse(mDur.group(1) ?? '1') ?? 1;
      if (d.contains('week')) {
        days = num * 7;
      } else if (d.contains('month')) {
        days = num * 30;
      } else {
        days = num;
      }
    } else {
      if (d.contains('week')) days = 7;
      else if (d.contains('month')) days = 30;
      else days = 5;
    }
    return (daily * days).clamp(1, 500);
  }

  Widget _buildPharmacyBillingTab(bool isMobile) {
    // Filter prescriptions
    final filtered = _pharmacyPrescriptions.where((p) {
      final q = _pharmacySearch.toLowerCase();
      final pName = (p['patient_name'] ?? '').toString().toLowerCase();
      final pUhid = (p['patient_display_id'] ?? '').toString().toLowerCase();
      final docName = (p['doctor_name'] ?? '').toString().toLowerCase();
      final matchQ = pName.contains(q) || pUhid.contains(q) || docName.contains(q);
      if (!matchQ) return false;

      final stat = (p['pharmacy_status'] ?? 'Pending').toString();
      final isDone = stat == 'Billed' || stat == 'Dispensed';
      if (_pharmacyStatusFilter == 'Pending') return !isDone;
      if (_pharmacyStatusFilter == 'Dispensed') return isDone;
      return true;
    }).toList();

    final pendingCount = _pharmacyPrescriptions.where((p) {
      final s = (p['pharmacy_status'] ?? 'Pending').toString();
      return s != 'Billed' && s != 'Dispensed';
    }).length;

    final dispensedCount = _pharmacyPrescriptions.length - pendingCount;

    double pharmacyRev = 0;
    for (var inv in _invoices) {
      if ((inv['admission_type'] ?? '') == 'Pharmacy') {
        pharmacyRev += double.tryParse((inv['net_amount'] ?? 0).toString()) ?? 0.0;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 12.0 : 20.0, 10.0, isMobile ? 12.0 : 20.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header & Quick Stats Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text(
                    'Pharmacy Prescriptions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryColor),
                  ),
                  if (!isMobile) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text('$pendingCount Pending', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text('$dispensedCount Dispensed', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                      ),
                      child: Text('Sales: ₹${pharmacyRev.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ),
                  ],
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                label: Text(isMobile ? 'Walk-in Bill' : 'Walk-in Medicine Bill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                onPressed: () => _showWalkInPharmacyBillDialog(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Compact Search & Filter Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextFormField(
                    onChanged: (val) => setState(() => _pharmacySearch = val),
                    decoration: InputDecoration(
                      hintText: 'Search by Patient Name, UHID, Doctor...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 38,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentedFilterPill('Pending', 'Pending ($pendingCount)', _pharmacyStatusFilter, (v) => setState(() => _pharmacyStatusFilter = v)),
                    _buildSegmentedFilterPill('Dispensed', 'Dispensed ($dispensedCount)', _pharmacyStatusFilter, (v) => setState(() => _pharmacyStatusFilter = v)),
                    _buildSegmentedFilterPill('All', 'All (${_pharmacyPrescriptions.length})', _pharmacyStatusFilter, (v) => setState(() => _pharmacyStatusFilter = v)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 20),
                tooltip: 'Refresh Queue',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  _loadPrescriptions();
                  _loadMedicineInventory();
                  _loadInvoices();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Prescriptions List
          Expanded(
            child: _isLoadingPrescriptions
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.medication_liquid_rounded, size: 52, color: Color(0xFFDDD6FE)),
                            const SizedBox(height: 12),
                            Text('No prescriptions found in $_pharmacyStatusFilter queue.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final pres = filtered[index];
                          final items = (pres['items'] as List?) ?? [];
                          final stat = (pres['pharmacy_status'] ?? 'Pending').toString();
                          final bool isDone = stat == 'Billed' || stat == 'Dispensed';
                          final dateStr = pres['created_at'] != null
                              ? DateFormat('dd-MMM-yyyy • hh:mm a').format(DateTime.parse(pres['created_at']).toLocal())
                              : 'Recent';

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDone ? const Color(0xFFBBF7D0) : AppTheme.borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFF5F3FF),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isDone ? Icons.check_circle_rounded : Icons.medication_rounded,
                                          color: isDone ? const Color(0xFF16A34A) : const Color(0xFF7C3AED),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              alignment: WrapAlignment.spaceBetween,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 6,
                                                  children: [
                                                    Text(
                                                      pres['patient_name'] ?? 'Patient',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                                    ),
                                                    if (pres['patient_display_id'] != null)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          pres['patient_display_id'].toString(),
                                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: isDone ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                                                  ),
                                                  child: Text(
                                                    isDone ? 'Billed & Dispensed' : 'Pending Dispense',
                                                    style: TextStyle(
                                                      color: isDone ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.person, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Prescribed by Dr. ${pres['doctor_name'] ?? 'Doctor'}',
                                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Prescribed Medicines Chips / List
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Prescribed Medications (${items.length}):',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: items.map((it) {
                                            final mName = it['name'] ?? it['medicine_name'] ?? 'Medicine';
                                            final dosage = it['dosage'] ?? '';
                                            final freq = it['frequency'] ?? '';
                                            final dur = it['duration'] ?? '';
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 4,
                                                runSpacing: 2,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.medication, size: 14, color: Color(0xFF7C3AED)),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        mName,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                                      ),
                                                    ],
                                                  ),
                                                  if (dosage.toString().isNotEmpty)
                                                    Text('($dosage)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                  if (freq.toString().isNotEmpty || dur.toString().isNotEmpty)
                                                    Text('• $freq • $dur', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Actions
                                  if (isMobile)
                                    SizedBox(
                                      width: double.infinity,
                                      child: !isDone
                                          ? ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryColor,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.receipt_long, size: 16),
                                              label: const Text('Generate Pharmacy Bill & Dispense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              onPressed: () => _showGeneratePharmacyBillDialog(pres),
                                            )
                                          : OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF16A34A),
                                                side: const BorderSide(color: Color(0xFF86EFAC)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                              label: const Text('Dispensed & Billed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              onPressed: () => _tabController?.animateTo(1),
                                            ),
                                    )
                                  else
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (!isDone)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.receipt_long, size: 16),
                                            label: const Text('Generate Pharmacy Bill & Dispense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            onPressed: () => _showGeneratePharmacyBillDialog(pres),
                                          )
                                        else
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF16A34A),
                                              side: const BorderSide(color: Color(0xFF86EFAC)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                            label: const Text('Dispensed & Billed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            onPressed: () => _tabController?.animateTo(1),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ─── PHARMACY BILLING CONFIRMATION DIALOG (MocDoc Itemized Review) ─────────
  void _showGeneratePharmacyBillDialog(Map<String, dynamic> pres) {
    final patientId = int.tryParse((pres['patient_id'] ?? '').toString());
    if (patientId == null || patientId <= 0) return;

    final rawItems = pres['items'] as List? ?? [];
    final List<Map<String, dynamic>> billItems = [];

    for (var it in rawItems) {
      final drugName = (it['name'] ?? it['medicine_name'] ?? '').toString();
      if (drugName.isEmpty) continue;
      final freq = (it['frequency'] ?? '').toString();
      final dur = (it['duration'] ?? '').toString();
      final qty = _calcDrugQuantity(freq, dur);

      double rate = 5.0;
      final invMatch = _medicineInventory.firstWhere(
        (m) => (m['name'] ?? '').toString().toLowerCase().contains(drugName.toLowerCase()) ||
               drugName.toLowerCase().contains((m['name'] ?? '').toString().toLowerCase()),
        orElse: () => {},
      );
      if (invMatch.isNotEmpty && invMatch['unit_price'] != null) {
        rate = double.tryParse(invMatch['unit_price'].toString()) ?? 5.0;
      } else {
        final catMatch = _catalogServices.firstWhere(
          (s) => s['category'] == 'Pharmacy' && (s['name'] ?? '').toString().toLowerCase().contains(drugName.toLowerCase()),
          orElse: () => {},
        );
        if (catMatch.isNotEmpty && catMatch['price'] != null) {
          rate = double.tryParse(catMatch['price'].toString()) ?? 5.0;
        }
      }

      billItems.add({
        'item_name': drugName,
        'quantity': qty,
        'unit_price': rate,
      });
    }

    if (billItems.isEmpty) {
      billItems.add({'item_name': 'Prescribed Medications', 'quantity': 1, 'unit_price': 50.0});
    }

    double discount = 0.0;
    String payMode = 'Cash';
    final TextEditingController discountCtrl = TextEditingController(text: '0');
    final TextEditingController paidCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            double subtotal = 0;
            for (var bi in billItems) {
              subtotal += (bi['quantity'] as int) * (bi['unit_price'] as double);
            }
            double net = (subtotal - discount).clamp(0.0, double.infinity);
            if (paidCtrl.text.isEmpty) {
              paidCtrl.text = net.toStringAsFixed(0);
            }

            final bool isMobileDialog = MediaQuery.of(ctx).size.width < 620;
            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobileDialog ? 12.0 : 40.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.medication_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate Pharmacy Bill - ${pres['patient_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'UHID: ${pres['patient_display_id'] ?? ''} • Dr. ${pres['doctor_name'] ?? 'Doctor'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? double.maxFinite : 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Itemized Medicines & Dispensing Charges:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: billItems.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 8),
                        itemBuilder: (c, idx) {
                          final item = billItems[idx];
                          final int q = item['quantity'] as int;
                          final double pr = item['unit_price'] as double;
                          final double rowTotal = q * pr;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['item_name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '₹${rowTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7C3AED)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Rate: ₹${pr.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setDlgState(() {
                                                if (q > 1) {
                                                  item['quantity'] = q - 1;
                                                } else {
                                                  billItems.removeAt(idx);
                                                }
                                                paidCtrl.text = '';
                                              });
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              child: Icon(Icons.remove, size: 16, color: Color(0xFF475569)),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text('$q', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              setDlgState(() {
                                                item['quantity'] = q + 1;
                                                paidCtrl.text = '';
                                              });
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              child: Icon(Icons.add, size: 16, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24, thickness: 1.2),

                      // Totals & Discount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount (₹):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          SizedBox(
                            width: 100,
                            height: 38,
                            child: TextFormField(
                              controller: discountCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setDlgState(() {
                                  discount = double.tryParse(val) ?? 0.0;
                                  paidCtrl.text = '';
                                });
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                fillColor: const Color(0xFFF1F5F9),
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF7C3AED))),
                          Text('₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF7C3AED))),
                        ],
                      ),
                      const Divider(height: 24),

                      // Payment Mode & Collection
                      const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Cash', 'Card', 'UPI', 'Insurance'].map((m) {
                          final isSel = payMode == m;
                          return ChoiceChip(
                            label: Text(m),
                            selected: isSel,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                            onSelected: (val) {
                              if (val) setDlgState(() => payMode = m);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Collected Amount (₹)'),
                                TextFormField(
                                  controller: paidCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: net.toStringAsFixed(0),
                                    fillColor: const Color(0xFFF1F5F9),
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
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
              actions: isMobileDialog
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Confirm & Print Pharmacy Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setDlgState(() => isSubmitting = true);
                                  final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                                  try {
                                    final res = await _billingCtrl.createInvoice(
                                      patientId: patientId,
                                      admissionType: 'Pharmacy',
                                      consultationId: int.tryParse(pres['id']?.toString() ?? ''),
                                      doctorName: pres['doctor_name']?.toString(),
                                      items: billItems,
                                      discount: discount,
                                      initialPayment: collected > 0 ? {
                                        'amount': collected,
                                        'payment_mode': payMode,
                                      } : null,
                                    );

                                    if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Pharmacy bill created & dispensed successfully!'), backgroundColor: Colors.green),
                                      );
                                      _loadInvoices();
                                      _loadPrescriptions();
                                      _loadMedicineInventory();
                                      _showInvoiceReceiptDialog(res['id']);
                                    }
                                  } catch (e) {
                                    if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                      ),
                    ]
                  : [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                            style: AppTheme.cancelButton,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.receipt_long, size: 18),
                            label: const Text('Confirm & Print Pharmacy Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDlgState(() => isSubmitting = true);
                                    final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                                    try {
                                      final res = await _billingCtrl.createInvoice(
                                        patientId: patientId,
                                        admissionType: 'Pharmacy',
                                        consultationId: int.tryParse(pres['id']?.toString() ?? ''),
                                        doctorName: pres['doctor_name']?.toString(),
                                        items: billItems,
                                        discount: discount,
                                        initialPayment: collected > 0 ? {
                                          'amount': collected,
                                          'payment_mode': payMode,
                                        } : null,
                                      );

                                      if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Pharmacy bill created & dispensed successfully!'), backgroundColor: Colors.green),
                                        );
                                        _loadInvoices();
                                        _loadPrescriptions();
                                        _loadMedicineInventory();
                                        _showInvoiceReceiptDialog(res['id']);
                                      }
                                    } catch (e) {
                                      if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  // ─── LAB BILLING TAB (MocDoc Lab Orders Queue & Billing) ─────────────────────
  Widget _buildLabBillingTab(bool isMobile) {
    // Filter lab requests
    final filtered = _labRequests.where((r) {
      final q = _labSearch.toLowerCase();
      final pName = (r['patient_name'] ?? '').toString().toLowerCase();
      final pUhid = (r['patient_display_id'] ?? '').toString().toLowerCase();
      final tName = (r['test_name'] ?? '').toString().toLowerCase();
      final docName = (r['doctor_name'] ?? '').toString().toLowerCase();
      final matchQ = pName.contains(q) || pUhid.contains(q) || tName.contains(q) || docName.contains(q);
      if (!matchQ) return false;

      final isBilled = r['is_billed'] == true;
      if (_labStatusFilter == 'Pending') return !isBilled;
      if (_labStatusFilter == 'Billed') return isBilled;
      return true;
    }).toList();

    final pendingCount = _labRequests.where((r) => r['is_billed'] != true).length;
    final billedCount = _labRequests.length - pendingCount;

    double labRev = 0;
    for (var inv in _invoices) {
      if ((inv['admission_type'] ?? '') == 'Lab') {
        labRev += double.tryParse((inv['net_amount'] ?? 0).toString()) ?? 0.0;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 12.0 : 20.0, 10.0, isMobile ? 12.0 : 20.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header & Quick Stats Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text(
                    'Lab Investigation Orders',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryColor),
                  ),
                  if (!isMobile) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text('$pendingCount Pending', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text('$billedCount Billed', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                      ),
                      child: Text('Revenue: ₹${labRev.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ),
                  ],
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.biotech_rounded, size: 16),
                label: Text(isMobile ? 'Walk-in Bill' : 'Walk-in Lab Bill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                onPressed: () => _showWalkInLabBillDialog(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Compact Search & Filter Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextFormField(
                    onChanged: (val) => setState(() => _labSearch = val),
                    decoration: InputDecoration(
                      hintText: 'Search by Patient Name, UHID, Doctor, or Test...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 38,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSegmentedFilterPill('Pending', 'Pending ($pendingCount)', _labStatusFilter, (v) => setState(() => _labStatusFilter = v)),
                    _buildSegmentedFilterPill('Billed', 'Billed ($billedCount)', _labStatusFilter, (v) => setState(() => _labStatusFilter = v)),
                    _buildSegmentedFilterPill('All', 'All (${_labRequests.length})', _labStatusFilter, (v) => setState(() => _labStatusFilter = v)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 20),
                tooltip: 'Refresh Queue',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  _loadLabRequests();
                  _loadCatalog();
                  _loadInvoices();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Lab Requests List
          Expanded(
            child: _isLoadingLabRequests
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.science_outlined, size: 52, color: Color(0xFFC7D2FE)),
                            const SizedBox(height: 12),
                            Text('No lab orders found in $_labStatusFilter queue.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final req = filtered[index];
                          final bool isBilled = req['is_billed'] == true;
                          final dateStr = req['created_at'] != null
                              ? DateFormat('dd-MMM-yyyy • hh:mm a').format(DateTime.parse(req['created_at']).toLocal())
                              : 'Recent';
                          final tName = req['test_name'] ?? 'Diagnostic Test';

                          // match catalog price
                          double catalogPrice = 350.0;
                          final match = _catalogServices.firstWhere(
                            (s) => s['category'] == 'Lab' && (s['name'] ?? '').toString().toLowerCase().contains(tName.toString().toLowerCase()),
                            orElse: () => {},
                          );
                          if (match.isNotEmpty && match['price'] != null) {
                            catalogPrice = double.tryParse(match['price'].toString()) ?? 350.0;
                          }

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isBilled ? const Color(0xFFBBF7D0) : AppTheme.borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isBilled ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isBilled ? Icons.check_circle_rounded : Icons.biotech_rounded,
                                          color: isBilled ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              alignment: WrapAlignment.spaceBetween,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 6,
                                                  children: [
                                                    Text(
                                                      req['patient_name'] ?? 'Patient',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                                    ),
                                                    if (req['patient_display_id'] != null)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          req['patient_display_id'].toString(),
                                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isBilled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: isBilled ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                                                  ),
                                                  child: Text(
                                                    isBilled ? 'Billed' : 'Pending Billing',
                                                    style: TextStyle(
                                                      color: isBilled ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.person, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Ordered by Dr. ${req['doctor_name'] ?? 'Doctor'}',
                                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Test Details Card
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          children: [
                                            const Icon(Icons.science, size: 16, color: Color(0xFF4F46E5)),
                                            Text(
                                              tName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
                                            ),
                                            if (req['status'] != null)
                                              Text('• Status: ${req['status']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                        Text(
                                          'Rate: ₹${catalogPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4F46E5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Actions
                                  if (isMobile)
                                    SizedBox(
                                      width: double.infinity,
                                      child: !isBilled
                                          ? ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryColor,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.receipt_long, size: 16),
                                              label: const Text('Generate Lab Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              onPressed: () => _showGenerateLabBillDialog(req),
                                            )
                                          : OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF16A34A),
                                                side: const BorderSide(color: Color(0xFF86EFAC)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                              label: const Text('Billed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              onPressed: () {
                                                if (req['invoice_id'] != null) {
                                                  _showInvoiceReceiptDialog(req['invoice_id']);
                                                }
                                              },
                                            ),
                                    )
                                  else
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (!isBilled)
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.receipt_long, size: 16),
                                            label: const Text('Generate Lab Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            onPressed: () => _showGenerateLabBillDialog(req),
                                          )
                                        else
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF16A34A),
                                              side: const BorderSide(color: Color(0xFF86EFAC)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                            label: const Text('Billed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            onPressed: () {
                                              if (req['invoice_id'] != null) {
                                                _showInvoiceReceiptDialog(req['invoice_id']);
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ─── LAB BILLING CONFIRMATION DIALOG ───────────────────────────────────────
  void _showGenerateLabBillDialog(Map<String, dynamic> req) {
    final patientId = int.tryParse((req['patient_id'] ?? '').toString());
    if (patientId == null || patientId <= 0) return;

    final tName = req['test_name'] ?? 'Diagnostic Test';
    double catalogPrice = 350.0;
    final match = _catalogServices.firstWhere(
      (s) => s['category'] == 'Lab' && (s['name'] ?? '').toString().toLowerCase().contains(tName.toString().toLowerCase()),
      orElse: () => {},
    );
    if (match.isNotEmpty && match['price'] != null) {
      catalogPrice = double.tryParse(match['price'].toString()) ?? 350.0;
    }

    final List<Map<String, dynamic>> billItems = [
      {
        'service_id': match['id'],
        'item_name': tName,
        'quantity': 1,
        'unit_price': catalogPrice,
      }
    ];

    double discount = 0.0;
    String payMode = 'Cash';
    final TextEditingController discountCtrl = TextEditingController(text: '0');
    final TextEditingController paidCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            double subtotal = 0;
            for (var bi in billItems) {
              subtotal += (bi['quantity'] as int) * (bi['unit_price'] as double);
            }
            double net = (subtotal - discount).clamp(0.0, double.infinity);
            if (paidCtrl.text.isEmpty) {
              paidCtrl.text = net.toStringAsFixed(0);
            }

            final bool isMobileDialog = MediaQuery.of(ctx).size.width < 620;
            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobileDialog ? 12.0 : 40.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.biotech_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate Lab Diagnostics Bill - ${req['patient_name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'UHID: ${req['patient_display_id'] ?? ''} • Dr. ${req['doctor_name'] ?? 'Doctor'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? double.maxFinite : 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Investigation Tests to Bill:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: billItems.length,
                        separatorBuilder: (c, i) => const Divider(height: 12),
                        itemBuilder: (c, idx) {
                          final item = billItems[idx];
                          final double pr = item['unit_price'] as double;

                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text('₹${pr.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4F46E5))),
                              ),
                              if (billItems.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () {
                                    setDlgState(() {
                                      billItems.removeAt(idx);
                                      paidCtrl.text = '';
                                    });
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Add Additional Lab Service dropdown
                      Row(
                        children: [
                          Expanded(
                            child: CustomDropdownSearch(
                              label: '',
                              hint: '+ Add Another Lab Test',
                              clearOnSelect: true,
                              dropdownMap: {
                                for (var s in _catalogServices.where((x) => x['category'] == 'Lab'))
                                  s['id'].toString(): '${s['name']} (₹${s['price']})'
                              },
                              onChanged: (val) {
                                if (val != null) {
                                  final svc = _catalogServices.firstWhere((s) => s['id'].toString() == val);
                                  setDlgState(() {
                                    final exists = billItems.any((x) => x['service_id'] == svc['id'] || x['item_name'] == svc['name']);
                                    if (!exists) {
                                      billItems.add({
                                        'service_id': svc['id'],
                                        'item_name': svc['name'],
                                        'quantity': 1,
                                        'unit_price': double.tryParse(svc['price'].toString()) ?? 350.0,
                                      });
                                      paidCtrl.text = '';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1.2),

                      // Totals & Discount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount (₹):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          SizedBox(
                            width: 100,
                            height: 38,
                            child: TextFormField(
                              controller: discountCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                setDlgState(() {
                                  discount = double.tryParse(val) ?? 0.0;
                                  paidCtrl.text = '';
                                });
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                fillColor: const Color(0xFFF1F5F9),
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4F46E5))),
                          Text('₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4F46E5))),
                        ],
                      ),
                      const Divider(height: 24),

                      // Payment Mode & Collection
                      const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['Cash', 'Card', 'UPI', 'Insurance'].map((m) {
                          final isSel = payMode == m;
                          return ChoiceChip(
                            label: Text(m),
                            selected: isSel,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                            onSelected: (val) {
                              if (val) setDlgState(() => payMode = m);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Collected Amount (₹)'),
                                TextFormField(
                                  controller: paidCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: net.toStringAsFixed(0),
                                    fillColor: const Color(0xFFF1F5F9),
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
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
              actions: isMobileDialog
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Confirm & Print Lab Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setDlgState(() => isSubmitting = true);
                                  final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                                  try {
                                    final res = await _billingCtrl.createInvoice(
                                      patientId: patientId,
                                      admissionType: 'Lab',
                                      labRequestIds: [int.tryParse(req['id']?.toString() ?? '') ?? 0],
                                      doctorName: req['doctor_name']?.toString(),
                                      items: billItems,
                                      discount: discount,
                                      initialPayment: collected > 0 ? {
                                        'amount': collected,
                                        'payment_mode': payMode,
                                      } : null,
                                    );

                                    if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Lab diagnostics bill created successfully!'), backgroundColor: Colors.green),
                                      );
                                      _loadInvoices();
                                      _loadLabRequests();
                                      _showInvoiceReceiptDialog(res['id']);
                                    }
                                  } catch (e) {
                                    if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                        style: AppTheme.cancelButton,
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Confirm & Print Lab Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setDlgState(() => isSubmitting = true);
                                final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                                try {
                                  final res = await _billingCtrl.createInvoice(
                                    patientId: patientId,
                                    admissionType: 'Lab',
                                    labRequestIds: [int.tryParse(req['id']?.toString() ?? '') ?? 0],
                                    doctorName: req['doctor_name']?.toString(),
                                    items: billItems,
                                    discount: discount,
                                    initialPayment: collected > 0 ? {
                                      'amount': collected,
                                      'payment_mode': payMode,
                                    } : null,
                                  );

                                  if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Lab diagnostics bill created successfully!'), backgroundColor: Colors.green),
                                    );
                                    _loadInvoices();
                                    _loadLabRequests();
                                    _showInvoiceReceiptDialog(res['id']);
                                  }
                                } catch (e) {
                                  if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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

  // Helper class for department badges



  // ─── DIRECT / WALK-IN PHARMACY BILLING DIALOG ─────────────────────────────
  void _showWalkInPharmacyBillDialog() {
    PatientModel? selectedPatient;
    final List<Map<String, dynamic>> items = [];
    String? selectedMedId;
    String? medName;
    bool isCustom = false;
    final TextEditingController customCtrl = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController();
    final TextEditingController qtyCtrl = TextEditingController(text: '1');
    final TextEditingController discountCtrl = TextEditingController(text: '0');
    final TextEditingController paidCtrl = TextEditingController();
    String payMode = 'Cash';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            double subtotal = 0;
            for (var it in items) {
              subtotal += (it['unit_price'] as double) * (it['quantity'] as int);
            }
            final discount = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
            final net = (subtotal - discount).clamp(0.0, double.infinity);
            if (paidCtrl.text.isEmpty) paidCtrl.text = net.toStringAsFixed(0);

            final bool isMobileDialog = MediaQuery.of(ctx).size.width < 620;
            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobileDialog ? 12.0 : 40.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF7C3AED), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Walk-in Pharmacy Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? double.maxFinite : 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Select Patient *'),
                      CustomDropdownSearch(
                        label: '',
                        hint: 'Choose Patient',
                        value: selectedPatient?.id?.toString(),
                        dropdownMap: {
                          for (var p in _patients)
                            p.id.toString(): '${p.name} (${p.patientId}) - ${p.phone}'
                        },
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() {
                              selectedPatient = _patients.firstWhere((pt) => pt.id.toString() == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Add Medicine'),
                      Row(
                        children: [
                          Checkbox(
                            value: isCustom,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) {
                              setDlgState(() {
                                isCustom = val ?? false;
                                selectedMedId = null;
                                medName = null;
                                customCtrl.clear();
                              });
                            },
                          ),
                          const Text('Custom Medicine (Non-Inventory)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: isCustom
                                ? TextFormField(
                                    controller: customCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Medicine Name',
                                      fillColor: const Color(0xFFF1F5F9),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  )
                                : CustomDropdownSearch(
                                    label: '',
                                    hint: 'Select Medicine',
                                    value: selectedMedId,
                                    dropdownMap: {
                                      for (var med in _medicineInventory)
                                        med['id'].toString(): '${med['name']} (${med['quantity']} in stock)'
                                    },
                                    onChanged: (val) {
                                      if (val != null) {
                                        final med = _medicineInventory.firstWhere((m) => m['id'].toString() == val);
                                        setDlgState(() {
                                          selectedMedId = val;
                                          medName = med['name'];
                                          priceCtrl.text = (med['unit_price'] ?? '5.0').toString();
                                        });
                                      }
                                    },
                                  ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: 'Price',
                                fillColor: const Color(0xFFF1F5F9),
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Qty',
                                fillColor: const Color(0xFFF1F5F9),
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF7C3AED), size: 32),
                            onPressed: () {
                              final name = isCustom ? customCtrl.text.trim() : (medName ?? '');
                              final pr = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                              final qt = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                              if (name.isEmpty || pr <= 0) return;
                              setDlgState(() {
                                items.add({
                                  'item_name': name,
                                  'unit_price': pr,
                                  'quantity': qt,
                                });
                                selectedMedId = null;
                                medName = null;
                                customCtrl.clear();
                                priceCtrl.clear();
                                qtyCtrl.text = '1';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (items.isNotEmpty) ...[
                        const Text('Billed Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final it = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(it['item_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                Text('${it['quantity']} x ₹${(it['unit_price'] as double).toStringAsFixed(2)} = ₹${((it['quantity'] as int) * (it['unit_price'] as double)).toStringAsFixed(2)}'),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () => setDlgState(() => items.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Payment Mode'),
                                  DropdownButtonFormField<String>(
                                    value: payMode,
                                    decoration: InputDecoration(
                                      fillColor: const Color(0xFFF1F5F9),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: ['Cash', 'UPI / QR', 'Card', 'Bank Transfer'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDlgState(() => payMode = val);
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
                                  _buildLabel('Paid Amount (₹)'),
                                  TextFormField(
                                    controller: paidCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      fillColor: const Color(0xFFF1F5F9),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: isMobileDialog
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Create Pharmacy Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: (isSubmitting || selectedPatient == null || items.isEmpty)
                              ? null
                              : () async {
                                  setDlgState(() => isSubmitting = true);
                                  final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                                  try {
                                    final res = await _billingCtrl.createInvoice(
                                      patientId: selectedPatient!.id!,
                                      admissionType: 'Pharmacy',
                                      items: items,
                                      discount: discount,
                                      initialPayment: collected > 0 ? {
                                        'amount': collected,
                                        'payment_mode': payMode,
                                      } : null,
                                    );

                                    if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Walk-in Pharmacy Bill created successfully!'), backgroundColor: Colors.green),
                                      );
                                      _loadInvoices();
                                      _loadMedicineInventory();
                                      if (res['id'] != null) {
                                        _showInvoiceReceiptDialog(res['id']);
                                      }
                                    }
                                  } catch (e) {
                                    if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                        style: AppTheme.cancelButton,
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Create Pharmacy Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: (isSubmitting || selectedPatient == null || items.isEmpty)
                            ? null
                            : () async {
                          setDlgState(() => isSubmitting = true);
                          final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                          try {
                            final res = await _billingCtrl.createInvoice(
                              patientId: selectedPatient!.id!,
                              admissionType: 'Pharmacy',
                              items: items,
                              discount: discount,
                              initialPayment: collected > 0 ? {
                                'amount': collected,
                                'payment_mode': payMode,
                              } : null,
                            );

                            if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pharmacy bill created successfully!'), backgroundColor: Colors.green),
                              );
                              _loadInvoices();
                              _loadPrescriptions();
                              _showInvoiceReceiptDialog(res['id']);
                            }
                          } catch (e) {
                            if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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

  // ─── DIRECT / WALK-IN LAB BILLING DIALOG ───────────────────────────────────
  void _showWalkInLabBillDialog() {
    PatientModel? selectedPatient;
    final List<Map<String, dynamic>> items = [];
    final TextEditingController discountCtrl = TextEditingController(text: '0');
    final TextEditingController paidCtrl = TextEditingController();
    String payMode = 'Cash';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            double subtotal = 0;
            for (var it in items) {
              subtotal += (it['unit_price'] as double) * (it['quantity'] as int);
            }
            final discount = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
            final net = (subtotal - discount).clamp(0.0, double.infinity);
            if (paidCtrl.text.isEmpty) paidCtrl.text = net.toStringAsFixed(0);

            final bool isMobileDialog = MediaQuery.of(ctx).size.width < 620;
            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobileDialog ? 12.0 : 40.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.biotech_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Walk-in Lab Diagnostics Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? double.maxFinite : 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Select Patient *'),
                      CustomDropdownSearch(
                        label: '',
                        hint: 'Choose Patient',
                        value: selectedPatient?.id?.toString(),
                        dropdownMap: {
                          for (var p in _patients)
                            p.id.toString(): '${p.name} (${p.patientId}) - ${p.phone}'
                        },
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() {
                              selectedPatient = _patients.firstWhere((pt) => pt.id.toString() == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Add Lab Diagnostic Test'),
                      CustomDropdownSearch(
                        label: '',
                        hint: 'Select Lab Test from Catalog',
                        clearOnSelect: true,
                        dropdownMap: {
                          for (var s in _catalogServices.where((x) => x['category'] == 'Lab'))
                            s['id'].toString(): '${s['name']} (₹${s['price']})'
                        },
                        onChanged: (val) {
                          if (val != null) {
                            final svc = _catalogServices.firstWhere((s) => s['id'].toString() == val);
                            setDlgState(() {
                              final exists = items.any((x) => x['service_id'] == svc['id'] || x['item_name'] == svc['name']);
                              if (!exists) {
                                items.add({
                                  'service_id': svc['id'],
                                  'item_name': svc['name'],
                                  'unit_price': double.tryParse(svc['price'].toString()) ?? 350.0,
                                  'quantity': 1,
                                });
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      if (items.isNotEmpty) ...[
                        const Text('Selected Diagnostic Tests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final it = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(it['item_name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                Text('₹${(it['unit_price'] as double).toStringAsFixed(2)}'),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () => setDlgState(() => items.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Payment Mode'),
                                  DropdownButtonFormField<String>(
                                    value: payMode,
                                    decoration: InputDecoration(
                                      fillColor: const Color(0xFFF1F5F9),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    items: ['Cash', 'UPI / QR', 'Card', 'Bank Transfer'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDlgState(() => payMode = val);
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
                                  _buildLabel('Paid Amount (₹)'),
                                  TextFormField(
                                    controller: paidCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      fillColor: const Color(0xFFF1F5F9),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: isMobileDialog
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Create Lab Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: (isSubmitting || selectedPatient == null || items.isEmpty)
                              ? null
                              : () async {
                                  setDlgState(() => isSubmitting = true);
                                  final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                                  try {
                                    final res = await _billingCtrl.createInvoice(
                                      patientId: selectedPatient!.id!,
                                      admissionType: 'Lab',
                                      items: items,
                                      discount: discount,
                                      initialPayment: collected > 0 ? {
                                        'amount': collected,
                                        'payment_mode': payMode,
                                      } : null,
                                    );

                                    if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Walk-in Lab Bill created successfully!'), backgroundColor: Colors.green),
                                      );
                                      _loadInvoices();
                                      _loadLabRequests();
                                      if (res['id'] != null) {
                                        _showInvoiceReceiptDialog(res['id']);
                                      }
                                    }
                                  } catch (e) {
                                    if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                        style: AppTheme.cancelButton,
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Create Lab Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: (isSubmitting || selectedPatient == null || items.isEmpty)
                            ? null
                            : () async {
                          setDlgState(() => isSubmitting = true);
                          final double collected = double.tryParse(paidCtrl.text.trim()) ?? net;
                          try {
                            final res = await _billingCtrl.createInvoice(
                              patientId: selectedPatient!.id!,
                              admissionType: 'Lab',
                              items: items,
                              discount: discount,
                              initialPayment: collected > 0 ? {
                                'amount': collected,
                                'payment_mode': payMode,
                              } : null,
                            );

                            if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lab bill created successfully!'), backgroundColor: Colors.green),
                              );
                              _loadInvoices();
                              _loadLabRequests();
                              _showInvoiceReceiptDialog(res['id']);
                            }
                          } catch (e) {
                            if (dlgCtx.mounted) setDlgState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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


  Widget _buildSegmentedFilterPill(String key, String label, String currentVal, Function(String) onSelect) {
    final bool isSelected = currentVal == key;
    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // 3. IP Billing Tab
  Widget _buildIpBillingTab(bool isMobile) {
    final filtered = _ipAdmissions.where((adm) {
      final q = _ipSearch.toLowerCase();
      return (adm['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
             (adm['patient_display_id'] ?? '').toString().toLowerCase().contains(q) ||
             (adm['bed_number'] ?? '').toString().toLowerCase().contains(q) ||
             (adm['ward_type'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  onChanged: (val) => setState(() => _ipSearch = val),
                  decoration: const InputDecoration(
                    hintText: 'Search IP cases by Patient, Bed, or Ward...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _loadIpAdmissions,
              )
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingAdmissions
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(child: Text('No Inpatient (IPD) cases found.', style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final adm = filtered[index];
                          final active = adm['status'] == 'Admitted' || adm['status'] == 'Pending Allocation';
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: isMobile
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  Text(
                                                    adm['patient_name'] ?? 'Unknown',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                  Text(
                                                    '(${adm['patient_display_id'] ?? ''})',
                                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildIpdStatusBadge(adm['status']),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Ward: ${adm['ward_type'] ?? '--'} | Bed: ${adm['bed_number'] ?? 'Unallocated'}\n'
                                          'Admission Date: ${adm['admission_date'] != null ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(adm['admission_date']).toLocal()) : '--'}',
                                          style: const TextStyle(height: 1.3, fontSize: 13, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: active ? AppTheme.primaryColor : Colors.grey.shade100,
                                              foregroundColor: active ? Colors.white : Colors.black87,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: Icon(active ? Icons.receipt_long : Icons.visibility_outlined, size: 16),
                                            label: Text(active ? 'Worksheet' : 'Receipt'),
                                            onPressed: () => _openIpBillingWorksheet(adm),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(adm['patient_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                  const SizedBox(width: 8),
                                                  Text('(${adm['patient_display_id'] ?? ''})', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                                  const SizedBox(width: 12),
                                                  _buildIpdStatusBadge(adm['status']),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Ward: ${adm['ward_type'] ?? '--'} | Bed: ${adm['bed_number'] ?? 'Unallocated'}\n'
                                                'Admission Date: ${adm['admission_date'] != null ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(adm['admission_date']).toLocal()) : '--'}',
                                                style: const TextStyle(height: 1.3),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: active ? AppTheme.primaryColor : Colors.grey.shade100,
                                            foregroundColor: active ? Colors.white : Colors.black87,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: Icon(active ? Icons.receipt_long : Icons.visibility_outlined, size: 16),
                                          label: Text(active ? 'Worksheet' : 'Receipt'),
                                          onPressed: () => _openIpBillingWorksheet(adm),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ─── OT BILLING TAB (Dedicated MocDoc-Style Operation Theatre Billing) ────────
  Widget _buildOtBillingTab(bool isMobile) {
    final allCases = _otBillingCases;
    final unbilledList = allCases.where((c) => c['is_billed'] != true).toList();
    final billedList = allCases.where((c) => c['is_billed'] == true).toList();

    final double totalUnbilledAmt = unbilledList.fold(0.0, (sum, c) => sum + (double.tryParse((c['subtotal'] ?? 0).toString()) ?? 0.0));
    final double totalBilledAmt = billedList.fold(0.0, (sum, c) => sum + (double.tryParse((c['invoice_net_amount'] ?? c['subtotal'] ?? 0).toString()) ?? 0.0));

    final filtered = allCases.where((c) {
      if (_otBillingFilter == 'Unbilled' && c['is_billed'] == true) return false;
      if (_otBillingFilter == 'Billed' && c['is_billed'] != true) return false;

      if (_otBillingSearch.trim().isNotEmpty) {
        final q = _otBillingSearch.trim().toLowerCase();
        final caseNum = (c['case_number'] ?? c['ot_case_id'] ?? '').toString().toLowerCase();
        final patName = (c['patient_name'] ?? '').toString().toLowerCase();
        final patId = (c['patient_display_id'] ?? '').toString().toLowerCase();
        final surg = (c['surgery_type'] ?? '').toString().toLowerCase();
        final doc = (c['lead_surgeon'] ?? c['surgeon'] ?? '').toString().toLowerCase();
        final th = (c['theatre_name'] ?? '').toString().toLowerCase();
        return caseNum.contains(q) || patName.contains(q) || patId.contains(q) || surg.contains(q) || doc.contains(q) || th.contains(q);
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadOtBillingCases,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14.0 : 22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Stat Summary
            isMobile
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Total Cases', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
                              const SizedBox(height: 3),
                              Text('${allCases.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              const SizedBox(height: 1),
                              const Text('Booked', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                              const SizedBox(height: 3),
                              Text('${unbilledList.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                              const SizedBox(height: 1),
                              Text('₹${totalUnbilledAmt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                            ],
                          ),
                        ),
                        Container(height: 32, width: 1, color: const Color(0xFFE2E8F0)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Billed OT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                              const SizedBox(height: 3),
                              Text('${billedList.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              const SizedBox(height: 1),
                              Text('₹${totalBilledAmt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (ctx, constraints) {
                      final cardWidth = constraints.maxWidth > 900
                          ? (constraints.maxWidth - 24) / 3
                          : (constraints.maxWidth > 600 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth);

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildOtStatCard(
                            title: 'All Surgical Cases',
                            value: '${allCases.length}',
                            subtitle: 'Total booked & performed',
                            icon: Icons.medical_services_outlined,
                            color: AppTheme.primaryColor,
                            width: cardWidth,
                          ),
                          _buildOtStatCard(
                            title: 'Pending Unbilled Cases',
                            value: '${unbilledList.length}',
                            subtitle: 'Est. ₹${totalUnbilledAmt.toStringAsFixed(0)} pending',
                            icon: Icons.pending_actions_outlined,
                            color: const Color(0xFFD97706),
                            width: cardWidth,
                          ),
                          _buildOtStatCard(
                            title: 'Billed OT Cases',
                            value: '${billedList.length}',
                            subtitle: '₹${totalBilledAmt.toStringAsFixed(0)} settled revenue',
                            icon: Icons.verified_outlined,
                            color: const Color(0xFF059669),
                            width: cardWidth,
                          ),
                        ],
                      );
                    },
                  ),
            const SizedBox(height: 14),

            // Search & Filter Controls
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                onChanged: (val) => setState(() => _otBillingSearch = val),
                                decoration: InputDecoration(
                                  hintText: 'Search Case #, Patient, Surgeon...',
                                  hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryColor),
                                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondaryColor),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Refresh OT Cases',
                              icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _loadOtBillingCases,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Pending OT Drawer',
                              icon: _isLoadingUnbilledOtCases
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                                  : const Icon(Icons.view_sidebar_outlined, color: AppTheme.primaryColor, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _isLoadingUnbilledOtCases ? null : _showUnbilledOtCasesDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildOtFilterChip('All', 'All (${allCases.length})'),
                              const SizedBox(width: 6),
                              _buildOtFilterChip('Unbilled', 'Pending (${unbilledList.length})'),
                              const SizedBox(width: 6),
                              _buildOtFilterChip('Billed', 'Billed (${billedList.length})'),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            onChanged: (val) => setState(() => _otBillingSearch = val),
                            decoration: InputDecoration(
                              hintText: 'Search by Case #, Patient Name, UHID, Surgery Type, or Surgeon...',
                              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondaryColor),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildOtFilterChip('All', 'All (${allCases.length})'),
                              const SizedBox(width: 6),
                              _buildOtFilterChip('Unbilled', 'Pending (${unbilledList.length})'),
                              const SizedBox(width: 6),
                              _buildOtFilterChip('Billed', 'Billed (${billedList.length})'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Refresh OT Cases',
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                          onPressed: _loadOtBillingCases,
                        ),
                        IconButton(
                          tooltip: 'Pending OT Drawer',
                          icon: _isLoadingUnbilledOtCases
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
                              : const Icon(Icons.view_sidebar_outlined, color: AppTheme.primaryColor),
                          onPressed: _isLoadingUnbilledOtCases ? null : _showUnbilledOtCasesDialog,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Main List Content
            Expanded(
              child: _isLoadingOtBillingCases
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medical_information_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('No OT surgical cases found matching criteria', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('Refresh Cases'),
                                onPressed: _loadOtBillingCases,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) => _buildOtCaseCard(filtered[idx], isMobile),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtFilterChip(String key, String label) {
    final bool isSelected = _otBillingFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppTheme.primaryColor : const Color(0xFF475569),
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
      ),
      onSelected: (val) {
        if (val) setState(() => _otBillingFilter = key);
      },
    );
  }

  Widget _buildOtCaseCard(Map<String, dynamic> otc, bool isMobile) {
    final bool isBilled = otc['is_billed'] == true;
    final double subtotal = double.tryParse((otc['subtotal'] ?? 0).toString()) ?? 0.0;
    final double theatreFee = double.tryParse((otc['theatre_fee'] ?? 0).toString()) ?? 0.0;
    final double surgeonFee = double.tryParse((otc['surgeon_fee'] ?? 0).toString()) ?? 0.0;
    final double asstFee = double.tryParse((otc['assistant_surgeon_fee'] ?? 0).toString()) ?? 0.0;
    final double anaesthFee = double.tryParse((otc['anaesthesia_fee'] ?? 0).toString()) ?? 0.0;

    final String dateStr = otc['surgery_date_time'] != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.parse(otc['surgery_date_time'].toString()).toLocal())
        : (otc['created_at'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(otc['created_at'].toString()).toLocal()) : '-');

    final bool isIp = otc['admission_id'] != null;

    final pac = (otc['pac_status'] ?? 'Pending').toString();
    Color pacColor = const Color(0xFFD97706);
    if (pac == 'Cleared') pacColor = const Color(0xFF059669);
    if (pac == 'High Risk') pacColor = AppTheme.dangerColor;

    final items = List<Map<String, dynamic>>.from(otc['items'] ?? []);

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isBilled ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD),
          width: isBilled ? 1.0 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Case ID, Date, Theatre, IP vs OP, Billing Status
            if (isMobile) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      otc['case_number'] ?? otc['ot_case_id'] ?? 'OT Case',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0369A1)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBilled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isBilled ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBilled ? Icons.check_circle : Icons.hourglass_top,
                          size: 13,
                          color: isBilled ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBilled ? 'BILLED • ${otc['invoice_number'] ?? 'Inv'}' : 'PENDING BILLING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isBilled ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      otc['theatre_name'] ?? otc['ot_room'] ?? 'OT',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),
                  if (isIp)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hotel_outlined, size: 12, color: Color(0xFF6D28D9)),
                          const SizedBox(width: 4),
                          Text(
                            'IP Stay (Bed ${otc['admission_bed_number'] ?? '-'})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Day Care / OP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      otc['case_number'] ?? otc['ot_case_id'] ?? 'OT Case',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0369A1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      otc['theatre_name'] ?? otc['ot_room'] ?? 'OT',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isIp)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hotel_outlined, size: 12, color: Color(0xFF6D28D9)),
                          const SizedBox(width: 4),
                          Text(
                            'IP Stay (Bed ${otc['admission_bed_number'] ?? '-'})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Day Care / OP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBilled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isBilled ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBilled ? Icons.check_circle : Icons.hourglass_top,
                          size: 13,
                          color: isBilled ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBilled ? 'BILLED • ${otc['invoice_number'] ?? 'Inv'}' : 'PENDING BILLING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isBilled ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 22, thickness: 1, color: Color(0xFFF1F5F9)),

            // Middle: Patient Details & Surgical Team
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOtPatientSection(otc),
                      const SizedBox(height: 12),
                      _buildOtSurgerySection(otc, pac, pacColor),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildOtPatientSection(otc)),
                      Container(width: 1, height: 75, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 14)),
                      Expanded(flex: 7, child: _buildOtSurgerySection(otc, pac, pacColor)),
                    ],
                  ),
            const SizedBox(height: 14),

            // Itemized Charges Breakdown Wrap
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Surgical Bill', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            Text(
                              '₹${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildFeeChip('Theatre', theatreFee > 0 ? theatreFee : 5000),
                            _buildFeeChip('Surgeon', surgeonFee > 0 ? surgeonFee : 6000),
                            if (otc['assistant_surgeon'] != null && otc['assistant_surgeon'].toString().trim().isNotEmpty)
                              _buildFeeChip('Asst Surgeon', asstFee > 0 ? asstFee : 2000),
                            if (otc['anaesthetist'] != null && otc['anaesthetist'].toString().trim().isNotEmpty)
                              _buildFeeChip('Anaesthesia', anaesthFee > 0 ? anaesthFee : 3000),
                            for (var it in items)
                              if (it['category'] == 'Surgical Consumables' || it['category'] == 'Surgical Implants')
                                Chip(
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  label: Text(
                                    '${it['item_name']}: ₹${it['unit_price']}',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                  ),
                                ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildFeeChip('Theatre', theatreFee > 0 ? theatreFee : 5000),
                              _buildFeeChip('Surgeon', surgeonFee > 0 ? surgeonFee : 6000),
                              if (otc['assistant_surgeon'] != null && otc['assistant_surgeon'].toString().trim().isNotEmpty)
                                _buildFeeChip('Asst Surgeon', asstFee > 0 ? asstFee : 2000),
                              if (otc['anaesthetist'] != null && otc['anaesthetist'].toString().trim().isNotEmpty)
                                _buildFeeChip('Anaesthesia', anaesthFee > 0 ? anaesthFee : 3000),
                              for (var it in items)
                                if (it['category'] == 'Surgical Consumables' || it['category'] == 'Surgical Implants')
                                  Chip(
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    label: Text(
                                      '${it['item_name']}: ₹${it['unit_price']}',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Surgical Bill', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),

            // Actions Row
            isMobile
                ? Column(
                    children: [
                      if (!isBilled) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_note, size: 16),
                                label: const Text('Edit Case Fees'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0284C7),
                                  side: const BorderSide(color: Color(0xFF0284C7)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showEditOtCaseFeesDialog(otc, onUpdated: () => _loadOtBillingCases()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('Generate OT Bill'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showOtBillSettlementDialog(otc),
                              ),
                            ),
                          ],
                        ),
                        if (isIp) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.hotel_outlined, size: 16),
                              label: const Text('Inpatient Folio'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6D28D9),
                                side: const BorderSide(color: Color(0xFF8B5CF6)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showIpdWorksheetDialog(otc['admission_id']),
                            ),
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.receipt_outlined, size: 16),
                                label: const Text('View Invoice'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: const BorderSide(color: AppTheme.primaryColor),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showInvoiceReceiptDialog(otc['invoice_id']),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.print, size: 16),
                                label: const Text('Print Receipt'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _showInvoiceReceiptDialog(otc['invoice_id']),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                : Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!isBilled) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('Edit Case Fees'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showEditOtCaseFeesDialog(otc, onUpdated: () => _loadOtBillingCases()),
                        ),
                        if (isIp)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.hotel_outlined, size: 16),
                            label: const Text('Inpatient Folio'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6D28D9),
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showIpdWorksheetDialog(otc['admission_id']),
                          ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Generate OT Bill'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showOtBillSettlementDialog(otc),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.receipt_outlined, size: 16),
                          label: const Text('View Invoice'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showInvoiceReceiptDialog(otc['invoice_id']),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Print Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showInvoiceReceiptDialog(otc['invoice_id']),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtPatientSection(Map<String, dynamic> otc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                otc['patient_name'] ?? 'Patient',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${otc['patient_age'] ?? '-'} Yrs • ${otc['patient_gender'] ?? '-'} • UHID: ${otc['patient_display_id'] ?? '-'}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          'Phone: ${otc['patient_phone'] ?? '-'}',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildOtSurgerySection(Map<String, dynamic> otc, String pac, Color pacColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                otc['surgery_type'] ?? 'Surgery',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0369A1)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pacColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PAC: $pac',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: pacColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Lead Surgeon: Dr. ${otc['lead_surgeon'] ?? otc['surgeon'] ?? '-'}${otc['anaesthetist'] != null ? ' • Anaesthetist: Dr. ${otc['anaesthetist']}' : ''}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
        ),
        if (otc['assistant_surgeon'] != null && otc['assistant_surgeon'].toString().trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Assistant Surgeon: Dr. ${otc['assistant_surgeon']}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
        ],
      ],
    );
  }

  Widget _buildFeeChip(String label, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        '$label: ₹${amount.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
    );
  }

  // Dedicated MocDoc-Style OT Bill Settlement Dialog
  void _showOtBillSettlementDialog(Map<String, dynamic> otc) {
    final caseId = otc['id'] ?? otc['ot_case_id'];
    if (caseId == null) return;

    final double gross = double.tryParse((otc['subtotal'] ?? 0).toString()) ?? 0.0;
    final TextEditingController discountCtrl = TextEditingController(text: '0');
    final TextEditingController paymentAmtCtrl = TextEditingController(text: gross.toStringAsFixed(2));
    final TextEditingController refCtrl = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (dialogContext, setDlgState) {
            final bool isMobileDialog = MediaQuery.of(dialogContext).size.width < 600;
            final double disc = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
            final double netPayable = (gross - disc) > 0 ? (gross - disc) : 0.0;

            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobileDialog ? 12.0 : 40.0,
                vertical: 24.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generate OT Bill — ${otc['case_number'] ?? 'OT Case'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${otc['patient_name'] ?? 'Patient'} (${otc['patient_display_id'] ?? ''}) • ${otc['surgery_type'] ?? 'Surgery'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? double.maxFinite : 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alert if IP patient
                      if (otc['admission_id'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFF6D28D9)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Patient is currently admitted (Bed ${otc['admission_bed_number'] ?? '-'}). Generating this bill produces a standalone OT invoice.',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF5B21B6), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Financial summary card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text('Total Surgical Gross:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                                Text('₹${gross.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                              ],
                            ),
                            const Divider(height: 14),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text('Net Amount Payable:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                                Text('₹${netPayable.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.secondaryColor)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Discount Input
                      _buildLabel('Special Discount (₹)'),
                      TextFormField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(prefixText: '₹ ', hintText: '0'),
                        onChanged: (val) {
                          final d = double.tryParse(val) ?? 0;
                          final net = (gross - d) > 0 ? (gross - d) : 0.0;
                          paymentAmtCtrl.text = net.toStringAsFixed(2);
                          setDlgState(() {});
                        },
                      ),
                      const SizedBox(height: 14),

                      // Initial Payment Amount
                      _buildLabel('Initial Payment Collected (₹)'),
                      TextFormField(
                        controller: paymentAmtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Enter amount'),
                      ),
                      const SizedBox(height: 14),

                      // Payment Mode & Reference
                      if (isMobileDialog) ...[
                        _buildLabel('Payment Mode'),
                        DropdownButtonFormField<String>(
                          value: paymentMode,
                          isExpanded: true,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                          items: ['Cash', 'UPI', 'Card', 'Net Banking']
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => paymentMode = v);
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildLabel('Txn / Reference ID'),
                        TextFormField(
                          controller: refCtrl,
                          decoration: const InputDecoration(hintText: 'Optional'),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Payment Mode'),
                                  DropdownButtonFormField<String>(
                                    value: paymentMode,
                                    isExpanded: true,
                                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                    items: ['Cash', 'UPI', 'Card', 'Net Banking']
                                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) setDlgState(() => paymentMode = v);
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
                                  _buildLabel('Txn / Reference ID'),
                                  TextFormField(
                                    controller: refCtrl,
                                    decoration: const InputDecoration(hintText: 'Optional'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: isMobileDialog
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isSubmitting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 16),
                          label: const Text('Confirm & Generate Bill'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSubmitting ? null : () async {
                            setDlgState(() => isSubmitting = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(dCtx);

                            final collected = double.tryParse(paymentAmtCtrl.text.trim()) ?? 0.0;
                            final d = double.tryParse(discountCtrl.text.trim()) ?? 0.0;

                            try {
                              final res = await _billingCtrl.createOtCaseInvoice(
                                caseId: caseId,
                                discount: d,
                                initialPayment: collected > 0 ? {
                                  'amount': collected,
                                  'payment_mode': paymentMode,
                                  'transaction_reference': refCtrl.text.trim(),
                                } : null,
                              );

                              if (dCtx.mounted) navigator.pop();
                              if (mounted) {
                                _loadOtBillingCases();
                                _loadInvoices();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('OT Case Bill generated successfully!'), backgroundColor: Colors.green),
                                );
                                if (res['id'] != null) {
                                  _showInvoiceReceiptDialog(res['id']);
                                }
                              }
                            } catch (e) {
                              if (dialogContext.mounted) setDlgState(() => isSubmitting = false);
                              messenger.showSnackBar(SnackBar(content: Text('Error generating bill: $e'), backgroundColor: Colors.red));
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dCtx),
                          style: AppTheme.cancelButton,
                          child: const Text('Cancel'),
                        ),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(dCtx),
                        style: AppTheme.cancelButton,
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        icon: isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 16),
                        label: const Text('Confirm & Generate Bill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: isSubmitting ? null : () async {
                    setDlgState(() => isSubmitting = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dCtx);

                    final collected = double.tryParse(paymentAmtCtrl.text.trim()) ?? 0.0;
                    final d = double.tryParse(discountCtrl.text.trim()) ?? 0.0;

                    try {
                      final res = await _billingCtrl.createOtCaseInvoice(
                        caseId: caseId,
                        discount: d,
                        initialPayment: collected > 0 ? {
                          'amount': collected,
                          'payment_mode': paymentMode,
                          'transaction_reference': refCtrl.text.trim(),
                        } : null,
                      );

                      if (dCtx.mounted) navigator.pop();
                      if (mounted) {
                        _loadOtBillingCases();
                        _loadInvoices();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('OT Case Bill generated successfully!'), backgroundColor: Colors.green),
                        );
                        if (res['id'] != null) {
                          _showInvoiceReceiptDialog(res['id']);
                        }
                      }
                    } catch (e) {
                      if (dialogContext.mounted) setDlgState(() => isSubmitting = false);
                      messenger.showSnackBar(SnackBar(content: Text('Error generating bill: $e'), backgroundColor: Colors.red));
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


  // 4. Services Catalog Tab
  final TextEditingController _svcNameController = TextEditingController();
  final TextEditingController _svcPriceController = TextEditingController();
  final TextEditingController _svcDescController = TextEditingController();
  String _svcCategory = 'General';

  Widget _buildCatalogTab(bool isMobile) {
    final filtered = _catalogServices.where((svc) {
      final q = _catalogSearch.toLowerCase();
      return (svc['name'] ?? '').toString().toLowerCase().contains(q) ||
             (svc['category'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        children: [
          if (isMobile)
            Column(
              children: [
                TextFormField(
                  onChanged: (val) => setState(() => _catalogSearch = val),
                  decoration: InputDecoration(
                    hintText: 'Search catalog by Service Name or Category...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                    filled: true,
                    fillColor: AppTheme.getCardColor(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddServiceDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    onChanged: (val) => setState(() => _catalogSearch = val),
                    decoration: InputDecoration(
                      hintText: 'Search catalog by Service Name or Category...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                      filled: true,
                      fillColor: AppTheme.getCardColor(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddServiceDialog(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingCatalog
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(child: Text('No service items found in catalog.', style: TextStyle(color: Colors.grey.shade500)))
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 3,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final svc = filtered[index];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.borderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                svc['category'],
                                                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 10),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                svc['name'],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          svc['description'] ?? 'No description',
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${double.parse(svc['price'].toString()).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.secondaryColor),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                                        onPressed: () => _showAddServiceDialog(svc),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog(Map<String, dynamic>? service) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final role = user?.role;

    if (service != null) {
      _svcNameController.text = service['name'];
      _svcPriceController.text = service['price'].toString();
      _svcDescController.text = service['description'] ?? '';
      _svcCategory = service['category'];
    } else {
      _svcNameController.clear();
      _svcPriceController.clear();
      _svcDescController.clear();
      _svcCategory = role == 'Lab' ? 'Lab' : 'General';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dIsMobile = MediaQuery.of(context).size.width < 600;
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              insetPadding: EdgeInsets.symmetric(
                horizontal: dIsMobile ? 16 : 24,
                vertical: 24,
              ),
              title: Text(service == null ? 'Add Service Item' : 'Edit Service Item', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: dIsMobile ? double.maxFinite : 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Service Name *'),
                      TextFormField(controller: _svcNameController, decoration: const InputDecoration(hintText: 'e.g. CBC Blood Test')),
                      const SizedBox(height: 16),
                      _buildLabel('Price (₹) *'),
                      TextFormField(controller: _svcPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '0.00')),
                      const SizedBox(height: 16),
                      if (role != 'Lab') ...[
                        _buildLabel('Category *'),
                        CustomDropdownSearch(
                          label: '',
                          value: _svcCategory,
                          dropdownItems: const ['OP', 'IP', 'Home Care', 'OT', 'Lab', 'Pharmacy', 'General'],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => _svcCategory = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildLabel('Description'),
                      TextFormField(controller: _svcDescController, maxLines: 2, decoration: const InputDecoration(hintText: 'Brief details...')),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(onPressed: () => Navigator.pop(ctx), style: AppTheme.cancelButton, child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (_svcNameController.text.trim().isEmpty || _svcPriceController.text.trim().isEmpty) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await _billingCtrl.saveBillingService(
                        name: _svcNameController.text.trim(),
                        category: _svcCategory,
                        price: double.parse(_svcPriceController.text.trim()),
                        description: _svcDescController.text.trim(),
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) _loadCatalog();
                      messenger.showSnackBar(const SnackBar(content: Text('Service saved successfully!'), backgroundColor: Colors.green));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  style: AppTheme.primaryButton,
                  child: const Text('Save'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // ─── IP WORKSHEET & DISCHARGE PANEL ────────────────────────────────────────

  void _openIpBillingWorksheet(Map<String, dynamic> adm) async {
    final int admissionId = adm['id'];

    if (adm['status'] == 'Discharged') {
      // Patients who are already discharged: load invoice receipt dialog directly
      try {
        final res = await _billingCtrl.fetchIpdBillingSummary(admissionId);
        final inv = res['invoice'];
        if (inv != null) {
          _showInvoiceReceiptDialog(inv['id']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No invoice found for this discharged patient'), backgroundColor: Colors.orange));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading invoice: $e'), backgroundColor: Colors.red));
      }
      return;
    }

    // Otherwise, open worksheet dialog for active IP cases
    _showIpdWorksheetDialog(admissionId);
  }

  void _showIpdWorksheetDialog(int admissionId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Map<String, dynamic> admission = {};
        Map<String, dynamic> bedDetails = {};
        Map<String, dynamic> clearances = {};
        Map<String, dynamic> unifiedFolio = {};
        Map<String, dynamic> clinicalData = {};
        Map<String, dynamic>? activeInvoice;
        List<Map<String, dynamic>> advancesPaid = [];
        bool loading = true;

        final TextEditingController ipSvcPriceCtrl = TextEditingController();
        final TextEditingController depositAmtCtrl = TextEditingController();
        final TextEditingController ipSvcQtyCtrl = TextEditingController(text: '1');
        String? selectedSvcId;
        bool fetchInitiated = false;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Future<void> fetchSummary() async {
              try {
                final summary = await _billingCtrl.fetchIpdBillingSummary(admissionId);
                if (sheetCtx.mounted) {
                  setSheetState(() {
                    admission = Map<String, dynamic>.from(summary['admission'] ?? {});
                    bedDetails = Map<String, dynamic>.from(summary['bed_details'] ?? {});
                    clearances = Map<String, dynamic>.from(summary['clearances'] ?? {});
                    unifiedFolio = Map<String, dynamic>.from(summary['unified_folio'] ?? {});
                    clinicalData = Map<String, dynamic>.from(summary['clinical_discharge_data'] ?? {});
                    activeInvoice = summary['invoice'] != null ? Map<String, dynamic>.from(summary['invoice']) : null;
                    advancesPaid = List<Map<String, dynamic>>.from(summary['payments'] ?? []);
                    loading = false;
                  });
                }
              } catch (e) {
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading IP billing: $e'), backgroundColor: Colors.red));
                }
              }
            }

            if (loading) {
              if (!fetchInitiated) {
                fetchInitiated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => fetchSummary());
              }
              return const AlertDialog(
                backgroundColor: Colors.white,
                content: SizedBox(height: 120, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Assembling Unified Inpatient Folio...')]))),
              );
            }

            // Calculation Logic from Unified Folio Totals
            final folioTotals = (unifiedFolio['totals'] as Map<String, dynamic>?) ?? {};
            final int bedDays = bedDetails['days'] as int? ?? (folioTotals['bed_days'] as int? ?? 1);
            final double grossFolioTotal = double.tryParse((folioTotals['gross_total'] ?? 0).toString()) ?? 0.0;
            final double folioDiscount = double.tryParse((folioTotals['discount'] ?? 0).toString()) ?? 0.0;
            final double netFolioTotal = double.tryParse((folioTotals['net_total'] ?? 0).toString()) ?? (grossFolioTotal - folioDiscount);
            final double totalAdvancesPaid = double.tryParse((folioTotals['advance_paid'] ?? 0).toString()) ?? 0.0;
            final double remainingBalance = double.tryParse((folioTotals['balance_due'] ?? 0).toString()) ?? math.max(0.0, netFolioTotal - totalAdvancesPaid);

            final roomCharges = (unifiedFolio['room_charges'] as Map<String, dynamic>?) ?? {};
            final nursingServices = (unifiedFolio['nursing_services'] as Map<String, dynamic>?) ?? {};
            final doctorRounds = (unifiedFolio['doctor_rounds'] as Map<String, dynamic>?) ?? {};
            final pharmacyItems = (unifiedFolio['pharmacy_items'] as Map<String, dynamic>?) ?? {};
            final labInvestigations = (unifiedFolio['lab_investigations'] as Map<String, dynamic>?) ?? {};
            final otCharges = (unifiedFolio['ot_charges'] as Map<String, dynamic>?) ?? {};
            final otherCharges = (unifiedFolio['other_charges'] as Map<String, dynamic>?) ?? {};

            final roomItems = List<Map<String, dynamic>>.from(roomCharges['items'] ?? []);
            final nursingItems = List<Map<String, dynamic>>.from(nursingServices['items'] ?? []);
            final doctorItems = List<Map<String, dynamic>>.from(doctorRounds['items'] ?? []);
            final pharmacyItemsList = List<Map<String, dynamic>>.from(pharmacyItems['items'] ?? []);
            final labItemsList = List<Map<String, dynamic>>.from(labInvestigations['items'] ?? []);
            final otItemsList = List<Map<String, dynamic>>.from(otCharges['items'] ?? []);
            final otCasesList = List<Map<String, dynamic>>.from(otCharges['cases'] ?? []);
            final otherItemsList = List<Map<String, dynamic>>.from(otherCharges['items'] ?? []);

            final pharmacyClr = (clearances['pharmacy'] as Map<String, dynamic>?) ?? {};
            final labClr = (clearances['lab'] as Map<String, dynamic>?) ?? {};
            final nursingClr = (clearances['nursing'] as Map<String, dynamic>?) ?? {};
            final otClr = (clearances['ot'] as Map<String, dynamic>?) ?? {};
            final billingClr = (clearances['billing'] as Map<String, dynamic>?) ?? {};

            final bool isPharmacyCleared = pharmacyClr['is_cleared'] == true;
            final bool isLabCleared = labClr['is_cleared'] == true;
            final bool isNursingCleared = nursingClr['is_cleared'] == true;
            final bool isOtCleared = otClr['is_cleared'] == true;
            final bool isBillingCleared = billingClr['is_cleared'] == true;
            final bool allClearancesPassed = isPharmacyCleared && isLabCleared && isNursingCleared && isOtCleared && isBillingCleared;

            void showPendingItemsDialog(String stageTitle, List<dynamic> pendingList, String notes) {
              showDialog(
                context: ctx,
                builder: (pCtx) => AlertDialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  title: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(stageTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  content: SizedBox(
                    width: 440,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notes, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor)),
                        const SizedBox(height: 14),
                        if (pendingList.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
                                SizedBox(width: 8),
                                Text('All items in this clearance stage are verified!', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          )
                        else ...[
                          const Text('Pending Action Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: pendingList.length,
                              separatorBuilder: (_, _) => const Divider(height: 12),
                              itemBuilder: (_, idx) {
                                final item = pendingList[idx];
                                return Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item is Map ? '${item['name'] ?? item['test_name'] ?? 'Item'} (${item['status'] ?? 'Pending'})' : item.toString(),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(pCtx), child: const Text('Close')),
                  ],
                ),
              );
            }

            final bool isMobileDialog = MediaQuery.of(sheetCtx).size.width < 900;

            final card1 = _buildClearanceItemCard(
              title: '1. Pharmacy',
              statusText: isPharmacyCleared ? 'Cleared' : '${pharmacyClr['pending_count'] ?? 0} Pending',
              isCleared: isPharmacyCleared,
              onTap: () => showPendingItemsDialog('Pharmacy Clearance Details', pharmacyClr['pending_items'] ?? [], pharmacyClr['summary'] ?? ''),
            );
            final card2 = _buildClearanceItemCard(
              title: '2. Lab Tests',
              statusText: isLabCleared ? 'Cleared' : '${labClr['pending_count'] ?? 0} Pending',
              isCleared: isLabCleared,
              onTap: () => showPendingItemsDialog('Laboratory Clearance Details', labClr['pending_items'] ?? [], labClr['summary'] ?? ''),
            );
            final card3 = _buildClearanceItemCard(
              title: '3. Nursing',
              statusText: isNursingCleared ? 'Cleared' : 'Pending',
              isCleared: isNursingCleared,
              onTap: () => showPendingItemsDialog('Nursing Clearance Details', nursingClr['pending_items'] ?? [], nursingClr['summary'] ?? ''),
            );
            final card4 = _buildClearanceItemCard(
              title: '4. OT & Surgery',
              statusText: isOtCleared ? 'Cleared' : '${otClr['pending_count'] ?? 0} Pending',
              isCleared: isOtCleared,
              onTap: () => showPendingItemsDialog('OT & Surgical Clearance Details', otClr['pending_items'] ?? [], otClr['summary'] ?? ''),
            );
            final card5 = _buildClearanceItemCard(
              title: '5. Final Billing',
              statusText: isBillingCleared ? 'Settled' : '₹${remainingBalance.toStringAsFixed(0)} Due',
              isCleared: isBillingCleared,
              onTap: () => showPendingItemsDialog('Billing Clearance Details', isBillingCleared ? [] : ['Outstanding Balance: ₹${remainingBalance.toStringAsFixed(2)}'], billingClr['summary'] ?? ''),
            );

            final List<Widget> leftFolioSections = [

                            // 1. Room Accommodation Charges Card
                            _buildFolioSectionCard(
                              title: 'Room / Accommodation Charges',
                              icon: Icons.hotel,
                              color: const Color(0xFF0284C7),
                              subtotal: double.tryParse((roomCharges['subtotal'] ?? 0).toString()) ?? 0.0,
                              children: [
                                for (var item in roomItems)
                                  _buildFolioItemRow(
                                    name: item['item_name'] ?? 'Bed Charge',
                                    details: item['details'] ?? '',
                                    qty: item['quantity'] ?? bedDays,
                                    price: double.tryParse((item['unit_price'] ?? 0).toString()) ?? 0.0,
                                    subtotal: double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 2. Nursing Services Card
                            _buildFolioSectionCard(
                              title: 'Inpatient Nursing Care Services',
                              icon: Icons.health_and_safety,
                              color: const Color(0xFF059669),
                              subtotal: double.tryParse((nursingServices['subtotal'] ?? 0).toString()) ?? 0.0,
                              children: [
                                for (var item in nursingItems)
                                  _buildFolioItemRow(
                                    name: item['item_name'] ?? 'Nursing Care',
                                    details: item['details'] ?? '',
                                    qty: item['quantity'] ?? bedDays,
                                    price: double.tryParse((item['unit_price'] ?? 0).toString()) ?? 0.0,
                                    subtotal: double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 3. Physician Clinical Rounds Card
                            _buildFolioSectionCard(
                              title: 'Physician Rounds & Consultations',
                              icon: Icons.person_search_outlined,
                              color: const Color(0xFF6366F1),
                              subtotal: double.tryParse((doctorRounds['subtotal'] ?? 0).toString()) ?? 0.0,
                              children: [
                                for (var item in doctorItems)
                                  _buildFolioItemRow(
                                    name: item['item_name'] ?? 'Doctor Round',
                                    details: item['details'] ?? '',
                                    qty: item['quantity'] ?? 1,
                                    price: double.tryParse((item['unit_price'] ?? 0).toString()) ?? 0.0,
                                    subtotal: double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 4. Pharmacy & Inpatient Medications Card
                            _buildFolioSectionCard(
                              title: 'Prescriptions & Pharmacy Items (${pharmacyItemsList.length})',
                              icon: Icons.medication_outlined,
                              color: const Color(0xFF8B5CF6),
                              subtotal: double.tryParse((pharmacyItems['subtotal'] ?? 0).toString()) ?? 0.0,
                              children: [
                                if (pharmacyItemsList.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('No pharmacy items recorded during this stay.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                                  )
                                else
                                  for (var item in pharmacyItemsList)
                                    _buildFolioItemRow(
                                      name: item['item_name'] ?? 'Medicine',
                                      details: item['details'] ?? '',
                                      qty: item['quantity'] ?? 1,
                                      price: double.tryParse((item['unit_price'] ?? 0).toString()) ?? 0.0,
                                      subtotal: double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0,
                                      badge: item['pharmacy_status'] ?? 'Dispensed',
                                      badgeColor: (item['pharmacy_status'] == 'Dispensed' || item['pharmacy_status'] == 'Completed') ? const Color(0xFF059669) : Colors.orange,
                                    ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 5. Diagnostic Laboratory Investigations Card
                            _buildFolioSectionCard(
                              title: 'Diagnostic & Lab Investigations (${labItemsList.length})',
                              icon: Icons.biotech_outlined,
                              color: const Color(0xFFD97706),
                              subtotal: double.tryParse((labInvestigations['subtotal'] ?? 0).toString()) ?? 0.0,
                              children: [
                                if (labItemsList.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('No lab investigations recorded during this stay.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                                  )
                                else
                                  for (var item in labItemsList)
                                    _buildFolioItemRow(
                                      name: item['item_name'] ?? 'Investigation',
                                      details: item['details'] ?? '',
                                      qty: item['quantity'] ?? 1,
                                      price: double.tryParse((item['unit_price'] ?? 0).toString()) ?? 0.0,
                                      subtotal: double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0,
                                      badge: item['status'] ?? 'Report Ready',
                                      badgeColor: ['Completed', 'Report Ready', 'Approved'].contains(item['status']) ? const Color(0xFF059669) : Colors.orange,
                                    ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 5. Operation Theatre & Surgical Charges Card
                            if (otItemsList.isNotEmpty || otCasesList.isNotEmpty) ...[
                              _buildFolioSectionCard(
                                title: 'Operation Theatre & Surgical Charges',
                                icon: Icons.medical_services_outlined,
                                color: const Color(0xFF0284C7),
                                subtotal: double.tryParse((otCharges['subtotal'] ?? 0).toString()) ?? 0.0,
                                children: [
                                  for (var c in otCasesList)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F9FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBAE6FD)),
                                      ),
                                      child: isMobileDialog
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.emergency_outlined, size: 16, color: Color(0xFF0284C7)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '${c['case_number'] ?? 'OT Case'}: ${c['surgery_type'] ?? 'Surgery'}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: c['is_billed'] == true ? Colors.grey.shade200 : const Color(0xFFDCFCE7),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        c['is_billed'] == true ? 'Already Billed' : 'Ready for Folio',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: c['is_billed'] == true ? Colors.grey.shade700 : const Color(0xFF15803D),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Theatre: ${c['theatre_name'] ?? '-'} • Lead Surgeon: Dr. ${c['lead_surgeon'] ?? '-'}${c['anaesthetist'] != null ? ' • Anaesthetist: Dr. ' + c['anaesthetist'] : ''}',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                                ),
                                                if (c['is_billed'] != true) ...[
                                                  const SizedBox(height: 6),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: OutlinedButton.icon(
                                                      icon: const Icon(Icons.edit_note, size: 14),
                                                      label: const Text('Edit Fees', style: TextStyle(fontSize: 11)),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: const Color(0xFF0284C7),
                                                        side: const BorderSide(color: Color(0xFF0284C7)),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                      onPressed: () {
                                                        _showEditOtCaseFeesDialog(c, onUpdated: () {
                                                          fetchSummary();
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                const Icon(Icons.emergency_outlined, size: 16, color: Color(0xFF0284C7)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${c['case_number'] ?? 'OT Case'}: ${c['surgery_type'] ?? 'Surgery'}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                                                      ),
                                                      Text(
                                                        'Theatre: ${c['theatre_name'] ?? '-'} • Lead Surgeon: Dr. ${c['lead_surgeon'] ?? '-'}${c['anaesthetist'] != null ? ' • Anaesthetist: Dr. ' + c['anaesthetist'] : ''}',
                                                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: c['is_billed'] == true ? Colors.grey.shade200 : const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    c['is_billed'] == true ? 'Already Billed' : 'Ready for Folio',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: c['is_billed'] == true ? Colors.grey.shade700 : const Color(0xFF15803D),
                                                    ),
                                                  ),
                                                ),
                                                if (c['is_billed'] != true) ...[
                                                  const SizedBox(width: 8),
                                                  OutlinedButton.icon(
                                                    icon: const Icon(Icons.edit_note, size: 14),
                                                    label: const Text('Edit Fees', style: TextStyle(fontSize: 11)),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: const Color(0xFF0284C7),
                                                      side: const BorderSide(color: Color(0xFF0284C7)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    onPressed: () {
                                                      _showEditOtCaseFeesDialog(c, onUpdated: () {
                                                        fetchSummary();
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                    ),
                                  if (otItemsList.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text('No itemized OT charges recorded for this case.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    )
                                  else
                                    for (var item in otItemsList)
                                      _buildFolioItemRow(
                                        name: item['item_name'] ?? 'OT Charge',
                                        details: item['details'] ?? '',
                                        qty: item['quantity'] ?? 1,
                                        price: double.tryParse((item['unit_price'] ?? 0).toString()) ?? 0.0,
                                        subtotal: double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0,
                                        badge: item['category'] ?? 'OT',
                                        badgeColor: item['category'] == 'Surgical Implants'
                                            ? Colors.purple
                                            : (item['category'] == 'Surgical Consumables' ? Colors.teal : const Color(0xFF0284C7)),
                                      ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            // 6. Procedures, Consumables & Custom Items Card
                            _buildFolioSectionCard(
                              title: 'Procedures, Consumables & Additional Services',
                              icon: Icons.healing_outlined,
                              color: const Color(0xFF475569),
                              subtotal: double.tryParse((otherCharges['subtotal'] ?? 0).toString()) ?? 0.0,
                              children: [
                                // Inline adder form
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F7FB), borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: CustomDropdownSearch(
                                          label: '',
                                          hint: 'Add Service or Consumable',
                                          value: selectedSvcId,
                                          dropdownMap: {
                                            for (var s in _catalogServices.where((x) => x['category'] != 'OP'))
                                              s['id'].toString(): '${s['name']} (₹${s['price']})'
                                          },
                                          onChanged: (val) {
                                            if (val != null) {
                                              final sObj = _catalogServices.firstWhere((x) => x['id'].toString() == val);
                                              setSheetState(() {
                                                selectedSvcId = val;
                                                ipSvcPriceCtrl.text = sObj['price'].toString();
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 80,
                                        height: 48,
                                        child: TextFormField(
                                          controller: ipSvcPriceCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(hintText: 'Price', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 60,
                                        height: 48,
                                        child: TextFormField(
                                          controller: ipSvcQtyCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          decoration: const InputDecoration(hintText: 'Qty', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor, size: 28),
                                        onPressed: () async {
                                          if (selectedSvcId == null) return;
                                          final double pr = double.tryParse(ipSvcPriceCtrl.text) ?? 0.0;
                                          final int qt = int.tryParse(ipSvcQtyCtrl.text) ?? 1;
                                          final sObj = _catalogServices.firstWhere((x) => x['id'].toString() == selectedSvcId);

                                          try {
                                            int invoiceId;
                                            if (activeInvoice == null) {
                                              final newInv = await _billingCtrl.createInvoice(
                                                patientId: admission['patient_id'],
                                                admissionType: 'IP',
                                                admissionId: admissionId,
                                                items: [
                                                  {
                                                    'service_id': sObj['id'],
                                                    'item_name': sObj['name'],
                                                    'quantity': qt,
                                                    'unit_price': pr
                                                  }
                                                ],
                                                discount: 0
                                              );
                                              invoiceId = newInv['id'];
                                            } else {
                                              invoiceId = activeInvoice!['id'];
                                              await _billingCtrl.addInvoiceItem(
                                                invoiceId: invoiceId,
                                                itemName: sObj['name'],
                                                unitPrice: pr,
                                                quantity: qt,
                                                serviceId: sObj['id'],
                                              );
                                            }

                                            setSheetState(() {
                                              selectedSvcId = null;
                                              ipSvcPriceCtrl.clear();
                                              ipSvcQtyCtrl.text = '1';
                                            });

                                            await fetchSummary();
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding item: $e'), backgroundColor: Colors.red));
                                          }
                                        },
                                      )
                                    ],
                                  ),
                                ),

                                if (otherItemsList.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text('No additional consumables or procedures added.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  )
                                else
                                  for (var item in otherItemsList)
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(item['item_name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      subtitle: Text('${item['quantity']} x ₹${double.parse((item['unit_price'] ?? 0).toString()).toStringAsFixed(2)}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('₹${double.parse((item['subtotal'] ?? 0).toString()).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          if (item['id'] != null)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                              onPressed: () async {
                                                try {
                                                  await _billingCtrl.deleteInvoiceItem(item['id']);
                                                  await fetchSummary();
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                              ],
                            ),

            ];

            final List<Widget> rightSummaryWidgets = [

                            // Consolidated Folio Summary Breakdown Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Consolidated Folio Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                                  const SizedBox(height: 12),
                                  _buildSummaryRow('Room Accommodation (${bedDays}d)', double.tryParse((roomCharges['subtotal'] ?? 0).toString()) ?? 0.0),
                                  const SizedBox(height: 6),
                                  _buildSummaryRow('Inpatient Nursing Care', double.tryParse((nursingServices['subtotal'] ?? 0).toString()) ?? 0.0),
                                  const SizedBox(height: 6),
                                  _buildSummaryRow('Physician Rounds', double.tryParse((doctorRounds['subtotal'] ?? 0).toString()) ?? 0.0),
                                  const SizedBox(height: 6),
                                  _buildSummaryRow('Pharmacy & Prescriptions', double.tryParse((pharmacyItems['subtotal'] ?? 0).toString()) ?? 0.0),
                                  const SizedBox(height: 6),
                                  _buildSummaryRow('Diagnostic Labs', double.tryParse((labInvestigations['subtotal'] ?? 0).toString()) ?? 0.0),
                                  const SizedBox(height: 6),
                                  _buildSummaryRow('Consumables & Procedures', double.tryParse((otherCharges['subtotal'] ?? 0).toString()) ?? 0.0),
                                  const Divider(height: 18),
                                  _buildSummaryRow('Gross Folio Total', grossFolioTotal, isBold: true),
                                  const SizedBox(height: 6),
                                  _buildSummaryRow('Discounts', folioDiscount, color: Colors.redAccent),
                                  const Divider(height: 18),
                                  _buildSummaryRow('Net Folio Bill', netFolioTotal, isBold: true, color: AppTheme.primaryColor),
                                  const SizedBox(height: 6),
                                  _buildSummaryRow('Advances & Deposits Paid', totalAdvancesPaid, color: const Color(0xFF059669)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Advance Deposits Section
                            const Text('Advances & Deposits Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: TextFormField(
                                      controller: depositAmtCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(hintText: 'Enter Deposit (₹)', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final double amt = double.tryParse(depositAmtCtrl.text) ?? 0;
                                    if (amt <= 0) return;
                                    try {
                                      int invoiceId;
                                      if (activeInvoice == null) {
                                        final newInv = await _billingCtrl.createInvoice(
                                          patientId: admission['patient_id'],
                                          admissionType: 'IP',
                                          admissionId: admissionId,
                                          items: [],
                                          discount: 0
                                        );
                                        invoiceId = newInv['id'];
                                      } else {
                                        invoiceId = activeInvoice!['id'];
                                      }

                                      await _billingCtrl.recordPayment(
                                        invoiceId: invoiceId,
                                        amount: amt,
                                        paymentMode: 'Cash'
                                      );

                                      depositAmtCtrl.clear();
                                      await fetchSummary();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14)),
                                  child: const Text('Add Deposit'),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (advancesPaid.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Center(child: Text('No advance deposits recorded.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
                              )
                            else
                              Container(
                                constraints: const BoxConstraints(maxHeight: 100),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: advancesPaid.length,
                                  itemBuilder: (payCtx, index) {
                                    final pay = advancesPaid[index];
                                    final date = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(pay['payment_date']).toLocal());
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('₹${double.parse(pay['amount'].toString()).toStringAsFixed(2)} (${pay['payment_mode']})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                          Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const Divider(),
                            const SizedBox(height: 6),

                            // Remaining Balance Due Pill
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: remainingBalance > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: remainingBalance > 0 ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text('Remaining Balance Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${remainingBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: remainingBalance > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Settle & Structured Discharge Action Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                                label: const Text('Proceed to Structured Discharge & Settle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      _openFinalDischargePanel(
                                        admissionId: admissionId,
                                        balance: remainingBalance,
                                        clearances: clearances,
                                        unifiedFolio: unifiedFolio,
                                        clinicalData: clinicalData,
                                        otherItems: otherItemsList,
                                        oldDiscount: folioDiscount,
                                      );
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

            ];

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: isMobileDialog
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 14)
                  : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              titlePadding: isMobileDialog
                  ? const EdgeInsets.fromLTRB(16, 16, 16, 10)
                  : const EdgeInsets.fromLTRB(24, 20, 20, 12),
              contentPadding: isMobileDialog
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unified Inpatient Folio — ${admission['patient_name'] ?? 'Patient'}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobileDialog ? 15 : 18,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'UHID: ${admission['patient_display_id'] ?? '—'}  •  Bed: ${bedDetails['bed_number'] ?? '—'} (${bedDetails['ward_type'] ?? 'Ward'})  •  Doctor: ${admission['doctor_name'] ?? 'Attending Clinician'}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── CLEARANCE STAGES BAR ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Discharge Clearance Workflow:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: allClearancesPassed ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: allClearancesPassed ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                allClearancesPassed ? 'All Clearances Verified ✓' : 'Clearances Pending Review ⚠️',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: allClearancesPassed ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        isMobileDialog
                            ? Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: card1),
                                      const SizedBox(width: 8),
                                      Expanded(child: card2),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(child: card3),
                                      const SizedBox(width: 8),
                                      Expanded(child: card4),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: card5,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: card1),
                                  const SizedBox(width: 8),
                                  Expanded(child: card2),
                                  const SizedBox(width: 8),
                                  Expanded(child: card3),
                                  const SizedBox(width: 8),
                                  Expanded(child: card4),
                                  const SizedBox(width: 8),
                                  Expanded(child: card5),
                                ],
                              ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isMobileDialog ? double.maxFinite : 1040,
                height: MediaQuery.of(sheetCtx).size.height * 0.82,
                child: isMobileDialog
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...leftFolioSections,
                            const SizedBox(height: 16),
                            const Divider(thickness: 1.5, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 16),
                            ...rightSummaryWidgets,
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: leftFolioSections,
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 32),
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: rightSummaryWidgets,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClearanceItemCard({
    required String title,
    required String statusText,
    required bool isCleared,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isCleared ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Icon(
              isCleared ? Icons.check_circle : Icons.warning_amber_rounded,
              size: 16,
              color: isCleared ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCleared ? const Color(0xFF059669) : const Color(0xFFD97706),
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

  // ─── HELPER WIDGETS FOR UNIFIED FOLIO ─────────────────────────────────────

  Widget _buildFolioSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required double subtotal,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B))),
              ),
              Text(
                'Subtotal: ₹${subtotal.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
              ),
            ],
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFolioItemRow({
    required String name,
    required String details,
    required dynamic qty,
    required double price,
    required double subtotal,
    String? badge,
    Color? badgeColor,
    bool? isMobile,
  }) {
    final bool mobile = isMobile ?? (MediaQuery.of(context).size.width < 800);

    if (mobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF1E293B)),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? Colors.blue).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor ?? Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    details.isNotEmpty ? details : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$qty x ₹${price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF1E293B))),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? Colors.blue).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(badge, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor ?? Colors.blue)),
                      ),
                  ],
                ),
                if (details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(details, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$qty x ₹${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 16),
          SizedBox(
            width: 85,
            child: Text(
              '₹${subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STRUCTURED INPATIENT DISCHARGE & FINAL SETTLEMENT PANEL ───────────────

  void _openFinalDischargePanel({
    required int admissionId,
    required double balance,
    required Map<String, dynamic> clearances,
    required Map<String, dynamic> unifiedFolio,
    required Map<String, dynamic> clinicalData,
    required List<Map<String, dynamic>> otherItems,
    required double oldDiscount,
  }) {
    final TextEditingController finalDiagCtrl = TextEditingController(text: clinicalData['final_diagnosis'] ?? clinicalData['provisional_diagnosis'] ?? '');
    final TextEditingController treatmentSumCtrl = TextEditingController(text: clinicalData['treatment_summary'] ?? '');
    final TextEditingController medsPlanCtrl = TextEditingController(text: clinicalData['discharge_medications'] ?? '');
    final TextEditingController instructionsCtrl = TextEditingController(text: clinicalData['discharge_instructions'] ?? '');
    final TextEditingController followUpCtrl = TextEditingController(text: clinicalData['follow_up_date'] ?? '');
    final TextEditingController discCtrl = TextEditingController(text: oldDiscount.toStringAsFixed(0));
    final TextEditingController balancePayCtrl = TextEditingController(text: balance.toStringAsFixed(0));
    final TextEditingController finalRefCtrl = TextEditingController();
    String payMode = 'Cash';

    final pharmacyClr = (clearances['pharmacy'] as Map<String, dynamic>?) ?? {};
    final labClr = (clearances['lab'] as Map<String, dynamic>?) ?? {};
    final nursingClr = (clearances['nursing'] as Map<String, dynamic>?) ?? {};
    final billingClr = (clearances['billing'] as Map<String, dynamic>?) ?? {};

    final bool isPharmacyCleared = pharmacyClr['is_cleared'] == true;
    final bool isLabCleared = labClr['is_cleared'] == true;
    final bool isNursingCleared = nursingClr['is_cleared'] == true;
    final bool isBillingCleared = billingClr['is_cleared'] == true;
    final bool hasPendingClearances = !isPharmacyCleared || !isLabCleared || !isNursingCleared;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) {
            void autoFillFromClinicalData() {
              setDState(() {
                finalDiagCtrl.text = clinicalData['final_diagnosis'] ?? clinicalData['provisional_diagnosis'] ?? '';
                treatmentSumCtrl.text = clinicalData['treatment_summary'] ?? '';
                medsPlanCtrl.text = clinicalData['discharge_medications'] ?? '';
                instructionsCtrl.text = clinicalData['discharge_instructions'] ?? '';
                followUpCtrl.text = clinicalData['follow_up_date'] ?? '';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Clinical discharge summary auto-filled from verified hospital records!'),
                  backgroundColor: Color(0xFF059669),
                  duration: Duration(seconds: 2),
                ),
              );
            }

            final bool isMobileDischarge = MediaQuery.of(dCtx).size.width < 800;
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: isMobileDischarge
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 14)
                  : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              titlePadding: isMobileDischarge
                  ? const EdgeInsets.fromLTRB(16, 16, 16, 10)
                  : const EdgeInsets.fromLTRB(24, 20, 20, 12),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.exit_to_app_rounded, color: AppTheme.dangerColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Structured Discharge Workflow & Settlement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobileDischarge ? 15 : 17,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Patient: ${clinicalData['patient_name'] ?? 'Patient'} (${clinicalData['patient_display_id'] ?? ''}) • Bed: ${clinicalData['bed_number'] ?? ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: isMobileDischarge ? double.maxFinite : 780,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── FOUR CLEARANCES AUDIT STRIP ─────────────────────────
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: hasPendingClearances ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: hasPendingClearances ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  hasPendingClearances ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                  color: hasPendingClearances ? const Color(0xFFD97706) : const Color(0xFF059669),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hasPendingClearances
                                        ? 'Clearance Stage Status: Certain clearances pending clinical sign-off'
                                        : 'All 4 Clearance Stages Cleared (Pharmacy, Lab, Nursing, Final Billing)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: hasPendingClearances ? const Color(0xFF92400E) : const Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildClearanceBadge('Pharmacy', isPharmacyCleared, isPharmacyCleared ? 'Dispensed ✓' : '${pharmacyClr['pending_count']} Pending'),
                                _buildClearanceBadge('Laboratory', isLabCleared, isLabCleared ? 'Reported ✓' : '${labClr['pending_count']} Pending'),
                                _buildClearanceBadge('Nursing', isNursingCleared, isNursingCleared ? 'Signed off ✓' : 'Pending Sign-off'),
                                _buildClearanceBadge('Final Billing', isBillingCleared, isBillingCleared ? 'Settled ✓' : '₹${balance.toStringAsFixed(0)} Due'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ─── CLINICAL DISCHARGE SUMMARY SECTION ──────────────────
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text('Clinical Discharge Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                          TextButton.icon(
                            icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0284C7)),
                            label: Text(
                              isMobileDischarge ? 'Auto-Fill Records' : 'Auto-Fill from Verified Records',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7)),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: autoFillFromClinicalData,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Final Diagnosis Field
                      _buildLabel('Final Diagnosis *'),
                      TextFormField(
                        controller: finalDiagCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Acute appendicitis with localized peritonitis — post laparoscopic appendectomy (resolved)',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Treatment Summary & Clinical Course
                      _buildLabel('Treatment Summary & Clinical Course *'),
                      TextFormField(
                        controller: treatmentSumCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Summary of clinical interventions, operative findings, daily doctor rounds progress, and response to treatment...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Discharge Medications & Regimen
                      _buildLabel('Discharge Medications & Advice'),
                      TextFormField(
                        controller: medsPlanCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Take-home medications with dosage, frequency, route, and duration...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Discharge Instructions & Follow-up Date Row
                      if (isMobileDischarge) ...[
                        _buildLabel('Discharge Care Instructions'),
                        TextFormField(
                          controller: instructionsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Activity restrictions, diet, wound dressing, red-flag symptoms...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildLabel('Follow-up Date'),
                        TextFormField(
                          controller: followUpCtrl,
                          decoration: const InputDecoration(
                            hintText: 'YYYY-MM-DD',
                            prefixIcon: Icon(Icons.calendar_today, size: 16),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Discharge Care Instructions'),
                                  TextFormField(
                                    controller: instructionsCtrl,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      hintText: 'Activity restrictions, diet, wound dressing, red-flag symptoms...',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Follow-up Date'),
                                  TextFormField(
                                    controller: followUpCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'YYYY-MM-DD',
                                      prefixIcon: Icon(Icons.calendar_today, size: 16),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 28),

                      // ─── FINAL BILLING SETTLEMENT SECTION ────────────────────
                      const Text('Final Billing Settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Discount (₹)'),
                                TextFormField(
                                  controller: discCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                  onChanged: (val) {
                                    final d = double.tryParse(val) ?? 0.0;
                                    setDState(() {
                                      balancePayCtrl.text = math.max(0.0, balance - (d - oldDiscount)).toStringAsFixed(0);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isMobileDischarge ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Settlement Amount to Collect (₹)'),
                                TextFormField(
                                  controller: balancePayCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildLabel('Payment Mode'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Cash', 'Card', 'UPI', 'Insurance', 'Cheque'].map((mode) {
                          final selected = payMode == mode;
                          return ChoiceChip(
                            label: Text(mode),
                            selected: selected,
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                            backgroundColor: Colors.grey.shade100,
                            onSelected: (val) {
                              if (val) setDState(() => payMode = mode);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      _buildLabel('Transaction Reference / Receipt Note'),
                      TextFormField(controller: finalRefCtrl, decoration: const InputDecoration(hintText: 'e.g. UPI Ref / Card Auth No / Cheque No / Notes')),
                    ],
                  ),
                ),
              ),
              actions: isMobileDischarge
                  ? [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Confirm Discharge & Final Settle', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.logoRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                        if (finalDiagCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Final Diagnosis is mandatory for certified discharge.'), backgroundColor: Colors.red));
                          return;
                        }
                        if (treatmentSumCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treatment Summary is required for discharge report.'), backgroundColor: Colors.red));
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);

                        try {
                          final discTotal = double.tryParse(discCtrl.text) ?? 0.0;

                          // Flatten all unified folio items across all departments so the complete bill is saved
                          final List<Map<String, dynamic>> consolidatedItems = [];
                          for (var cat in ['room_charges', 'nursing_services', 'doctor_rounds', 'pharmacy_items', 'lab_investigations', 'ot_charges', 'other_charges']) {
                            final catObj = (unifiedFolio[cat] as Map<String, dynamic>?) ?? {};
                            final itemsArr = List<Map<String, dynamic>>.from(catObj['items'] ?? []);
                            for (var it in itemsArr) {
                              consolidatedItems.add({
                                'service_id': it['service_id'],
                                'item_name': it['item_name'],
                                'quantity': it['quantity'] ?? 1,
                                'unit_price': double.tryParse((it['unit_price'] ?? 0).toString()) ?? 0.0,
                                'subtotal': double.tryParse((it['subtotal'] ?? 0).toString()) ?? 0.0,
                              });
                            }
                          }

                          final res = await _billingCtrl.dischargeAndSettleIP(
                            admissionId: admissionId,
                            dischargeSummary: treatmentSumCtrl.text.trim(),
                            finalDiagnosis: finalDiagCtrl.text.trim(),
                            treatmentSummary: treatmentSumCtrl.text.trim(),
                            medicationPlan: medsPlanCtrl.text.trim(),
                            dischargeInstructions: instructionsCtrl.text.trim(),
                            followUpDate: followUpCtrl.text.trim(),
                            clearanceStatuses: clearances,
                            structuredDischargeData: {
                              'clearances': clearances,
                              'clinical_summary': {
                                'final_diagnosis': finalDiagCtrl.text.trim(),
                                'treatment_summary': treatmentSumCtrl.text.trim(),
                                'medication_plan': medsPlanCtrl.text.trim(),
                                'discharge_instructions': instructionsCtrl.text.trim(),
                                'follow_up_date': followUpCtrl.text.trim(),
                              },
                              'folio_totals': unifiedFolio['totals']
                            },
                            items: otherItems.map((x) => {
                              'service_id': x['service_id'],
                              'item_name': x['item_name'],
                              'quantity': x['quantity'] ?? 1,
                              'unit_price': double.parse(x['unit_price'].toString())
                            }).toList(),
                            folioItems: consolidatedItems,
                            discount: discTotal,
                            finalPaymentMode: payMode,
                            transactionReference: finalRefCtrl.text.trim()
                          );

                          if (ctx.mounted) navigator.pop();
                          if (mounted) {
                            _loadIpAdmissions();
                            _loadInvoices();

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Patient successfully discharged! Bed transitioned to Cleaning status. Inpatient folio settled.'),
                                backgroundColor: Color(0xFF059669),
                                duration: Duration(seconds: 3),
                              ),
                            );

                            // Open final invoice receipt dialog with print capability
                            if (res['invoice'] != null && res['invoice']['id'] != null) {
                              _showInvoiceReceiptDialog(res['invoice']['id']);
                            }
                          }
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Error settling discharge: $e'), backgroundColor: Colors.red));
                        }},
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: AppTheme.cancelButton,
                          child: const Text('Back to Worksheet'),
                        ),
                      ),
                    ]
                  : [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: AppTheme.cancelButton,
                            child: const Text('Back to Worksheet'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text('Confirm Discharge & Final Settle', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.logoRed,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                        if (finalDiagCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Final Diagnosis is mandatory for certified discharge.'), backgroundColor: Colors.red));
                          return;
                        }
                        if (treatmentSumCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treatment Summary is required for discharge report.'), backgroundColor: Colors.red));
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);

                        try {
                          final discTotal = double.tryParse(discCtrl.text) ?? 0.0;

                          // Flatten all unified folio items across all departments so the complete bill is saved
                          final List<Map<String, dynamic>> consolidatedItems = [];
                          for (var cat in ['room_charges', 'nursing_services', 'doctor_rounds', 'pharmacy_items', 'lab_investigations', 'ot_charges', 'other_charges']) {
                            final catObj = (unifiedFolio[cat] as Map<String, dynamic>?) ?? {};
                            final itemsArr = List<Map<String, dynamic>>.from(catObj['items'] ?? []);
                            for (var it in itemsArr) {
                              consolidatedItems.add({
                                'service_id': it['service_id'],
                                'item_name': it['item_name'],
                                'quantity': it['quantity'] ?? 1,
                                'unit_price': double.tryParse((it['unit_price'] ?? 0).toString()) ?? 0.0,
                                'subtotal': double.tryParse((it['subtotal'] ?? 0).toString()) ?? 0.0,
                              });
                            }
                          }

                          final res = await _billingCtrl.dischargeAndSettleIP(
                            admissionId: admissionId,
                            dischargeSummary: treatmentSumCtrl.text.trim(),
                            finalDiagnosis: finalDiagCtrl.text.trim(),
                            treatmentSummary: treatmentSumCtrl.text.trim(),
                            medicationPlan: medsPlanCtrl.text.trim(),
                            dischargeInstructions: instructionsCtrl.text.trim(),
                            followUpDate: followUpCtrl.text.trim(),
                            clearanceStatuses: clearances,
                            structuredDischargeData: {
                              'clearances': clearances,
                              'clinical_summary': {
                                'final_diagnosis': finalDiagCtrl.text.trim(),
                                'treatment_summary': treatmentSumCtrl.text.trim(),
                                'medication_plan': medsPlanCtrl.text.trim(),
                                'discharge_instructions': instructionsCtrl.text.trim(),
                                'follow_up_date': followUpCtrl.text.trim(),
                              },
                              'folio_totals': unifiedFolio['totals']
                            },
                            items: otherItems.map((x) => {
                              'service_id': x['service_id'],
                              'item_name': x['item_name'],
                              'quantity': x['quantity'] ?? 1,
                              'unit_price': double.parse(x['unit_price'].toString())
                            }).toList(),
                            folioItems: consolidatedItems,
                            discount: discTotal,
                            finalPaymentMode: payMode,
                            transactionReference: finalRefCtrl.text.trim()
                          );

                          if (ctx.mounted) navigator.pop();
                          if (mounted) {
                            _loadIpAdmissions();
                            _loadInvoices();

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Patient successfully discharged! Bed transitioned to Cleaning status. Inpatient folio settled.'),
                                backgroundColor: Color(0xFF059669),
                                duration: Duration(seconds: 3),
                              ),
                            );

                            // Open final invoice receipt dialog with print capability
                            if (res['invoice'] != null && res['invoice']['id'] != null) {
                              _showInvoiceReceiptDialog(res['invoice']['id']);
                            }
                          }
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Error settling discharge: $e'), backgroundColor: Colors.red));
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildClearanceBadge(String stage, bool isCleared, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCleared ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isCleared ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCleared ? Icons.check : Icons.access_time, size: 12, color: isCleared ? const Color(0xFF059669) : const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text('$stage: $label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCleared ? const Color(0xFF065F46) : const Color(0xFF92400E))),
        ],
      ),
    );
  }

  // ─── INVOICE RECEIPT / PRINT RECEIPT DIALOG ────────────────────────────────

  void _showInvoiceReceiptDialog(dynamic rawInvoiceId) async {
    final int? invoiceId = (rawInvoiceId is int)
        ? rawInvoiceId
        : int.tryParse(rawInvoiceId?.toString() ?? '');

    if (invoiceId == null || invoiceId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice receipt unavailable (missing or invalid invoice ID).'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
      return;
    }

    BillingReceiptDialog.show(
      context,
      invoiceId: invoiceId,
      onPaymentSuccess: _loadInvoices,
    );
  }

  // ─── HOME CARE CONSOLIDATED PATIENT BILL DIALOG (Grouped by Date) ───────────

  void _showHomeCareConsolidatedBillDialog(int patientId, Map<String, dynamic>? fallbackSummary) {
    if (patientId <= 0) return;

    bool showPaymentForm = false;
    String payMode = 'Cash';
    final TextEditingController collectAmtCtrl = TextEditingController();
    final TextEditingController collectRefCtrl = TextEditingController();
    final TextEditingController discountCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) {
        Map<String, dynamic>? billData;
        bool loading = true;
        bool loadInitiated = false;

        return StatefulBuilder(
          builder: (dCtx, setDState) {
            void loadConsolidatedBill() async {
              try {
                final data = await _billingCtrl.fetchHomeCarePatientBill(patientId);
                if (dCtx.mounted) {
                  setDState(() {
                    billData = data;
                    loading = false;
                    final double due = double.tryParse((billData?['balance_due'] ?? 0.0).toString()) ?? 0.0;
                    collectAmtCtrl.text = due.toStringAsFixed(0);
                  });
                }
              } catch (e) {
                if (dCtx.mounted) {
                  setDState(() => loading = false);
                }
              }
            }

            if (!loadInitiated) {
              loadInitiated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => loadConsolidatedBill());
            }

            final data = billData;
            final patient = data?['patient'] ?? (fallbackSummary ?? {});
            final List visits = data?['visits_by_date'] ?? [];
            final List payments = data?['payments'] ?? [];
            final double grandTotal = double.tryParse((data?['total_amount'] ?? fallbackSummary?['total_amount'] ?? 0.0).toString()) ?? 0.0;
            final double grandDiscount = double.tryParse((data?['discount'] ?? fallbackSummary?['discount'] ?? 0.0).toString()) ?? 0.0;
            final double grandNet = double.tryParse((data?['net_amount'] ?? fallbackSummary?['net_amount'] ?? 0.0).toString()) ?? 0.0;
            final double grandPaid = double.tryParse((data?['paid_amount'] ?? fallbackSummary?['paid_amount'] ?? 0.0).toString()) ?? 0.0;
            final double grandDue = double.tryParse((data?['balance_due'] ?? (grandNet - grandPaid)).toString()) ?? (grandNet - grandPaid);
            final String overallStatus = data?['payment_status'] ?? fallbackSummary?['payment_status'] ?? 'Unpaid';
            final bool isFullyPaid = overallStatus == 'Paid' || grandDue <= 0.01;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_rounded, color: AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Home Care Consolidated Bill',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${patient['name'] ?? patient['patient_name'] ?? 'Patient'} (${patient['patient_display_id'] ?? ''}) • ${visits.isNotEmpty ? visits.length : (fallbackSummary?['visit_count'] ?? 1)} Visit Sessions',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  _buildPaymentStatusBadge(overallStatus),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(dCtx).size.width < 700 ? double.maxFinite : 650,
                child: loading
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 16),
                            
                            // Sessions breakdown header
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                const Text(
                                  'Care Sessions & Itemized Details:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${visits.length} Dates Billed',
                                    style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Date-wise cards
                            if (visits.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text('No itemized sessions recorded.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ),
                              ),
                            ] else ...[
                              ...visits.map((v) {
                                final List items = v['items'] ?? [];
                                final String dateStr = v['date'] != null && v['date'].toString().isNotEmpty
                                    ? DateFormat('dd-MMM-yyyy').format(DateTime.tryParse(v['date'].toString()) ?? DateTime.now())
                                    : 'Care Session';
                                final double vNet = double.tryParse(v['net_amount'].toString()) ?? 0.0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Date Banner
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.event_available_outlined, size: 15, color: AppTheme.primaryColor),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Date: $dateStr',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.primaryColor),
                                                    ),
                                                  ],
                                                ),
                                                _buildPaymentStatusBadge(v['payment_status'] ?? 'Unpaid'),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  '• ${v['visit_number'] ?? 'Visit'}',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF334155)),
                                                ),
                                                if (v['nurse_name'] != null && v['nurse_name'].toString().isNotEmpty)
                                                  Text(
                                                    '• Nurse: ${v['nurse_name']}',
                                                    style: const TextStyle(color: AppTheme.nurseColor, fontSize: 11.5, fontWeight: FontWeight.w500),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Itemized Rows
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Column(
                                          children: [
                                            if (items.isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                                child: Text('Visit consultation and general nursing care.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                              )
                                            else
                                              ...items.map((it) {
                                                final qty = it['quantity'] ?? 1;
                                                final price = double.tryParse(it['unit_price'].toString()) ?? 0.0;
                                                final sub = double.tryParse(it['subtotal'].toString()) ?? (qty * price);
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                                  child: Row(
                                                    children: [
                                                      Expanded(child: Text(it['item_name'] ?? 'Item', style: const TextStyle(fontSize: 12.5))),
                                                      const SizedBox(width: 8),
                                                      Text('$qty x ₹${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
                                                      const SizedBox(width: 14),
                                                      Text('₹${sub.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            const Divider(height: 14),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Session Subtotal ($dateStr):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Colors.grey.shade700)),
                                                Text('₹${vNet.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.primaryColor)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],

                            const Divider(height: 20),

                            // Overall Financial Summary
                            _buildSummaryRow('Combined Total Amount', grandTotal),
                            const SizedBox(height: 6),
                            _buildSummaryRow('Combined Discount Offered', grandDiscount, color: Colors.red),
                            const SizedBox(height: 6),
                            _buildSummaryRow('Total Net Amount Due', grandNet, isBold: true, color: AppTheme.primaryColor),
                            const SizedBox(height: 6),
                            _buildSummaryRow('Total Paid Amount', grandPaid, color: Colors.green),
                            const SizedBox(height: 6),
                            _buildSummaryRow('Outstanding Balance Due', grandDue, isBold: true, color: grandDue > 0 ? AppTheme.dangerColor : Colors.green),

                            const Divider(height: 24),

                            // Payment History
                            const Text('Payments Recorded:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                            const SizedBox(height: 8),
                            payments.isEmpty
                                ? Center(child: Text('No payments recorded for this patient yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)))
                                : Column(
                                    children: payments.map((pay) {
                                      final pDate = pay['payment_date'] != null
                                          ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(pay['payment_date']).toLocal())
                                          : 'N/A';
                                      final amt = double.tryParse(pay['amount'].toString()) ?? 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          children: [
                                            Text('₹${amt.toStringAsFixed(2)} (${pay['payment_mode']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '$pDate ${pay['invoice_number'] != null ? "• ${pay['invoice_number']}" : ""}',
                                                textAlign: TextAlign.end,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),

                            // In-Dialog Collect Payment Form
                            if (!isFullyPaid && showPaymentForm) ...[
                              const Divider(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Record Payment on Consolidated Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildLabel('Discount (₹)'),
                                              TextFormField(
                                                controller: discountCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                                onChanged: (val) {
                                                  final double disc = double.tryParse(val) ?? 0.0;
                                                  final double rem = (grandDue - disc).clamp(0.0, double.infinity);
                                                  collectAmtCtrl.text = rem.toStringAsFixed(0);
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
                                              _buildLabel('Amount to Collect (₹) *'),
                                              TextFormField(
                                                controller: collectAmtCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildLabel('Payment Mode'),
                                    Row(
                                      children: ['Cash', 'Card', 'UPI', 'Insurance'].map((mode) {
                                        final sel = payMode == mode;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: ChoiceChip(
                                            label: Text(mode, style: const TextStyle(fontSize: 11.5)),
                                            selected: sel,
                                            selectedColor: AppTheme.primaryColor,
                                            labelStyle: TextStyle(color: sel ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                                            backgroundColor: Colors.grey.shade100,
                                            onSelected: (val) {
                                              if (val) setDState(() => payMode = mode);
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildLabel('Transaction Reference'),
                                    TextFormField(
                                      controller: collectRefCtrl,
                                      decoration: const InputDecoration(hintText: 'Txn Ref / Cheque # (Optional)', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () => setDState(() => showPaymentForm = false),
                                          style: AppTheme.cancelButton,
                                          child: const Text('Cancel'),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton(
                                          style: AppTheme.primaryButton,
                                          onPressed: () async {
                                            final double amt = double.tryParse(collectAmtCtrl.text) ?? 0.0;
                                            if (amt < 0) return;
                                            final double disc = double.tryParse(discountCtrl.text) ?? 0.0;
                                            try {
                                              await _billingCtrl.recordHomeCarePatientPayment(
                                                patientId: patientId,
                                                amount: amt,
                                                paymentMode: payMode,
                                                transactionReference: collectRefCtrl.text.trim(),
                                                discount: disc,
                                              );
                                              if (dCtx.mounted) {
                                                ScaffoldMessenger.of(dCtx).showSnackBar(
                                                  const SnackBar(content: Text('Payment recorded on consolidated home care bill!'), backgroundColor: Colors.green),
                                                );
                                                setDState(() {
                                                  loading = true;
                                                  loadInitiated = false;
                                                  showPaymentForm = false;
                                                });
                                                loadConsolidatedBill();
                                              }
                                              _loadInvoices();
                                            } catch (e) {
                                              if (dCtx.mounted) {
                                                ScaffoldMessenger.of(dCtx).showSnackBar(
                                                  SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerColor),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Submit Payment'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              actions: [
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        fixedSize: const Size.fromHeight(42),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      child: const Text('Close'),
                    ),
                    if (!isFullyPaid && !showPaymentForm)
                      ElevatedButton.icon(
                        onPressed: () {
                          collectAmtCtrl.text = grandDue.toStringAsFixed(0);
                          setDState(() => showPaymentForm = true);
                        },
                        icon: const Icon(Icons.payment, size: 17),
                        label: const Text('Collect Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.white,
                          fixedSize: const Size.fromHeight(42),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          elevation: 0,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final List allItems = [];
                        for (final v in visits) {
                          final vItems = v['items'] as List? ?? [];
                          for (final it in vItems) {
                            allItems.add({
                              'item_name': '${it['item_name'] ?? 'Charge'} (${v['date'] ?? 'Session'})',
                              'quantity': it['quantity'] ?? 1,
                              'unit_price': it['unit_price'] ?? 0,
                            });
                          }
                        }
                        printHospitalReceipt(
                          context: context,
                          invoice: {
                            'invoice_number': data?['invoice_number'] ?? 'CONSOL-HC-${patient['patient_id'] ?? 'BILL'}',
                            'patient_name': patient['name'],
                            'patient_display_id': patient['patient_id'],
                            'patient_phone': patient['phone'],
                            'patient_gender': patient['gender'],
                            'admission_type': 'Home Care (Consolidated)',
                            'total_amount': grandTotal,
                            'discount': grandDiscount,
                            'net_amount': grandNet,
                            'paid_amount': grandPaid,
                            'payment_status': overallStatus,
                            'created_at': DateTime.now().toIso8601String(),
                          },
                          items: allItems,
                          payments: payments,
                        );
                      },
                      icon: const Icon(Icons.print, size: 17),
                      label: const Text('Print Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        fixedSize: const Size.fromHeight(42),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── STYLING HELPERS ───────────────────────────────────────────────────────

  Widget _buildLabel(String label) {
    final bool hasStar = label.endsWith(' *');
    final String baseText = hasStar ? label.substring(0, label.length - 2) : label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: RichText(
        text: TextSpan(
          text: baseText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Inter',
          ),
          children: [
            if (hasStar)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isBold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 15 : 13,
      color: color ?? AppTheme.textPrimaryColor,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 8),
        Text('₹${value.toStringAsFixed(2)}', style: style),
      ],
    );
  }

  Widget _buildPaymentModeWrap(
    String currentMode,
    ValueChanged<String> onSelected, {
    double spacing = 8,
    double? fontSize,
  }) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: ['Cash', 'Card', 'UPI', 'Insurance'].map((mode) {
        final selected = currentMode == mode;
        return ChoiceChip(
          label: Text(mode, style: fontSize != null ? TextStyle(fontSize: fontSize) : null),
          selected: selected,
          selectedColor: AppTheme.primaryColor,
          labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          backgroundColor: Colors.grey.shade100,
          onSelected: (val) {
            if (val) onSelected(mode);
          },
        );
      }).toList(),
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    Color bg;
    Color text;
    if (status == 'Paid') {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF166534);
    } else if (status == 'Partially Paid') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFF92400E);
    } else {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildIpdStatusBadge(String status) {
    Color bg;
    Color text;
    if (status == 'Discharged') {
      bg = const Color(0xFFF3F4F6);
      text = const Color(0xFF374151);
    } else if (status == 'Admitted') {
      bg = const Color(0xFFDBEAFE);
      text = const Color(0xFF1E40AF);
    } else {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFF92400E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  // Home Care Billing Tab for Front Desk & Billing Executives
  Widget _buildHomeCareBillingTab(bool isMobile) {
    // Group all home care invoices by patient to make ONE consolidated bill per patient
    final Map<int, Map<String, dynamic>> patientBillMap = {};
    for (final inv in _invoices) {
      if (inv['admission_type'] != 'HomeVisit') continue;
      final int pid = int.tryParse(inv['patient_id']?.toString() ?? '') ?? 0;
      if (pid <= 0) continue;

      final double net = double.tryParse(inv['net_amount']?.toString() ?? '') ?? 0.0;
      final double paid = double.tryParse(inv['paid_amount']?.toString() ?? '') ?? 0.0;
      final double total = double.tryParse(inv['total_amount']?.toString() ?? '') ?? 0.0;
      final double discount = double.tryParse(inv['discount']?.toString() ?? '') ?? 0.0;

      if (!patientBillMap.containsKey(pid)) {
        patientBillMap[pid] = {
          'patient_id': pid,
          'patient_name': inv['patient_name'] ?? 'Patient',
          'patient_display_id': inv['patient_display_id'] ?? '',
          'patient_phone': inv['patient_phone'] ?? '',
          'nurse_name': inv['nurse_name'],
          'total_amount': total,
          'discount': discount,
          'net_amount': net,
          'paid_amount': paid,
          'visit_count': 1,
          'invoices': [inv],
          'latest_date': inv['created_at'],
          'first_date': inv['created_at'],
        };
      } else {
        final cur = patientBillMap[pid]!;
        cur['total_amount'] = (cur['total_amount'] as double) + total;
        cur['discount'] = (cur['discount'] as double) + discount;
        cur['net_amount'] = (cur['net_amount'] as double) + net;
        cur['paid_amount'] = (cur['paid_amount'] as double) + paid;
        cur['visit_count'] = (cur['visit_count'] as int) + 1;
        (cur['invoices'] as List).add(inv);
        if (inv['created_at'] != null) {
          cur['latest_date'] = inv['created_at'];
        }
      }
    }

    final patientBills = patientBillMap.values.map((bill) {
      final double net = bill['net_amount'] as double;
      final double paid = bill['paid_amount'] as double;
      String status = 'Unpaid';
      if (paid >= net && net > 0) {
        status = 'Paid';
      } else if (paid > 0) {
        status = 'Partially Paid';
      } else if (net == 0) {
        status = 'Paid';
      }
      bill['payment_status'] = status;
      bill['balance_due'] = (net - paid).clamp(0.0, double.infinity);
      return bill;
    }).toList();

    final filteredPatientBills = patientBills.where((bill) {
      final q = _invoiceSearch.toLowerCase();
      final matchQuery = (bill['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
          (bill['patient_display_id'] ?? '').toString().toLowerCase().contains(q) ||
          (bill['invoices'] as List).any((i) => (i['invoice_number'] ?? '').toString().toLowerCase().contains(q));

      if (!matchQuery) return false;

      if (_homeCareStatusFilter == 'Unpaid') {
        return bill['payment_status'] == 'Unpaid' || bill['payment_status'] == 'Partially Paid';
      } else if (_homeCareStatusFilter == 'Paid') {
        return bill['payment_status'] == 'Paid' || bill['payment_status'] == 'Settled';
      }
      return true;
    }).toList();

    final filteredUnbilled = _pendingUnbilledHomeVisits.where((v) {
      final q = _homeCareUnbilledSearch.toLowerCase();
      if (q.isEmpty) return true;
      return (v.patientName ?? '').toLowerCase().contains(q) ||
          (v.patientDisplayId ?? '').toLowerCase().contains(q) ||
          (v.nurseName ?? '').toLowerCase().contains(q) ||
          v.visitNumber.toLowerCase().contains(q) ||
          (v.patientPhone ?? v.phone ?? '').toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Sub-Tab Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _homeCareSubTab = 'Invoiced'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _homeCareSubTab == 'Invoiced' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _homeCareSubTab == 'Invoiced'
                          ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: _homeCareSubTab == 'Invoiced' ? AppTheme.primaryColor : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Invoiced Patients (${filteredPatientBills.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _homeCareSubTab == 'Invoiced' ? AppTheme.primaryColor : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _homeCareSubTab = 'Pending Unbilled'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _homeCareSubTab == 'Pending Unbilled' ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _homeCareSubTab == 'Pending Unbilled'
                          ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pending_actions_outlined,
                          size: 16,
                          color: _homeCareSubTab == 'Pending Unbilled' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pending Unbilled Visits (${_pendingUnbilledHomeVisits.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _homeCareSubTab == 'Pending Unbilled' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content based on sub-tab
          if (_homeCareSubTab == 'Invoiced') ...[
            // Search & Filter Bar
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    onChanged: (val) => setState(() => _invoiceSearch = val),
                    decoration: InputDecoration(
                      hintText: 'Search Home Care Bills by Patient Name, ID, or Invoice #...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 175,
                  child: CustomDropdownSearch(
                    label: '',
                    hint: 'Status: All',
                    value: _homeCareStatusFilter,
                    readOnly: true,
                    fillColor: Colors.white,
                    borderColor: AppTheme.borderColor,
                    borderWidth: 1.0,
                    height: 48,
                    dropdownMap: const {
                      'All': 'Status: All',
                      'Unpaid': 'Status: Unpaid',
                      'Paid': 'Status: Paid',
                    },
                    onChanged: (val) {
                      if (val != null) setState(() => _homeCareStatusFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: () {
                    _loadInvoices();
                    _loadPendingUnbilledHomeVisits();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Invoices List
            Expanded(
              child: _isLoadingInvoices
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPatientBills.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_work_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('No Home Care daily verified invoices found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredPatientBills.length,
                          itemBuilder: (context, index) {
                            final bill = filteredPatientBills[index];
                            final double net = bill['net_amount'] as double;
                            final double paid = bill['paid_amount'] as double;
                            final String pStatus = bill['payment_status'] ?? 'Unpaid';
                            final bool isPaid = pStatus == 'Paid' || pStatus == 'Settled';
                            final int visitCount = bill['visit_count'] as int;

                            String dateSpan = '';
                            if (bill['first_date'] != null && bill['latest_date'] != null) {
                              final d1 = DateFormat('dd-MMM-yyyy').format(DateTime.parse(bill['first_date']).toLocal());
                              final d2 = DateFormat('dd-MMM-yyyy').format(DateTime.parse(bill['latest_date']).toLocal());
                              dateSpan = (d1 == d2) ? d1 : '$d1 to $d2';
                            } else {
                              dateSpan = 'Recent Care';
                            }

                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppTheme.borderColor),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showHomeCareConsolidatedBillDialog(bill['patient_id'] as int, bill),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: isMobile
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.home_work_rounded, color: AppTheme.primaryColor, size: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              '${bill['patient_name']} (${bill['patient_display_id']})',
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.black87),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          _buildPaymentStatusBadge(pStatus),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: visitCount > 1 ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              visitCount > 1 ? '$visitCount Visits Consolidated' : '1 Visit Session',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: visitCount > 1 ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              dateSpan,
                                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (bill['nurse_name'] != null && bill['nurse_name'].toString().isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          'Nurse: ${bill['nurse_name']}',
                                                          style: const TextStyle(fontSize: 12, color: AppTheme.nurseColor, fontWeight: FontWeight.w500),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Total: ₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
                                                Text('Paid: ₹${paid.toStringAsFixed(2)}', style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppTheme.primaryColor,
                                                    side: const BorderSide(color: AppTheme.primaryColor),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.receipt_long, size: 14),
                                                  label: const Text('View Itemized Bill', style: TextStyle(fontSize: 12)),
                                                  onPressed: () => _showHomeCareConsolidatedBillDialog(bill['patient_id'] as int, bill),
                                                ),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF475569),
                                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: const Icon(Icons.print, size: 14),
                                                  label: const Text('Receipt', style: TextStyle(fontSize: 12)),
                                                  onPressed: () => _showHomeCareConsolidatedBillDialog(bill['patient_id'] as int, bill),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.home_work_rounded, color: AppTheme.primaryColor, size: 24),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${bill['patient_name']} (${bill['patient_display_id']})',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: visitCount > 1 ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          visitCount > 1 ? '$visitCount Care Visits' : '1 Care Visit',
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: visitCount > 1 ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      _buildPaymentStatusBadge(pStatus),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Dates: $dateSpan${bill['nurse_name'] != null ? " • Nurse: ${bill['nurse_name']}" : ""}',
                                                    style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Phone: ${bill['patient_phone'] ?? "N/A"}',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryColor)),
                                                Text('Paid: ₹${paid.toStringAsFixed(2)}', style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    OutlinedButton.icon(
                                                      style: AppTheme.outlinedButton,
                                                      icon: const Icon(Icons.receipt_long, size: 14),
                                                      label: const Text('View Itemized Bill', style: TextStyle(fontSize: 12)),
                                                      onPressed: () => _showHomeCareConsolidatedBillDialog(bill['patient_id'] as int, bill),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    OutlinedButton.icon(
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: const Color(0xFF475569),
                                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      ),
                                                      icon: const Icon(Icons.print, size: 14),
                                                      label: const Text('Receipt', style: TextStyle(fontSize: 12)),
                                                      onPressed: () => _showHomeCareConsolidatedBillDialog(bill['patient_id'] as int, bill),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ] else ...[
            // Pending Unbilled Home Visits
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    onChanged: (val) => setState(() => _homeCareUnbilledSearch = val),
                    decoration: InputDecoration(
                      hintText: 'Search Unbilled Visits by Patient Name, ID, Nurse, or Visit #...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondaryColor, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: _loadPendingUnbilledHomeVisits,
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoadingUnbilledVisits
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUnbilled.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                              const SizedBox(height: 12),
                              const Text('All completed home visits are billed!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                              const SizedBox(height: 4),
                              Text('No pending unbilled home care sessions found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredUnbilled.length,
                          itemBuilder: (context, index) {
                            final visit = filteredUnbilled[index];

                            return Card(
                              elevation: 0,
                              color: const Color(0xFFFFFBEB),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: isMobile
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withOpacity(0.25),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.home_work_rounded, color: Color(0xFFB45309), size: 22),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(visit.visitNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E))),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.shade100,
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: Colors.amber.shade400),
                                                          ),
                                                          child: const Text('Unbilled', style: TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.bold)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${visit.patientName ?? "Patient"} (${visit.patientDisplayId ?? ""})',
                                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Nurse: ${visit.nurseName ?? "Unassigned"} • Date: ${visit.scheduledDate}',
                                                      style: const TextStyle(fontSize: 12, color: AppTheme.nurseColor, fontWeight: FontWeight.w500),
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
                                              style: AppTheme.primaryButton,
                                              icon: const Icon(Icons.receipt, size: 16, color: Colors.white),
                                              label: const Text('Generate Bill & Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                              onPressed: () => _generateAndOpenHomeVisitInvoice(visit),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.25),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.home_work_rounded, color: Color(0xFFB45309), size: 24),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(visit.visitNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF92400E))),
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.shade100,
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: Colors.amber.shade400),
                                                      ),
                                                      child: const Text('Unbilled Care Session', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${visit.patientName ?? "Patient"} (${visit.patientDisplayId ?? ""})',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Nurse: ${visit.nurseName ?? "Unassigned"} • Scheduled Date: ${visit.scheduledDate}',
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.nurseColor, fontWeight: FontWeight.w500),
                                                ),
                                                if (visit.attenderName != null && visit.attenderName!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Attender: ${visit.attenderName} (${visit.attenderRelation ?? "Family"})',
                                                    style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            style: AppTheme.primaryButton,
                                            icon: const Icon(Icons.receipt, size: 16, color: Colors.white),
                                            label: const Text('Generate Bill & Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                                            onPressed: () => _generateAndOpenHomeVisitInvoice(visit),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ],
      ),
    );
  }
}
